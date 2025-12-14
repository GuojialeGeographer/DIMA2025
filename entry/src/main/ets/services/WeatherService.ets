/**
 * Weather service for OpenWeatherMap API integration and environment scoring
 */
import { WeatherData, validateWeatherData } from '../models/WeatherData';
import { EnvironmentScore, validateEnvironmentScore } from '../models/EnvironmentScore';
import { LocationData } from '../models/LocationData';
import { DatabaseService, CachedEnvironmentData } from './DatabaseService';
import { ErrorHandler, ErrorCategory, retryWithBackoff, withTimeout } from '../utils/ErrorHandler';
import { createLogger } from '../utils/Logger';
import http from '@ohos.net.http';

/**
 * Weather API response interface
 */
interface WeatherAPIResponse {
  main: {
    temp: number;
    humidity: number;
  };
  wind: {
    speed: number;
    deg: number;
  };
  visibility: number;
  dt: number;
}

/**
 * Air Quality API response interface
 */
interface AirQualityAPIResponse {
  list: Array<{
    main: {
      aqi: number;
    };
    components: {
      co: number;
      no: number;
      no2: number;
      o3: number;
      so2: number;
      pm2_5: number;
      pm10: number;
      nh3: number;
    };
    dt: number;
  }>;
}

/**
 * UV Index API response interface
 */
interface UVIndexAPIResponse {
  value: number;
  date_iso: string;
}

/**
 * Retry configuration for API calls
 */
interface RetryConfig {
  maxAttempts: number;
  baseDelay: number;
  backoffStrategy: 'exponential' | 'linear' | 'fixed';
}

/**
 * Default retry configuration
 */
const DEFAULT_RETRY_CONFIG: RetryConfig = {
  maxAttempts: 3,
  baseDelay: 1000, // 1 second
  backoffStrategy: 'exponential'
};

/**
 * Cache expiration time in milliseconds (30 minutes)
 */
const CACHE_EXPIRATION_MS = 30 * 60 * 1000;

/**
 * Weather service class
 */
export class WeatherService {
  private apiKey: string;
  private baseUrl: string = 'https://api.openweathermap.org/data/2.5';
  private databaseService: DatabaseService;
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();
  private logger = createLogger('WeatherService');

  constructor(apiKey: string, databaseService: DatabaseService) {
    this.apiKey = apiKey;
    this.databaseService = databaseService;
  }

  /**
   * Get weather data for given coordinates
   * @param location - GPS coordinates
   * @returns Promise<WeatherData>
   */
  async getWeatherData(location: LocationData): Promise<WeatherData> {
    this.logger.info('Fetching weather data', { 
      latitude: location.latitude, 
      longitude: location.longitude 
    });

    try {
      // Check cache first
      const cachedData = await this.getCachedWeatherData(location);
      if (cachedData && !this.isCacheExpired(cachedData)) {
        this.logger.info('Using cached weather data');
        return cachedData.weatherData;
      }

      // Fetch fresh data from API with timeout and retry
      const weatherData = await withTimeout(
        this.fetchWeatherDataWithRetry(location),
        30000, // 30 second timeout
        'Weather API request timed out'
      );
      
      // Cache the data
      await this.cacheWeatherData(location, weatherData);
      
      this.logger.info('Successfully fetched fresh weather data');
      return weatherData;
    } catch (error) {
      // Handle error with structured error handling
      const appError = await this.errorHandler.handleError(
        error as Error,
        ErrorCategory.API,
        { 
          service: 'WeatherService',
          operation: 'getWeatherData',
          location: { lat: location.latitude, lon: location.longitude }
        },
        {
          maxRetries: 2,
          retryDelay: 2000,
          fallbackAction: async () => {
            // Try to use cached data even if expired
            const cachedData = await this.getCachedWeatherData(location);
            if (cachedData) {
              this.logger.warn('Using expired cached weather data due to API failure');
              return cachedData.weatherData;
            }
            throw new Error('No cached data available');
          }
        }
      );

      // If we have cached data, use it even if expired
      const cachedData = await this.getCachedWeatherData(location);
      if (cachedData) {
        this.logger.warn('Using expired cached weather data due to API failure');
        return cachedData.weatherData;
      }

      throw appError;
    }
  }

