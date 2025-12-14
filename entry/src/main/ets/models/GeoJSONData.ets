/**
 * GeoJSON data structures for environmental zones
 */

export interface GeoJSONGeometry {
  type: 'Point' | 'LineString' | 'Polygon' | 'MultiPoint' | 'MultiLineString' | 'MultiPolygon';
  coordinates: number[] | number[][] | number[][][];
}

export interface GeoJSONProperties {
  zoneType: 'green' | 'red' | 'gray';
  name: string;
  description: string;
  environmentalFactors: {
    airQuality?: 'good' | 'moderate' | 'poor';
    noiseLevel?: 'low' | 'medium' | 'high';
    gpsSignal?: 'strong' | 'weak' | 'blocked';
  };
}

export interface GeoJSONFeature {
  type: 'Feature';
  geometry: GeoJSONGeometry;
  properties: GeoJSONProperties;
}

export interface GeoJSONFeatureCollection {
  type: 'FeatureCollection';
  features: GeoJSONFeature[];
}

export interface ZoneInfo {
  name: string;
  description: string;
  zoneType: 'green' | 'red' | 'gray';
  environmentalFactors: {
    airQuality?: 'good' | 'moderate' | 'poor';
    noiseLevel?: 'low' | 'medium' | 'high';
    gpsSignal?: 'strong' | 'weak' | 'blocked';
  };
}

/**
 * Static GeoJSON data for environmental zones
 * This represents sample environmental zones in a city
 */
export const STATIC_ENVIRONMENTAL_ZONES: GeoJSONFeatureCollection = {
  type: 'FeatureCollection',
  features: [
    // Green zones (Parks & Clean Air)
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4194, 37.7749], // San Francisco coordinates as example
          [-122.4184, 37.7749],
          [-122.4184, 37.7759],
          [-122.4194, 37.7759],
          [-122.4194, 37.7749]
        ]]
      },
      properties: {
        zoneType: 'green',
        name: 'Golden Gate Park',
        description: 'Large urban park with excellent air quality and low noise levels',
        environmentalFactors: {
          airQuality: 'good',
          noiseLevel: 'low',
          gpsSignal: 'strong'
        }
      }
    },
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4094, 37.7849],
          [-122.4084, 37.7849],
          [-122.4084, 37.7859],
          [-122.4094, 37.7859],
          [-122.4094, 37.7849]
        ]]
      },
      properties: {
        zoneType: 'green',
        name: 'Presidio Park',
        description: 'Historic park with clean air and peaceful environment',
        environmentalFactors: {
          airQuality: 'good',
          noiseLevel: 'low',
          gpsSignal: 'strong'
        }
      }
    },
    // Red zones (High Traffic)
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4094, 37.7649],
          [-122.4084, 37.7649],
          [-122.4084, 37.7659],
          [-122.4094, 37.7659],
          [-122.4094, 37.7649]
        ]]
      },
      properties: {
        zoneType: 'red',
        name: 'Downtown Financial District',
        description: 'High traffic area with poor air quality and high noise levels',
        environmentalFactors: {
          airQuality: 'poor',
          noiseLevel: 'high',
          gpsSignal: 'strong'
        }
      }
    },
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4294, 37.7549],
          [-122.4284, 37.7549],
          [-122.4284, 37.7559],
          [-122.4294, 37.7559],
          [-122.4294, 37.7549]
        ]]
      },
      properties: {
        zoneType: 'red',
        name: 'Highway 101 Corridor',
        description: 'Major highway with heavy traffic and pollution',
        environmentalFactors: {
          airQuality: 'poor',
          noiseLevel: 'high',
          gpsSignal: 'strong'
        }
      }
    },
    // Gray zones (Poor GPS Signal)
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4394, 37.7449],
          [-122.4384, 37.7449],
          [-122.4384, 37.7459],
          [-122.4394, 37.7459],
          [-122.4394, 37.7449]
        ]]
      },
      properties: {
        zoneType: 'gray',
        name: 'Underground Shopping Center',
        description: 'Indoor area with blocked GPS signals',
        environmentalFactors: {
          airQuality: 'moderate',
          noiseLevel: 'medium',
          gpsSignal: 'blocked'
        }
      }
    },
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [[
          [-122.4494, 37.7349],
          [-122.4484, 37.7349],
          [-122.4484, 37.7359],
          [-122.4494, 37.7359],
          [-122.4494, 37.7349]
        ]]
      },
      properties: {
        zoneType: 'gray',
        name: 'Dense Urban Canyon',
        description: 'Tall buildings causing GPS signal interference',
        environmentalFactors: {
          airQuality: 'moderate',
          noiseLevel: 'medium',
          gpsSignal: 'weak'
        }
      }
    }
  ]
};

/**
 * Validates GeoJSON feature data
 * @param feature - The GeoJSON feature to validate
 * @returns true if valid, false otherwise
 */
export function validateGeoJSONFeature(feature: any): feature is GeoJSONFeature {
  if (!feature || typeof feature !== 'object') {
    return false;
  }

  // Check required fields
  if (feature.type !== 'Feature' || 
      !feature.geometry || 
      !feature.properties) {
    return false;
  }

  // Validate geometry
  if (!feature.geometry.type || !feature.geometry.coordinates) {
    return false;
  }

  // Validate properties
  const props = feature.properties;
  if (!props.zoneType || !props.name || !props.description) {
    return false;
  }

  // Validate zone type
  if (!['green', 'red', 'gray'].includes(props.zoneType)) {
    return false;
  }

  return true;
}