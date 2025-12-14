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
 * Default location change configuration
 */
export const DEFAULT_LOCATION_CONFIG: LocationChangeConfig = {
  distanceThreshold: 50, // 50 meters
  timeThreshold: 10000, // 10 seconds
  maxLocationAge: 300000 // 5 minutes
};

/**
 * Location service for handling GPS positioning and permission management
 */
export class LocationService {
  private static instance: LocationService;
  private watchId: number | null = null;
  private lastKnownLocation: LocationData | null = null;
  private locationChangeCallback: ((location: LocationData) => void) | null = null;
  private config: LocationChangeConfig;
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();
  private logger = createLogger('LocationService');

  private constructor(config: LocationChangeConfig = DEFAULT_LOCATION_CONFIG) {
    this.config = config;
  }

  /**
   * Get singleton instance of LocationService
   */
  public static getInstance(config?: LocationChangeConfig): LocationService {
    if (!LocationService.instance) {
      LocationService.instance = new LocationService(config);
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
   * Get current GPS position
   * @returns Promise<LocationData> - Current location data
   */
  public async getCurrentPosition(): Promise<LocationData> {
    return new Promise((resolve, reject) => {
      try {
        const requestInfo: geoLocationManager.CurrentLocationRequest = {
          priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
          scenario: geoLocationManager.LocationRequestScenario.UNSET,
          maxAccuracy: 100,
          timeoutMs: 30000
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
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        maxAccuracy: 100,
        timeInterval: this.config.timeThreshold / 1000, // Convert to seconds
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
}