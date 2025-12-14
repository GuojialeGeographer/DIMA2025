import hilog from '@ohos.hilog';
import { MapComponent, MapCallbacks } from '../components/MapComponent';
import { LocationData } from '../models/LocationData';
import { ZoneInfo } from '../models/GeoJSONData';

const TAG = 'SmartMapPage';
const DOMAIN = 0xFF00;

@Component
export struct SmartMapPage {
  @State selectedZoneInfo: ZoneInfo | null = null;
  @State currentLocation: LocationData | null = null;
  @State mapError: string | null = null;
  
  private mapComponentRef: MapComponent | null = null;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'SmartMapPage aboutToAppear');
  }

  /**
   * Get map callbacks for handling map events
   */
  private getMapCallbacks(): MapCallbacks {
    return {
      onZoneSelected: (zoneInfo: ZoneInfo) => {
        this.selectedZoneInfo = zoneInfo;
        hilog.info(DOMAIN, TAG, `Zone selected: ${zoneInfo.name}`);
      },
      onLocationUpdate: (location: LocationData) => {
        this.currentLocation = location;
        hilog.info(DOMAIN, TAG, `Location updated: ${location.latitude}, ${location.longitude}`);
      },
      onMapError: (error: string) => {
        this.mapError = error;
        hilog.error(DOMAIN, TAG, `Map error: ${error}`);
      }
    };
  }

  /**
   * Center map on user location
   */
  private centerOnLocation(): void {
    if (this.mapComponentRef) {
      this.mapComponentRef.centerOnUserLocation();
      hilog.info(DOMAIN, TAG, 'Centering map on user location');
    }
  }

  /**
   * Zoom in on map
   */
  private zoomIn(): void {
    if (this.mapComponentRef) {
      this.mapComponentRef.zoomIn();
      hilog.info(DOMAIN, TAG, 'Zooming in');
    }
  }

  /**
   * Zoom out on map
   */
  private zoomOut(): void {
    if (this.mapComponentRef) {
      this.mapComponentRef.zoomOut();
      hilog.info(DOMAIN, TAG, 'Zooming out');
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('Smart Map')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Blank()

        // Location center button
        Button('🎯')
          .fontSize(20)
          .fontColor('#007AFF')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.centerOnLocation();
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      // Map area
      Stack() {
        // Main map component
        MapComponent()
        .width('100%')
        .height('100%')

        // Map controls overlay
        Column() {
          Button('+')
            .fontSize(20)
            .width(40)
            .height(40)
            .backgroundColor('#FFFFFF')
            .fontColor('#333333')
            .borderRadius(20)
            .shadow({ radius: 4, color: '#00000020' })
            .margin({ bottom: 10 })
            .onClick(() => {
              this.zoomIn();
            })

          Button('−')
            .fontSize(20)
            .width(40)
            .height(40)
            .backgroundColor('#FFFFFF')
            .fontColor('#333333')
            .borderRadius(20)
            .shadow({ radius: 4, color: '#00000020' })
            .onClick(() => {
              this.zoomOut();
            })
        }
        .position({ x: '90%', y: '20%' })
        .translate({ x: -20 })

        // Zone legend
        this.ZoneLegend()
      }
      .width('100%')
      .layoutWeight(1)

      // Status bar
      if (this.currentLocation || this.mapError) {
        this.StatusBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder ZoneLegend() {
    Column() {
      Text('Environmental Zones')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      Row() {
        this.ZoneLegendItem('🟢', 'Green', 'Parks & Clean Air')
        this.ZoneLegendItem('🔴', 'Red', 'High Traffic')
        this.ZoneLegendItem('⚪', 'Gray', 'Poor GPS Signal')
      }
      .justifyContent(FlexAlign.SpaceAround)
      .width('100%')
    }
    .width('90%')
    .padding(10)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({ radius: 4, color: '#00000020' })
    .position({ x: '50%', y: '85%' })
    .translate({ x: '-50%' })
  }

  @Builder ZoneLegendItem(icon: string, title: string, description: string) {
    Column() {
      Text(icon)
        .fontSize(16)
        .margin({ bottom: 3 })

      Text(title)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')

      Text(description)
        .fontSize(8)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
    }
    .width(60)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder StatusBar() {
    Row() {
      if (this.mapError) {
        Text(`⚠️ ${this.mapError}`)
          .fontSize(12)
          .fontColor('#F44336')
          .layoutWeight(1)
      } else if (this.currentLocation) {
        Column() {
          Text(`📍 ${this.currentLocation.latitude.toFixed(4)}, ${this.currentLocation.longitude.toFixed(4)}`)
            .fontSize(12)
            .fontColor('#333333')
          Text(`Accuracy: ${this.currentLocation.accuracy.toFixed(0)}m`)
            .fontSize(10)
            .fontColor('#666666')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      if (this.selectedZoneInfo) {
        Text(`Selected: ${this.selectedZoneInfo.name}`)
          .fontSize(12)
          .fontColor('#007AFF')
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 15, right: 15 })
    .backgroundColor('#F8F8F8')
    .alignItems(VerticalAlign.Center)
  }
}