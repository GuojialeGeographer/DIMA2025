import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { DatabaseService, CachedEnvironmentData } from '../../../main/ets/services/DatabaseService';
import { ExerciseSession } from '../../../main/ets/models/ExerciseSession';
import { LocationData } from '../../../main/ets/models/LocationData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';
import { WeatherData } from '../../../main/ets/models/WeatherData';

const TAG = 'DatabaseServiceTest';
const DOMAIN = 0xFF00;

/**
 * Unit tests for DatabaseService
 * Tests database initialization, CRUD operations, and caching functionality
 * Validates Requirements 4.1, 4.2
 */
export default function databaseServiceTest() {
  describe('DatabaseServiceTests', () => {
    let dbService: DatabaseService;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'DatabaseService tests starting');
      dbService = DatabaseService.getInstance();
      
      try {
        await dbService.initializeDatabase();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Database initialized successfully');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', error.message);
      }
    });

    beforeEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual test');
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual test');
    });

    /**
     * Test database initialization and schema creation
     * Validates Requirements 4.1: Database should initialize with proper schema
     */
    it('should_initialize_database_successfully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing database initialization');
      
      // Test that DatabaseService is a singleton
      const dbService2 = DatabaseService.getInstance();
      expect(dbService).assertEqual(dbService2);
      
      // Test that we can get database statistics (indicates tables exist)
      try {
        const stats = await dbService.getDatabaseStats();
        expect(typeof stats.exerciseCount).assertEqual('number');
        expect(typeof stats.cacheCount).assertEqual('number');
        expect(stats.exerciseCount >= 0).assertTrue();
        expect(stats.cacheCount >= 0).assertTrue();
        
        hilog.info(DOMAIN, TAG, 'Database stats - exercises: %{public}d, cache: %{public}d', 
          stats.exerciseCount, stats.cacheCount);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Database stats failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test exercise session CRUD operations
     * Validates Requirements 4.1, 4.2: Exercise session storage and retrieval
     */
    it('should_save_and_retrieve_exercise_session', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing exercise session CRUD operations');
      
      // Create test data
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

      const startTime = Date.now() - 3600000; // 1 hour ago
      const duration = 1800000; // 30 minutes
      const endTime = startTime + duration;

      const testSession: ExerciseSession = {
        id: 0, // Will be set by database
        startTime: startTime,
        endTime: endTime,
        route: [testLocation],
        environmentalConditions: [testEnvironmentScore],
        averageEnvironmentScore: 75.5,
        distance: 5000, // 5km
        duration: duration,
        notes: 'Test exercise session'
      };

      try {
        // Test saving exercise session
        const sessionId = await dbService.saveExerciseSession(testSession);
        expect(sessionId > 0).assertTrue();
        hilog.info(DOMAIN, TAG, 'Saved exercise session with ID: %{public}d', sessionId);

        // Test retrieving exercise session by ID
        testSession.id = sessionId;
        const retrievedSession = await dbService.getExerciseSessionById(sessionId);
        expect(retrievedSession).assertNotNull();
        
        if (retrievedSession) {
          expect(retrievedSession.id).assertEqual(sessionId);
          expect(retrievedSession.startTime).assertEqual(testSession.startTime);
          expect(retrievedSession.endTime).assertEqual(testSession.endTime);
          expect(retrievedSession.distance).assertEqual(testSession.distance);
          expect(retrievedSession.duration).assertEqual(testSession.duration);
          expect(retrievedSession.notes).assertEqual(testSession.notes);
          expect(retrievedSession.route.length).assertEqual(1);
          expect(retrievedSession.environmentalConditions.length).assertEqual(1);
        }

        // Test getting exercise history
        const history = await dbService.getExerciseHistory(10);
        expect(Array.isArray(history)).assertTrue();
        expect(history.length > 0).assertTrue();
        
        // Find our test session in the history
        const foundSession = history.find(session => session.id === sessionId);
        expect(foundSession).assertNotNull();

        // Test updating exercise session
        if (retrievedSession) {
          retrievedSession.notes = 'Updated test notes';
          const updateResult = await dbService.updateExerciseSession(retrievedSession);
          expect(updateResult).assertTrue();
          
          // Verify the update
          const updatedSession = await dbService.getExerciseSessionById(sessionId);
          expect(updatedSession?.notes).assertEqual('Updated test notes');
        }

        // Test deleting exercise session
        const deleteResult = await dbService.deleteExerciseSession(sessionId);
        expect(deleteResult).assertTrue();
        
        // Verify deletion
        const deletedSession = await dbService.getExerciseSessionById(sessionId);
        expect(deletedSession).assertNull();

      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Exercise session CRUD test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test environment data caching functionality
     * Validates Requirements 4.2: Environment data caching and retrieval
     */
    it('should_cache_and_retrieve_environment_data', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing environment data caching');
      
      // Create test weather data
      const testWeatherData: WeatherData = {
        temperature: 22.5,
        humidity: 65.0,
        windSpeed: 10.0,
        windDirection: 180.0,
        uvIndex: 5.0,
        airQualityIndex: 50.0,
        visibility: 10.0,
        timestamp: Date.now()
      };

      const testEnvironmentScore: EnvironmentScore = {
        overall: 85.0,
        airQuality: 90.0,
        weatherConditions: 80.0,
        uvRisk: 70.0,
        calculatedAt: Date.now()
      };

      const testLocation = {
        latitude: 37.7749,
        longitude: -122.4194
      };

      const currentTime = Date.now();
      const cacheData: CachedEnvironmentData = {
        latitude: testLocation.latitude,
        longitude: testLocation.longitude,
        weatherData: testWeatherData,
        environmentScore: testEnvironmentScore,
        cachedAt: currentTime,
        expiresAt: currentTime + 3600000 // Expires in 1 hour
      };

      try {
        // Test caching environment data
        await dbService.cacheEnvironmentData(cacheData);
        hilog.info(DOMAIN, TAG, '%{public}s', 'Environment data cached successfully');

        // Test retrieving cached environment data
        const retrievedData = await dbService.getCachedEnvironmentData(
          testLocation.latitude, 
          testLocation.longitude, 
          1 // 1km radius
        );
        
        expect(retrievedData).assertNotNull();
        
        if (retrievedData) {
          expect(Math.abs(retrievedData.latitude - testLocation.latitude) < 0.01).assertTrue();
          expect(Math.abs(retrievedData.longitude - testLocation.longitude) < 0.01).assertTrue();
          expect(retrievedData.weatherData.temperature).assertEqual(testWeatherData.temperature);
          expect(retrievedData.environmentScore.overall).assertEqual(testEnvironmentScore.overall);
          expect(retrievedData.cachedAt).assertEqual(currentTime);
        }

        // Test cache miss for distant location
        const distantData = await dbService.getCachedEnvironmentData(
          40.7128, // New York coordinates
          -74.0060,
          1 // 1km radius
        );
        expect(distantData).assertNull();

        // Test expired cache (create data that's already expired)
        const expiredCacheData: CachedEnvironmentData = {
          latitude: 40.7128,
          longitude: -74.0060,
          weatherData: testWeatherData,
          environmentScore: testEnvironmentScore,
          cachedAt: currentTime - 7200000, // 2 hours ago
          expiresAt: currentTime - 3600000  // Expired 1 hour ago
        };

        await dbService.cacheEnvironmentData(expiredCacheData);
        
        const expiredData = await dbService.getCachedEnvironmentData(40.7128, -74.0060, 1);
        expect(expiredData).assertNull(); // Should not return expired data

      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Environment caching test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    /**
     * Test database error handling
     * Validates Requirements 4.1: Proper error handling for database operations
     */
    it('should_handle_database_errors_gracefully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing database error handling');
      
      try {
        // Test retrieving non-existent exercise session
        const nonExistentSession = await dbService.getExerciseSessionById(999999);
        expect(nonExistentSession).assertNull();

        // Test deleting non-existent exercise session
        const deleteResult = await dbService.deleteExerciseSession(999999);
        expect(deleteResult).assertEqual(false);

        // Test updating non-existent exercise session
        const fakeSession: ExerciseSession = {
          id: 999999,
          startTime: Date.now() - 3600000,
          endTime: Date.now(),
          route: [],
          environmentalConditions: [],
          averageEnvironmentScore: 50.0,
          distance: 1000,
          duration: 3600000
        };
        
        const updateResult = await dbService.updateExerciseSession(fakeSession);
        expect(updateResult).assertEqual(false);

        hilog.info(DOMAIN, TAG, '%{public}s', 'Error handling tests passed');

      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Error handling test failed: %{public}s', error.message);
        expect(false).assertTrue(); // Fail the test
      }
    });

    afterAll(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'DatabaseService tests completed');
    });
  });
}