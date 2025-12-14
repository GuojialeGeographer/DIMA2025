import geoLocationManager from '@ohos.geoLocationManager';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { LocationData } from '../models/LocationData';
import { BusinessError } from '@ohos.base';
import { ErrorHandler, ErrorCategory, retryWithBackoff, withTimeout } from '../utils/ErrorHandler';
import { createLogger } from '../utils/Logger';

/**
 * Configuration for location change detection
 */
export interface LocationChangeConfig {
  /** Minimum distance in meters to trigger location change */
  distanceThreshold: number;
  /** Minimum time interval in milliseconds between location updates */
  timeThreshold: number;
  /** Maximum age of cached location in milliseconds */
  maxLocationAge: number;
}

/**
 * Battery optimization configuration for location tracking
 */
export interface BatteryOptimizationConfig {
  /** Enable adaptive location frequency based on movement */
  adaptiveFrequency: boolean;
  /** Reduce accuracy when stationary to save battery */
  reduceAccuracyWhenStationary: boolean;
  /** Maximum location requests per minute */
  maxRequestsPerMinute: number;
  /** Stationary detection threshold in meters */
  stationaryThreshold: number;
  /** Time to consider user stationary in milliseconds */
  stationaryTimeThreshold: number;
  /** Enable background location optimization */
  backgroundOptimization: boolean;
}

/**
 * Default location change configuration
 */
export const DEFAULT_LOCATION_CONFIG: LocationChangeConfig = {
  distanceThreshold: 50, // 50 meters
  timeThreshold: 10000, // 10 seconds
  maxLocationAge: 300000 // 5 minutes
};

/**
 * Default battery optimization configuration
 */
export const DEFAULT_BATTERY_CONFIG: BatteryOptimizationConfig = {
  adaptiveFrequency: true,
  reduceAccuracyWhenStationary: true,
  maxRequestsPerMinute: 6, // Once every 10 seconds max
  stationaryThreshold: 20, // 20 meters
  stationaryTimeThreshold: 120000, // 2 minutes
  backgroundOptimization: true
};

/**
 * Location service for handling GPS positioning and permission management
 * Optimized for battery usage and performance
 */
export class LocationService {
  private static instance: LocationService;
  private watchId: number | null = null;
  private lastKnownLocation: LocationData | null = null;
  private locationChangeCallback: ((location: LocationData) => void) | null = null;
  private config: LocationChangeConfig;
  private batteryConfig: BatteryOptimizationConfig;
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();
  private logger = createLogger('LocationService');
  
  // Battery optimization state
  private locationRequestCount: number = 0;
  private lastRequestTime: number = 0;
  private isStationary: boolean = false;
  private stationaryStartTime: number = 0;
  private locationHistory: LocationData[] = [];
  private currentAccuracyMode: 'high' | 'medium' | 'low' = 'high';

  private constructor(config: LocationChangeConfig = DEFAULT_LOCATION_CONFIG, batteryConfig: BatteryOptimizationConfig = DEFAULT_BATTERY_CONFIG) {
    this.config = config;
    this.batteryConfig = batteryConfig;
  }

  /**
   * Get singleton instance of LocationService
   */
  public static getInstance(config?: LocationChangeConfig, batteryConfig?: BatteryOptimizationConfig): LocationService {
    if (!LocationService.instance) {
      LocationService.instance = new LocationService(config, batteryConfig);
    }
    return LocationService.instance;
  }

  /**
   * Request location permissions from user
   * @returns Promise<boolean> - true if permissions granted, false otherwise
   */
  public async requestPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await globalThis.getContext().getBundleInfo();
      
      // Check if permissions are already granted
      const locationPermission = await atManager.checkAccessToken(
        bundleInfo.appInfo.accessTokenId,
        'ohos.permission.LOCATION'
      );
      
      const approximateLocationPermission = await atManager.checkAccessToken(
        bundleInfo.appInfo.accessTokenId,
        'ohos.permission.APPROXIMATELY_LOCATION'
      );

      if (locationPermission === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
          approximateLocationPermission === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }

      // Request permissions if not granted
      const permissions: Array<Permissions> = [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ];

      const requestResult = await atManager.requestPermissionsFromUser(
        globalThis.getContext(),
        permissions
      );

