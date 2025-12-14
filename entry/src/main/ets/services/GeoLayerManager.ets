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
 * Performance optimization configuration
 */
export interface PerformanceConfig {
  enableSpatialIndexing: boolean;
  maxRenderDistance: number; // Maximum distance in meters to render zones
  levelOfDetail: boolean; // Enable level-of-detail rendering
  batchSize: number; // Number of zones to process in each batch
  cacheEnabled: boolean; // Enable zone lookup caching
}

/**
 * Default performance configuration
 */
export const DEFAULT_PERFORMANCE_CONFIG: PerformanceConfig = {
  enableSpatialIndexing: true,
  maxRenderDistance: 10000, // 10km
  levelOfDetail: true,
  batchSize: 50,
  cacheEnabled: true
};

/**
 * Manager for loading and rendering environmental zones on maps
 * Optimized for performance with large datasets
 */
export class GeoLayerManager {
  private static instance: GeoLayerManager;
  private environmentalZones: GeoJSONFeatureCollection;
  private config: MapLayerConfig;
  private performanceConfig: PerformanceConfig;
  private zoneInteractionCallback: ((event: ZoneInteractionEvent) => void) | null = null;
  
  // Performance optimization caches
  private spatialIndex: Map<string, GeoJSONFeature[]> = new Map();
  private zoneLookupCache: Map<string, GeoJSONFeature[]> = new Map();
  private renderCache: Map<string, any> = new Map();
  private lastCacheCleanup: number = Date.now();

  private constructor(config: MapLayerConfig = DEFAULT_LAYER_CONFIG, performanceConfig: PerformanceConfig = DEFAULT_PERFORMANCE_CONFIG) {
    this.config = config;
    this.performanceConfig = performanceConfig;
    this.environmentalZones = STATIC_ENVIRONMENTAL_ZONES;
    
    // Initialize spatial indexing if enabled
    if (this.performanceConfig.enableSpatialIndexing) {
      this.buildSpatialIndex();
    }
  }

  /**
   * Get singleton instance of GeoLayerManager
   */
  public static getInstance(config?: MapLayerConfig, performanceConfig?: PerformanceConfig): GeoLayerManager {
    if (!GeoLayerManager.instance) {
      GeoLayerManager.instance = new GeoLayerManager(config, performanceConfig);
    }
    return GeoLayerManager.instance;
  }

  /**
   * Build spatial index for faster zone lookups
   * Divides the world into grid cells for efficient spatial queries
   */
  private buildSpatialIndex(): void {
    try {
      hilog.info(DOMAIN, TAG, 'Building spatial index for performance optimization');
      
      this.spatialIndex.clear();
      const gridSize = 0.1; // 0.1 degree grid cells (~11km at equator)
      
      for (const feature of this.environmentalZones.features) {
        const bounds = this.getFeatureBounds(feature);
        if (bounds) {
          // Calculate grid cells that this feature intersects
          const minGridX = Math.floor(bounds.minLon / gridSize);
          const maxGridX = Math.floor(bounds.maxLon / gridSize);
          const minGridY = Math.floor(bounds.minLat / gridSize);
          const maxGridY = Math.floor(bounds.maxLat / gridSize);
          
          for (let x = minGridX; x <= maxGridX; x++) {
            for (let y = minGridY; y <= maxGridY; y++) {
              const cellKey = `${x},${y}`;
              
              if (!this.spatialIndex.has(cellKey)) {
                this.spatialIndex.set(cellKey, []);
              }
              
              this.spatialIndex.get(cellKey)!.push(feature);
            }
          }
        }
      }
      
      hilog.info(DOMAIN, TAG, `Spatial index built with ${this.spatialIndex.size} grid cells`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to build spatial index: ${error}`);
    }
  }

  /**
   * Get bounding box of a GeoJSON feature
   */
  private getFeatureBounds(feature: GeoJSONFeature): { minLat: number; maxLat: number; minLon: number; maxLon: number } | null {
    try {
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
        
        return { minLat, maxLat, minLon, maxLon };
      }
      
      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Error calculating feature bounds: ${error}`);
      return null;
    }
  }

