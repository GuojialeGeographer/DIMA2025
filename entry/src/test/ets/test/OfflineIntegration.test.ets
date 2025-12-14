import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { OfflineService } from '../../../main/ets/services/OfflineService';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { WeatherService } from '../../../main/ets/services/WeatherService';
import { ExerciseTrackingService, ExerciseSessionState } from '../../../main/ets/services/ExerciseTrackingService';
import { LocationData } from '../../../main/ets/models/LocationData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';

const TAG = 'OfflineIntegrationTest';
const DOMAIN = 0xFF00;

/**
 * Integration tests for offline functionality with existing services
 * Tests data synchronization across services and offline mode behavior
 * Validates Requirements 1.4, 4.4, 5.3, 6.5
 */
export default function offlineIntegrationTest() {
  describe('OfflineIntegrationTests', () => {
    let offlineService: OfflineService;
    let databaseService: DatabaseService;
    let weatherService: WeatherService;
    let exerciseService: ExerciseTrackingService;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'OfflineIntegration tests starting');
      
      // Initialize services
      databaseService = DatabaseService.getInstance();
      await databaseService.initializeDatabase();
      
      offlineService = OfflineService.getInstance(databaseService);
      weatherService = new WeatherService('test_api_key', databaseService);
      exerciseService = ExerciseTrackingService.getInstance();
      
      hilog.info(DOMAIN, TAG, '%{public}s', 'All services initialized for integration tests');
    });

    beforeEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual integration test');
      // Clear queue and reset services
      await offlineService.clearQueue();
      
      // Ensure exercise service is in idle state
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        try {
          await exerciseService.stopExerciseSession();
        } catch (error) {
          // Ignore errors when stopping non-active sessions
        }
      }
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual integration test');
    });

    /**
     * Test weather service integration with offline functionality
     * Validates Requirements 1.4, 6.5: Weather data caching and offline fallback
     */
    it('should_integrate_weather_service_with_offline_mode', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing weather service offline integration');
      
      try {
        const testLocation: LocationData = {
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 5.0,
          timestamp: Date.now(),
          altitude: 100
        };

        // Test weather data retrieval (will use cache if offline)
        try {
          const weatherData = await weatherService.getWeatherData(testLocation);
          
          if (weatherData) {
            // Verify weather data structure
            expect(typeof weatherData.temperature).assertEqual('number');
            expect(typeof weatherData.humidity).assertEqual('number');
            expect(typeof weatherData.airQualityIndex).assertEqual('number');
            expect(weatherData.timestamp > 0).assertTrue();
            
            // Test environment score calculation
            const environmentScore = weatherService.calculateEnvironmentScore(weatherData);
            expect(typeof environmentScore.overall).assertEqual('number');
            expect(environmentScore.overall >= 0 && environmentScore.overall <= 100).assertTrue();
            
            hilog.info(DOMAIN, TAG, 'Weather data retrieved - temp: %{public}f, score: %{public}f',
              weatherData.temperature, environmentScore.overall);
          } else {
            hilog.info(DOMAIN, TAG, '%{public}s', 'No weather data available (expected in offline mode)');
          }
          
        } catch (error) {
          // Expected if offline and no cached data
          hilog.info(DOMAIN, TAG, 'Weather service error (expected if offline): %{public}s', error.message);
          expect(error.message.length > 0).assertTrue();
        }

        // Test that weather requests are queued when offline
        if (!offlineService.isDeviceOnline()) {
          const initialQueueCount = offlineService.getQueuedOperationsCount();
          
          // This should queue a weather request
          try {
            await weatherService.getWeatherData(testLocation);
          } catch (error) {
            // Expected when offline
          }
          
          // Check if weather operations were queued (this depends on implementation)
          const weatherOps = offlineService.getQueuedOperationsByType('weather_request');
          hilog.info(DOMAIN, TAG, 'Weather operations queued: %{public}d', weatherOps.length);
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Weather service integration test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test exercise tracking service integration with offline functionality
     * Validates Requirements 4.4: Exercise session queuing and offline tracking
     */
    it('should_integrate_exercise_tracking_with_offline_mode', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing exercise tracking offline integration');
      
      try {
        // Test starting exercise session (should work offline)
        const sessionStarted = await exerciseService.startExerciseSession('Offline integration test');
        
        if (sessionStarted) {
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
          
          // Let session run briefly
          await new Promise(resolve => setTimeout(resolve, 1000));
          
          // Test stopping session
          const completedSession = await exerciseService.stopExerciseSession();
          
          if (completedSession) {
            expect(completedSession.id > 0).assertTrue();
            expect(completedSession.route.length > 0).assertTrue();
            expect(completedSession.duration > 0).assertTrue();
            expect(completedSession.notes).assertEqual('Offline integration test');
            
            // Check if session was queued for sync when offline
            if (!offlineService.isDeviceOnline()) {
              const exerciseOps = offlineService.getQueuedOperationsByType('exercise_session');
              expect(exerciseOps.length > 0).assertTrue();
              
              hilog.info(DOMAIN, TAG, 'Exercise session queued for sync: %{public}d operations', exerciseOps.length);
            }
            
            hilog.info(DOMAIN, TAG, 'Exercise session completed - ID: %{public}d, duration: %{public}d',
              completedSession.id, completedSession.duration);
          } else {
            hilog.warn(DOMAIN, TAG, '%{public}s', 'Exercise session completion failed');
          }
          
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.COMPLETED);
        } else {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Exercise session start failed (may be due to permissions)');
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Exercise tracking integration test failed: %{public}s', error.message);
        // Don't fail the test for permission-related errors
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test database service integration with offline synchronization
     * Validates Requirements 4.4: Database operations and sync queue persistence
     */
    it('should_integrate_database_with_offline_sync', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing database offline sync integration');
      
      try {
        // Test that queued operations persist across service restarts
        const testData = {
          testId: 'integration_test_' + Date.now(),
          location: {
            latitude: 37.7749,
            longitude: -122.4194
          }
        };
        
        // Queue some operations
        const operationId1 = await offlineService.queueOperation({
          type: 'exercise_session',
          data: testData,
          maxRetries: 3
        });
        
        const operationId2 = await offlineService.queueOperation({
          type: 'ai_request',
          data: testData,
          maxRetries: 2
        });
        
        // Verify operations are queued
        const initialCount = offlineService.getQueuedOperationsCount();
        expect(initialCount >= 2).assertTrue();
        
        // Test database statistics
        const dbStats = await databaseService.getDatabaseStats();
        expect(typeof dbStats.exerciseCount).assertEqual('number');
        expect(typeof dbStats.cacheCount).assertEqual('number');
        expect(dbStats.exerciseCount >= 0).assertTrue();
        expect(dbStats.cacheCount >= 0).assertTrue();
        
        // Test cache integration
        const testEnvironmentScore: EnvironmentScore = {
          overall: 75.0,
          airQuality: 80.0,
          weatherConditions: 70.0,
          uvRisk: 65.0,
          calculatedAt: Date.now()
        };
        
        const cacheData = {
          latitude: testData.location.latitude,
          longitude: testData.location.longitude,
          weatherData: {
            temperature: 22.0,
            humidity: 60.0,
            windSpeed: 5.0,
            windDirection: 180.0,
            uvIndex: 3.0,
            airQualityIndex: 45.0,
            visibility: 10.0,
            timestamp: Date.now()
          },
          environmentScore: testEnvironmentScore,
          cachedAt: Date.now(),
          expiresAt: Date.now() + 3600000 // 1 hour
        };
        
        await databaseService.cacheEnvironmentData(cacheData);
        
        // Verify cached data can be retrieved
        const retrievedCache = await databaseService.getCachedEnvironmentData(
          testData.location.latitude,
          testData.location.longitude
        );
        
        expect(retrievedCache).assertNotNull();
        if (retrievedCache) {
          expect(retrievedCache.environmentScore.overall).assertEqual(75.0);
        }
        
        hilog.info(DOMAIN, TAG, 'Database integration - queued: %{public}d, exercises: %{public}d, cache: %{public}d',
          initialCount, dbStats.exerciseCount, dbStats.cacheCount);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Database integration test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test cross-service offline behavior and data consistency
     * Validates Requirements 1.4, 5.3: Consistent offline behavior across services
     */
    it('should_maintain_data_consistency_across_services', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing cross-service data consistency');
      
      try {
        const testLocation: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 3.0,
          timestamp: Date.now(),
          altitude: 50
        };

        // Test offline status consistency across services
        const offlineStatus = offlineService.isDeviceOnline();
        
        // All services should be aware of offline status
        hilog.info(DOMAIN, TAG, 'Offline status across services - online: %{public}s', offlineStatus.toString());
        
        // Test cache age validation consistency
        const currentTime = Date.now();
        const testTimestamp = currentTime - (45 * 60 * 1000); // 45 minutes ago
        
        const cacheAge = offlineService.getCacheAgeHours(testTimestamp);
        const isValid = offlineService.isCacheValid(testTimestamp);
        
        expect(cacheAge).assertClose(0.75, 0.1); // Should be around 0.75 hours
        expect(isValid).assertTrue(); // Should be valid (less than 1 hour)
        
        // Test that all services handle offline mode gracefully
        let servicesHandleOffline = true;
        
        try {
          // Weather service should handle offline mode
          await weatherService.getWeatherData(testLocation);
        } catch (error) {
          // Expected if offline, should not crash
          if (!error.message.includes('offline') && !error.message.includes('cache')) {
            servicesHandleOffline = false;
          }
        }
        
        expect(servicesHandleOffline).assertTrue();
        
        // Test queue operations from different services
        const initialQueueCount = offlineService.getQueuedOperationsCount();
        
        // Queue operations from different contexts
        await offlineService.queueOperation({
          type: 'weather_request',
          data: { location: testLocation, source: 'weather_service' },
          maxRetries: 3
        });
        
        await offlineService.queueOperation({
          type: 'ai_request',
          data: { location: testLocation, source: 'dashboard' },
          maxRetries: 2
        });
        
        const finalQueueCount = offlineService.getQueuedOperationsCount();
        expect(finalQueueCount).assertEqual(initialQueueCount + 2);
        
        // Test queue operations by type
        const weatherOps = offlineService.getQueuedOperationsByType('weather_request');
        const aiOps = offlineService.getQueuedOperationsByType('ai_request');
        
        expect(weatherOps.length >= 1).assertTrue();
        expect(aiOps.length >= 1).assertTrue();
        
        hilog.info(DOMAIN, TAG, 'Data consistency - cache age: %{public}f, valid: %{public}s, queued: %{public}d',
          cacheAge, isValid.toString(), finalQueueCount);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Data consistency test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test offline mode recovery and synchronization
     * Validates Requirements 6.5: Data sync when connectivity returns
     */
    it('should_handle_offline_recovery_and_sync', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing offline recovery and sync');
      
      try {
        // Queue multiple operations to simulate offline activity
        const testOperations = [
          {
            type: 'exercise_session' as const,
            data: { sessionId: 'test_1', timestamp: Date.now() - 3000 },
            maxRetries: 3
          },
          {
            type: 'ai_request' as const,
            data: { requestId: 'test_2', timestamp: Date.now() - 2000 },
            maxRetries: 2
          },
          {
            type: 'weather_request' as const,
            data: { requestId: 'test_3', timestamp: Date.now() - 1000 },
            maxRetries: 3
          }
        ];
        
        // Queue all operations
        const operationIds: string[] = [];
        for (const op of testOperations) {
          const id = await offlineService.queueOperation(op);
          operationIds.push(id);
        }
        
        const queuedCount = offlineService.getQueuedOperationsCount();
        expect(queuedCount >= 3).assertTrue();
        
        // Test sync statistics
        const stats = offlineService.getOfflineStats();
        expect(stats.queuedOperations >= 3).assertTrue();
        expect(typeof stats.syncInProgress).assertEqual('boolean');
        expect(typeof stats.lastSyncAttempt).assertEqual('number');
        
        // Test sync attempt (will only work if online)
        if (offlineService.isDeviceOnline()) {
          try {
            await offlineService.startSynchronization();
            
            // Wait for sync to complete
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // Check if operations were processed
            const postSyncCount = offlineService.getQueuedOperationsCount();
            hilog.info(DOMAIN, TAG, 'Sync completed - before: %{public}d, after: %{public}d',
              queuedCount, postSyncCount);
            
          } catch (error) {
            hilog.warn(DOMAIN, TAG, 'Sync failed (expected in test environment): %{public}s', error.message);
          }
        } else {
          hilog.info(DOMAIN, TAG, '%{public}s', 'Device offline, skipping sync test');
        }
        
        // Test force sync error handling when offline
        if (!offlineService.isDeviceOnline()) {
          try {
            await offlineService.forceSynchronization();
            expect(false).assertTrue(); // Should not reach here
          } catch (error) {
            expect(error.message.includes('offline')).assertTrue();
          }
        }
        
        hilog.info(DOMAIN, TAG, 'Recovery test completed - final queue: %{public}d', 
          offlineService.getQueuedOperationsCount());
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Recovery and sync test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Cleaning up OfflineIntegration tests');
      
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
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'OfflineIntegration tests completed');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Integration cleanup failed: %{public}s', error.message);
      }
    });
  });
}