      // Check if at least one location permission was granted
      return requestResult.authResults.some(result => 
        result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      );
    } catch (error) {
      console.error('LocationService: Permission request failed:', error);
      return false;
    }
  }

  /**
   * Check if location request should be throttled for battery optimization
   */
  private shouldThrottleRequest(): boolean {
    const now = Date.now();
    const timeSinceLastRequest = now - this.lastRequestTime;
    const minInterval = 60000 / this.batteryConfig.maxRequestsPerMinute; // Convert to milliseconds
    
    if (timeSinceLastRequest < minInterval) {
      console.warn('LocationService: Request throttled for battery optimization');
      return true;
    }
    
    this.lastRequestTime = now;
    this.locationRequestCount++;
    
    return false;
  }

  /**
   * Determine optimal accuracy based on movement state
   */
  private getOptimalAccuracy(): geoLocationManager.LocationRequestPriority {
    if (!this.batteryConfig.reduceAccuracyWhenStationary) {
      return geoLocationManager.LocationRequestPriority.ACCURACY;
    }
    
    if (this.isStationary) {
      this.currentAccuracyMode = 'low';
      return geoLocationManager.LocationRequestPriority.LOW_POWER;
    } else if (this.locationHistory.length > 2) {
      // Check movement speed to determine accuracy needs
      const recentMovement = this.calculateRecentMovementSpeed();
      
      if (recentMovement < 1.0) { // Less than 1 m/s (walking speed)
        this.currentAccuracyMode = 'medium';
        return geoLocationManager.LocationRequestPriority.FIRST_FIX;
      }
    }
    
    this.currentAccuracyMode = 'high';
    return geoLocationManager.LocationRequestPriority.ACCURACY;
  }

  /**
   * Calculate recent movement speed for battery optimization
   */
  private calculateRecentMovementSpeed(): number {
    if (this.locationHistory.length < 2) {
      return 0;
    }
    
    const recent = this.locationHistory.slice(-2);
    const distance = this.calculateDistance(
      recent[0].latitude, recent[0].longitude,
      recent[1].latitude, recent[1].longitude
    );
    
    const timeDiff = (recent[1].timestamp - recent[0].timestamp) / 1000; // Convert to seconds
    
    return timeDiff > 0 ? distance / timeDiff : 0;
  }

  /**
   * Update stationary detection for battery optimization
   */
  private updateStationaryDetection(location: LocationData): void {
    if (!this.batteryConfig.adaptiveFrequency) {
      return;
    }
    
    // Add to location history
    this.locationHistory.push(location);
    
    // Keep only recent locations for analysis
    const maxHistorySize = 10;
    if (this.locationHistory.length > maxHistorySize) {
      this.locationHistory = this.locationHistory.slice(-maxHistorySize);
    }
    
    // Check if user is stationary
    if (this.locationHistory.length >= 3) {
      const recentLocations = this.locationHistory.slice(-3);
      let maxDistance = 0;
      
      for (let i = 1; i < recentLocations.length; i++) {
        const distance = this.calculateDistance(
          recentLocations[0].latitude, recentLocations[0].longitude,
          recentLocations[i].latitude, recentLocations[i].longitude
        );
        maxDistance = Math.max(maxDistance, distance);
      }
      
      const wasStationary = this.isStationary;
      this.isStationary = maxDistance < this.batteryConfig.stationaryThreshold;
      
      // Track stationary time
      if (this.isStationary && !wasStationary) {
        this.stationaryStartTime = Date.now();
      } else if (!this.isStationary) {
        this.stationaryStartTime = 0;
      }
      
      console.info(`LocationService: Movement detection - Stationary: ${this.isStationary}, Max distance: ${maxDistance.toFixed(1)}m`);
    }
  }

  /**
   * Get adaptive time interval based on movement state
   */
  private getAdaptiveTimeInterval(): number {
    if (!this.batteryConfig.adaptiveFrequency) {
      return this.config.timeThreshold / 1000; // Convert to seconds
    }
    
    const baseInterval = this.config.timeThreshold / 1000;
    
    if (this.isStationary) {
      const stationaryTime = Date.now() - this.stationaryStartTime;
      
      if (stationaryTime > this.batteryConfig.stationaryTimeThreshold) {
        // Increase interval significantly when stationary for a while
        return Math.min(baseInterval * 4, 60); // Max 1 minute
      } else {
        // Moderate increase when recently stationary
        return baseInterval * 2;
      }
    }
    
    // Normal interval when moving
    return baseInterval;
  }

  /**
   * Get current GPS position
   * Optimized for battery usage
   * @returns Promise<LocationData> - Current location data
   */
  public async getCurrentPosition(): Promise<LocationData> {
    // Check throttling for battery optimization
    if (this.shouldThrottleRequest()) {
      // Return cached location if available and recent
      const cached = this.getLastKnownLocation();
      if (cached) {
        return Promise.resolve(cached);
      }
    }

    return new Promise((resolve, reject) => {
      try {
        const requestInfo: geoLocationManager.CurrentLocationRequest = {
          priority: this.getOptimalAccuracy(),
          scenario: geoLocationManager.LocationRequestScenario.UNSET,
          maxAccuracy: this.currentAccuracyMode === 'low' ? 500 : 
                      this.currentAccuracyMode === 'medium' ? 200 : 100,
          timeoutMs: this.currentAccuracyMode === 'low' ? 15000 : 30000
        };

        geoLocationManager.getCurrentLocation(requestInfo, (err, location) => {
          if (err) {
            console.error('LocationService: Failed to get current location:', err);
            reject(new Error(`Failed to get location: ${err.message}`));
            return;
          }

          if (!location) {
            reject(new Error('Location data is null'));
            return;
          }

          const locationData: LocationData = {
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            timestamp: Date.now(),
            altitude: location.altitude
          };

          // Validate the location data
          if (!this.validateGPSCoordinates(locationData)) {
            reject(new Error('Invalid GPS coordinates received'));
            return;
          }

          this.lastKnownLocation = locationData;
          
          // Update battery optimization state
          this.updateStationaryDetection(locationData);
          
          resolve(locationData);
        });
      } catch (error) {
        console.error('LocationService: getCurrentPosition error:', error);
        reject(error);
      }
    });
  }

  /**
   * Start watching position changes
   * @param callback - Function to call when location changes significantly
   * @returns number - Watch ID for stopping the watch
   */
  public watchPosition(callback: (location: LocationData) => void): number {
    try {
      this.locationChangeCallback = callback;

      const requestInfo: geoLocationManager.LocationRequest = {
        priority: this.getOptimalAccuracy(),
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        maxAccuracy: this.currentAccuracyMode === 'low' ? 500 : 
                    this.currentAccuracyMode === 'medium' ? 200 : 100,
        timeInterval: this.getAdaptiveTimeInterval(),
        distanceInterval: this.config.distanceThreshold
      };

      this.watchId = geoLocationManager.on('locationChange', requestInfo, (location) => {
        if (!location) {
          console.warn('LocationService: Received null location in watch');
          return;
        }

        const locationData: LocationData = {
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          timestamp: Date.now(),
          altitude: location.altitude
        };

        // Validate coordinates
        if (!this.validateGPSCoordinates(locationData)) {
          console.warn('LocationService: Invalid coordinates in watch:', locationData);
          return;
        }

        // Update battery optimization state
        this.updateStationaryDetection(locationData);
        
        // Check if location change is significant
        if (this.isSignificantLocationChange(locationData)) {
          this.lastKnownLocation = locationData;
          callback(locationData);
        }
      });

      return this.watchId;
    } catch (error) {
      console.error('LocationService: Failed to start watching position:', error);
      throw error;
    }
  }

  /**
   * Stop watching position changes
   * @param watchId - The watch ID returned by watchPosition
   */
  public clearWatch(watchId: number): void {
    try {
      if (this.watchId === watchId) {
        geoLocationManager.off('locationChange', watchId);
        this.watchId = null;
        this.locationChangeCallback = null;
      }
    } catch (error) {
      console.error('LocationService: Failed to clear watch:', error);
    }
  }

  /**
   * Get last known location if available and not too old
   * @returns LocationData | null - Last known location or null if unavailable/too old
   */
  public getLastKnownLocation(): LocationData | null {
    if (!this.lastKnownLocation) {
      return null;
    }

    const age = Date.now() - this.lastKnownLocation.timestamp;
    if (age > this.config.maxLocationAge) {
      return null; // Location is too old
    }

    return this.lastKnownLocation;
  }

  /**
   * Validate GPS coordinates for accuracy and range
   * @param location - Location data to validate
   * @returns boolean - true if coordinates are valid
   */
  public validateGPSCoordinates(location: LocationData): boolean {
    // Check latitude range
    if (location.latitude < -90 || location.latitude > 90) {
      return false;
    }

    // Check longitude range
    if (location.longitude < -180 || location.longitude > 180) {
      return false;
    }

    // Check accuracy (should be positive and reasonable)
    if (location.accuracy < 0 || location.accuracy > 10000) {
      return false;
    }

    // Check timestamp (should be recent)
    const age = Date.now() - location.timestamp;
    if (age < 0 || age > 24 * 60 * 60 * 1000) { // Not older than 24 hours
      return false;
    }

    return true;
  }

  /**
   * Check if location change is significant based on distance and time thresholds
   * @param newLocation - New location to compare
   * @returns boolean - true if change is significant
   */
  private isSignificantLocationChange(newLocation: LocationData): boolean {
    if (!this.lastKnownLocation) {
      return true; // First location is always significant
    }

    // Check time threshold
    const timeDiff = newLocation.timestamp - this.lastKnownLocation.timestamp;
    if (timeDiff < this.config.timeThreshold) {
      return false;
    }

    // Calculate distance using Haversine formula
    const distance = this.calculateDistance(
      this.lastKnownLocation.latitude,
      this.lastKnownLocation.longitude,
      newLocation.latitude,
      newLocation.longitude
    );

    return distance >= this.config.distanceThreshold;
  }

  /**
   * Calculate distance between two GPS coordinates using Haversine formula
   * @param lat1 - First latitude
   * @param lon1 - First longitude
   * @param lat2 - Second latitude
   * @param lon2 - Second longitude
   * @returns number - Distance in meters
   */
  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371000; // Earth's radius in meters
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return R * c;
  }

  /**
   * Convert degrees to radians
   * @param degrees - Degrees to convert
   * @returns number - Radians
   */
  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }

  /**
   * Update location change configuration
   * @param config - New configuration
   */
  public updateConfig(config: Partial<LocationChangeConfig>): void {
    this.config = { ...this.config, ...config };
  }

  /**
   * Get current configuration
   * @returns LocationChangeConfig - Current configuration
   */
  public getConfig(): LocationChangeConfig {
    return { ...this.config };
  }

  /**
   * Update battery optimization configuration
   * @param config - New battery optimization configuration
   */
  public updateBatteryConfig(config: Partial<BatteryOptimizationConfig>): void {
    this.batteryConfig = { ...this.batteryConfig, ...config };
    console.info('LocationService: Battery optimization configuration updated');
  }

  /**
   * Get current battery optimization configuration
   * @returns BatteryOptimizationConfig - Current battery configuration
   */
  public getBatteryConfig(): BatteryOptimizationConfig {
    return { ...this.batteryConfig };
  }

  /**
   * Get battery optimization statistics
   * @returns Battery optimization statistics
   */
  public getBatteryStats(): {
    requestCount: number;
    isStationary: boolean;
    stationaryDuration: number;
    currentAccuracyMode: string;
    locationHistorySize: number;
    averageRequestInterval: number;
  } {
    const stationaryDuration = this.isStationary && this.stationaryStartTime > 0 
      ? Date.now() - this.stationaryStartTime 
      : 0;

    const averageInterval = this.locationRequestCount > 1 
      ? (Date.now() - (this.lastRequestTime - (this.locationRequestCount - 1) * 10000)) / this.locationRequestCount
      : 0;

    return {
      requestCount: this.locationRequestCount,
      isStationary: this.isStationary,
      stationaryDuration: stationaryDuration,
      currentAccuracyMode: this.currentAccuracyMode,
      locationHistorySize: this.locationHistory.length,
      averageRequestInterval: averageInterval
    };
  }

  /**
   * Reset battery optimization state
   */
  public resetBatteryOptimization(): void {
    this.locationRequestCount = 0;
    this.lastRequestTime = 0;
    this.isStationary = false;
    this.stationaryStartTime = 0;
    this.locationHistory = [];
    this.currentAccuracyMode = 'high';
    
    console.info('LocationService: Battery optimization state reset');
  }

  /**
   * Enable/disable battery optimization features
   * @param enabled - Whether to enable battery optimization
   */
  public setBatteryOptimizationEnabled(enabled: boolean): void {
    this.batteryConfig.adaptiveFrequency = enabled;
    this.batteryConfig.reduceAccuracyWhenStationary = enabled;
    this.batteryConfig.backgroundOptimization = enabled;
    
    if (!enabled) {
      this.resetBatteryOptimization();
    }
    
    console.info(`LocationService: Battery optimization ${enabled ? 'enabled' : 'disabled'}`);
  }
}