  /**
   * Get zones near a location using spatial indexing for performance
   */
  private getZonesNearLocationOptimized(location: LocationData): GeoJSONFeature[] {
    if (!this.performanceConfig.enableSpatialIndexing) {
      return this.environmentalZones.features;
    }
    
    try {
      const gridSize = 0.1;
      const gridX = Math.floor(location.longitude / gridSize);
      const gridY = Math.floor(location.latitude / gridSize);
      
      // Check current cell and adjacent cells for better coverage
      const nearbyFeatures: Set<GeoJSONFeature> = new Set();
      
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          const cellKey = `${gridX + dx},${gridY + dy}`;
          const cellFeatures = this.spatialIndex.get(cellKey);
          
          if (cellFeatures) {
            for (const feature of cellFeatures) {
              // Additional distance check for performance
              if (this.isFeatureWithinRenderDistance(feature, location)) {
                nearbyFeatures.add(feature);
              }
            }
          }
        }
      }
      
      return Array.from(nearbyFeatures);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Error in optimized zone lookup: ${error}`);
      return this.environmentalZones.features;
    }
  }

  /**
   * Check if feature is within render distance for performance optimization
   */
  private isFeatureWithinRenderDistance(feature: GeoJSONFeature, location: LocationData): boolean {
    try {
      const bounds = this.getFeatureBounds(feature);
      if (!bounds) return true;
      
      // Calculate approximate distance to feature center
      const centerLat = (bounds.minLat + bounds.maxLat) / 2;
      const centerLon = (bounds.minLon + bounds.maxLon) / 2;
      
      const distance = this.calculateDistance(
        location.latitude, location.longitude,
        centerLat, centerLon
      );
      
      return distance <= this.performanceConfig.maxRenderDistance;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Error checking render distance: ${error}`);
      return true;
    }
  }

  /**
   * Calculate distance between two points (Haversine formula)
   */
  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371000; // Earth's radius in meters
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);
    
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this.toRadians(lat1)) * Math.cos(this.toRadians(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return R * c;
  }

  /**
   * Convert degrees to radians
   */
  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }

  /**
   * Clean up caches periodically for memory management
   */
  private cleanupCaches(): void {
    const now = Date.now();
    const cacheMaxAge = 300000; // 5 minutes
    
    if (now - this.lastCacheCleanup > cacheMaxAge) {
      this.zoneLookupCache.clear();
      this.renderCache.clear();
      this.lastCacheCleanup = now;
      
      hilog.info(DOMAIN, TAG, 'Performance caches cleaned up');
    }
  }

  /**
   * Render zones in batches for better performance
   */
  private async renderZonesBatched(zones: GeoJSONFeature[], mapComponent: any): Promise<void> {
    const batchSize = this.performanceConfig.batchSize;
    
    for (let i = 0; i < zones.length; i += batchSize) {
      const batch = zones.slice(i, i + batchSize);
      
      // Process batch
      for (const zone of batch) {
        await this.renderZoneFeature(zone, mapComponent);
      }
      
      // Yield control to prevent blocking UI
      if (i + batchSize < zones.length) {
        await new Promise(resolve => setTimeout(resolve, 1));
      }
    }
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
   * Optimized for performance with large datasets
   * @param mapComponent - The map component to render zones on
   * @param centerLocation - Optional center location for optimized rendering
   */
  public async renderEnvironmentalZones(mapComponent: any, centerLocation?: LocationData): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Rendering environmental zones on map with performance optimizations');
      
      // Clean up caches if needed
      this.cleanupCaches();
      
      const zones = await this.loadStaticLayers();
      let zonesToRender = zones.features;
      
      // Apply performance optimizations if center location is provided
      if (centerLocation && this.performanceConfig.enableSpatialIndexing) {
        zonesToRender = this.getZonesNearLocationOptimized(centerLocation);
        hilog.info(DOMAIN, TAG, `Optimized rendering: ${zonesToRender.length}/${zones.features.length} zones in render area`);
      }
      
      // Use batched rendering for better performance
      await this.renderZonesBatched(zonesToRender, mapComponent);

      hilog.info(DOMAIN, TAG, `Rendered ${zonesToRender.length} environmental zones`);
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
   * Optimized with caching and spatial indexing
   * @param location - The location to check for zones
   * @returns GeoJSONFeature[] - Array of zones at the location
   */
  public getZonesAtLocation(location: LocationData): GeoJSONFeature[] {
    try {
      // Check cache first if enabled
      const cacheKey = `${location.latitude.toFixed(4)},${location.longitude.toFixed(4)}`;
      
      if (this.performanceConfig.cacheEnabled && this.zoneLookupCache.has(cacheKey)) {
        const cached = this.zoneLookupCache.get(cacheKey)!;
        hilog.debug(DOMAIN, TAG, `Cache hit for location ${cacheKey}`);
        return cached;
      }
      
      const zonesAtLocation: GeoJSONFeature[] = [];
      
      // Use spatial indexing for better performance
      const candidateZones = this.performanceConfig.enableSpatialIndexing 
        ? this.getZonesNearLocationOptimized(location)
        : this.environmentalZones.features;

      for (const feature of candidateZones) {
        if (this.isPointInZone(location, feature)) {
          zonesAtLocation.push(feature);
        }
      }

      // Cache the result if enabled
      if (this.performanceConfig.cacheEnabled) {
        this.zoneLookupCache.set(cacheKey, zonesAtLocation);
      }

      hilog.info(DOMAIN, TAG, `Found ${zonesAtLocation.length} zones at location (${location.latitude}, ${location.longitude}) from ${candidateZones.length} candidates`);
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
      
      // Rebuild spatial index if enabled
      if (this.performanceConfig.enableSpatialIndexing) {
        this.buildSpatialIndex();
      }
      
      // Clear caches
      this.zoneLookupCache.clear();
      this.renderCache.clear();
    }
    
    return removed;
  }

  /**
   * Update performance configuration
   * @param config - New performance configuration
   */
  public updatePerformanceConfig(config: Partial<PerformanceConfig>): void {
    const oldConfig = { ...this.performanceConfig };
    this.performanceConfig = { ...this.performanceConfig, ...config };
    
    // Rebuild spatial index if indexing was enabled
    if (!oldConfig.enableSpatialIndexing && this.performanceConfig.enableSpatialIndexing) {
      this.buildSpatialIndex();
    } else if (oldConfig.enableSpatialIndexing && !this.performanceConfig.enableSpatialIndexing) {
      this.spatialIndex.clear();
    }
    
    // Clear caches if caching was disabled
    if (oldConfig.cacheEnabled && !this.performanceConfig.cacheEnabled) {
      this.zoneLookupCache.clear();
      this.renderCache.clear();
    }
    
    hilog.info(DOMAIN, TAG, 'Performance configuration updated');
  }

  /**
   * Get current performance configuration
   * @returns PerformanceConfig - Current performance configuration
   */
  public getPerformanceConfig(): PerformanceConfig {
    return { ...this.performanceConfig };
  }

  /**
   * Get performance statistics
   * @returns Performance statistics object
   */
  public getPerformanceStats(): {
    spatialIndexSize: number;
    cacheSize: number;
    totalZones: number;
    lastCacheCleanup: number;
  } {
    return {
      spatialIndexSize: this.spatialIndex.size,
      cacheSize: this.zoneLookupCache.size,
      totalZones: this.environmentalZones.features.length,
      lastCacheCleanup: this.lastCacheCleanup
    };
  }

  /**
   * Force cache cleanup for memory management
   */
  public forceCacheCleanup(): void {
    this.zoneLookupCache.clear();
    this.renderCache.clear();
    this.lastCacheCleanup = Date.now();
    hilog.info(DOMAIN, TAG, 'Forced cache cleanup completed');
  }
}