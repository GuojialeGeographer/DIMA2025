import { LocationData } from '../models/LocationData';
import { GeoJSONFeature, ZoneInfo } from '../models/GeoJSONData';
import { GeoLayerManager, ZoneInteractionEvent } from '../services/GeoLayerManager';
import { LocationService } from '../services/LocationService';
import { LoadingIndicator, LoadingStates, LoadingManager } from './LoadingIndicator';
import hilog from '@ohos.hilog';

const TAG = 'MapComponent';
const DOMAIN = 0xFF00;

/**
 * Map component state interface
 */
export interface MapState {
  isLoaded: boolean;
  isLoading: boolean;
  userLocation: LocationData | null;
  selectedZone: ZoneInfo | null;
  showZonePopup: boolean;
  zoomLevel: number;
  centerLocation: LocationData;
  error: string | null;
}

/**
 * Map interaction callbacks
 */
export interface MapCallbacks {
  onZoneSelected?: (zoneInfo: ZoneInfo) => void;
  onLocationUpdate?: (location: LocationData) => void;
  onMapError?: (error: string) => void;
}

/**
 * Map component for displaying environmental zones and user location
 * This simulates Huawei Map Kit integration
 */
@Component
export struct MapComponent {
  @State private mapState: MapState = {
    isLoaded: false,
    isLoading: true,
    userLocation: null,
    selectedZone: null,
    showZonePopup: false,
    zoomLevel: 12,
    centerLocation: {
      latitude: 37.7749, // Default to San Francisco
      longitude: -122.4194,
      accuracy: 0,
      timestamp: Date.now()
    },
    error: null
  };

  private geoLayerManager: GeoLayerManager = GeoLayerManager.getInstance();
  private locationService: LocationService = LocationService.getInstance();
  private locationWatchId: number | null = null;
  private callbacks: MapCallbacks = {};

