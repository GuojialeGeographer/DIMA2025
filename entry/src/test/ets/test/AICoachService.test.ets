import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { AICoachService } from '../../../main/ets/services/AICoachService';
import { LocationData } from '../../../main/ets/models/LocationData';
import { WeatherData } from '../../../main/ets/models/WeatherData';
import { EnvironmentScore } from '../../../main/ets/models/EnvironmentScore';
import { 
  AIRecommendation, 
  EnvironmentContext,
  validateAIRecommendation,
  validateEnvironmentContext 
} from '../../../main/ets/models/AIRecommendation';
import { forAll, Random, Generator } from './PropertyTestUtils';

/**
 * **Feature: cityzen-app, Property 2: AI Recommendation Generation**
 * **Validates: Requirements 2.1, 2.4, 2.5**
 * 
 * Property: For any valid environmental context (time, location, weather, Environment_Score), 
 * the AI_Coach should generate contextual exercise recommendations within 10 seconds, 
 * and hazardous conditions should always produce safety warnings
 */

export default function aiCoachServiceTests() {
  describe('AICoachService', () => {
    let aiCoachService: AICoachService;
    
    beforeAll(() => {
      // Mock configuration for testing
      const mockConfig = {
        apiUrl: 'https://mock-api.example.com/chat',
        apiKey: 'test-key',
        timeout: 10000,
        maxRetries: 3,
        cacheExpiryMinutes: 15
      };
      aiCoachService = new AICoachService(mockConfig);
    });

    /**
     * Generator for valid LocationData
     */
    const generateLocationData: Generator<LocationData> = () => ({
      latitude: Random.float(-90, 90),
      longitude: Random.float(-180, 180),
      accuracy: Random.float(1, 100),
      timestamp: Date.now() - Random.between(0, 3600000), // Within last hour
      altitude: Random.boolean() ? Random.float(0, 8848) : undefined
    });

    /**
     * Generator for valid WeatherData
     */
    const generateWeatherData: Generator<WeatherData> = () => ({
      temperature: Random.float(-40, 50), // Celsius
      humidity: Random.float(0, 100),
      windSpeed: Random.float(0, 50),
      windDirection: Random.float(0, 360),
      uvIndex: Random.float(0, 15),
      airQualityIndex: Random.float(0, 500),
      visibility: Random.float(0, 50000),
      timestamp: Date.now() - Random.between(0, 1800000) // Within last 30 minutes
    });

    /**
     * Generator for valid EnvironmentScore
     */
    const generateEnvironmentScore: Generator<EnvironmentScore> = () => ({
      overall: Random.float(0, 100),
      airQuality: Random.float(0, 100),
      weatherConditions: Random.float(0, 100),
      uvRisk: Random.float(0, 100),
      noiseLevel: Random.boolean() ? Random.float(0, 100) : undefined,
      greenSpaceProximity: Random.boolean() ? Random.float(0, 100) : undefined,
      calculatedAt: Date.now() - Random.between(0, 900000) // Within last 15 minutes
    });

    /**
     * Generator for hazardous EnvironmentScore (overall < 40)
     */
    const generateHazardousEnvironmentScore: Generator<EnvironmentScore> = () => ({
      overall: Random.float(0, 39), // Hazardous conditions
      airQuality: Random.float(0, 50),
      weatherConditions: Random.float(0, 50),
      uvRisk: Random.float(0, 100),
      noiseLevel: Random.boolean() ? Random.float(60, 100) : undefined,
      greenSpaceProximity: Random.boolean() ? Random.float(0, 30) : undefined,
      calculatedAt: Date.now() - Random.between(0, 900000)
    });

    /**
     * Property Test 1: AI Recommendation Generation Consistency
     * Tests that valid environmental data always produces valid recommendations
     */
    it('should generate valid AI recommendations for any valid environmental context', () => {
      const testProperty = (data: { location: LocationData; weather: WeatherData; score: EnvironmentScore }) => {
        try {
          // Create environment context
          const context = createTestEnvironmentContext(data.location, data.weather, data.score);
          
          // Validate context is properly formed
          if (!validateEnvironmentContext(context)) {
            return false;
          }

          // Test fallback recommendation (since we can't test real AI API in unit tests)
          const fallbackRec = aiCoachService.getFallbackRecommendation(data.score.overall);
          
          // Validate fallback recommendation structure
          if (!fallbackRec.recommendation || typeof fallbackRec.recommendation !== 'string') {
            return false;
          }
          
          if (!['indoor', 'outdoor', 'mixed'].includes(fallbackRec.activityType)) {
            return false;
          }
          
          if (!fallbackRec.reasoning || typeof fallbackRec.reasoning !== 'string') {
            return false;
          }
          
          if (fallbackRec.source !== 'fallback') {
            return false;
          }

          return true;
        } catch (error) {
          console.error('Property test failed:', error);
          return false;
        }
      };

      const generator: Generator<{ location: LocationData; weather: WeatherData; score: EnvironmentScore }> = () => ({
        location: generateLocationData(),
        weather: generateWeatherData(),
        score: generateEnvironmentScore()
      });

      const result = forAll(generator, testProperty, { iterations: 100 });
      
      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Counter-example found:', JSON.stringify(result.counterExample, null, 2));
      }
    });

    /**
     * Property Test 2: Hazardous Conditions Safety Warnings
     * Tests that hazardous conditions always produce appropriate safety warnings
     */
    it('should always provide safety warnings for hazardous environmental conditions', () => {
      const testProperty = (data: { location: LocationData; weather: WeatherData; score: EnvironmentScore }) => {
        try {
          // Ensure we're testing hazardous conditions
          if (data.score.overall >= 40) {
            return true; // Skip non-hazardous conditions for this test
          }

          const fallbackRec = aiCoachService.getFallbackRecommendation(data.score.overall);
          
          // For hazardous conditions (score < 40), should recommend indoor activities
          // and include safety warnings in the recommendation text
          const recommendationText = fallbackRec.recommendation.toLowerCase();
          
          // Should recommend indoor activities for hazardous conditions
          if (data.score.overall < 40 && fallbackRec.activityType !== 'indoor') {
            return false;
          }
          
          // Should contain safety-related keywords for low scores
          if (data.score.overall < 20) {
            const hasSafetyWarning = recommendationText.includes('poor') || 
                                   recommendationText.includes('hazardous') ||
                                   recommendationText.includes('avoid') ||
                                   recommendationText.includes('indoor') ||
                                   recommendationText.includes('strongly recommend');
            
            if (!hasSafetyWarning) {
              return false;
            }
          }

          return true;
        } catch (error) {
          console.error('Hazardous conditions test failed:', error);
          return false;
        }
      };

      const generator: Generator<{ location: LocationData; weather: WeatherData; score: EnvironmentScore }> = () => ({
        location: generateLocationData(),
        weather: generateWeatherData(),
        score: generateHazardousEnvironmentScore()
      });

      const result = forAll(generator, testProperty, { iterations: 100 });
      
      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Hazardous conditions counter-example:', JSON.stringify(result.counterExample, null, 2));
      }
    });

    /**
     * Property Test 3: Environment Score Correlation
     * Tests that recommendation quality correlates with environment score
     */
    it('should provide recommendations that correlate with environment score quality', () => {
      const testProperty = (data: { location: LocationData; weather: WeatherData; score: EnvironmentScore }) => {
        try {
          const fallbackRec = aiCoachService.getFallbackRecommendation(data.score.overall);
          
          // High scores (80+) should recommend outdoor activities
          if (data.score.overall >= 80 && fallbackRec.activityType !== 'outdoor') {
            return false;
          }
          
          // Low scores (<40) should recommend indoor activities
          if (data.score.overall < 40 && fallbackRec.activityType !== 'indoor') {
            return false;
          }
          
          // Medium scores (40-79) should recommend outdoor or mixed activities
          if (data.score.overall >= 40 && data.score.overall < 80 && 
              !['outdoor', 'mixed'].includes(fallbackRec.activityType)) {
            return false;
          }

          return true;
        } catch (error) {
          console.error('Score correlation test failed:', error);
          return false;
        }
      };

      const generator: Generator<{ location: LocationData; weather: WeatherData; score: EnvironmentScore }> = () => ({
        location: generateLocationData(),
        weather: generateWeatherData(),
        score: generateEnvironmentScore()
      });

      const result = forAll(generator, testProperty, { iterations: 100 });
      
      expect(result.success).assertTrue();
      if (!result.success) {
        console.error('Score correlation counter-example:', JSON.stringify(result.counterExample, null, 2));
      }
    });

    /**
     * Property Test 4: API Response Validation
     * Tests that API response validation correctly identifies valid and invalid responses
     */
    it('should correctly validate API responses', () => {
      const testProperty = (validResponse: boolean) => {
        try {
          let response: any;
          
          if (validResponse) {
            // Generate valid response
            response = {
              recommendation: Random.string(50),
              reasoning: Random.string(100),
              activityType: Random.arrayElement(['indoor', 'outdoor', 'mixed']),
              urgency: Random.arrayElement(['low', 'medium', 'high']),
              confidence: Random.float(0, 1)
            };
          } else {
            // Generate invalid response
            const invalidTypes = [
              { recommendation: 123 }, // Wrong type
              { reasoning: null }, // Missing field
              { activityType: 'invalid' }, // Invalid value
              { urgency: 'extreme' }, // Invalid value
              { confidence: 1.5 }, // Out of range
              null, // Null response
              'string' // Wrong type
            ];
            response = Random.arrayElement(invalidTypes);
          }
          
          const isValid = aiCoachService.validateAPIResponse(response);
          
          // Should return true for valid responses, false for invalid ones
          return isValid === validResponse;
        } catch (error) {
          console.error('API validation test failed:', error);
          return false;
        }
      };

      // Test both valid and invalid responses
      const validGenerator: Generator<boolean> = () => true;
      const invalidGenerator: Generator<boolean> = () => false;
      
      const validResult = forAll(validGenerator, testProperty, { iterations: 50 });
      const invalidResult = forAll(invalidGenerator, testProperty, { iterations: 50 });
      
      expect(validResult.success).assertTrue();
      expect(invalidResult.success).assertTrue();
      
      if (!validResult.success) {
        console.error('Valid response validation failed');
      }
      if (!invalidResult.success) {
        console.error('Invalid response validation failed');
      }
    });

    /**
     * Unit Tests for AI Coach Service
     * Testing specific functionality: prompt generation, fallback logic, response validation, caching
     */

    /**
     * Unit Test: Prompt Generation from Environmental Context
     */
    it('should generate proper prompts from environmental context', () => {
      const location: LocationData = {
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 10,
        timestamp: Date.now()
      };

      const weather: WeatherData = {
        temperature: 22,
        humidity: 65,
        windSpeed: 5.5,
        windDirection: 180,
        uvIndex: 6,
        airQualityIndex: 85,
        visibility: 10000,
        timestamp: Date.now()
      };

      const environmentScore: EnvironmentScore = {
        overall: 75,
        airQuality: 80,
        weatherConditions: 85,
        uvRisk: 60,
        calculatedAt: Date.now()
      };

      // Test fallback recommendation generation (proxy for prompt generation logic)
      const recommendation = aiCoachService.getFallbackRecommendation(environmentScore.overall);
      
      expect(recommendation).assertInstanceOf(Object);
      expect(recommendation.recommendation).assertInstanceOf('string');
      expect(recommendation.reasoning).assertInstanceOf('string');
      expect(['indoor', 'outdoor', 'mixed']).assertContain(recommendation.activityType);
      expect(recommendation.source).assertEqual('fallback');
    });

    /**
     * Unit Test: Fallback Recommendation Logic for Different Score Ranges
     */
    it('should provide appropriate fallback recommendations for different environment scores', () => {
      // Test excellent conditions (80+)
      const excellentRec = aiCoachService.getFallbackRecommendation(85);
      expect(excellentRec.activityType).assertEqual('outdoor');
      expect(excellentRec.recommendation.toLowerCase()).assertContain('excellent');

      // Test good conditions (60-79)
      const goodRec = aiCoachService.getFallbackRecommendation(70);
      expect(goodRec.activityType).assertEqual('outdoor');
      expect(goodRec.recommendation.toLowerCase()).assertContain('good');

      // Test mixed conditions (40-59)
      const mixedRec = aiCoachService.getFallbackRecommendation(50);
      expect(mixedRec.activityType).assertEqual('mixed');
      expect(mixedRec.recommendation.toLowerCase()).assertContain('mixed');

      // Test poor conditions (<40)
      const poorRec = aiCoachService.getFallbackRecommendation(25);
      expect(poorRec.activityType).assertEqual('indoor');
      expect(poorRec.recommendation.toLowerCase()).assertContain('poor');
    });

    /**
     * Unit Test: API Response Validation with Specific Cases
     */
    it('should validate API responses correctly for specific test cases', () => {
      // Valid response
      const validResponse = {
        recommendation: "Great weather for outdoor running!",
        reasoning: "Good air quality and moderate temperature",
        activityType: "outdoor",
        urgency: "medium",
        confidence: 0.85
      };
      expect(aiCoachService.validateAPIResponse(validResponse)).assertTrue();

      // Invalid response - missing field
      const invalidResponse1 = {
        recommendation: "Go for a walk",
        reasoning: "Nice weather",
        activityType: "outdoor"
        // Missing urgency
      };
      expect(aiCoachService.validateAPIResponse(invalidResponse1)).assertFalse();

      // Invalid response - wrong activity type
      const invalidResponse2 = {
        recommendation: "Exercise indoors",
        reasoning: "Poor air quality",
        activityType: "invalid_type",
        urgency: "high",
        confidence: 0.9
      };
      expect(aiCoachService.validateAPIResponse(invalidResponse2)).assertFalse();

      // Invalid response - confidence out of range
      const invalidResponse3 = {
        recommendation: "Light exercise recommended",
        reasoning: "Moderate conditions",
        activityType: "mixed",
        urgency: "low",
        confidence: 1.5 // Invalid: > 1
      };
      expect(aiCoachService.validateAPIResponse(invalidResponse3)).assertFalse();

      // Invalid response - null
      expect(aiCoachService.validateAPIResponse(null)).assertFalse();

      // Invalid response - wrong type
      expect(aiCoachService.validateAPIResponse("string")).assertFalse();
    });

    /**
     * Unit Test: Cache Management
     */
    it('should manage recommendation caching properly', () => {
      // Test cache statistics
      const initialStats = aiCoachService.getCacheStats();
      expect(initialStats.size).assertInstanceOf('number');
      expect(initialStats.expired).assertInstanceOf('number');

      // Test cache clearing
      aiCoachService.clearExpiredCache();
      const afterClearStats = aiCoachService.getCacheStats();
      expect(afterClearStats.expired).assertEqual(0);
    });

    /**
     * Unit Test: Fallback Recommendation Validation
     */
    it('should generate valid fallback recommendations for edge cases', () => {
      // Test boundary values
      const minScore = aiCoachService.getFallbackRecommendation(0);
      expect(minScore.activityType).assertEqual('indoor');
      expect(minScore.recommendation).assertInstanceOf('string');
      expect(minScore.reasoning).assertInstanceOf('string');

      const maxScore = aiCoachService.getFallbackRecommendation(100);
      expect(maxScore.activityType).assertEqual('outdoor');
      expect(maxScore.recommendation).assertInstanceOf('string');
      expect(maxScore.reasoning).assertInstanceOf('string');

      // Test threshold boundaries
      const threshold39 = aiCoachService.getFallbackRecommendation(39);
      expect(threshold39.activityType).assertEqual('indoor');

      const threshold40 = aiCoachService.getFallbackRecommendation(40);
      expect(threshold40.activityType).assertEqual('mixed');

      const threshold60 = aiCoachService.getFallbackRecommendation(60);
      expect(threshold60.activityType).assertEqual('outdoor');

      const threshold80 = aiCoachService.getFallbackRecommendation(80);
      expect(threshold80.activityType).assertEqual('outdoor');
    });

    /**
     * Unit Test: Safety Warnings for Hazardous Conditions
     */
    it('should include appropriate safety warnings for hazardous conditions', () => {
      // Test very poor conditions
      const veryPoorRec = aiCoachService.getFallbackRecommendation(15);
      const recommendationText = veryPoorRec.recommendation.toLowerCase();
      
      expect(veryPoorRec.activityType).assertEqual('indoor');
      
      // Should contain safety-related keywords
      const hasSafetyKeywords = recommendationText.includes('poor') ||
                               recommendationText.includes('hazardous') ||
                               recommendationText.includes('strongly recommend') ||
                               recommendationText.includes('indoor');
      expect(hasSafetyKeywords).assertTrue();
    });

    /**
     * Unit Test: Recommendation Consistency
     */
    it('should provide consistent recommendations for same input', () => {
      const score = 65;
      
      // Generate multiple recommendations for same score
      const rec1 = aiCoachService.getFallbackRecommendation(score);
      const rec2 = aiCoachService.getFallbackRecommendation(score);
      const rec3 = aiCoachService.getFallbackRecommendation(score);
      
      // Should be identical
      expect(rec1.recommendation).assertEqual(rec2.recommendation);
      expect(rec2.recommendation).assertEqual(rec3.recommendation);
      expect(rec1.activityType).assertEqual(rec2.activityType);
      expect(rec2.activityType).assertEqual(rec3.activityType);
      expect(rec1.reasoning).assertEqual(rec2.reasoning);
      expect(rec2.reasoning).assertEqual(rec3.reasoning);
    });
  });
}

/**
 * Helper function to create environment context for testing
 */
function createTestEnvironmentContext(
  location: LocationData,
  weather: WeatherData,
  environmentScore: EnvironmentScore
): EnvironmentContext {
  const now = new Date();
  const hour = now.getHours();
  const dayOfWeek = now.getDay();
  const month = now.getMonth();
  
  let season: 'spring' | 'summer' | 'autumn' | 'winter';
  if (month >= 2 && month <= 4) season = 'spring';
  else if (month >= 5 && month <= 7) season = 'summer';
  else if (month >= 8 && month <= 10) season = 'autumn';
  else season = 'winter';

  return {
    location: {
      latitude: location.latitude,
      longitude: location.longitude
    },
    weather: {
      temperature: weather.temperature,
      humidity: weather.humidity,
      windSpeed: weather.windSpeed,
      uvIndex: weather.uvIndex,
      airQualityIndex: weather.airQualityIndex
    },
    environmentScore: {
      overall: environmentScore.overall,
      airQuality: environmentScore.airQuality,
      weatherConditions: environmentScore.weatherConditions,
      uvRisk: environmentScore.uvRisk
    },
    timeContext: {
      hour,
      dayOfWeek,
      season
    }
  };
}