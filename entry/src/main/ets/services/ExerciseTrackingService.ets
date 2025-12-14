import { LocationService } from './LocationService';
import { WeatherService } from './WeatherService';
import { DatabaseService } from './DatabaseService';
import { OfflineService } from './OfflineService';
import { LocationData } from '../models/LocationData';
import { EnvironmentScore } from '../models/EnvironmentScore';
import { ExerciseSession, validateExerciseSession } from '../models/ExerciseSession';

/**
 * Exercise session state enumeration
 */
export enum ExerciseSessionState {
  IDLE = 'idle',
  STARTING = 'starting',
  ACTIVE = 'active',
  PAUSING = 'pausing',
  PAUSED = 'paused',
  STOPPING = 'stopping',
  COMPLETED = 'completed'
}

/**
 * Exercise tracking configuration
 */
export interface ExerciseTrackingConfig {
  /** Minimum time between location updates in milliseconds */
  locationUpdateInterval: number;
  /** Minimum distance between recorded points in meters */
  minDistanceBetweenPoints: number;
  /** Environment data collection interval in milliseconds */
  environmentUpdateInterval: number;
  /** Maximum session duration in milliseconds */
  maxSessionDuration: number;
}

/**
 * Default exercise tracking configuration
 */
export const DEFAULT_EXERCISE_CONFIG: ExerciseTrackingConfig = {
  locationUpdateInterval: 5000, // 5 seconds
  minDistanceBetweenPoints: 10, // 10 meters
  environmentUpdateInterval: 30000, // 30 seconds
  maxSessionDuration: 8 * 60 * 60 * 1000 // 8 hours
};

/**
 * Exercise tracking service for managing workout sessions with GPS and environmental data
 */
export class ExerciseTrackingService {
  private static instance: ExerciseTrackingService;
  private locationService: LocationService;
  private weatherService: WeatherService;
  private databaseService: DatabaseService;
  private offlineService: OfflineService;
  private config: ExerciseTrackingConfig;

  // Session state
  private currentState: ExerciseSessionState = ExerciseSessionState.IDLE;
  private currentSession: Partial<ExerciseSession> | null = null;
  private sessionStartTime: number = 0;
  private routePoints: LocationData[] = [];
  private environmentalData: EnvironmentScore[] = [];
  
  // Tracking intervals
  private locationWatchId: number | null = null;
  private environmentTimer: number | null = null;
  
  // Event callbacks
  private stateChangeCallback: ((state: ExerciseSessionState) => void) | null = null;
  private routeUpdateCallback: ((route: LocationData[]) => void) | null = null;
  private environmentUpdateCallback: ((environment: EnvironmentScore[]) => void) | null = null;

  private constructor(config: ExerciseTrackingConfig = DEFAULT_EXERCISE_CONFIG) {
    this.config = config;
    this.locationService = LocationService.getInstance();
    this.databaseService = DatabaseService.getInstance();
    this.weatherService = new WeatherService('demo_api_key', this.databaseService);
    this.offlineService = OfflineService.getInstance(this.databaseService);
  }

  /**
   * Get singleton instance of ExerciseTrackingService
   */
  public static getInstance(config?: ExerciseTrackingConfig): ExerciseTrackingService {
    if (!ExerciseTrackingService.instance) {
      ExerciseTrackingService.instance = new ExerciseTrackingService(config);
    }
    return ExerciseTrackingService.instance;
  }