  /**
   * Set callbacks for map interactions
   */
  public setCallbacks(callbacks: MapCallbacks): void {
    this.callbacks = callbacks;
  }

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'MapComponent aboutToAppear');
    this.initializeMap();
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'MapComponent aboutToDisappear');
    this.cleanup();
  }

  /**
   * Initialize the map component with performance optimizations
   */
  private async initializeMap(): Promise<void> {
    const loadingId = 'map-initialization';
    
    try {
      LoadingManager.startLoading(loadingId);
      this.mapState.isLoading = true;
      this.mapState.error = null;

      // Request location permission
      const hasPermission = await this.locationService.requestPermission();
      if (!hasPermission) {
        throw new Error('Location permission denied');
      }

      // Get current location with battery optimization
      let currentLocation: LocationData | null = null;
      try {
        currentLocation = await this.locationService.getCurrentPosition();
        this.updateUserLocation(currentLocation);
      } catch (locationError) {
        hilog.warn(DOMAIN, TAG, `Could not get current location: ${locationError}`);
        // Continue with default location
      }

      // Load environmental zones with performance optimization
      await this.geoLayerManager.loadStaticLayers();

      // Render zones with location-based optimization
      if (currentLocation) {
        await this.geoLayerManager.renderEnvironmentalZones(this, currentLocation);
      }

      // Set up zone interaction callback
      this.geoLayerManager.setZoneInteractionCallback((event: ZoneInteractionEvent) => {
        this.handleZoneInteraction(event);
      });

      // Start location tracking with battery optimization
      this.startLocationTracking();

      // Optimized loading completion
      setTimeout(() => {
        this.mapState.isLoaded = true;
        this.mapState.isLoading = false;
        LoadingManager.stopLoading(loadingId);
        hilog.info(DOMAIN, TAG, 'Map initialization completed with optimizations');
      }, 800); // Reduced delay for better UX

    } catch (error) {
      this.mapState.error = `Failed to initialize map: ${error}`;
      this.mapState.isLoading = false;
      LoadingManager.stopLoading(loadingId);
      hilog.error(DOMAIN, TAG, this.mapState.error);
      
      if (this.callbacks.onMapError) {
        this.callbacks.onMapError(this.mapState.error);
      }
    }
  }

  /**
   * Start tracking user location
   */
  private startLocationTracking(): void {
    try {
      this.locationWatchId = this.locationService.watchPosition((location: LocationData) => {
        this.updateUserLocation(location);
      });
      hilog.info(DOMAIN, TAG, 'Location tracking started');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to start location tracking: ${error}`);
    }
  }

  /**
   * Update user location on map
   */
  private updateUserLocation(location: LocationData): void {
    this.mapState.userLocation = location;
    this.mapState.centerLocation = location;
    
    hilog.info(DOMAIN, TAG, `User location updated: ${location.latitude}, ${location.longitude}`);
    
    if (this.callbacks.onLocationUpdate) {
      this.callbacks.onLocationUpdate(location);
    }
  }

  /**
   * Handle zone interaction
   */
  private handleZoneInteraction(event: ZoneInteractionEvent): void {
    this.mapState.selectedZone = event.zoneInfo;
    this.mapState.showZonePopup = true;
    
    hilog.info(DOMAIN, TAG, `Zone selected: ${event.zoneInfo.name}`);
    
    if (this.callbacks.onZoneSelected) {
      this.callbacks.onZoneSelected(event.zoneInfo);
    }
  }

  /**
   * Simulate zone tap interaction
   */
  private simulateZoneTap(coordinates: { x: number, y: number }): void {
    if (!this.mapState.userLocation) return;

    // Find zones at the tapped location (simplified)
    const zones = this.geoLayerManager.getZonesAtLocation(this.mapState.userLocation);
    if (zones.length > 0) {
      const zoneInfo = this.geoLayerManager.handleZoneInteraction(zones[0]);
      this.mapState.selectedZone = zoneInfo;
      this.mapState.showZonePopup = true;
    }
  }

  /**
   * Center map on user location
   */
  public centerOnUserLocation(): void {
    if (this.mapState.userLocation) {
      this.mapState.centerLocation = this.mapState.userLocation;
      hilog.info(DOMAIN, TAG, 'Map centered on user location');
    }
  }

  /**
   * Zoom in on map
   */
  public zoomIn(): void {
    if (this.mapState.zoomLevel < 18) {
      this.mapState.zoomLevel++;
      hilog.info(DOMAIN, TAG, `Zoomed in to level ${this.mapState.zoomLevel}`);
    }
  }

  /**
   * Zoom out on map
   */
  public zoomOut(): void {
    if (this.mapState.zoomLevel > 1) {
      this.mapState.zoomLevel--;
      hilog.info(DOMAIN, TAG, `Zoomed out to level ${this.mapState.zoomLevel}`);
    }
  }

  /**
   * Close zone popup
   */
  private closeZonePopup(): void {
    this.mapState.showZonePopup = false;
    this.mapState.selectedZone = null;
  }

  /**
   * Cleanup resources
   */
  private cleanup(): void {
    if (this.locationWatchId !== null) {
      this.locationService.clearWatch(this.locationWatchId);
      this.locationWatchId = null;
    }
  }

  build() {
    Stack() {
      if (this.mapState.isLoading) {
        // Optimized loading state
        Column() {
          LoadingIndicator({ config: LoadingStates.MAP_LOADING })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#E8F4FD')
      } else if (this.mapState.error) {
        // Error state
        Column() {
          Text('⚠️')
            .fontSize(48)
            .margin({ bottom: 20 })

          Text('Map Error')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F44336')
            .margin({ bottom: 10 })

          Text(this.mapState.error)
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 20 })

          Button('Retry')
            .onClick(() => {
              this.initializeMap();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFF5F5')
        .padding(20)
      } else {
        // Map content
        Column() {
          // Simulated map view with environmental zones
          Stack() {
            // Base map background
            Column() {
              Text('🗺️')
                .fontSize(64)
                .margin({ bottom: 20 })

              Text(`Interactive Map (Zoom: ${this.mapState.zoomLevel})`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')

              if (this.mapState.userLocation) {
                Text(`Location: ${this.mapState.userLocation.latitude.toFixed(4)}, ${this.mapState.userLocation.longitude.toFixed(4)}`)
                  .fontSize(12)
                  .fontColor('#666666')
                  .margin({ top: 10 })
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#E8F4FD')

            // Environmental zones overlay
            this.EnvironmentalZonesOverlay()

            // User location marker
            if (this.mapState.userLocation) {
              Text('📍')
                .fontSize(24)
                .position({ x: '50%', y: '50%' })
                .translate({ x: -12, y: -12 })
            }
          }
          .width('100%')
          .height('100%')
          .onClick((event: ClickEvent) => {
            this.simulateZoneTap({ x: event.x, y: event.y });
          })
        }
        .width('100%')
        .height('100%')

        // Zone information popup
        if (this.mapState.showZonePopup && this.mapState.selectedZone) {
          this.ZonePopup()
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder EnvironmentalZonesOverlay() {
    Stack() {
      // Green zones
      ForEach(this.geoLayerManager.getZonesByType('green'), (zone: GeoJSONFeature, index: number) => {
        Circle({ width: 60, height: 60 })
          .fill('#4CAF50')
          .fillOpacity(0.3)
          .stroke('#4CAF50')
          .strokeWidth(2)
          .position({ 
            x: `${20 + (index * 15)}%`, 
            y: `${30 + (index * 10)}%` 
          })
      }, (zone: GeoJSONFeature) => zone.properties.name)

      // Red zones
      ForEach(this.geoLayerManager.getZonesByType('red'), (zone: GeoJSONFeature, index: number) => {
        Circle({ width: 60, height: 60 })
          .fill('#F44336')
          .fillOpacity(0.3)
          .stroke('#F44336')
          .strokeWidth(2)
          .position({ 
            x: `${60 + (index * 15)}%`, 
            y: `${20 + (index * 10)}%` 
          })
      }, (zone: GeoJSONFeature) => zone.properties.name)

      // Gray zones
      ForEach(this.geoLayerManager.getZonesByType('gray'), (zone: GeoJSONFeature, index: number) => {
        Circle({ width: 60, height: 60 })
          .fill('#9E9E9E')
          .fillOpacity(0.3)
          .stroke('#9E9E9E')
          .strokeWidth(2)
          .position({ 
            x: `${40 + (index * 20)}%`, 
            y: `${60 + (index * 10)}%` 
          })
      }, (zone: GeoJSONFeature) => zone.properties.name)
    }
    .width('100%')
    .height('100%')
  }

  @Builder ZonePopup() {
    if (this.mapState.selectedZone) {
      Column() {
        Row() {
          Text(this.mapState.selectedZone.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)

          Button('×')
            .fontSize(18)
            .fontColor('#666666')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.closeZonePopup();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 10 })

        Text(this.mapState.selectedZone.description)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 15 })

        // Environmental factors
        Column() {
          Text('Environmental Factors:')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .margin({ bottom: 5 })

          if (this.mapState.selectedZone.environmentalFactors.airQuality) {
            Row() {
              Text('Air Quality:')
                .fontSize(12)
                .fontColor('#666666')
              Text(this.mapState.selectedZone.environmentalFactors.airQuality)
                .fontSize(12)
                .fontColor(this.getFactorColor(this.mapState.selectedZone.environmentalFactors.airQuality))
                .margin({ left: 5 })
            }
            .width('100%')
            .margin({ bottom: 3 })
          }

          if (this.mapState.selectedZone.environmentalFactors.noiseLevel) {
            Row() {
              Text('Noise Level:')
                .fontSize(12)
                .fontColor('#666666')
              Text(this.mapState.selectedZone.environmentalFactors.noiseLevel)
                .fontSize(12)
                .fontColor(this.getFactorColor(this.mapState.selectedZone.environmentalFactors.noiseLevel))
                .margin({ left: 5 })
            }
            .width('100%')
            .margin({ bottom: 3 })
          }

          if (this.mapState.selectedZone.environmentalFactors.gpsSignal) {
            Row() {
              Text('GPS Signal:')
                .fontSize(12)
                .fontColor('#666666')
              Text(this.mapState.selectedZone.environmentalFactors.gpsSignal)
                .fontSize(12)
                .fontColor(this.getFactorColor(this.mapState.selectedZone.environmentalFactors.gpsSignal))
                .margin({ left: 5 })
            }
            .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('80%')
      .padding(15)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .shadow({ radius: 8, color: '#00000020' })
      .position({ x: '50%', y: '20%' })
      .translate({ x: '-50%' })
    }
  }

  /**
   * Get color for environmental factor based on value
   */
  private getFactorColor(value: string): string {
    switch (value) {
      case 'good':
      case 'low':
      case 'strong':
        return '#4CAF50';
      case 'moderate':
      case 'medium':
      case 'weak':
        return '#FF9800';
      case 'poor':
      case 'high':
      case 'blocked':
        return '#F44336';
      default:
        return '#666666';
    }
  }
}