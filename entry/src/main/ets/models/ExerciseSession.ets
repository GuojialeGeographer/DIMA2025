import { LocationData } from './LocationData';
import { EnvironmentScore } from './EnvironmentScore';

/**
 * Exercise session interface for tracking workout data with environmental context
 */
export interface ExerciseSession {
  id: number;
  startTime: number;
  endTime: number;
  route: LocationData[];
  environmentalConditions: EnvironmentScore[];
  averageEnvironmentScore: number;
  distance: number;
  duration: number;
  notes?: string;
}

/**
 * Validates ExerciseSession object
 * @param data - The exercise session data to validate
 * @returns true if valid, false otherwise
 */
export function validateExerciseSession(data: any): data is ExerciseSession {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.id !== 'number' ||
      typeof data.startTime !== 'number' ||
      typeof data.endTime !== 'number' ||
      !Array.isArray(data.route) ||
      !Array.isArray(data.environmentalConditions) ||
      typeof data.averageEnvironmentScore !== 'number' ||
      typeof data.distance !== 'number' ||
      typeof data.duration !== 'number') {
    return false;
  }

  // Validate ID (should be positive)
  if (data.id < 0) {
    return false;
  }

  // Validate timestamps
  if (data.startTime < 0 || data.endTime < 0) {
    return false;
  }

  // Validate that end time is after start time
  if (data.endTime <= data.startTime) {
    return false;
  }

  // Validate average environment score (0-100)
  if (data.averageEnvironmentScore < 0 || data.averageEnvironmentScore > 100) {
    return false;
  }

  // Validate distance (should be non-negative)
  if (data.distance < 0) {
    return false;
  }

  // Validate duration (should be positive)
  if (data.duration <= 0) {
    return false;
  }

  // Validate duration matches time difference (within reasonable tolerance)
  const calculatedDuration = data.endTime - data.startTime;
  if (Math.abs(data.duration - calculatedDuration) > 1000) { // 1 second tolerance
    return false;
  }

  // Validate optional notes field
  if (data.notes !== undefined && typeof data.notes !== 'string') {
    return false;
  }

  // Note: We don't validate the contents of route and environmentalConditions arrays here
  // as that would require importing and using the respective validation functions
  // This validation focuses on the structure of the ExerciseSession itself

  return true;
}