  /**
   * Start a new exercise session
   * @param notes - Optional notes for the session
   * @returns Promise<boolean> - true if session started successfully
   */
  public async startExerciseSession(notes?: string): Promise<boolean> {
    if (this.currentState !== ExerciseSessionState.IDLE) {
      throw new Error(`Cannot start session in state: ${this.currentState}`);
    }

    try {
      this.setState(ExerciseSessionState.STARTING);

      // Request location permission if needed
      const hasPermission = await this.locationService.requestPermission();
      if (!hasPermission) {
        throw new Error('Location permission required for exercise tracking');
      }

      // Get initial location
      const initialLocation = await this.locationService.getCurrentPosition();
      if (!this.locationService.validateGPSCoordinates(initialLocation)) {
        throw new Error('Invalid initial GPS coordinates');
      }

      // Initialize session data
      this.sessionStartTime = Date.now();
      this.routePoints = [initialLocation];
      this.environmentalData = [];

      this.currentSession = {
        id: 0, // Will be set when saved to database
        startTime: this.sessionStartTime,
        endTime: 0, // Will be set when session ends
        route: this.routePoints,
        environmentalConditions: this.environmentalData,
        averageEnvironmentScore: 0,
        distance: 0,
        duration: 0,
        notes: notes
      };

      // Start location tracking
      this.startLocationTracking();
      
      // Start environment data collection
      this.startEnvironmentTracking();

      this.setState(ExerciseSessionState.ACTIVE);
      return true;

    } catch (error) {
      console.error('ExerciseTrackingService: Failed to start session:', error);
      this.setState(ExerciseSessionState.IDLE);
      return false;
    }
  }

  /**
   * Stop the current exercise session
   * @returns Promise<ExerciseSession | null> - Completed session data or null if failed
   */
  public async stopExerciseSession(): Promise<ExerciseSession | null> {
    if (this.currentState !== ExerciseSessionState.ACTIVE && this.currentState !== ExerciseSessionState.PAUSED) {
      throw new Error(`Cannot stop session in state: ${this.currentState}`);
    }

    try {
      this.setState(ExerciseSessionState.STOPPING);

      // Stop tracking
      this.stopLocationTracking();
      this.stopEnvironmentTracking();

      if (!this.currentSession) {
        throw new Error('No active session to stop');
      }

      // Calculate final session data
      const endTime = Date.now();
      const duration = endTime - this.sessionStartTime;
      const distance = this.calculateTotalDistance(this.routePoints);
      const averageEnvironmentScore = this.calculateAverageEnvironmentScore(this.environmentalData);

      // Create complete session object
      const completedSession: ExerciseSession = {
        id: 0, // Will be set by database
        startTime: this.sessionStartTime,
        endTime: endTime,
        route: [...this.routePoints],
        environmentalConditions: [...this.environmentalData],
        averageEnvironmentScore: averageEnvironmentScore,
        distance: distance,
        duration: duration,
        notes: this.currentSession.notes
      };

      // Validate session data before saving
      if (!this.validateSessionData(completedSession)) {
        throw new Error('Session data validation failed');
      }

      // Save to database
      const sessionId = await this.databaseService.saveExerciseSession(completedSession);
      completedSession.id = sessionId;

      // Queue for sync if offline
      if (!this.offlineService.isDeviceOnline()) {
        await this.offlineService.queueOperation({
          type: 'exercise_session',
          data: completedSession,
          maxRetries: 3
        });
        console.info('Exercise session queued for sync (offline mode)');
      }

      // Reset state
      this.resetSessionState();
      this.setState(ExerciseSessionState.COMPLETED);

      return completedSession;

    } catch (error) {
      console.error('ExerciseTrackingService: Failed to stop session:', error);
      this.setState(ExerciseSessionState.ACTIVE); // Return to active state on error
      return null;
    }
  }

  /**
   * Pause the current exercise session
   */
  public pauseExerciseSession(): boolean {
    if (this.currentState !== ExerciseSessionState.ACTIVE) {
      return false;
    }

    this.setState(ExerciseSessionState.PAUSING);
    this.stopLocationTracking();
    this.stopEnvironmentTracking();
    this.setState(ExerciseSessionState.PAUSED);
    return true;
  }

