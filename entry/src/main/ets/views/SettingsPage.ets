import hilog from '@ohos.hilog';
import { UserPreferences, NotificationPreferences, DataSyncPreferences, PrivacyPreferences, DisplayPreferences, SyncFrequency, AppTheme, TemperatureUnit, DistanceUnit, MapStyle } from '../models/UserPreferences';
import { PreferencesService } from '../services/PreferencesService';

const TAG = 'SettingsPage';
const DOMAIN = 0xFF00;

@Component
export struct SettingsPage {
  @State preferences: UserPreferences | null = null;
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State showResetDialog: boolean = false;
  @State showExportDialog: boolean = false;
  @State exportedData: string = '';
  
  private preferencesService: PreferencesService = PreferencesService.getInstance();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'SettingsPage aboutToAppear');
    this.loadPreferences();
  }

  async loadPreferences(): Promise<void> {
    try {
      this.isLoading = true;
      this.errorMessage = '';
      this.preferences = await this.preferencesService.getPreferences();
    } catch (error) {
      this.errorMessage = `Failed to load preferences: ${error}`;
      hilog.error(DOMAIN, TAG, this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  async savePreferences(): Promise<void> {
    if (!this.preferences) return;
    
    try {
      await this.preferencesService.savePreferences(this.preferences);
      hilog.info(DOMAIN, TAG, 'Preferences saved successfully');
    } catch (error) {
      this.errorMessage = `Failed to save preferences: ${error}`;
      hilog.error(DOMAIN, TAG, this.errorMessage);
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('Settings')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 20 })

        Blank()

        Button('Reset')
          .fontSize(14)
          .backgroundColor('#FF6B6B')
          .fontColor('#FFFFFF')
          .margin({ right: 20 })
          .onClick(() => {
            this.showResetDialog = true;
          })
      }
      .width('100%')
      .height(60)
      .backgroundColor('#FFFFFF')
      .alignItems(VerticalAlign.Center)
      .border({
        width: { bottom: 1 },
        color: '#E0E0E0'
      })

      if (this.isLoading) {
        this.LoadingView()
      } else if (this.errorMessage) {
        this.ErrorView()
      } else if (this.preferences) {
        this.SettingsContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color('#007AFF')

      Text('Loading preferences...')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder ErrorView() {
    Column() {
      Text('⚠️')
        .fontSize(48)
        .margin({ bottom: 16 })

      Text(this.errorMessage)
        .fontSize(16)
        .fontColor('#FF6B6B')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      Button('Retry')
        .onClick(() => {
          this.loadPreferences();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(20)
  }

  @Builder SettingsContent() {
    Scroll() {
      Column() {
        this.NotificationSection()
        this.DataSyncSection()
        this.PrivacySection()
        this.DisplaySection()
        this.ActionsSection()
      }
      .width('100%')
      .padding({ top: 10, bottom: 20 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
  }

  @Builder NotificationSection() {
    this.SectionCard('Notifications', () => {
      Column() {
        this.ToggleItem('Push Notifications', this.preferences!.notifications.enablePushNotifications, (value: boolean) => {
          this.preferences!.notifications.enablePushNotifications = value;
          this.savePreferences();
        })

        this.ToggleItem('Location Alerts', this.preferences!.notifications.enableLocationAlerts, (value: boolean) => {
          this.preferences!.notifications.enableLocationAlerts = value;
          this.savePreferences();
        })

        this.ToggleItem('Weather Alerts', this.preferences!.notifications.enableWeatherAlerts, (value: boolean) => {
          this.preferences!.notifications.enableWeatherAlerts = value;
          this.savePreferences();
        })

        this.ToggleItem('Exercise Reminders', this.preferences!.notifications.enableExerciseReminders, (value: boolean) => {
          this.preferences!.notifications.enableExerciseReminders = value;
          this.savePreferences();
        })

        this.TimePickerItem('Quiet Hours Start', this.preferences!.notifications.quietHoursStart, (value: string) => {
          this.preferences!.notifications.quietHoursStart = value;
          this.savePreferences();
        })

        this.TimePickerItem('Quiet Hours End', this.preferences!.notifications.quietHoursEnd, (value: string) => {
          this.preferences!.notifications.quietHoursEnd = value;
          this.savePreferences();
        })
      }
    })
  }

  @Builder DataSyncSection() {
    this.SectionCard('Data Sync', () => {
      Column() {
        this.ToggleItem('Auto Sync', this.preferences!.dataSync.enableAutoSync, (value: boolean) => {
          this.preferences!.dataSync.enableAutoSync = value;
          this.savePreferences();
        })

        this.ToggleItem('WiFi Only', this.preferences!.dataSync.syncOnWifiOnly, (value: boolean) => {
          this.preferences!.dataSync.syncOnWifiOnly = value;
          this.savePreferences();
        })

        this.SelectItem('Sync Frequency', this.getSyncFrequencyLabel(this.preferences!.dataSync.syncFrequency), () => {
          // TODO: Show sync frequency picker
        })

        this.ToggleItem('Offline Mode', this.preferences!.dataSync.enableOfflineMode, (value: boolean) => {
          this.preferences!.dataSync.enableOfflineMode = value;
          this.savePreferences();
        })

        this.SliderItem('Cache Size (MB)', this.preferences!.dataSync.maxCacheSize, 10, 1000, (value: number) => {
          this.preferences!.dataSync.maxCacheSize = value;
          this.savePreferences();
        })
      }
    })
  }

  @Builder PrivacySection() {
    this.SectionCard('Privacy', () => {
      Column() {
        this.ToggleItem('Share Location Data', this.preferences!.privacy.shareLocationData, (value: boolean) => {
          this.preferences!.privacy.shareLocationData = value;
          this.savePreferences();
        })

        this.ToggleItem('Usage Analytics', this.preferences!.privacy.shareUsageAnalytics, (value: boolean) => {
          this.preferences!.privacy.shareUsageAnalytics = value;
          this.savePreferences();
        })

        this.ToggleItem('Crash Reporting', this.preferences!.privacy.enableCrashReporting, (value: boolean) => {
          this.preferences!.privacy.enableCrashReporting = value;
          this.savePreferences();
        })

        this.SliderItem('Data Retention (Days)', this.preferences!.privacy.dataRetentionDays, 1, 365, (value: number) => {
          this.preferences!.privacy.dataRetentionDays = value;
          this.savePreferences();
        })
      }
    })
  }

  @Builder DisplaySection() {
    this.SectionCard('Display', () => {
      Column() {
        this.SelectItem('Theme', this.getThemeLabel(this.preferences!.display.theme), () => {
          // TODO: Show theme picker
        })

        this.SelectItem('Temperature Unit', this.preferences!.display.temperatureUnit, () => {
          // TODO: Show temperature unit picker
        })

        this.SelectItem('Distance Unit', this.preferences!.display.distanceUnit, () => {
          // TODO: Show distance unit picker
        })

        this.SelectItem('Map Style', this.preferences!.display.mapStyle, () => {
          // TODO: Show map style picker
        })
      }
    })
  }

  @Builder ActionsSection() {
    this.SectionCard('Actions', () => {
      Column() {
        this.ActionItem('Export Settings', () => {
          this.exportSettings();
        })

        this.ActionItem('Import Settings', () => {
          // TODO: Show import dialog
        })

        this.ActionItem('Reset to Defaults', () => {
          this.showResetDialog = true;
        })
      }
    })
  }

  @Builder SectionCard(title: string, content: () => void) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ left: 20, top: 16, bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Column() {
        content()
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
  }

  @Builder ToggleItem(label: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
  }

  @Builder SelectItem(label: string, value: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333333')

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor('#666666')
        .margin({ right: 8 })

      Image($r('sys.symbol.chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
    .onClick(() => {
      onTap();
    })
  }

  @Builder SliderItem(label: string, value: number, min: number, max: number, onChange: (value: number) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor('#333333')

        Blank()

        Text(`${value}`)
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Slider({
        value: value,
        min: min,
        max: max,
        step: label.includes('Days') ? 1 : 10
      })
        .width('100%')
        .trackColor('#E0E0E0')
        .selectedColor('#007AFF')
        .onChange((value: number) => {
          onChange(Math.round(value));
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
  }

  @Builder TimePickerItem(label: string, value: string, onChange: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333333')

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor('#666666')
        .margin({ right: 8 })

      Image($r('sys.symbol.clock'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
    .onClick(() => {
      // TODO: Show time picker dialog
    })
  }

  @Builder ActionItem(label: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#007AFF')

      Blank()

      Image($r('sys.symbol.chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
    .onClick(() => {
      onTap();
    })
  }

  private getSyncFrequencyLabel(frequency: SyncFrequency): string {
    switch (frequency) {
      case SyncFrequency.REAL_TIME: return 'Real Time';
      case SyncFrequency.EVERY_5_MINUTES: return 'Every 5 Minutes';
      case SyncFrequency.EVERY_15_MINUTES: return 'Every 15 Minutes';
      case SyncFrequency.EVERY_30_MINUTES: return 'Every 30 Minutes';
      case SyncFrequency.HOURLY: return 'Hourly';
      case SyncFrequency.MANUAL: return 'Manual';
      default: return 'Unknown';
    }
  }

  private getThemeLabel(theme: AppTheme): string {
    switch (theme) {
      case AppTheme.LIGHT: return 'Light';
      case AppTheme.DARK: return 'Dark';
      case AppTheme.SYSTEM: return 'System';
      default: return 'Unknown';
    }
  }

  private async exportSettings(): Promise<void> {
    try {
      this.exportedData = await this.preferencesService.exportPreferences();
      this.showExportDialog = true;
    } catch (error) {
      this.errorMessage = `Failed to export settings: ${error}`;
    }
  }

  private async resetSettings(): Promise<void> {
    try {
      await this.preferencesService.resetToDefaults();
      await this.loadPreferences();
      this.showResetDialog = false;
    } catch (error) {
      this.errorMessage = `Failed to reset settings: ${error}`;
    }
  }
}