/**
 * Weather data interface for environmental conditions
 */
export interface WeatherData {
  temperature: number;
  humidity: number;
  windSpeed: number;
  windDirection: number;
  uvIndex: number;
  airQualityIndex: number;
  visibility: number;
  timestamp: number;
}

/**
 * Validates WeatherData object
 * @param data - The weather data to validate
 * @returns true if valid, false otherwise
 */
export function validateWeatherData(data: any): data is WeatherData {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.temperature !== 'number' ||
      typeof data.humidity !== 'number' ||
      typeof data.windSpeed !== 'number' ||
      typeof data.windDirection !== 'number' ||
      typeof data.uvIndex !== 'number' ||
      typeof data.airQualityIndex !== 'number' ||
      typeof data.visibility !== 'number' ||
      typeof data.timestamp !== 'number') {
    return false;
  }

  // Validate humidity range (0-100%)
  if (data.humidity < 0 || data.humidity > 100) {
    return false;
  }

  // Validate wind speed (should be non-negative)
  if (data.windSpeed < 0) {
    return false;
  }

  // Validate wind direction (0-360 degrees)
  if (data.windDirection < 0 || data.windDirection > 360) {
    return false;
  }

  // Validate UV index (typically 0-11+, but allow higher values)
  if (data.uvIndex < 0) {
    return false;
  }

  // Validate air quality index (typically 0-500)
  if (data.airQualityIndex < 0 || data.airQualityIndex > 500) {
    return false;
  }

  // Validate visibility (should be non-negative)
  if (data.visibility < 0) {
    return false;
  }

  // Validate timestamp (should be positive)
  if (data.timestamp < 0) {
    return false;
  }

  return true;
}