  /**
   * Resume a paused exercise session
   */
  public async resumeExerciseSession(): Promise<boolean> {
    if (this.currentState !== ExerciseSessionState.PAUSED) {
      return false;
    }

    try {
      // Get current location to resume tracking
      const currentLocation = await this.locationService.getCurrentPosition();
      if (!this.locationService.validateGPSCoordinates(currentLocation)) {
        return false;
      }

      // Add current location to route
      this.routePoints.push(currentLocation);

      // Resume tracking
      this.startLocationTracking();
      this.startEnvironmentTracking();

      this.setState(ExerciseSessionState.ACTIVE);
      return true;

    } catch (error) {
      console.error('ExerciseTrackingService: Failed to resume session:', error);
      return false;
    }
  }

  /**
   * Get current session state
   */
  public getCurrentState(): ExerciseSessionState {
    return this.currentState;
  }

  /**
   * Get current session data (if active)
   */
  public getCurrentSession(): Partial<ExerciseSession> | null {
    if (this.currentState === ExerciseSessionState.IDLE || this.currentState === ExerciseSessionState.COMPLETED) {
      return null;
    }
    
    if (!this.currentSession) {
      return null;
    }

    // Return current session with updated real-time data
    const currentTime = Date.now();
    const currentDistance = this.calculateTotalDistance(this.routePoints);
    const currentAverageScore = this.calculateAverageEnvironmentScore(this.environmentalData);

    return {
      ...this.currentSession,
      route: [...this.routePoints],
      environmentalConditions: [...this.environmentalData],
      distance: currentDistance,
      duration: currentTime - this.sessionStartTime,
      averageEnvironmentScore: currentAverageScore
    };
  }

  /**
   * Set state change callback
   */
  public setStateChangeCallback(callback: (state: ExerciseSessionState) => void): void {
    this.stateChangeCallback = callback;
  }

  /**
   * Set route update callback
   */
  public setRouteUpdateCallback(callback: (route: LocationData[]) => void): void {
    this.routeUpdateCallback = callback;
  }

  /**
   * Set environment update callback
   */
  public setEnvironmentUpdateCallback(callback: (environment: EnvironmentScore[]) => void): void {
    this.environmentUpdateCallback = callback;
  }

  /**
   * Start location tracking
   */
  private startLocationTracking(): void {
    this.locationWatchId = this.locationService.watchPosition((location: LocationData) => {
      if (this.currentState === ExerciseSessionState.ACTIVE) {
        // Check if location change is significant enough to record
        if (this.shouldRecordLocation(location)) {
          this.routePoints.push(location);
          
          // Notify callback
          if (this.routeUpdateCallback) {
            this.routeUpdateCallback([...this.routePoints]);
          }
        }
      }
    });
  }

  /**
   * Stop location tracking
   */
  private stopLocationTracking(): void {
    if (this.locationWatchId !== null) {
      this.locationService.clearWatch(this.locationWatchId);
      this.locationWatchId = null;
    }
  }

  /**
   * Start environment data collection
   */
  private startEnvironmentTracking(): void {
    this.environmentTimer = setInterval(async () => {
      if (this.currentState === ExerciseSessionState.ACTIVE && this.routePoints.length > 0) {
        try {
          const lastLocation = this.routePoints[this.routePoints.length - 1];
          
          // Try to get weather data (will use cache if offline)
          const weatherData = await this.weatherService.getWeatherData(lastLocation);
          
          if (weatherData) {
            const environmentScore = this.weatherService.calculateEnvironmentScore(weatherData);
            this.environmentalData.push(environmentScore);

            // Notify callback
            if (this.environmentUpdateCallback) {
              this.environmentUpdateCallback([...this.environmentalData]);
            }
          } else if (!this.offlineService.isDeviceOnline()) {
            // If offline and no cached data, create a basic environment score
            const basicScore: EnvironmentScore = {
              overall: 50, // Neutral score when no data available
              airQuality: 50,
              weatherConditions: 50,
              uvRisk: 50,
              calculatedAt: Date.now()
            };
            this.environmentalData.push(basicScore);
            
            console.info('Using basic environment score (offline, no cached data)');
          }
        } catch (error) {
          console.warn('ExerciseTrackingService: Failed to collect environment data:', error);
          
          // If we're offline, still record a basic score to maintain data continuity
          if (!this.offlineService.isDeviceOnline()) {
            const fallbackScore: EnvironmentScore = {
              overall: 50,
              airQuality: 50,
              weatherConditions: 50,
              uvRisk: 50,
              calculatedAt: Date.now()
            };
            this.environmentalData.push(fallbackScore);
          }
        }
      }
    }, this.config.environmentUpdateInterval);
  }

