import { 
  AIRecommendation, 
  EnvironmentContext, 
  LocalRecommendation,
  validateAIRecommendation,
  validateEnvironmentContext 
} from '../models/AIRecommendation';
import { LocationData } from '../models/LocationData';
import { WeatherData } from '../models/WeatherData';
import { EnvironmentScore } from '../models/EnvironmentScore';
import { ErrorHandler, ErrorCategory, retryWithBackoff, withTimeout } from '../utils/ErrorHandler';
import { createLogger } from '../utils/Logger';

/**
 * Configuration for AI Coach Service
 */
interface AICoachConfig {
  apiUrl: string;
  apiKey: string;
  timeout: number;
  maxRetries: number;
  cacheExpiryMinutes: number;
}

/**
 * Cached recommendation entry
 */
interface CachedRecommendation {
  recommendation: AIRecommendation;
  expiresAt: number;
}

/**
 * AI Coach Service for generating personalized exercise recommendations
 */
export class AICoachService {
  private config: AICoachConfig;
  private cache: Map<string, CachedRecommendation> = new Map();
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();
  private logger = createLogger('AICoachService');

  constructor(config: AICoachConfig) {
    this.config = config;
  }

  /**
   * Generate AI-powered exercise recommendation based on environmental context
   * @param location - Current location data
   * @param weather - Current weather data
   * @param environmentScore - Calculated environment score
   * @returns Promise resolving to AI recommendation
   */
  async generateRecommendation(
    location: LocationData,
    weather: WeatherData,
    environmentScore: EnvironmentScore
  ): Promise<AIRecommendation> {
    this.logger.info('Generating AI recommendation', {
      environmentScore: environmentScore.overall,
      temperature: weather.temperature,
      aqi: weather.airQualityIndex
    });

    try {
      // Create environment context
      const context = this.createEnvironmentContext(location, weather, environmentScore);
      
      // Validate context
      if (!validateEnvironmentContext(context)) {
        throw new Error('Invalid environment context');
      }
      
      // Check cache first
      const cacheKey = this.generateCacheKey(context);
      const cached = this.getCachedRecommendation(cacheKey);
      if (cached) {
        this.logger.info('Using cached AI recommendation');
        return cached;
      }

      // Generate prompt for AI service
      const prompt = this.generatePrompt(context);
      
      // Call AI service with timeout and retry logic
      const response = await withTimeout(
        retryWithBackoff(
          () => this.callAIService(prompt),
          this.config.maxRetries,
          2000, // 2 second base delay
          2 // exponential backoff multiplier
        ),
        this.config.timeout,
        'AI service request timed out'
      );
      
      // Validate and parse response
      const recommendation = this.parseAIResponse(response, context);
      
      // Cache the recommendation
      this.cacheRecommendation(cacheKey, recommendation);
      
      this.logger.info('Successfully generated AI recommendation', {
        recommendationId: recommendation.id,
        confidence: recommendation.confidence,
        activityType: recommendation.activityType
      });
      
      return recommendation;
    } catch (error) {
      // Handle error with structured error handling
      const appError = await this.errorHandler.handleError(
        error as Error,
        ErrorCategory.API,
        {
          service: 'AICoachService',
          operation: 'generateRecommendation',
          environmentScore: environmentScore.overall,
          temperature: weather.temperature
        },
        {
          maxRetries: 1,
          retryDelay: 1000,
          fallbackAction: async () => {
            const fallback = this.getFallbackRecommendation(environmentScore.overall);
            return this.convertFallbackToAI(fallback, location, weather, environmentScore);
          }
        }
      );

      this.logger.warn('AI recommendation generation failed, using fallback', {
        error: (error as Error).message
      });

      // Return fallback recommendation
      const fallback = this.getFallbackRecommendation(environmentScore.overall);
      return this.convertFallbackToAI(fallback, location, weather, environmentScore);
    }
  }

