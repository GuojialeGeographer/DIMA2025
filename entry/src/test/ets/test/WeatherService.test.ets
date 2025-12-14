/**
 * Weather Service Tests
 * Tests for weather API integration and environment scoring
 */
import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { WeatherService } from '../../../main/ets/services/WeatherService';
import { DatabaseService } from '../../../main/ets/services/DatabaseService';
import { WeatherData, validateWeatherData } from '../../../main/ets/models/WeatherData';
import { EnvironmentScore, validateEnvironmentScore } from '../../../main/ets/models/EnvironmentScore';
import { LocationData, validateLocationData } from '../../../main/ets/models/LocationData';
import { forAll, Random, Generator } from './PropertyTestUtils';

const TAG = 'WeatherServiceTest';
const DOMAIN = 0xFF00;

export default function weatherServiceTest() {
  describe('WeatherService', () => {
    let weatherService: WeatherService;
    let databaseService: DatabaseService;

    beforeAll(async () => {
      // Initialize database service for testing
      databaseService = new DatabaseService();
      await databaseService.initializeDatabase();
      
      // Initialize weather service with test API key
      weatherService = new WeatherService('test_api_key', databaseService);
    });

    afterAll(async () => {
      // Clean up database
      if (databaseService) {
        await databaseService.closeDatabase();
      }
    });

    describe('Property Tests', () => {
      /**
       * **Feature: cityzen-app, Property 1: Location-Environment Data Consistency (Environment part)**
       * **Validates: Requirements 1.2**
       */
      it('property_environment_score_calculation_consistency', 0, () => {
        hilog.info(DOMAIN, TAG, '%{public}s', 'Testing environment score calculation consistency property');
        const weatherDataGenerator: Generator<WeatherData> = () => ({
          temperature: Random.float(-40, 50), // Realistic temperature range
          humidity: Random.float(0, 100),
          windSpeed: Random.float(0, 50), // km/h
          windDirection: Random.float(0, 360),
          uvIndex: Random.float(0, 15),
          airQualityIndex: Random.float(0, 500),
          visibility: Random.float(0, 50), // km
          timestamp: Date.now() - Random.between(0, 86400000) // Within last 24 hours
        });

        const property = (weatherData: WeatherData): boolean => {
          // Only test with valid weather data
          if (!validateWeatherData(weatherData)) {
            return true; // Skip invalid inputs
          }

          const environmentScore = weatherService.calculateEnvironmentScore(weatherData);
          
          // Verify the environment score is valid
          if (!validateEnvironmentScore(environmentScore)) {
            return false;
          }

          // Verify all scores are within 0-100 range
          if (environmentScore.overall < 0 || environmentScore.overall > 100 ||
              environmentScore.airQuality < 0 || environmentScore.airQuality > 100 ||
              environmentScore.weatherConditions < 0 || environmentScore.weatherConditions > 100 ||
              environmentScore.uvRisk < 0 || environmentScore.uvRisk > 100) {
            return false;
          }

          // Verify calculatedAt timestamp is reasonable (within last minute)
          const now = Date.now();
          if (environmentScore.calculatedAt < now - 60000 || environmentScore.calculatedAt > now + 1000) {
            return false;
          }

          return true;
        };

        const result = forAll(weatherDataGenerator, property, { iterations: 100 });
        
        if (!result.success) {
          hilog.error(DOMAIN, TAG, 'Property failed with counterexample: %{public}s', 
            JSON.stringify(result.counterExample));
        }
        
        expect(result.success).assertTrue();
        hilog.info(DOMAIN, TAG, 'Completed %{public}d iterations', result.iterations);
      });

      /**
       * Test that environment scores are consistent for identical weather data
       */
      it('should produce identical environment scores for identical weather data', () => {
        const weatherDataGenerator: Generator<WeatherData> = () => ({
          temperature: Random.float(-40, 50),
          humidity: Random.float(0, 100),
          windSpeed: Random.float(0, 50),
          windDirection: Random.float(0, 360),
          uvIndex: Random.float(0, 15),
          airQualityIndex: Random.float(0, 500),
          visibility: Random.float(0, 50),
          timestamp: Date.now()
        });

        const property = (weatherData: WeatherData): boolean => {
          if (!validateWeatherData(weatherData)) {
            return true; // Skip invalid inputs
          }

          const score1 = weatherService.calculateEnvironmentScore(weatherData);
          const score2 = weatherService.calculateEnvironmentScore(weatherData);
          
          // Scores should be identical (except for calculatedAt timestamp)
          return score1.overall === score2.overall &&
                 score1.airQuality === score2.airQuality &&
                 score1.weatherConditions === score2.weatherConditions &&
                 score1.uvRisk === score2.uvRisk;
        };

        const result = forAll(weatherDataGenerator, property, { iterations: 50 });
        expect(result.success).assertTrue();
      });

      /**
       * Test that better air quality produces higher air quality scores
       */
      it('should produce higher air quality scores for better air quality indices', () => {
        const property = (): boolean => {
          const baseWeatherData: WeatherData = {
            temperature: 20,
            humidity: 50,
            windSpeed: 10,
            windDirection: 180,
            uvIndex: 3,
            airQualityIndex: 0, // Will be set below
            visibility: 10,
            timestamp: Date.now()
          };

          // Test with good air quality (AQI 25)
          const goodAirData = { ...baseWeatherData, airQualityIndex: 25 };
          const goodScore = weatherService.calculateEnvironmentScore(goodAirData);

          // Test with poor air quality (AQI 200)
          const poorAirData = { ...baseWeatherData, airQualityIndex: 200 };
          const poorScore = weatherService.calculateEnvironmentScore(poorAirData);

          // Good air quality should have higher air quality score
          return goodScore.airQuality > poorScore.airQuality;
        };

        const result = forAll(() => true, property, { iterations: 10 });
        expect(result.success).assertTrue();
      });
    });

    describe('API Response Validation', () => {
      it('should validate API response structure correctly', () => {
        const validResponse = {
          main: { temp: 20, humidity: 50 },
          wind: { speed: 10, deg: 180 },
          visibility: 10000,
          dt: Date.now()
        };

        const expectedFields = ['main.temp', 'main.humidity', 'wind.speed', 'visibility'];
        const isValid = weatherService.validateAPIResponse(validResponse, expectedFields);
        expect(isValid).assertTrue();
      });

      it('should reject invalid API response structure', () => {
        const invalidResponse = {
          main: { temp: 20 }, // Missing humidity
          wind: { speed: 10 },
          visibility: 10000
        };

        const expectedFields = ['main.temp', 'main.humidity', 'wind.speed', 'visibility'];
        const isValid = weatherService.validateAPIResponse(invalidResponse, expectedFields);
        expect(isValid).assertFalse();
      });
    });

    describe('Environment Score Calculation', () => {
      it('should calculate correct air quality scores for known AQI values', () => {
        const testCases = [
          { aqi: 25, expectedMinScore: 95 },   // Good air quality
          { aqi: 75, expectedMinScore: 75 },   // Moderate air quality
          { aqi: 125, expectedMinScore: 55 },  // Unhealthy for sensitive groups
          { aqi: 175, expectedMinScore: 35 },  // Unhealthy
          { aqi: 250, expectedMinScore: 15 },  // Very unhealthy
          { aqi: 400, expectedMaxScore: 5 }    // Hazardous
        ];

        testCases.forEach(testCase => {
          const weatherData: WeatherData = {
            temperature: 20,
            humidity: 50,
            windSpeed: 10,
            windDirection: 180,
            uvIndex: 3,
            airQualityIndex: testCase.aqi,
            visibility: 10,
            timestamp: Date.now()
          };

          const score = weatherService.calculateEnvironmentScore(weatherData);
          
          if ('expectedMinScore' in testCase) {
            expect(score.airQuality).assertGreaterOrEqual(testCase.expectedMinScore);
          } else if ('expectedMaxScore' in testCase) {
            expect(score.airQuality).assertLessOrEqual(testCase.expectedMaxScore);
          }
        });
      });

      it('should calculate reasonable weather condition scores', () => {
        // Test optimal conditions
        const optimalWeather: WeatherData = {
          temperature: 20,    // Optimal
          humidity: 50,       // Optimal
          windSpeed: 10,      // Light breeze
          windDirection: 180,
          uvIndex: 3,
          airQualityIndex: 25,
          visibility: 15,     // Good visibility
          timestamp: Date.now()
        };

        const optimalScore = weatherService.calculateEnvironmentScore(optimalWeather);
        expect(optimalScore.weatherConditions).assertGreaterOrEqual(90);

        // Test poor conditions
        const poorWeather: WeatherData = {
          temperature: -5,    // Too cold
          humidity: 90,       // Too humid
          windSpeed: 30,      // Too windy
          windDirection: 180,
          uvIndex: 3,
          airQualityIndex: 25,
          visibility: 0.5,    // Poor visibility
          timestamp: Date.now()
        };

        const poorScore = weatherService.calculateEnvironmentScore(poorWeather);
        expect(poorScore.weatherConditions).assertLessOrEqual(50);
      });

      it('should calculate correct UV risk scores', () => {
        const testCases = [
          { uvIndex: 1, expectedMinScore: 95 },   // Low UV
          { uvIndex: 4, expectedMinScore: 75 },   // Moderate UV
          { uvIndex: 6, expectedMinScore: 55 },   // High UV
          { uvIndex: 9, expectedMinScore: 35 },   // Very high UV
          { uvIndex: 12, expectedMaxScore: 25 }   // Extreme UV
        ];

        testCases.forEach(testCase => {
          const weatherData: WeatherData = {
            temperature: 20,
            humidity: 50,
            windSpeed: 10,
            windDirection: 180,
            uvIndex: testCase.uvIndex,
            airQualityIndex: 25,
            visibility: 10,
            timestamp: Date.now()
          };

          const score = weatherService.calculateEnvironmentScore(weatherData);
          
          if ('expectedMinScore' in testCase) {
            expect(score.uvRisk).assertGreaterOrEqual(testCase.expectedMinScore);
          } else if ('expectedMaxScore' in testCase) {
            expect(score.uvRisk).assertLessOrEqual(testCase.expectedMaxScore);
          }
        });
      });
    });
  });
}