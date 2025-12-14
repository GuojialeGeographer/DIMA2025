import { 
  GeoJSONFeatureCollection, 
  GeoJSONFeature, 
  ZoneInfo, 
  STATIC_ENVIRONMENTAL_ZONES,
  validateGeoJSONFeature 
} from '../models/GeoJSONData';
import { LocationData } from '../models/LocationData';
import hilog from '@ohos.hilog';

const TAG = 'GeoLayerManager';
const DOMAIN = 0xFF00;

/**
 * Map layer configuration for rendering environmental zones
 */
export interface MapLayerConfig {
  zoneColors: {
    green: string;
    red: string;
    gray: string;
  };
  zoneOpacity: number;
  strokeWidth: number;
  strokeColor: string;
}

/**
 * Default map layer configuration
 */
export const DEFAULT_LAYER_CONFIG: MapLayerConfig = {
  zoneColors: {
    green: '#4CAF50',
    red: '#F44336',
    gray: '#9E9E9E'
  },
  zoneOpacity: 0.3,
  strokeWidth: 2,
  strokeColor: '#FFFFFF'
};

/**
 * Zone interaction event data
 */
export interface ZoneInteractionEvent {
  feature: GeoJSONFeature;
  zoneInfo: ZoneInfo;
  coordinates: {
    latitude: number;
    longitude: number;
  };
}

/**
 * Manager for loading and rendering environmental zones on maps
 */
export class GeoLayerManager {
  private static instance: GeoLayerManager;
  private environmentalZones: GeoJSONFeatureCollection;
  private config: MapLayerConfig;
  private zoneInteractionCallback: ((event: ZoneInteractionEvent) => void) | null = null;

  private constructor(config: MapLayerConfig = DEFAULT_LAYER_CONFIG) {
    this.config = config;
    this.environmentalZones = STATIC_ENVIRONMENTAL_ZONES;
  }

  /**
   * Get singleton instance of GeoLayerManager
   */
  public static getInstance(config?: MapLayerConfig): GeoLayerManager {
    if (!GeoLayerManager.instance) {
      GeoLayerManager.instance = new GeoLayerManager(config);
    }
    return GeoLayerManager.instance;
  }