  /**
   * Get rule-based fallback recommendation when AI service fails
   * @param environmentScore - Overall environment score (0-100)
   * @returns Local fallback recommendation
   */
  getFallbackRecommendation(environmentScore: number): LocalRecommendation {
    if (environmentScore >= 80) {
      return {
        recommendation: "Excellent conditions for outdoor exercise! Consider running, cycling, or outdoor sports. The air quality is good and weather conditions are favorable.",
        activityType: 'outdoor',
        reasoning: "High environment score indicates optimal outdoor conditions with good air quality and favorable weather.",
        source: 'fallback'
      };
    } else if (environmentScore >= 60) {
      return {
        recommendation: "Good conditions for moderate outdoor activities. Try walking, light jogging, or outdoor yoga. Monitor air quality if you have respiratory sensitivities.",
        activityType: 'outdoor',
        reasoning: "Moderate environment score suggests acceptable outdoor conditions with some minor concerns.",
        source: 'fallback'
      };
    } else if (environmentScore >= 40) {
      return {
        recommendation: "Mixed conditions - consider indoor alternatives or light outdoor activities in well-ventilated areas. Avoid intense outdoor exercise.",
        activityType: 'mixed',
        reasoning: "Below-average environment score indicates potential air quality or weather concerns.",
        source: 'fallback'
      };
    } else {
      return {
        recommendation: "Poor outdoor conditions detected. Strongly recommend indoor exercise such as gym workouts, home fitness, or indoor sports facilities.",
        activityType: 'indoor',
        reasoning: "Low environment score indicates hazardous outdoor conditions that could impact health during exercise.",
        source: 'fallback'
      };
    }
  }

  /**
   * Validate API response structure and content
   * @param response - Raw API response
   * @returns true if response is valid, false otherwise
   */
  validateAPIResponse(response: any): boolean {
    if (!response || typeof response !== 'object') {
      return false;
    }

    // Check for required fields in API response
    if (!response.recommendation || typeof response.recommendation !== 'string') {
      return false;
    }

    if (!response.reasoning || typeof response.reasoning !== 'string') {
      return false;
    }

    if (!response.activityType || !['indoor', 'outdoor', 'mixed'].includes(response.activityType)) {
      return false;
    }

    if (!response.urgency || !['low', 'medium', 'high'].includes(response.urgency)) {
      return false;
    }

    // Validate confidence if present
    if (response.confidence !== undefined && 
        (typeof response.confidence !== 'number' || response.confidence < 0 || response.confidence > 1)) {
      return false;
    }

    return true;
  }

  /**
   * Create environment context from current data
   * @param location - Location data
   * @param weather - Weather data
   * @param environmentScore - Environment score
   * @returns Environment context object
   */
  private createEnvironmentContext(
    location: LocationData,
    weather: WeatherData,
    environmentScore: EnvironmentScore
  ): EnvironmentContext {
    const now = new Date();
    const hour = now.getHours();
    const dayOfWeek = now.getDay();
    const month = now.getMonth();
    
    // Determine season based on month (Northern Hemisphere)
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

  /**
   * Generate cache key for recommendation caching
   * @param context - Environment context
   * @returns Cache key string
   */
  private generateCacheKey(context: EnvironmentContext): string {
    const roundedLat = Math.round(context.location.latitude * 100) / 100;
    const roundedLon = Math.round(context.location.longitude * 100) / 100;
    const roundedTemp = Math.round(context.weather.temperature);
    const roundedScore = Math.round(context.environmentScore.overall);
    
    return `${roundedLat}_${roundedLon}_${roundedTemp}_${roundedScore}_${context.timeContext.hour}`;
  }

  /**
   * Get cached recommendation if available and not expired
   * @param cacheKey - Cache key
   * @returns Cached recommendation or null
   */
  private getCachedRecommendation(cacheKey: string): AIRecommendation | null {
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.recommendation;
    }
    
    // Remove expired entry
    if (cached) {
      this.cache.delete(cacheKey);
    }
    
    return null;
  }

  /**
   * Cache recommendation with expiry
   * @param cacheKey - Cache key
   * @param recommendation - Recommendation to cache
   */
  private cacheRecommendation(cacheKey: string, recommendation: AIRecommendation): void {
    const expiresAt = Date.now() + (this.config.cacheExpiryMinutes * 60 * 1000);
    this.cache.set(cacheKey, { recommendation, expiresAt });
  }