  /**
   * Stop environment data collection
   */
  private stopEnvironmentTracking(): void {
    if (this.environmentTimer !== null) {
      clearInterval(this.environmentTimer);
      this.environmentTimer = null;
    }
  }

  /**
   * Check if location should be recorded based on distance threshold
   */
  private shouldRecordLocation(newLocation: LocationData): boolean {
    if (this.routePoints.length === 0) {
      return true;
    }

    const lastLocation = this.routePoints[this.routePoints.length - 1];
    const distance = this.calculateDistance(
      lastLocation.latitude,
      lastLocation.longitude,
      newLocation.latitude,
      newLocation.longitude
    );

    return distance >= this.config.minDistanceBetweenPoints;
  }

  /**
   * Calculate total distance of the route
   */
  private calculateTotalDistance(route: LocationData[]): number {
    if (route.length < 2) {
      return 0;
    }

    let totalDistance = 0;
    for (let i = 1; i < route.length; i++) {
      const distance = this.calculateDistance(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude
      );
      totalDistance += distance;
    }

    return totalDistance / 1000; // Convert to kilometers
  }

  /**
   * Calculate distance between two points using Haversine formula
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
   */
  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }

  /**
   * Calculate average environment score
   */
  private calculateAverageEnvironmentScore(environmentData: EnvironmentScore[]): number {
    if (environmentData.length === 0) {
      return 0;
    }

    const sum = environmentData.reduce((total, score) => total + score.overall, 0);
    return Math.round((sum / environmentData.length) * 100) / 100; // Round to 2 decimal places
  }

  /**
   * Validate session data integrity
   */
  private validateSessionData(session: ExerciseSession): boolean {
    // Use the existing validation function
    if (!validateExerciseSession(session)) {
      return false;
    }

    // Additional validation specific to tracking
    if (session.route.length === 0) {
      console.error('Session validation failed: Empty route');
      return false;
    }

    if (session.duration <= 0) {
      console.error('Session validation failed: Invalid duration');
      return false;
    }

    if (session.distance < 0) {
      console.error('Session validation failed: Negative distance');
      return false;
    }

    // Check that route points are in chronological order
    for (let i = 1; i < session.route.length; i++) {
      if (session.route[i].timestamp < session.route[i - 1].timestamp) {
        console.error('Session validation failed: Route points not in chronological order');
        return false;
      }
    }

    return true;
  }

  /**
   * Set internal state and notify callback
   */
  private setState(newState: ExerciseSessionState): void {
    this.currentState = newState;
    if (this.stateChangeCallback) {
      this.stateChangeCallback(newState);
    }
  }

  /**
   * Reset session state
   */
  private resetSessionState(): void {
    this.currentSession = null;
    this.sessionStartTime = 0;
    this.routePoints = [];
    this.environmentalData = [];
    this.stopLocationTracking();
    this.stopEnvironmentTracking();
  }

  /**
   * Update configuration
   */
  public updateConfig(config: Partial<ExerciseTrackingConfig>): void {
    this.config = { ...this.config, ...config };
  }

  /**
   * Get current configuration
   */
  public getConfig(): ExerciseTrackingConfig {
    return { ...this.config };
  }
}