  /**
   * Load static environmental zone layers
   * @returns Promise<GeoJSONFeatureCollection> - The loaded GeoJSON data
   */
  public async loadStaticLayers(): Promise<GeoJSONFeatureCollection> {
    try {
      hilog.info(DOMAIN, TAG, 'Loading static environmental layers');
      
      // Validate all features in the collection
      const validFeatures = this.environmentalZones.features.filter(feature => {
        const isValid = validateGeoJSONFeature(feature);
        if (!isValid) {
          hilog.warn(DOMAIN, TAG, `Invalid GeoJSON feature: ${JSON.stringify(feature)}`);
        }
        return isValid;
      });

      const validatedCollection: GeoJSONFeatureCollection = {
        type: 'FeatureCollection',
        features: validFeatures
      };

      hilog.info(DOMAIN, TAG, `Loaded ${validFeatures.length} valid environmental zones`);
      return validatedCollection;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load static layers: ${error}`);
      throw new Error(`Failed to load environmental zones: ${error}`);
    }
  }

  /**
   * Render environmental zones on a map component
   * Note: This is a placeholder for actual map integration
   * In a real implementation, this would interact with Huawei Map Kit
   * @param mapComponent - The map component to render zones on
   */
  public async renderEnvironmentalZones(mapComponent: any): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Rendering environmental zones on map');
      
      const zones = await this.loadStaticLayers();
      
      // Simulate rendering process
      for (const feature of zones.features) {
        await this.renderZoneFeature(feature, mapComponent);
      }

      hilog.info(DOMAIN, TAG, `Rendered ${zones.features.length} environmental zones`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to render environmental zones: ${error}`);
      throw error;
    }
  }

  /**
   * Handle zone interaction (tap/click on a zone)
   * @param feature - The GeoJSON feature that was interacted with
   * @param coordinates - The coordinates where the interaction occurred
   * @returns ZoneInfo - Information about the interacted zone
   */
  public handleZoneInteraction(feature: GeoJSONFeature, coordinates?: { latitude: number; longitude: number }): ZoneInfo {
    try {
      const zoneInfo: ZoneInfo = {
        name: feature.properties.name,
        description: feature.properties.description,
        zoneType: feature.properties.zoneType,
        environmentalFactors: feature.properties.environmentalFactors
      };

      // Create interaction event
      const interactionEvent: ZoneInteractionEvent = {
        feature,
        zoneInfo,
        coordinates: coordinates || this.getFeatureCentroid(feature)
      };

      // Call interaction callback if set
      if (this.zoneInteractionCallback) {
        this.zoneInteractionCallback(interactionEvent);
      }

      hilog.info(DOMAIN, TAG, `Zone interaction: ${zoneInfo.name} (${zoneInfo.zoneType})`);
      return zoneInfo;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to handle zone interaction: ${error}`);
      throw error;
    }
  }

  /**
   * Set callback for zone interactions
   * @param callback - Function to call when a zone is interacted with
   */
  public setZoneInteractionCallback(callback: (event: ZoneInteractionEvent) => void): void {
    this.zoneInteractionCallback = callback;
  }

  /**
   * Find zones at a specific location
   * @param location - The location to check for zones
   * @returns GeoJSONFeature[] - Array of zones at the location
   */
  public getZonesAtLocation(location: LocationData): GeoJSONFeature[] {
    try {
      const zonesAtLocation: GeoJSONFeature[] = [];

      for (const feature of this.environmentalZones.features) {
        if (this.isPointInZone(location, feature)) {
          zonesAtLocation.push(feature);
        }
      }

      hilog.info(DOMAIN, TAG, `Found ${zonesAtLocation.length} zones at location (${location.latitude}, ${location.longitude})`);
      return zonesAtLocation;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to get zones at location: ${error}`);
      return [];
    }
  }

  /**
   * Get zones by type
   * @param zoneType - The type of zones to retrieve
   * @returns GeoJSONFeature[] - Array of zones of the specified type
   */
  public getZonesByType(zoneType: 'green' | 'red' | 'gray'): GeoJSONFeature[] {
    return this.environmentalZones.features.filter(
      feature => feature.properties.zoneType === zoneType
    );
  }

  /**
   * Update layer configuration
   * @param config - New configuration to apply
   */
  public updateConfig(config: Partial<MapLayerConfig>): void {
    this.config = { ...this.config, ...config };
    hilog.info(DOMAIN, TAG, 'Layer configuration updated');
  }

  /**
   * Get current layer configuration
   * @returns MapLayerConfig - Current configuration
   */
  public getConfig(): MapLayerConfig {
    return { ...this.config };
  }

  /**
   * Render a single zone feature on the map
   * @param feature - The GeoJSON feature to render
   * @param mapComponent - The map component to render on
   */
  private async renderZoneFeature(feature: GeoJSONFeature, mapComponent: any): Promise<void> {
    try {
      const zoneType = feature.properties.zoneType;
      const color = this.config.zoneColors[zoneType];
      
      // Simulate rendering delay
      await new Promise(resolve => setTimeout(resolve, 10));
      
      hilog.debug(DOMAIN, TAG, `Rendered zone: ${feature.properties.name} with color ${color}`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to render zone feature: ${error}`);
    }
  }

  /**
   * Check if a point is inside a zone (simplified point-in-polygon)
   * @param location - The location to check
   * @param feature - The zone feature to check against
   * @returns boolean - true if point is in zone
   */
  private isPointInZone(location: LocationData, feature: GeoJSONFeature): boolean {
    try {
      // Simplified bounding box check for polygon zones
      if (feature.geometry.type === 'Polygon') {
        const coordinates = feature.geometry.coordinates[0] as number[][];
        
        let minLat = Infinity, maxLat = -Infinity;
        let minLon = Infinity, maxLon = -Infinity;
        
        for (const coord of coordinates) {
          const [lon, lat] = coord;
          minLat = Math.min(minLat, lat);
          maxLat = Math.max(maxLat, lat);
          minLon = Math.min(minLon, lon);
          maxLon = Math.max(maxLon, lon);
        }
        
        return location.latitude >= minLat && location.latitude <= maxLat &&
               location.longitude >= minLon && location.longitude <= maxLon;
      }
      
      return false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Error checking point in zone: ${error}`);
      return false;
    }
  }

  /**
   * Get the centroid of a GeoJSON feature
   * @param feature - The feature to get centroid for
   * @returns coordinates - The centroid coordinates
   */
  private getFeatureCentroid(feature: GeoJSONFeature): { latitude: number; longitude: number } {
    try {
      if (feature.geometry.type === 'Polygon') {
        const coordinates = feature.geometry.coordinates[0] as number[][];
        
        let sumLat = 0, sumLon = 0;
        for (const coord of coordinates) {
          const [lon, lat] = coord;
          sumLat += lat;
          sumLon += lon;
        }
        
        return {
          latitude: sumLat / coordinates.length,
          longitude: sumLon / coordinates.length
        };
      }
      
      // Default fallback
      return { latitude: 37.7749, longitude: -122.4194 };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Error calculating centroid: ${error}`);
      return { latitude: 37.7749, longitude: -122.4194 };
    }
  }

  /**
   * Get all environmental zones
   * @returns GeoJSONFeatureCollection - All loaded zones
   */
  public getAllZones(): GeoJSONFeatureCollection {
    return { ...this.environmentalZones };
  }

  /**
   * Add a new environmental zone
   * @param feature - The GeoJSON feature to add
   */
  public addZone(feature: GeoJSONFeature): void {
    if (validateGeoJSONFeature(feature)) {
      this.environmentalZones.features.push(feature);
      hilog.info(DOMAIN, TAG, `Added new zone: ${feature.properties.name}`);
    } else {
      throw new Error('Invalid GeoJSON feature');
    }
  }

  /**
   * Remove a zone by name
   * @param zoneName - The name of the zone to remove
   * @returns boolean - true if zone was removed
   */
  public removeZone(zoneName: string): boolean {
    const initialLength = this.environmentalZones.features.length;
    this.environmentalZones.features = this.environmentalZones.features.filter(
      feature => feature.properties.name !== zoneName
    );
    
    const removed = this.environmentalZones.features.length < initialLength;
    if (removed) {
      hilog.info(DOMAIN, TAG, `Removed zone: ${zoneName}`);
    }
    
    return removed;
  }
}