  /**
   * Calculate environment score from weather data
   * @param weatherData - Weather data
   * @returns EnvironmentScore
   */
  calculateEnvironmentScore(weatherData: WeatherData): EnvironmentScore {
    const airQualityScore = this.calculateAirQualityScore(weatherData.airQualityIndex);
    const weatherConditionsScore = this.calculateWeatherConditionsScore(weatherData);
    const uvRiskScore = this.calculateUVRiskScore(weatherData.uvIndex);
    
    // Calculate overall score as weighted average
    const overall = Math.round(
      (airQualityScore * 0.4) + 
      (weatherConditionsScore * 0.4) + 
      (uvRiskScore * 0.2)
    );

    const environmentScore: EnvironmentScore = {
      overall: Math.max(0, Math.min(100, overall)),
      airQuality: airQualityScore,
      weatherConditions: weatherConditionsScore,
      uvRisk: uvRiskScore,
      calculatedAt: Date.now()
    };

    return environmentScore;
  }

  /**
   * Fetch weather data with retry mechanism
   * @param location - GPS coordinates
   * @param config - Retry configuration
   * @returns Promise<WeatherData>
   */
  private async fetchWeatherDataWithRetry(
    location: LocationData, 
    config: RetryConfig = DEFAULT_RETRY_CONFIG
  ): Promise<WeatherData> {
    let lastError: Error;

    for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        return await this.fetchWeatherDataFromAPI(location);
      } catch (error) {
        lastError = error as Error;
        
        if (attempt === config.maxAttempts) {
          break;
        }

        // Calculate delay based on backoff strategy
        const delay = this.calculateBackoffDelay(attempt, config);
        await this.sleep(delay);
      }
    }

    throw new Error(`Weather API failed after ${config.maxAttempts} attempts: ${lastError.message}`);
  }

  /**
   * Fetch weather data from OpenWeatherMap API
   * @param location - GPS coordinates
   * @returns Promise<WeatherData>
   */
  private async fetchWeatherDataFromAPI(location: LocationData): Promise<WeatherData> {
    const httpRequest = http.createHttp();
    const startTime = Date.now();
    
    try {
      this.logger.info('Making weather API requests', { 
        latitude: location.latitude, 
        longitude: location.longitude 
      });

      // Fetch current weather
      const weatherUrl = `${this.baseUrl}/weather?lat=${location.latitude}&lon=${location.longitude}&appid=${this.apiKey}&units=metric`;
      const weatherResponse = await httpRequest.request(weatherUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        }
      });

      this.logger.apiCall('GET', weatherUrl, weatherResponse.responseCode, Date.now() - startTime);

      if (weatherResponse.responseCode !== 200) {
        throw new Error(`Weather API returned status ${weatherResponse.responseCode}`);
      }

      const weatherData = JSON.parse(weatherResponse.result as string) as WeatherAPIResponse;

      // Validate API response structure
      if (!this.validateAPIResponse(weatherData, ['main.temp', 'main.humidity', 'wind.speed'])) {
        throw new Error('Invalid weather API response structure');
      }

      // Fetch air quality data
      const aqiUrl = `${this.baseUrl}/air_pollution?lat=${location.latitude}&lon=${location.longitude}&appid=${this.apiKey}`;
      const aqiResponse = await httpRequest.request(aqiUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        }
      });

      this.logger.apiCall('GET', aqiUrl, aqiResponse.responseCode);

      if (aqiResponse.responseCode !== 200) {
        throw new Error(`Air Quality API returned status ${aqiResponse.responseCode}`);
      }

      const aqiData = JSON.parse(aqiResponse.result as string) as AirQualityAPIResponse;

      // Validate AQI response
      if (!this.validateAPIResponse(aqiData, ['list.0.main.aqi'])) {
        throw new Error('Invalid air quality API response structure');
      }

      // Fetch UV index
      const uvUrl = `${this.baseUrl}/uvi?lat=${location.latitude}&lon=${location.longitude}&appid=${this.apiKey}`;
      const uvResponse = await httpRequest.request(uvUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        }
      });

      this.logger.apiCall('GET', uvUrl, uvResponse.responseCode);

      if (uvResponse.responseCode !== 200) {
        throw new Error(`UV Index API returned status ${uvResponse.responseCode}`);
      }

      const uvData = JSON.parse(uvResponse.result as string) as UVIndexAPIResponse;

      // Validate UV response
      if (!this.validateAPIResponse(uvData, ['value'])) {
        throw new Error('Invalid UV index API response structure');
      }

      // Combine data into WeatherData format
      const combinedWeatherData: WeatherData = {
        temperature: weatherData.main.temp,
        humidity: weatherData.main.humidity,
        windSpeed: weatherData.wind.speed,
        windDirection: weatherData.wind.deg || 0,
        uvIndex: uvData.value,
        airQualityIndex: this.convertAQIToStandardScale(aqiData.list[0].main.aqi),
        visibility: weatherData.visibility / 1000, // Convert to km
        timestamp: Date.now()
      };

      // Validate the data before returning
      if (!validateWeatherData(combinedWeatherData)) {
        throw new Error('Invalid weather data received from API');
      }

      this.logger.info('Successfully fetched and validated weather data', {
        temperature: combinedWeatherData.temperature,
        humidity: combinedWeatherData.humidity,
        aqi: combinedWeatherData.airQualityIndex
      });

      return combinedWeatherData;
    } catch (error) {
      this.logger.error('Weather API request failed', {
        latitude: location.latitude,
        longitude: location.longitude,
        duration: Date.now() - startTime
      }, error as Error);
      throw error;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * Convert OpenWeatherMap AQI scale (1-5) to standard scale (0-500)
   * @param owmAqi - OpenWeatherMap AQI value (1-5)
   * @returns Standard AQI value (0-500)
   */
  private convertAQIToStandardScale(owmAqi: number): number {
    // OpenWeatherMap uses 1-5 scale, convert to EPA standard 0-500 scale
    const aqiMapping = {
      1: 25,   // Good (0-50)
      2: 75,   // Fair (51-100)
      3: 150,  // Moderate (101-150)
      4: 225,  // Poor (151-200)
      5: 350   // Very Poor (201-300)
    };
    
    return aqiMapping[owmAqi as keyof typeof aqiMapping] || 500;
  }

  /**
   * Calculate air quality score (0-100, higher is better)
   * @param aqi - Air Quality Index (0-500)
   * @returns Score from 0-100
   */
  private calculateAirQualityScore(aqi: number): number {
    if (aqi <= 50) return 100;      // Good
    if (aqi <= 100) return 80;      // Moderate
    if (aqi <= 150) return 60;      // Unhealthy for sensitive groups
    if (aqi <= 200) return 40;      // Unhealthy
    if (aqi <= 300) return 20;      // Very unhealthy
    return 0;                       // Hazardous
  }

  /**
   * Calculate weather conditions score (0-100, higher is better)
   * @param weather - Weather data
   * @returns Score from 0-100
   */
  private calculateWeatherConditionsScore(weather: WeatherData): number {
    let score = 100;

    // Temperature factor (optimal range: 15-25°C)
    if (weather.temperature < 0 || weather.temperature > 35) {
      score -= 30;
    } else if (weather.temperature < 10 || weather.temperature > 30) {
      score -= 15;
    } else if (weather.temperature < 15 || weather.temperature > 25) {
      score -= 5;
    }

    // Humidity factor (optimal range: 40-60%)
    if (weather.humidity < 20 || weather.humidity > 80) {
      score -= 20;
    } else if (weather.humidity < 30 || weather.humidity > 70) {
      score -= 10;
    }

    // Wind factor (optimal: light breeze 5-15 km/h)
    if (weather.windSpeed > 25) {
      score -= 20;
    } else if (weather.windSpeed > 20) {
      score -= 10;
    } else if (weather.windSpeed < 2) {
      score -= 5;
    }

    // Visibility factor
    if (weather.visibility < 1) {
      score -= 25;
    } else if (weather.visibility < 5) {
      score -= 10;
    }

    return Math.max(0, Math.min(100, score));
  }

  /**
   * Calculate UV risk score (0-100, higher is better/safer)
   * @param uvIndex - UV Index value
   * @returns Score from 0-100
   */
  private calculateUVRiskScore(uvIndex: number): number {
    if (uvIndex <= 2) return 100;      // Low
    if (uvIndex <= 5) return 80;       // Moderate
    if (uvIndex <= 7) return 60;       // High
    if (uvIndex <= 10) return 40;      // Very high
    return 20;                         // Extreme
  }

  /**
   * Get cached weather data for location
   * @param location - GPS coordinates
   * @returns Promise<CachedEnvironmentData | null>
   */
  private async getCachedWeatherData(location: LocationData): Promise<CachedEnvironmentData | null> {
    try {
      return await this.databaseService.getCachedEnvironmentData(location);
    } catch (error) {
      console.warn('Failed to get cached weather data:', error);
      return null;
    }
  }

  /**
   * Cache weather data
   * @param location - GPS coordinates
   * @param weatherData - Weather data to cache
   */
  private async cacheWeatherData(location: LocationData, weatherData: WeatherData): Promise<void> {
    try {
      const environmentScore = this.calculateEnvironmentScore(weatherData);
      const cachedData: CachedEnvironmentData = {
        latitude: location.latitude,
        longitude: location.longitude,
        weatherData: weatherData,
        environmentScore: environmentScore,
        cachedAt: Date.now(),
        expiresAt: Date.now() + CACHE_EXPIRATION_MS
      };
      
      await this.databaseService.cacheEnvironmentData(cachedData);
    } catch (error) {
      console.warn('Failed to cache weather data:', error);
    }
  }

  /**
   * Check if cached data is expired
   * @param cachedData - Cached environment data
   * @returns true if expired, false otherwise
   */
  private isCacheExpired(cachedData: CachedEnvironmentData): boolean {
    return Date.now() > cachedData.expiresAt;
  }

  /**
   * Calculate backoff delay for retry attempts
   * @param attempt - Current attempt number
   * @param config - Retry configuration
   * @returns Delay in milliseconds
   */
  private calculateBackoffDelay(attempt: number, config: RetryConfig): number {
    switch (config.backoffStrategy) {
      case 'exponential':
        return config.baseDelay * Math.pow(2, attempt - 1);
      case 'linear':
        return config.baseDelay * attempt;
      case 'fixed':
      default:
        return config.baseDelay;
    }
  }

  /**
   * Sleep for specified milliseconds
   * @param ms - Milliseconds to sleep
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Validate API response structure
   * @param response - API response to validate
   * @param expectedFields - Expected fields in response
   * @returns true if valid, false otherwise
   */
  validateAPIResponse(response: any, expectedFields: string[]): boolean {
    if (!response || typeof response !== 'object') {
      return false;
    }

    return expectedFields.every(field => {
      const fieldPath = field.split('.');
      let current = response;
      
      for (const path of fieldPath) {
        if (!current || typeof current !== 'object' || !(path in current)) {
          return false;
        }
        current = current[path];
      }
      
      return true;
    });
  }
}