  /**
   * Generate prompt for AI service
   * @param context - Environment context
   * @returns Formatted prompt string
   */
  private generatePrompt(context: EnvironmentContext): string {
    return `You are an AI fitness coach specializing in urban exercise recommendations. Based on the following environmental data, provide a personalized exercise recommendation:

Location: ${context.location.latitude.toFixed(2)}, ${context.location.longitude.toFixed(2)}
Time: ${context.timeContext.hour}:00, Day ${context.timeContext.dayOfWeek}, Season: ${context.timeContext.season}

Weather Conditions:
- Temperature: ${context.weather.temperature}°C
- Humidity: ${context.weather.humidity}%
- Wind Speed: ${context.weather.windSpeed} m/s
- UV Index: ${context.weather.uvIndex}
- Air Quality Index: ${context.weather.airQualityIndex}

Environment Scores (0-100):
- Overall: ${context.environmentScore.overall}
- Air Quality: ${context.environmentScore.airQuality}
- Weather Conditions: ${context.environmentScore.weatherConditions}
- UV Risk: ${context.environmentScore.uvRisk}

Please provide:
1. A specific exercise recommendation (2-3 sentences)
2. Clear reasoning for your recommendation
3. Activity type: indoor, outdoor, or mixed
4. Urgency level: low, medium, or high
5. Confidence level (0.0-1.0)

Focus on health and safety. If conditions are hazardous (low air quality, extreme weather), explicitly warn against outdoor exercise.

Respond in JSON format:
{
  "recommendation": "your recommendation text",
  "reasoning": "explanation of your reasoning",
  "activityType": "indoor|outdoor|mixed",
  "urgency": "low|medium|high",
  "confidence": 0.85
}`;
  }

  /**
   * Call AI service with retry logic
   * @param prompt - Prompt to send to AI service
   * @returns API response
   */
  private async callAIService(prompt: string): Promise<any> {
    let lastError: Error | null = null;
    
    for (let attempt = 0; attempt < this.config.maxRetries; attempt++) {
      try {
        const response = await fetch(this.config.apiUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.config.apiKey}`
          },
          body: JSON.stringify({
            model: 'deepseek-chat',
            messages: [
              {
                role: 'user',
                content: prompt
              }
            ],
            temperature: 0.7,
            max_tokens: 500
          })
        });

        if (!response.ok) {
          throw new Error(`API request failed: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        
        // Extract content from API response (DeepSeek format)
        if (data.choices && data.choices[0] && data.choices[0].message) {
          return JSON.parse(data.choices[0].message.content);
        }
        
        throw new Error('Invalid API response format');
      } catch (error) {
        lastError = error as Error;
        console.warn(`AI service attempt ${attempt + 1} failed:`, error);
        
        // Exponential backoff delay
        if (attempt < this.config.maxRetries - 1) {
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
        }
      }
    }
    
    throw lastError || new Error('AI service failed after all retries');
  }

  /**
   * Parse and validate AI service response
   * @param response - Raw API response
   * @param context - Environment context
   * @returns Validated AI recommendation
   */
  private parseAIResponse(response: any, context: EnvironmentContext): AIRecommendation {
    if (!this.validateAPIResponse(response)) {
      throw new Error('Invalid API response structure');
    }

    const recommendation: AIRecommendation = {
      id: this.generateRecommendationId(),
      recommendation: response.recommendation,
      confidence: response.confidence || 0.8,
      reasoning: response.reasoning,
      activityType: response.activityType,
      urgency: response.urgency,
      timestamp: Date.now(),
      environmentContext: context
    };

    if (!validateAIRecommendation(recommendation)) {
      throw new Error('Generated recommendation failed validation');
    }

    return recommendation;
  }

  /**
   * Convert fallback recommendation to AI recommendation format
   * @param fallback - Local fallback recommendation
   * @param location - Location data
   * @param weather - Weather data
   * @param environmentScore - Environment score
   * @returns AI recommendation
   */
  private convertFallbackToAI(
    fallback: LocalRecommendation,
    location: LocationData,
    weather: WeatherData,
    environmentScore: EnvironmentScore
  ): AIRecommendation {
    const context = this.createEnvironmentContext(location, weather, environmentScore);
    
    return {
      id: this.generateRecommendationId(),
      recommendation: fallback.recommendation,
      confidence: 0.6, // Lower confidence for fallback
      reasoning: fallback.reasoning,
      activityType: fallback.activityType,
      urgency: environmentScore.overall < 40 ? 'high' : 'medium',
      timestamp: Date.now(),
      environmentContext: context
    };
  }

  /**
   * Generate unique recommendation ID
   * @returns Unique ID string
   */
  private generateRecommendationId(): string {
    return `rec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Clear expired cache entries
   */
  clearExpiredCache(): void {
    const now = Date.now();
    for (const [key, cached] of this.cache.entries()) {
      if (cached.expiresAt <= now) {
        this.cache.delete(key);
      }
    }
  }

  /**
   * Get cache statistics
   * @returns Cache statistics
   */
  getCacheStats(): { size: number; expired: number } {
    const now = Date.now();
    let expired = 0;
    
    for (const cached of this.cache.values()) {
      if (cached.expiresAt <= now) {
        expired++;
      }
    }
    
    return {
      size: this.cache.size,
      expired
    };
  }
}