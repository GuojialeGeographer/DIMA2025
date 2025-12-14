/**
 * AI recommendation interface for exercise suggestions
 */
export interface AIRecommendation {
  id: string;
  recommendation: string;
  confidence: number; // 0-1 scale
  reasoning: string;
  activityType: 'indoor' | 'outdoor' | 'mixed';
  urgency: 'low' | 'medium' | 'high';
  timestamp: number;
  environmentContext: EnvironmentContext;
}

/**
 * Environment context interface for AI recommendation generation
 */
export interface EnvironmentContext {
  location: {
    latitude: number;
    longitude: number;
  };
  weather: {
    temperature: number;
    humidity: number;
    windSpeed: number;
    uvIndex: number;
    airQualityIndex: number;
  };
  environmentScore: {
    overall: number;
    airQuality: number;
    weatherConditions: number;
    uvRisk: number;
  };
  timeContext: {
    hour: number;
    dayOfWeek: number;
    season: 'spring' | 'summer' | 'autumn' | 'winter';
  };
}

/**
 * Local fallback recommendation interface
 */
export interface LocalRecommendation {
  recommendation: string;
  activityType: 'indoor' | 'outdoor' | 'mixed';
  reasoning: string;
  source: 'fallback';
}

/**
 * Validates AIRecommendation object
 * @param data - The AI recommendation data to validate
 * @returns true if valid, false otherwise
 */
export function validateAIRecommendation(data: any): data is AIRecommendation {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.id !== 'string' ||
      typeof data.recommendation !== 'string' ||
      typeof data.confidence !== 'number' ||
      typeof data.reasoning !== 'string' ||
      typeof data.activityType !== 'string' ||
      typeof data.urgency !== 'string' ||
      typeof data.timestamp !== 'number') {
    return false;
  }

  // Validate confidence range (0-1)
  if (data.confidence < 0 || data.confidence > 1) {
    return false;
  }

  // Validate activity type
  if (!['indoor', 'outdoor', 'mixed'].includes(data.activityType)) {
    return false;
  }

  // Validate urgency
  if (!['low', 'medium', 'high'].includes(data.urgency)) {
    return false;
  }

  // Validate timestamp (should be positive)
  if (data.timestamp < 0) {
    return false;
  }

  // Validate environment context
  if (!validateEnvironmentContext(data.environmentContext)) {
    return false;
  }

  return true;
}

/**
 * Validates EnvironmentContext object
 * @param data - The environment context data to validate
 * @returns true if valid, false otherwise
 */
export function validateEnvironmentContext(data: any): data is EnvironmentContext {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Validate location
  if (!data.location || typeof data.location !== 'object' ||
      typeof data.location.latitude !== 'number' ||
      typeof data.location.longitude !== 'number') {
    return false;
  }

  // Validate latitude/longitude ranges
  if (data.location.latitude < -90 || data.location.latitude > 90 ||
      data.location.longitude < -180 || data.location.longitude > 180) {
    return false;
  }

  // Validate weather
  if (!data.weather || typeof data.weather !== 'object' ||
      typeof data.weather.temperature !== 'number' ||
      typeof data.weather.humidity !== 'number' ||
      typeof data.weather.windSpeed !== 'number' ||
      typeof data.weather.uvIndex !== 'number' ||
      typeof data.weather.airQualityIndex !== 'number') {
    return false;
  }

  // Validate environment score
  if (!data.environmentScore || typeof data.environmentScore !== 'object' ||
      typeof data.environmentScore.overall !== 'number' ||
      typeof data.environmentScore.airQuality !== 'number' ||
      typeof data.environmentScore.weatherConditions !== 'number' ||
      typeof data.environmentScore.uvRisk !== 'number') {
    return false;
  }

  // Validate time context
  if (!data.timeContext || typeof data.timeContext !== 'object' ||
      typeof data.timeContext.hour !== 'number' ||
      typeof data.timeContext.dayOfWeek !== 'number' ||
      typeof data.timeContext.season !== 'string') {
    return false;
  }

  // Validate time ranges
  if (data.timeContext.hour < 0 || data.timeContext.hour > 23 ||
      data.timeContext.dayOfWeek < 0 || data.timeContext.dayOfWeek > 6) {
    return false;
  }

  // Validate season
  if (!['spring', 'summer', 'autumn', 'winter'].includes(data.timeContext.season)) {
    return false;
  }

  return true;
}

/**
 * Validates LocalRecommendation object
 * @param data - The local recommendation data to validate
 * @returns true if valid, false otherwise
 */
export function validateLocalRecommendation(data: any): data is LocalRecommendation {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.recommendation !== 'string' ||
      typeof data.activityType !== 'string' ||
      typeof data.reasoning !== 'string' ||
      typeof data.source !== 'string') {
    return false;
  }

  // Validate activity type
  if (!['indoor', 'outdoor', 'mixed'].includes(data.activityType)) {
    return false;
  }

  // Validate source
  if (data.source !== 'fallback') {
    return false;
  }

  return true;
}