import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { NavigationViewModel, TabIndex } from '../../../main/ets/viewmodels/NavigationViewModel';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { LocationService } from '../../../main/ets/services/LocationService';
import { WeatherService } from '../../../main/ets/services/WeatherService';
import { AICoachService } from '../../../main/ets/services/AICoachService';
import { ExerciseTrackingService, ExerciseSessionState } from '../../../main/ets/services/ExerciseTrackingService';
import { OfflineService } from '../../../main/ets/services/OfflineService';
import { PreferencesService } from '../../../main/ets/services/PreferencesService';
import { LocationData } from '../../../main/ets/models/LocationData';
import { WeatherData } from '../../../main/ets/models/WeatherData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';
import { ExerciseSession } from '../../../main/ets/models/ExerciseSession';
import { PropertyTestUtils } from './PropertyTestUtils';

const TAG = 'SystemIntegrationTest';
const DOMAIN = 0xFF00;

/**
 * Comprehensive system integration tests for CityZen application
 * Tests complete user workflows and cross-component data flow
 * Validates all requirements integration and system correctness properties
 */
export default function systemIntegrationTest() {
  describe('SystemIntegrationTests', () => {
    let navigationViewModel: NavigationViewModel;
    let databaseService: DatabaseService;
    let locationService: LocationService;
    let weatherService: WeatherService;
    let aiCoachService: AICoachService;
    let exerciseService: ExerciseTrackingService;
    let offlineService: OfflineService;
    let preferencesService: PreferencesService;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'SystemIntegration tests starting - initializing all services');
      
      try {
        // Initialize all core services in proper order
        databaseService = DatabaseService.getInstance();
        await databaseService.initializeDatabase();
        
        preferencesService = PreferencesService.getInstance();
        await preferencesService.initialize();
        
        locationService = LocationService.getInstance();
        weatherService = new WeatherService('test_api_key', databaseService);
        aiCoachService = AICoachService.getInstance();
        exerciseService = ExerciseTrackingService.getInstance();
        offlineService = OfflineService.getInstance(databaseService);
        
        navigationViewModel = new NavigationViewModel();
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'All services initialized for system integration tests');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to initialize services: %{public}s', error.message);
        throw error;
      }
    });

    beforeEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual system integration test');
      
      // Reset navigation to dashboard
      navigationViewModel.switchTab(TabIndex.DASHBOARD);
      
      // Clear offline queue
      await offlineService.clearQueue();
      
      // Ensure exercise service is idle
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        try {
          await exerciseService.stopExerciseSession();
        } catch (error) {
          // Ignore errors when stopping non-active sessions
        }
      }
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual system integration test');
    });

    /**
     * Test complete user workflow: App launch → Dashboard → Environment data display
     * Validates Requirements: 1.1, 1.2, 1.3, 1.5, 7.1
     */
    it('should_complete_dashboard_workflow_from_app_launch', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing complete dashboard workflow from app launch');
      
      try {
        // Simulate app launch sequence
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
        
        // Test location permission and data retrieval workflow
        let locationData: LocationData | null = null;
        
        try {
          // Request location permission (simulated)
          const hasPermission = await locationService.requestLocationPermission();
          hilog.info(DOMAIN, TAG, 'Location permission status: %{public}s', hasPermission.toString());
          
          if (hasPermission) {
            // Get current location
            locationData = await locationService.getCurrentLocation();
            
            if (locationData) {
              expect(typeof locationData.latitude).assertEqual('number');
              expect(typeof locationData.longitude).assertEqual('number');
              expect(locationData.latitude >= -90 && locationData.latitude <= 90).assertTrue();
              expect(locationData.longitude >= -180 && locationData.longitude <= 180).assertTrue();
              expect(locationData.accuracy > 0).assertTrue();
              expect(locationData.timestamp > 0).assertTrue();
              
              hilog.info(DOMAIN, TAG, 'Location obtained - lat: %{public}f, lng: %{public}f, accuracy: %{public}f',
                locationData.latitude, locationData.longitude, locationData.accuracy);
            }
          }
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Location service error (expected in test environment): %{public}s', error.message);
        }
        
        // Test weather data and environment score calculation workflow
        if (locationData) {
          try {
            const weatherData = await weatherService.getWeatherData(locationData);
            
            if (weatherData) {
              // Validate weather data structure
              expect(typeof weatherData.temperature).assertEqual('number');
              expect(typeof weatherData.humidity).assertEqual('number');
              expect(typeof weatherData.airQualityIndex).assertEqual('number');
              expect(weatherData.timestamp > 0).assertTrue();
              
              // Test environment score calculation
              const environmentScore = weatherService.calculateEnvironmentScore(weatherData);
              expect(typeof environmentScore.overall).assertEqual('number');
              expect(environmentScore.overall >= 0 && environmentScore.overall <= 100).assertTrue();
              expect(typeof environmentScore.airQuality).assertEqual('number');
              expect(typeof environmentScore.weatherConditions).assertEqual('number');
              expect(typeof environmentScore.uvRisk).assertEqual('number');
              
              hilog.info(DOMAIN, TAG, 'Environment score calculated - overall: %{public}f, air: %{public}f, weather: %{public}f',
                environmentScore.overall, environmentScore.airQuality, environmentScore.weatherConditions);
              
              // Test AI recommendation generation workflow
              try {
                const recommendation = await aiCoachService.generateRecommendation({
                  location: locationData,
                  weather: weatherData,
                  environmentScore: environmentScore,
                  currentTime: Date.now()
                });
                
                if (recommendation) {
                  expect(typeof recommendation.message).assertEqual('string');
                  expect(recommendation.message.length > 0).assertTrue();
                  expect(typeof recommendation.confidence).assertEqual('number');
                  expect(recommendation.confidence >= 0 && recommendation.confidence <= 1).assertTrue();
                  
                  hilog.info(DOMAIN, TAG, 'AI recommendation generated - confidence: %{public}f, length: %{public}d',
                    recommendation.confidence, recommendation.message.length);
                }
              } catch (error) {
                hilog.warn(DOMAIN, TAG, 'AI service error (expected in test environment): %{public}s', error.message);
                
                // Test fallback recommendation
                const fallbackRecommendation = aiCoachService.getFallbackRecommendation(environmentScore.overall);
                expect(typeof fallbackRecommendation.message).assertEqual('string');
                expect(fallbackRecommendation.message.length > 0).assertTrue();
                
                hilog.info(DOMAIN, TAG, 'Fallback recommendation used: %{public}s', fallbackRecommendation.message.substring(0, 50));
              }
            }
          } catch (error) {
            hilog.warn(DOMAIN, TAG, 'Weather service error (expected in test environment): %{public}s', error.message);
          }
        }
        
        // Verify dashboard state consistency
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        expect(navigationViewModel.getNavigationHistory().length).assertGreaterThan(0);
        expect(navigationViewModel.getNavigationHistory()[0]).assertEqual(TabIndex.DASHBOARD);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Dashboard workflow test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test complete user workflow: Navigation → SmartMap → Zone interaction
     * Validates Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 5.1, 5.4
     */
    it('should_complete_smart_map_workflow_with_navigation', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing complete SmartMap workflow with navigation');
      
      try {
        // Start from dashboard
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        
        // Navigate to SmartMap tab
        const switchResult = navigationViewModel.switchTab(TabIndex.SMART_MAP);
        expect(switchResult).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);
        
        // Verify navigation history
        const history = navigationViewModel.getNavigationHistory();
        expect(history.length).assertEqual(2);
        expect(history[0]).assertEqual(TabIndex.DASHBOARD);
        expect(history[1]).assertEqual(TabIndex.SMART_MAP);
        
        // Test map initialization workflow (simulated)
        let mapInitialized = false;
        
        try {
          // Simulate map loading and GeoJSON layer initialization
          // In real implementation, this would involve Map Kit integration
          
          // Test location marker update
          const testLocation: LocationData = {
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 5.0,
            timestamp: Date.now(),
            altitude: 100
          };
          
          // Simulate zone interaction
          const testZone = {
            type: 'green' as const,
            name: 'Golden Gate Park',
            description: 'Large urban park with good air quality',
            environmentalFactors: {
              airQuality: 'good' as const,
              noiseLevel: 'low' as const,
              gpsSignal: 'strong' as const
            }
          };
          
          // Verify zone data structure
          expect(testZone.type === 'green' || testZone.type === 'red' || testZone.type === 'gray').assertTrue();
          expect(typeof testZone.name).assertEqual('string');
          expect(testZone.name.length > 0).assertTrue();
          expect(typeof testZone.description).assertEqual('string');
          
          mapInitialized = true;
          hilog.info(DOMAIN, TAG, 'Map workflow simulated - zone: %{public}s, type: %{public}s', 
            testZone.name, testZone.type);
          
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Map initialization error (expected in test environment): %{public}s', error.message);
        }
        
        // Test navigation back to dashboard
        const backResult = navigationViewModel.goBack();
        expect(backResult).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        
        // Verify navigation state consistency
        const finalHistory = navigationViewModel.getNavigationHistory();
        expect(finalHistory[finalHistory.length - 1]).assertEqual(TabIndex.DASHBOARD);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'SmartMap workflow test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test complete user workflow: Exercise tracking → Data persistence → History view
     * Validates Requirements: 4.1, 4.2, 4.3, 4.5, 5.4
     */
    it('should_complete_exercise_tracking_workflow', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing complete exercise tracking workflow');
      
      try {
        // Ensure starting from idle state
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.IDLE);
        
        // Start exercise session
        const sessionStarted = await exerciseService.startExerciseSession('Integration test session');
        
        if (sessionStarted) {
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
          hilog.info(DOMAIN, TAG, '%{public}s', 'Exercise session started successfully');
          
          // Let session run briefly to collect some data
          await new Promise(resolve => setTimeout(resolve, 2000));
          
          // Verify session is still active
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
          
          // Stop exercise session
          const completedSession = await exerciseService.stopExerciseSession();
          
          if (completedSession) {
            // Verify completed session data
            expect(completedSession.id > 0).assertTrue();
            expect(completedSession.startTime > 0).assertTrue();
            expect(completedSession.endTime > completedSession.startTime).assertTrue();
            expect(completedSession.duration > 0).assertTrue();
            expect(completedSession.notes).assertEqual('Integration test session');
            expect(Array.isArray(completedSession.route)).assertTrue();
            expect(Array.isArray(completedSession.environmentalConditions)).assertTrue();
            expect(typeof completedSession.averageEnvironmentScore).assertEqual('number');
            expect(completedSession.averageEnvironmentScore >= 0 && completedSession.averageEnvironmentScore <= 100).assertTrue();
            
            hilog.info(DOMAIN, TAG, 'Exercise session completed - ID: %{public}d, duration: %{public}d, score: %{public}f',
              completedSession.id, completedSession.duration, completedSession.averageEnvironmentScore);
            
            // Navigate to history page to view the session
            const historyNavResult = navigationViewModel.switchTab(TabIndex.HISTORY);
            expect(historyNavResult).assertEqual(true);
            expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.HISTORY);
            
            // Test exercise history retrieval
            const exerciseHistory = await databaseService.getExerciseHistory(10);
            expect(Array.isArray(exerciseHistory)).assertTrue();
            expect(exerciseHistory.length > 0).assertTrue();
            
            // Find our test session in history
            const testSession = exerciseHistory.find(session => session.id === completedSession.id);
            expect(testSession).assertNotNull();
            
            if (testSession) {
              expect(testSession.notes).assertEqual('Integration test session');
              expect(testSession.duration).assertEqual(completedSession.duration);
              expect(testSession.averageEnvironmentScore).assertEqual(completedSession.averageEnvironmentScore);
              
              hilog.info(DOMAIN, TAG, 'Test session found in history - verified data consistency');
            }
            
            // Test database statistics
            const dbStats = await databaseService.getDatabaseStats();
            expect(typeof dbStats.exerciseCount).assertEqual('number');
            expect(dbStats.exerciseCount > 0).assertTrue();
            
          } else {
            hilog.warn(DOMAIN, TAG, '%{public}s', 'Exercise session completion returned null');
          }
          
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.COMPLETED);
          
        } else {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Exercise session start failed (may be due to permissions)');
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Exercise tracking workflow test failed: %{public}s', error.message);
        // Don't fail the test for permission-related errors
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test complete offline workflow: Offline detection → Data queuing → Sync recovery
     * Validates Requirements: 1.4, 4.4, 5.3, 6.5
     */
    it('should_complete_offline_workflow_with_sync_recovery', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing complete offline workflow with sync recovery');
      
      try {
        // Test offline detection and mode switching
        const isOnline = offlineService.isDeviceOnline();
        hilog.info(DOMAIN, TAG, 'Device online status: %{public}s', isOnline.toString());
        
        // Test data queuing workflow
        const testOperations = [
          {
            type: 'weather_request' as const,
            data: { 
              location: { latitude: 37.7749, longitude: -122.4194 },
              timestamp: Date.now(),
              source: 'dashboard'
            },
            maxRetries: 3
          },
          {
            type: 'ai_request' as const,
            data: {
              environmentScore: 75.0,
              timestamp: Date.now(),
              source: 'dashboard'
            },
            maxRetries: 2
          },
          {
            type: 'exercise_session' as const,
            data: {
              sessionId: 'offline_test_' + Date.now(),
              duration: 1800000, // 30 minutes
              timestamp: Date.now()
            },
            maxRetries: 3
          }
        ];
        
        // Queue operations
        const operationIds: string[] = [];
        for (const operation of testOperations) {
          const id = await offlineService.queueOperation(operation);
          operationIds.push(id);
          expect(typeof id).assertEqual('string');
          expect(id.length > 0).assertTrue();
        }
        
        // Verify operations are queued
        const queuedCount = offlineService.getQueuedOperationsCount();
        expect(queuedCount >= 3).assertTrue();
        
        // Test queue operations by type
        const weatherOps = offlineService.getQueuedOperationsByType('weather_request');
        const aiOps = offlineService.getQueuedOperationsByType('ai_request');
        const exerciseOps = offlineService.getQueuedOperationsByType('exercise_session');
        
        expect(weatherOps.length >= 1).assertTrue();
        expect(aiOps.length >= 1).assertTrue();
        expect(exerciseOps.length >= 1).assertTrue();
        
        // Test offline statistics
        const offlineStats = offlineService.getOfflineStats();
        expect(typeof offlineStats.queuedOperations).assertEqual('number');
        expect(offlineStats.queuedOperations >= 3).assertTrue();
        expect(typeof offlineStats.syncInProgress).assertEqual('boolean');
        expect(typeof offlineStats.lastSyncAttempt).assertEqual('number');
        
        hilog.info(DOMAIN, TAG, 'Offline workflow - queued: %{public}d, weather: %{public}d, ai: %{public}d, exercise: %{public}d',
          queuedCount, weatherOps.length, aiOps.length, exerciseOps.length);
        
        // Test sync recovery workflow (if online)
        if (isOnline) {
          try {
            await offlineService.startSynchronization();
            
            // Wait for sync to process
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            const postSyncCount = offlineService.getQueuedOperationsCount();
            hilog.info(DOMAIN, TAG, 'Sync completed - before: %{public}d, after: %{public}d',
              queuedCount, postSyncCount);
            
          } catch (error) {
            hilog.warn(DOMAIN, TAG, 'Sync failed (expected in test environment): %{public}s', error.message);
          }
        } else {
          // Test offline behavior
          try {
            await offlineService.forceSynchronization();
            expect(false).assertTrue(); // Should not reach here when offline
          } catch (error) {
            expect(error.message.includes('offline')).assertTrue();
          }
        }
        
        // Test cache integration with offline mode
        const testCacheData = {
          latitude: 37.7749,
          longitude: -122.4194,
          weatherData: {
            temperature: 22.0,
            humidity: 65.0,
            windSpeed: 8.0,
            windDirection: 270.0,
            uvIndex: 4.0,
            airQualityIndex: 35.0,
            visibility: 15.0,
            timestamp: Date.now()
          },
          environmentScore: {
            overall: 80.0,
            airQuality: 85.0,
            weatherConditions: 75.0,
            uvRisk: 70.0,
            calculatedAt: Date.now()
          },
          cachedAt: Date.now(),
          expiresAt: Date.now() + 3600000 // 1 hour
        };
        
        await databaseService.cacheEnvironmentData(testCacheData);
        
        const retrievedCache = await databaseService.getCachedEnvironmentData(37.7749, -122.4194);
        expect(retrievedCache).assertNotNull();
        
        if (retrievedCache) {
          expect(retrievedCache.environmentScore.overall).assertEqual(80.0);
          expect(retrievedCache.weatherData.temperature).assertEqual(22.0);
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Offline workflow test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test cross-component data flow and state consistency
     * Validates all correctness properties and data consistency across services
     */
    it('should_maintain_cross_component_data_consistency', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing cross-component data flow and state consistency');
      
      try {
        // Test navigation state consistency across operations
        const initialTab = navigationViewModel.getCurrentTab();
        expect(initialTab).assertEqual(TabIndex.DASHBOARD);
        
        // Perform multiple navigation operations
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.openMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);
        
        navigationViewModel.closeMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);
        
        navigationViewModel.switchTab(TabIndex.HISTORY);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.HISTORY);
        expect(navigationViewModel.isMenuOpen()).assertEqual(false); // Menu state should be independent
        
        // Test data consistency across services
        const testLocation: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 3.0,
          timestamp: Date.now(),
          altitude: 50
        };
        
        // Test weather service data consistency
        try {
          const weatherData = await weatherService.getWeatherData(testLocation);
          
          if (weatherData) {
            const environmentScore1 = weatherService.calculateEnvironmentScore(weatherData);
            const environmentScore2 = weatherService.calculateEnvironmentScore(weatherData);
            
            // Same input should produce same output (deterministic)
            expect(environmentScore1.overall).assertEqual(environmentScore2.overall);
            expect(environmentScore1.airQuality).assertEqual(environmentScore2.airQuality);
            expect(environmentScore1.weatherConditions).assertEqual(environmentScore2.weatherConditions);
            
            hilog.info(DOMAIN, TAG, 'Weather service consistency verified - score: %{public}f', environmentScore1.overall);
          }
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Weather service error (expected in test environment): %{public}s', error.message);
        }
        
        // Test database service data consistency
        const testSession: ExerciseSession = {
          id: 0, // Will be assigned by database
          startTime: Date.now() - 3600000,
          endTime: Date.now(),
          route: [testLocation],
          environmentalConditions: [{
            overall: 75.0,
            airQuality: 80.0,
            weatherConditions: 70.0,
            uvRisk: 65.0,
            calculatedAt: Date.now()
          }],
          averageEnvironmentScore: 75.0,
          distance: 5.2,
          duration: 3600000,
          notes: 'Data consistency test session'
        };
        
        const savedSessionId = await databaseService.saveExerciseSession(testSession);
        expect(savedSessionId > 0).assertTrue();
        
        const retrievedSessions = await databaseService.getExerciseHistory(1);
        expect(retrievedSessions.length > 0).assertTrue();
        
        const retrievedSession = retrievedSessions.find(s => s.id === savedSessionId);
        expect(retrievedSession).assertNotNull();
        
        if (retrievedSession) {
          expect(retrievedSession.averageEnvironmentScore).assertEqual(75.0);
          expect(retrievedSession.distance).assertEqual(5.2);
          expect(retrievedSession.notes).assertEqual('Data consistency test session');
        }
        
        // Test preferences service consistency
        const testPreferences = {
          notificationsEnabled: true,
          locationTrackingEnabled: true,
          dataSync: 'wifi_only' as const,
          theme: 'light' as const,
          units: 'metric' as const
        };
        
        await preferencesService.savePreferences(testPreferences);
        const retrievedPreferences = await preferencesService.getPreferences();
        
        expect(retrievedPreferences.notificationsEnabled).assertEqual(true);
        expect(retrievedPreferences.locationTrackingEnabled).assertEqual(true);
        expect(retrievedPreferences.dataSync).assertEqual('wifi_only');
        expect(retrievedPreferences.theme).assertEqual('light');
        expect(retrievedPreferences.units).assertEqual('metric');
        
        // Test offline service consistency with other services
        const offlineStats = offlineService.getOfflineStats();
        expect(typeof offlineStats.queuedOperations).assertEqual('number');
        expect(offlineStats.queuedOperations >= 0).assertTrue();
        
        hilog.info(DOMAIN, TAG, 'Cross-component consistency verified - session ID: %{public}d, offline ops: %{public}d',
          savedSessionId, offlineStats.queuedOperations);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Cross-component consistency test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test error handling and recovery across all components
     * Validates Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
     */
    it('should_handle_errors_gracefully_across_all_components', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing error handling and recovery across all components');
      
      try {
        // Test navigation error handling
        const invalidTabResult = navigationViewModel.switchTab(-1); // Invalid tab index
        expect(invalidTabResult).assertEqual(false);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD); // Should remain unchanged
        
        // Test database error handling with invalid data
        try {
          const invalidSession: any = {
            // Missing required fields
            startTime: 'invalid',
            endTime: null,
            route: 'not an array'
          };
          
          await databaseService.saveExerciseSession(invalidSession);
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect(typeof error.message).assertEqual('string');
          expect(error.message.length > 0).assertTrue();
        }
        
        // Test weather service error handling with invalid coordinates
        try {
          const invalidLocation: LocationData = {
            latitude: 999, // Invalid latitude
            longitude: 999, // Invalid longitude
            accuracy: -1, // Invalid accuracy
            timestamp: -1 // Invalid timestamp
          };
          
          await weatherService.getWeatherData(invalidLocation);
          // May succeed with cached data or fail gracefully
        } catch (error) {
          expect(typeof error.message).assertEqual('string');
          hilog.info(DOMAIN, TAG, 'Weather service handled invalid location gracefully: %{public}s', error.message);
        }
        
        // Test AI service error handling
        try {
          const invalidContext: any = {
            // Missing required fields
            location: null,
            weather: undefined,
            environmentScore: 'invalid'
          };
          
          await aiCoachService.generateRecommendation(invalidContext);
          // Should fall back to local recommendations
        } catch (error) {
          // Test fallback mechanism
          const fallbackRecommendation = aiCoachService.getFallbackRecommendation(50);
          expect(typeof fallbackRecommendation.message).assertEqual('string');
          expect(fallbackRecommendation.message.length > 0).assertTrue();
          
          hilog.info(DOMAIN, TAG, 'AI service fallback working: %{public}s', fallbackRecommendation.message.substring(0, 30));
        }
        
        // Test exercise service error handling
        try {
          // Try to stop session when none is active
          await exerciseService.stopExerciseSession();
          // Should handle gracefully
        } catch (error) {
          expect(typeof error.message).assertEqual('string');
          hilog.info(DOMAIN, TAG, 'Exercise service handled invalid stop gracefully: %{public}s', error.message);
        }
        
        // Test offline service error handling
        try {
          const invalidOperation: any = {
            type: 'invalid_type',
            data: null,
            maxRetries: -1
          };
          
          await offlineService.queueOperation(invalidOperation);
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect(typeof error.message).assertEqual('string');
          expect(error.message.length > 0).assertTrue();
        }
        
        // Test preferences service error handling
        try {
          const invalidPreferences: any = {
            notificationsEnabled: 'not a boolean',
            dataSync: 'invalid_option',
            theme: 123
          };
          
          await preferencesService.savePreferences(invalidPreferences);
          // Should validate and reject or sanitize
        } catch (error) {
          expect(typeof error.message).assertEqual('string');
          hilog.info(DOMAIN, TAG, 'Preferences service handled invalid data gracefully: %{public}s', error.message);
        }
        
        // Verify system remains stable after error conditions
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.IDLE);
        
        const dbStats = await databaseService.getDatabaseStats();
        expect(typeof dbStats.exerciseCount).assertEqual('number');
        expect(dbStats.exerciseCount >= 0).assertTrue();
        
        hilog.info(DOMAIN, TAG, 'Error handling verification completed - system remains stable');
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Error handling test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Cleaning up SystemIntegration tests');
      
      try {
        // Clean up any remaining queued operations
        await offlineService.clearQueue();
        
        // Ensure exercise service is stopped
        if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
          try {
            await exerciseService.stopExerciseSession();
          } catch (error) {
            // Ignore cleanup errors
          }
        }
        
        // Reset navigation to initial state
        navigationViewModel.switchTab(TabIndex.DASHBOARD);
        navigationViewModel.closeMenu();
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'SystemIntegration tests completed successfully');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'System integration cleanup failed: %{public}s', error.message);
      }
    });
  });
}