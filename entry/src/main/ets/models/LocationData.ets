/**
 * Location data interface for GPS coordinates and related information
 */
export interface LocationData {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
  altitude?: number;
}

/**
 * Validates LocationData object
 * @param data - The location data to validate
 * @returns true if valid, false otherwise
 */
export function validateLocationData(data: any): data is LocationData {
  if (!data || typeof data !== 'object') {
    return false;
  }

  // Check required fields
  if (typeof data.latitude !== 'number' || 
      typeof data.longitude !== 'number' ||
      typeof data.accuracy !== 'number' ||
      typeof data.timestamp !== 'number') {
    return false;
  }

  // Validate latitude range (-90 to 90)
  if (data.latitude < -90 || data.latitude > 90) {
    return false;
  }

  // Validate longitude range (-180 to 180)
  if (data.longitude < -180 || data.longitude > 180) {
    return false;
  }

  // Validate accuracy (should be positive)
  if (data.accuracy < 0) {
    return false;
  }

  // Validate timestamp (should be positive)
  if (data.timestamp < 0) {
    return false;
  }

  // Validate optional altitude if present
  if (data.altitude !== undefined && typeof data.altitude !== 'number') {
    return false;
  }

  return true;
}