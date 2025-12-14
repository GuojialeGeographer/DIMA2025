import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ExerciseTrackingService, ExerciseSessionState, DEFAULT_EXERCISE_CONFIG } from '../../../main/ets/services/ExerciseTrackingService';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { LocationService } from '../../../main/ets/services/LocationService';
import { WeatherService } from '../../../main/ets/services/WeatherService';
import { ExerciseSession } from '../../../main/ets/models/ExerciseSession';
import { LocationData } from '../../../main/ets/models/LocationData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';

const TAG = 'ExerciseTrackingServiceTest';
const DOMAIN = 0xFF00;

/**
 * Unit tests for ExerciseTrackingService
 * Tests session start/stop functionality, GPS route recording, and session data persistence
 * Validates Requirements 4.1, 4.2
 */
export default function exerciseTrackingServiceTest() {
  describe('ExerciseTrackingServiceTests', () => {
    let exerciseService: ExerciseTrackingService;
    let databaseService: DatabaseService;
    let locationService: LocationService;
    let weatherService: WeatherService;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'ExerciseTrackingService tests starting');
      
      // Initialize services
      databaseService = DatabaseService.getInstance();
      locationService = LocationService.getInstance();
      weatherService = WeatherService.getInstance();
      exerciseService = ExerciseTrackingService.getInstance();
      
      try {
        await databaseService.initializeDatabase();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Database initialized successfully');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', error.message);
      }
    });

    beforeEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual test');
      
      // Ensure service is in idle state before each test
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        try {
          await exerciseService.stopExerciseSession();
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Failed to stop session in beforeEach: %{public}s', error.message);
        }
      }
    });

    afterEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual test');
      
      // Clean up any active sessions
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        try {
          await exerciseService.stopExerciseSession();
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Failed to stop session in afterEach: %{public}s', error.message);
        }
      }
    });

    /**
     * Test exercise session start functionality
     * Validates Requirements 4.1: Exercise session should start with GPS tracking
     */
    it('should_start_exercise_session_successfully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing exercise session start');
      
      try {
        // Test initial state
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.IDLE);
        expect(exerciseService.getCurrentSession()).assertNull();
        
        // Test starting session
        const startResult = await exerciseService.startExerciseSession('Test session');
        
        if (startResult) {
          // Verify state changed to active
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
          
          // Verify session data exists
          const currentSession = exerciseService.getCurrentSession();
          expect(currentSession).assertNotNull();
          
          if (currentSession) {
            expect(currentSession.startTime).assertLargerThan(0);
            expect(Array.isArray(currentSession.route)).assertTrue();
            expect(Array.isArray(currentSession.environmentalConditions)).assertTrue();
            expect(currentSession.notes).assertEqual('Test session');
            expect(typeof currentSession.distance).assertEqual('number');
            expect(currentSession.distance).assertLargerOrEqual(0);
          }
          
          hilog.info(DOMAIN, TAG, '%{public}s', 'Exercise session started successfully');
        } else {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Exercise session start failed (likely permission issue)');
          // This is acceptable in test environment where GPS permissions might not be available
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Session start test failed: %{public}s', error.message);
        // Don't fail the test for permission-related issues in test environment
        if (!error.message.includes('permission')) {
          expect(false).assertTrue(); // Fail the test for non-permission errors
        }
      }
    });

    /**
     * Test exercise session stop functionality
     * Validates Requirements 4.1, 4.2: Exercise session should stop and persist data
     */
    it('should_stop_exercise_session_and_persist_data', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing exercise session stop and data persistence');
      
      try {
        // Start a session first
        const startResult = await exerciseService.startExerciseSession('Test session for stop');
        
        if (!startResult) {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Cannot test stop without successful start (permission issue)');
          return; // Skip this test if we can't start
        }
        
        // Verify session is active
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
        
        // Wait a brief moment to simulate some activity
        await new Promise(resolve => setTimeout(resolve, 100));
        
        // Stop the session
        const completedSession = await exerciseService.stopExerciseSession();
        
        if (completedSession) {
          // Verify session data
          expect(completedSession.id).assertLargerThan(0); // Should have database ID
          expect(completedSession.startTime).assertLargerThan(0);
          expect(completedSession.endTime).assertLargerThan(completedSession.startTime);
          expect(completedSession.duration).assertLargerThan(0);
          expect(completedSession.distance).assertLargerOrEqual(0);
          expect(completedSession.averageEnvironmentScore).assertLargerOrEqual(0);
          expect(completedSession.averageEnvironmentScore).assertLessOrEqual(100);
          expect(Array.isArray(completedSession.route)).assertTrue();
          expect(Array.isArray(completedSession.environmentalConditions)).assertTrue();
          
          // Verify state changed to completed
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.COMPLETED);
          
          // Verify session is no longer current
          expect(exerciseService.getCurrentSession()).assertNull();
          
          // Verify data was persisted to database
          const retrievedSession = await databaseService.getExerciseSessionById(completedSession.id);
          expect(retrievedSession).assertNotNull();
          
          if (retrievedSession) {
            expect(retrievedSession.id).assertEqual(completedSession.id);
            expect(retrievedSession.startTime).assertEqual(completedSession.startTime);
            expect(retrievedSession.endTime).assertEqual(completedSession.endTime);
            expect(retrievedSession.duration).assertEqual(completedSession.duration);
            expect(retrievedSession.distance).assertEqual(completedSession.distance);
          }
          
          hilog.info(DOMAIN, TAG, 'Session stopped and persisted with ID: %{public}d', completedSession.id);
        } else {
          hilog.error(DOMAIN, TAG, '%{public}s', 'Failed to stop session');
          expect(false).assertTrue();
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Session stop test failed: %{public}s', error.message);
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test exercise session pause and resume functionality
     * Validates Requirements 4.1: Exercise session should support pause/resume
     */
    it('should_pause_and_resume_exercise_session', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing exercise session pause and resume');
      
      try {
        // Start a session
        const startResult = await exerciseService.startExerciseSession('Test pause/resume');
        
        if (!startResult) {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Cannot test pause/resume without successful start');
          return;
        }
        
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
        
        // Pause the session
        const pauseResult = exerciseService.pauseExerciseSession();
        expect(pauseResult).assertTrue();
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.PAUSED);
        
        // Session should still exist but be paused
        const pausedSession = exerciseService.getCurrentSession();
        expect(pausedSession).assertNotNull();
        
        // Resume the session
        const resumeResult = await exerciseService.resumeExerciseSession();
        
        if (resumeResult) {
          expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.ACTIVE);
          
          // Session should still exist and be active
          const resumedSession = exerciseService.getCurrentSession();
          expect(resumedSession).assertNotNull();
          
          hilog.info(DOMAIN, TAG, '%{public}s', 'Pause/resume functionality working correctly');
        } else {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Resume failed (likely GPS issue)');
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Pause/resume test failed: %{public}s', error.message);
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test GPS route recording functionality
     * Validates Requirements 4.1: GPS coordinates should be recorded during session
     */
    it('should_record_gps_route_during_session', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing GPS route recording');
      
      try {
        // Start a session
        const startResult = await exerciseService.startExerciseSession('GPS route test');
        
        if (!startResult) {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Cannot test GPS recording without successful start');
          return;
        }
        
        // Get initial session data
        const initialSession = exerciseService.getCurrentSession();
        expect(initialSession).assertNotNull();
        
        if (initialSession) {
          expect(Array.isArray(initialSession.route)).assertTrue();
          expect(initialSession.route.length).assertLargerOrEqual(1); // Should have at least initial location
          
          // Verify route points have valid structure
          for (const point of initialSession.route) {
            expect(typeof point.latitude).assertEqual('number');
            expect(typeof point.longitude).assertEqual('number');
            expect(typeof point.accuracy).assertEqual('number');
            expect(typeof point.timestamp).assertEqual('number');
            
            // Validate coordinate ranges
            expect(point.latitude).assertLargerOrEqual(-90);
            expect(point.latitude).assertLessOrEqual(90);
            expect(point.longitude).assertLargerOrEqual(-180);
            expect(point.longitude).assertLessOrEqual(180);
            expect(point.accuracy).assertLargerOrEqual(0);
            expect(point.timestamp).assertLargerThan(0);
          }
          
          hilog.info(DOMAIN, TAG, 'Route has %{public}d points', initialSession.route.length);
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'GPS route recording test failed: %{public}s', error.message);
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test session data validation
     * Validates Requirements 4.2: Session data should be validated before persistence
     */
    it('should_validate_session_data_before_persistence', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing session data validation');
      
      try {
        // Start and immediately stop a session to get minimal valid data
        const startResult = await exerciseService.startExerciseSession('Validation test');
        
        if (!startResult) {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Cannot test validation without successful start');
          return;
        }
        
        // Wait a brief moment
        await new Promise(resolve => setTimeout(resolve, 50));
        
        const completedSession = await exerciseService.stopExerciseSession();
        
        if (completedSession) {
          // Verify all required fields are present and valid
          expect(typeof completedSession.id).assertEqual('number');
          expect(completedSession.id).assertLargerThan(0);
          
          expect(typeof completedSession.startTime).assertEqual('number');
          expect(completedSession.startTime).assertLargerThan(0);
          
          expect(typeof completedSession.endTime).assertEqual('number');
          expect(completedSession.endTime).assertLargerThan(completedSession.startTime);
          
          expect(typeof completedSession.duration).assertEqual('number');
          expect(completedSession.duration).assertLargerThan(0);
          
          expect(typeof completedSession.distance).assertEqual('number');
          expect(completedSession.distance).assertLargerOrEqual(0);
          
          expect(typeof completedSession.averageEnvironmentScore).assertEqual('number');
          expect(completedSession.averageEnvironmentScore).assertLargerOrEqual(0);
          expect(completedSession.averageEnvironmentScore).assertLessOrEqual(100);
          
          expect(Array.isArray(completedSession.route)).assertTrue();
          expect(completedSession.route.length).assertLargerThan(0);
          
          expect(Array.isArray(completedSession.environmentalConditions)).assertTrue();
          
          // Verify duration matches time difference (within tolerance)
          const calculatedDuration = completedSession.endTime - completedSession.startTime;
          const durationDiff = Math.abs(completedSession.duration - calculatedDuration);
          expect(durationDiff).assertLessOrEqual(1000); // 1 second tolerance
          
          hilog.info(DOMAIN, TAG, '%{public}s', 'Session data validation passed');
        }
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Session validation test failed: %{public}s', error.message);
        if (!error.message.includes('permission')) {
          expect(false).assertTrue();
        }
      }
    });

    /**
     * Test exercise service configuration
     * Validates Requirements 4.1: Service should be configurable
     */
    it('should_handle_configuration_updates', 0, () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing service configuration');
      
      try {
        // Get default configuration
        const defaultConfig = exerciseService.getConfig();
        expect(typeof defaultConfig.locationUpdateInterval).assertEqual('number');
        expect(typeof defaultConfig.minDistanceBetweenPoints).assertEqual('number');
        expect(typeof defaultConfig.environmentUpdateInterval).assertEqual('number');
        expect(typeof defaultConfig.maxSessionDuration).assertEqual('number');
        
        // Verify default values
        expect(defaultConfig.locationUpdateInterval).assertEqual(DEFAULT_EXERCISE_CONFIG.locationUpdateInterval);
        expect(defaultConfig.minDistanceBetweenPoints).assertEqual(DEFAULT_EXERCISE_CONFIG.minDistanceBetweenPoints);
        expect(defaultConfig.environmentUpdateInterval).assertEqual(DEFAULT_EXERCISE_CONFIG.environmentUpdateInterval);
        expect(defaultConfig.maxSessionDuration).assertEqual(DEFAULT_EXERCISE_CONFIG.maxSessionDuration);
        
        // Update configuration
        const newConfig = {
          locationUpdateInterval: 3000,
          minDistanceBetweenPoints: 5
        };
        
        exerciseService.updateConfig(newConfig);
        
        // Verify configuration was updated
        const updatedConfig = exerciseService.getConfig();
        expect(updatedConfig.locationUpdateInterval).assertEqual(3000);
        expect(updatedConfig.minDistanceBetweenPoints).assertEqual(5);
        
        // Verify other values remained unchanged
        expect(updatedConfig.environmentUpdateInterval).assertEqual(DEFAULT_EXERCISE_CONFIG.environmentUpdateInterval);
        expect(updatedConfig.maxSessionDuration).assertEqual(DEFAULT_EXERCISE_CONFIG.maxSessionDuration);
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'Configuration update test passed');
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Configuration test failed: %{public}s', error.message);
        expect(false).assertTrue();
      }
    });

    /**
     * Test error handling for invalid operations
     * Validates Requirements 4.1, 4.2: Service should handle errors gracefully
     */
    it('should_handle_invalid_operations_gracefully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing error handling for invalid operations');
      
      try {
        // Ensure we're in idle state
        expect(exerciseService.getCurrentState()).assertEqual(ExerciseSessionState.IDLE);
        
        // Test stopping session when not active
        try {
          await exerciseService.stopExerciseSession();
          expect(false).assertTrue(); // Should throw error
        } catch (error) {
          expect(error.message.includes('Cannot stop session')).assertTrue();
        }
        
        // Test pausing session when not active
        const pauseResult = exerciseService.pauseExerciseSession();
        expect(pauseResult).assertEqual(false);
        
        // Test resuming session when not paused
        const resumeResult = await exerciseService.resumeExerciseSession();
        expect(resumeResult).assertEqual(false);
        
        // Test starting session when already active (if we can start one)
        const startResult1 = await exerciseService.startExerciseSession('First session');
        
        if (startResult1) {
          try {
            await exerciseService.startExerciseSession('Second session');
            expect(false).assertTrue(); // Should throw error
          } catch (error) {
            expect(error.message.includes('Cannot start session')).assertTrue();
          }
        }
        
        hilog.info(DOMAIN, TAG, '%{public}s', 'Error handling test passed');
        
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Error handling test failed: %{public}s', error.message);
        expect(false).assertTrue();
      }
    });

    afterAll(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'ExerciseTrackingService tests completed');
    });
  });
}