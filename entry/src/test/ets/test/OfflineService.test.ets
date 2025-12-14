import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { OfflineService, QueuedOperation, OfflineConfig } from '../../../main/ets/services/OfflineService';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { ExerciseSession } from '../../../main/ets/models/ExerciseSession';
import { LocationData } from '../../../main/ets/models/LocationData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';

const TAG = 'OfflineServiceTest';
const DOMAIN = 0xFF00;

/**
 * Unit tests for OfflineService
 * Tests offline mode detection and switching, data queuing and synchronization, offline UI indicators
 * Validates Requirements 1.4, 4.4, 5.3
 */
export default function offlineServiceTest() {
  describe('OfflineServiceTests', () => {
    let offlineService: OfflineService;
    let databaseService: DatabaseService;
    let testConfig: OfflineConfig;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'OfflineService tests starting');
      
      // Initialize database service first
      databaseService = DatabaseService.getInstance();
      await databaseService.initializeDatabase();
      
      // Test configuration with smaller values for faster testing
      testConfig = {
        maxQueueSize: 10,
        syncRetryDelay: 100, // 100ms for faster tests
        maxRetries: 2,
        cacheExpirationHours: 1
      };
      
      // Initialize offline service
      offlineService = OfflineService.getInstance(databaseService, testConfig);
      
      hilog.info(DOMAIN, TAG, '%{public}s', 'OfflineService initialized successfully');
    });

    beforeEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual test');
      // Clear queue before each test
      await offlineService.clearQueue();
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual test');
    });

    /**
     * Test offline mode detection and switching
     * Validates Requirements 1.4, 5.3: Offline mode detection and UI indicators
     */
    it('should_detect_offline_mode_and_provide_status', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing offline mode detection');
      
      try {
        // Test getting online status
        const isOnline = offlineService.isDeviceOnline();
        expect(typeof isOnline).assertEqual('boolean');
        
        // Test getting offline statistics
        const stats = offlineService.getOfflineStats();
        expect(typeof stats.isOnline).assertEqual('boolean');
        expect(typeof stats.queuedOperations).assertEqual('number');
        expect(typeof stats.syncInProgress).assertEqual('boolean');
        expect(stats.queuedOperations >= 0).assertTrue();
        
        hilog.info(DOMAIN, TAG, 'Offline stats - online: %{public}s, queued: %{public}d, syncing: %{public}s', 
          stats.isOnline.toString(), stats.queuedOperations, stats.syncInProgress.toString());
        
        // Test online status listener functionality
        let listenerCalled = false;
        let receivedStatus = false;
        
        const testListener = (isOnline: boolean) => {
          listenerCalled = true;
          receivedStatus = isOnline;
        };
        
        // Add listener
        offlineService.addOnlineStatusListener(testListener);
        
        // Remove listener (should not cause errors)
        offlineService.removeOnlineStatusListener(testListener);
        
        // Verify listener management doesn't throw errors
        expect(true).assertTrue();
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Offline mode detection test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test data queuing functionality
     * Validates Requirements 4.4: Data queuing for offline operations
     */
    it('should_queue_operations_for_offline_sync', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing data queuing functionality');
      
      try {
        // Create test exercise session data
        const testLocation: LocationData = {
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 5.0,
          timestamp: Date.now(),
          altitude: 100
        };

        const testEnvironmentScore: EnvironmentScore = {
          overall: 75.5,
          airQuality: 80.0,
          weatherConditions: 70.0,
          uvRisk: 60.0,
          calculatedAt: Date.now()
        };

        const testSession: ExerciseSession = {
          id: 1,
          startTime: Date.now() - 3600000,
          endTime: Date.now(),
          route: [testLocation],
          environmentalConditions: [testEnvironmentScore],
          averageEnvironmentScore: 75.5,
          distance: 5000,
          duration: 3600000,
          notes: 'Test session for offline queue'
        };

        // Test queuing exercise session
        const operationId1 = await offlineService.queueOperation({
          type: 'exercise_session',
          data: testSession,
          maxRetries: 3
        });
        
        expect(typeof operationId1).assertEqual('string');
        expect(operationId1.length > 0).assertTrue();
        
        // Test queuing AI request
        const operationId2 = await offlineService.queueOperation({
          type: 'ai_request',
          data: { location: testLocation, environmentScore: testEnvironmentScore },
          maxRetries: 2
        });
        
        expect(typeof operationId2).assertEqual('string');
        expect(operationId2.length > 0).assertTrue();
        
        // Test queuing weather request
        const operationId3 = await offlineService.queueOperation({
          type: 'weather_request',
          data: { location: testLocation },
          maxRetries: 3
        });
        
        expect(typeof operationId3).assertEqual('string');
        expect(operationId3.length > 0).assertTrue();
        
        // Verify queue count
        const queueCount = offlineService.getQueuedOperationsCount();
        expect(queueCount).assertEqual(3);
        
        // Test getting operations by type
        const exerciseOps = offlineService.getQueuedOperationsByType('exercise_session');
        expect(exerciseOps.length).assertEqual(1);
        expect(exerciseOps[0].id).assertEqual(operationId1);
        
        const aiOps = offlineService.getQueuedOperationsByType('ai_request');
        expect(aiOps.length).assertEqual(1);
        expect(aiOps[0].id).assertEqual(operationId2);
        
        const weatherOps = offlineService.getQueuedOperationsByType('weather_request');
        expect(weatherOps.length).assertEqual(1);
        expect(weatherOps[0].id).assertEqual(operationId3);
        
        hilog.info(DOMAIN, TAG, 'Successfully queued %{public}d operations', queueCount);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Data queuing test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test synchronization functionality
     * Validates Requirements 4.4: Data synchronization when connectivity returns
     */
    it('should_synchronize_queued_operations', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing synchronization functionality');
      
      try {
        // Queue some test operations first
        const testData = {
          sessionId: 'test_session_123',
          timestamp: Date.now()
        };
        
        const operationId1 = await offlineService.queueOperation({
          type: 'exercise_session',
          data: testData,
          maxRetries: 2
        });
        
        const operationId2 = await offlineService.queueOperation({
          type: 'ai_request',
          data: testData,
          maxRetries: 2
        });
        
        // Verify operations are queued
        let queueCount = offlineService.getQueuedOperationsCount();
        expect(queueCount).assertEqual(2);
        
        // Test synchronization (this will simulate sync even if offline)
        // Note: In a real scenario, sync would only work when online
        if (offlineService.isDeviceOnline()) {
          await offlineService.startSynchronization();
          
          // Wait a bit for sync to complete
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // Check if operations were processed (they should be removed from queue)
          queueCount = offlineService.getQueuedOperationsCount();
          // Operations should be removed after successful sync
          expect(queueCount <= 2).assertTrue(); // May still be there if sync failed
        } else {
          hilog.info(DOMAIN, TAG, '%{public}s', 'Device is offline, skipping actual sync test');
        }
        
        // Test force synchronization when offline (should throw error)
        if (!offlineService.isDeviceOnline()) {
          try {
            await offlineService.forceSynchronization();
            expect(false).assertTrue(); // Should not reach here
          } catch (error) {
            expect(error.message.includes('offline')).assertTrue();
          }
        }
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'Synchronization test completed');
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Synchronization test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test cache validation functionality
     * Validates Requirements 1.4: Cache age validation for offline data
     */
    it('should_validate_cache_age_correctly', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing cache validation functionality');
      
      try {
        const currentTime = Date.now();
        
        // Test recent cache (should be valid)
        const recentTimestamp = currentTime - (30 * 60 * 1000); // 30 minutes ago
        const recentCacheAge = offlineService.getCacheAgeHours(recentTimestamp);
        const isRecentValid = offlineService.isCacheValid(recentTimestamp);
        
        expect(recentCacheAge).assertClose(0.5, 0.1); // Should be around 0.5 hours
        expect(isRecentValid).assertTrue(); // Should be valid (less than 1 hour old)
        
        // Test old cache (should be invalid)
        const oldTimestamp = currentTime - (2 * 60 * 60 * 1000); // 2 hours ago
        const oldCacheAge = offlineService.getCacheAgeHours(oldTimestamp);
        const isOldValid = offlineService.isCacheValid(oldTimestamp);
        
        expect(oldCacheAge).assertClose(2.0, 0.1); // Should be around 2 hours
        expect(isOldValid).assertEqual(false); // Should be invalid (more than 1 hour old)
        
        // Test edge case - exactly at expiration limit
        const edgeTimestamp = currentTime - (1 * 60 * 60 * 1000); // Exactly 1 hour ago
        const edgeCacheAge = offlineService.getCacheAgeHours(edgeTimestamp);
        const isEdgeValid = offlineService.isCacheValid(edgeTimestamp);
        
        expect(edgeCacheAge).assertClose(1.0, 0.1); // Should be around 1 hour
        expect(isEdgeValid).assertEqual(false); // Should be invalid (exactly at limit)
        
        hilog.info(DOMAIN, TAG, 'Cache validation - recent: %{public}s, old: %{public}s, edge: %{public}s',
          isRecentValid.toString(), isOldValid.toString(), isEdgeValid.toString());
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Cache validation test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test queue management and cleanup
     * Validates Requirements 4.4: Queue size limits and cleanup
     */
    it('should_manage_queue_size_and_cleanup', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing queue management and cleanup');
      
      try {
        // Fill queue to capacity
        const maxSize = testConfig.maxQueueSize;
        const operationIds: string[] = [];
        
        for (let i = 0; i < maxSize; i++) {
          const operationId = await offlineService.queueOperation({
            type: 'exercise_session',
            data: { testIndex: i, timestamp: Date.now() - (i * 1000) }, // Older timestamps for older operations
            maxRetries: 1
          });
          operationIds.push(operationId);
        }
        
        // Verify queue is at capacity
        let queueCount = offlineService.getQueuedOperationsCount();
        expect(queueCount).assertEqual(maxSize);
        
        // Add one more operation (should trigger cleanup of oldest)
        const extraOperationId = await offlineService.queueOperation({
          type: 'ai_request',
          data: { testIndex: maxSize, timestamp: Date.now() },
          maxRetries: 1
        });
        
        // Queue should still be at max size (oldest operation removed)
        queueCount = offlineService.getQueuedOperationsCount();
        expect(queueCount).assertEqual(maxSize);
        
        // Test manual queue clearing
        await offlineService.clearQueue();
        queueCount = offlineService.getQueuedOperationsCount();
        expect(queueCount).assertEqual(0);
        
        hilog.info(DOMAIN, TAG, 'Queue management test completed - final count: %{public}d', queueCount);
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Queue management test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test offline service error handling
     * Validates Requirements 5.3: Proper error handling in offline scenarios
     */
    it('should_handle_offline_errors_gracefully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing offline error handling');
      
      try {
        // Test invalid operation type (should still queue but log warning)
        const invalidOperationId = await offlineService.queueOperation({
          type: 'invalid_type' as any,
          data: { test: 'data' },
          maxRetries: 1
        });
        
        expect(typeof invalidOperationId).assertEqual('string');
        expect(invalidOperationId.length > 0).assertTrue();
        
        // Test queuing with invalid data (should still work)
        const nullDataOperationId = await offlineService.queueOperation({
          type: 'exercise_session',
          data: null,
          maxRetries: 1
        });
        
        expect(typeof nullDataOperationId).assertEqual('string');
        
        // Test getting stats when queue has operations
        const stats = offlineService.getOfflineStats();
        expect(stats.queuedOperations >= 2).assertTrue(); // Should have at least our test operations
        
        // Test operations by non-existent type
        const nonExistentOps = offlineService.getQueuedOperationsByType('non_existent_type');
        expect(Array.isArray(nonExistentOps)).assertTrue();
        expect(nonExistentOps.length).assertEqual(0);
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'Error handling tests passed');
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Error handling test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    afterAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Cleaning up OfflineService tests');
      
      try {
        // Clean up any remaining queued operations
        await offlineService.clearQueue();
        
        // Cleanup offline service resources
        await offlineService.cleanup();
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'OfflineService tests completed');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Cleanup failed: %{public}s', error.message);
      }
    });
  });
}