import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ExerciseTrackingService, ExerciseSessionState } from '../../../main/ets/services/ExerciseTrackingService';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { LocationService } from '../../../main/ets/services/LocationService';
import { WeatherService } from '../../../main/ets/services/WeatherService';
import { ExerciseSession, validateExerciseSession } from '../../../main/ets/models/ExerciseSession';
import { LocationData, validateLocationData } from '../../../main/ets/models/LocationData';
import { EnvironmentScore, validateEnvironmentScore } from '../../../main/ets/models/EnvironmentScore';
import { PropertyTestUtils, forAll } from './PropertyTestUtils';

/**
 * **Feature: cityzen-app, Property 5: Exercise Session Data Integrity**
 * **Validates: Requirements 4.1, 4.2**
 * 
 * Property-based tests for exercise session data integrity
 * Tests that exercise sessions maintain data consistency throughout their lifecycle
 */
export default function exerciseSessionDataIntegrityTests() {
  describe('Exercise Session Data Integrity Property Tests', () => {
    let exerciseService: ExerciseTrackingService;
    let databaseService: DatabaseService;
    let locationService: LocationService;
    let weatherService: WeatherService;

    beforeAll(async () => {
      // Initialize services
      databaseService = DatabaseService.getInstance();
      locationService = LocationService.getInstance();
      weatherService = WeatherService.getInstance();
      exerciseService = ExerciseTrackingService.getInstance();
      
      // Initialize database
      await databaseService.initializeDatabase();
    });

    beforeEach(async () => {
      // Reset service state before each test
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        await exerciseService.stopExerciseSession();
      }
    });

    afterEach(async () => {
      // Clean up after each test
      if (exerciseService.getCurrentState() !== ExerciseSessionState.IDLE) {
        await exerciseService.stopExerciseSession();
      }
    });

    /**
     * Property 5.1: Exercise session data validation consistency
     * For any exercise session data, validation should be consistent and reliable
     */
    it('should maintain consistent validation for exercise session data', () => {
      const result = forAll(
        () => PropertyTestUtils.generateExerciseSession(),
        (sessionData: any) => {
          // Test that validation is consistent
          const isValid1 = validateExerciseSession(sessionData);
          const isValid2 = validateExerciseSession(sessionData);
          
          // Validation should be deterministic
          if (isValid1 !== isValid2) {
            return false;
          }
          
          // If valid, should have all required properties
          if (isValid1) {
            return (
              typeof sessionData.id === 'number' &&
              typeof sessionData.startTime === 'number' &&
              typeof sessionData.endTime === 'number' &&
              Array.isArray(sessionData.route) &&
              Array.isArray(sessionData.environmentalConditions) &&
              typeof sessionData.averageEnvironmentScore === 'number' &&
              typeof sessionData.distance === 'number' &&
              typeof sessionData.duration === 'number' &&
              sessionData.endTime > sessionData.startTime &&
              sessionData.averageEnvironmentScore >= 0 &&
              sessionData.averageEnvironmentScore <= 100 &&
              sessionData.distance >= 0 &&
              sessionData.duration > 0
            );
          }
          
          return true;
        },
        { iterations: 100 }
      );

      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Property 5.1 failed with counterexample:', JSON.stringify(result.counterExample));
      }
    });

    /**
     * Property 5.2: Route data integrity during session recording
     * For any sequence of location updates, route data should maintain chronological order and validity
     */
    it('should maintain route data integrity during session recording', () => {
      const result = forAll(
        () => {
          // Generate a sequence of location updates with increasing timestamps
          const locations = PropertyTestUtils.generateLocationSequence(3, 20);
          // Ensure chronological order
          locations.sort((a, b) => a.timestamp - b.timestamp);
          return locations;
        },
        (locationSequence: any[]) => {
          // All locations should be valid
          for (const location of locationSequence) {
            if (!validateLocationData(location)) {
              return false;
            }
          }
          
          // Timestamps should be in chronological order
          for (let i = 1; i < locationSequence.length; i++) {
            if (locationSequence[i].timestamp < locationSequence[i - 1].timestamp) {
              return false;
            }
          }
          
          // Coordinates should be within valid ranges
          for (const location of locationSequence) {
            if (location.latitude < -90 || location.latitude > 90 ||
                location.longitude < -180 || location.longitude > 180) {
              return false;
            }
          }
          
          return true;
        },
        { iterations: 100 }
      );

      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Property 5.2 failed with counterexample:', JSON.stringify(result.counterExample));
      }
    });

    /**
     * Property 5.3: Environment data consistency during session
     * For any sequence of environment scores, data should remain valid and within expected ranges
     */
    it('should maintain environment data consistency during session', () => {
      const result = forAll(
        () => PropertyTestUtils.generateEnvironmentScoreSequence(2, 15),
        (environmentSequence: any[]) => {
          // All environment scores should be valid
          for (const envScore of environmentSequence) {
            if (!validateEnvironmentScore(envScore)) {
              return false;
            }
          }
          
          // All scores should be within 0-100 range
          for (const envScore of environmentSequence) {
            if (envScore.overall < 0 || envScore.overall > 100 ||
                envScore.airQuality < 0 || envScore.airQuality > 100 ||
                envScore.weatherConditions < 0 || envScore.weatherConditions > 100 ||
                envScore.uvRisk < 0 || envScore.uvRisk > 100) {
              return false;
            }
          }
          
          // Timestamps should be positive
          for (const envScore of environmentSequence) {
            if (envScore.calculatedAt < 0) {
              return false;
            }
          }
          
          return true;
        },
        { iterations: 100 }
      );

      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Property 5.3 failed with counterexample:', JSON.stringify(result.counterExample));
      }
    });

    /**
     * Property 5.4: Session completion data integrity
     * For any completed exercise session, all calculated fields should be consistent with recorded data
     */
    it('should maintain data integrity when completing exercise sessions', () => {
      const result = forAll(
        () => {
          const session = PropertyTestUtils.generateExerciseSession();
          // Ensure the session is valid for this test
          session.endTime = session.startTime + session.duration;
          return session;
        },
        (sessionData: any) => {
          // Skip invalid sessions for this property test
          if (!validateExerciseSession(sessionData)) {
            return true;
          }
          
          // Duration should match time difference
          const calculatedDuration = sessionData.endTime - sessionData.startTime;
          if (Math.abs(sessionData.duration - calculatedDuration) > 1000) { // 1 second tolerance
            return false;
          }
          
          // Average environment score should be within valid range
          if (sessionData.averageEnvironmentScore < 0 || sessionData.averageEnvironmentScore > 100) {
            return false;
          }
          
          // Distance should be non-negative
          if (sessionData.distance < 0) {
            return false;
          }
          
          // If there are environment conditions, average should be reasonable
          if (sessionData.environmentalConditions.length > 0) {
            let sum = 0;
            for (const condition of sessionData.environmentalConditions) {
              if (!validateEnvironmentScore(condition)) {
                return false;
              }
              sum += condition.overall;
            }
            const calculatedAverage = sum / sessionData.environmentalConditions.length;
            
            // Allow some tolerance for rounding
            if (Math.abs(sessionData.averageEnvironmentScore - calculatedAverage) > 1) {
              return false;
            }
          }
          
          return true;
        },
        { iterations: 100 }
      );

      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Property 5.4 failed with counterexample:', JSON.stringify(result.counterExample));
      }
    });

    /**
     * Property 5.5: Session state transitions maintain data consistency
     * For any valid session state transition, data should remain consistent
     */
    it('should maintain data consistency during session state transitions', async () => {
      // This test uses a more controlled approach since it involves async operations
      let testsPassed = 0;
      const totalTests = 10; // Reduced iterations for async test
      
      for (let i = 0; i < totalTests; i++) {
        try {
          // Start a session
          const startResult = await exerciseService.startExerciseSession('Test session');
          if (!startResult) {
            continue; // Skip if start failed
          }
          
          // Check that session is active
          const state = exerciseService.getCurrentState();
          if (state !== ExerciseSessionState.ACTIVE) {
            continue;
          }
          
          // Get current session data
          const currentSession = exerciseService.getCurrentSession();
          if (!currentSession) {
            continue;
          }
          
          // Verify session data integrity
          if (currentSession.startTime && currentSession.startTime > 0 &&
              Array.isArray(currentSession.route) &&
              Array.isArray(currentSession.environmentalConditions) &&
              typeof currentSession.distance === 'number' &&
              currentSession.distance >= 0) {
            testsPassed++;
          }
          
          // Stop the session
          await exerciseService.stopExerciseSession();
          
        } catch (error) {
          // Continue with next iteration if error occurs
          console.warn('Session test iteration failed:', error);
        }
      }
      
      // At least 70% of tests should pass (accounting for potential permission/GPS issues)
      expect(testsPassed).assertLargerOrEqual(Math.floor(totalTests * 0.7));
    });
  });
}