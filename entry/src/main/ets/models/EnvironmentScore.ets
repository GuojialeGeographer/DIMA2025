/**
 * Environment score interface for calculated environmental quality metrics
 */
export interface EnvironmentScore {
  overall: number; // 0-100 scale
  airQuality: number;
  weatherConditions: number;
  uvRisk: number;
  noiseLevel?: number;
  greenSpaceProximity?: number;
  calculatedAt: number;
}

/**
 * Validates EnvironmentScore object
 * @param data - The environment score data to validate
 * @returns true if valid, false otherwise
 */
export function validateEnvironmentScore(data: any): data is EnvironmentScore {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.overall !== 'number' ||
      typeof data.airQuality !== 'number' ||
      typeof data.weatherConditions !== 'number' ||
      typeof data.uvRisk !== 'number' ||
      typeof data.calculatedAt !== 'number') {
    return false;
  }

  // Validate score ranges (0-100)
  if (data.overall < 0 || data.overall > 100 ||
      data.airQuality < 0 || data.airQuality > 100 ||
      data.weatherConditions < 0 || data.weatherConditions > 100 ||
      data.uvRisk < 0 || data.uvRisk > 100) {
    return false;
  }

  // Validate optional fields if present
  if (data.noiseLevel !== undefined && 
      (typeof data.noiseLevel !== 'number' || data.noiseLevel < 0 || data.noiseLevel > 100)) {
    return false;
  }

  if (data.greenSpaceProximity !== undefined && 
      (typeof data.greenSpaceProximity !== 'number' || data.greenSpaceProximity < 0 || data.greenSpaceProximity > 100)) {
    return false;
  }

  // Validate timestamp (should be positive)
  if (data.calculatedAt < 0) {
    return false;
  }

  return true;
}