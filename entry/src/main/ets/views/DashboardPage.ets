import hilog from '@ohos.hilog';
import { LocationService } from '../services/LocationService';
import { WeatherService } from '../services/WeatherService';
import { AICoachService } from '../services/AICoachService';
import { DatabaseService } from '../services/DatabaseService';
import { OfflineService } from '../services/OfflineService';
import { LocationData } from '../models/LocationData';
import { WeatherData } from '../models/WeatherData';
import { EnvironmentScore } from '../models/EnvironmentScore';
import { AIRecommendation } from '../models/AIRecommendation';
import { OfflineIndicator } from '../components/OfflineIndicator';

const TAG = 'DashboardPage';
const DOMAIN = 0xFF00;

interface DashboardState {
  environmentScore: EnvironmentScore | null;
  aiRecommendation: AIRecommendation | null;
  currentLocation: LocationData | null;
  isLoading: boolean;
  isLoadingAI: boolean;
  isOffline: boolean;
  lastUpdateTime: number;
  errorMessage: string;
  hasLocationPermission: boolean;
}

@Component
export struct DashboardPage {
  @State private dashboardState: DashboardState = {
    environmentScore: null,
    aiRecommendation: null,
    currentLocation: null,
    isLoading: true,
    isLoadingAI: false,
    isOffline: false,
    lastUpdateTime: 0,
    errorMessage: '',
    hasLocationPermission: false
  };

  private locationService: LocationService = new LocationService();
  private databaseService: DatabaseService = DatabaseService.getInstance();
  private weatherService: WeatherService = new WeatherService('demo_api_key', this.databaseService);
  private aiCoachService: AICoachService = new AICoachService({
    apiUrl: 'https://api.deepseek.com/v1/chat/completions',
    apiKey: 'demo_api_key',
    timeout: 10000,
    maxRetries: 3,
    cacheExpiryMinutes: 30
  });
  private offlineService: OfflineService = OfflineService.getInstance(this.databaseService);
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'DashboardPage aboutToAppear');
    this.initializeServices();
    this.initializeDashboard();
    this.startPeriodicRefresh();
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'DashboardPage aboutToDisappear');
    this.stopPeriodicRefresh();
    this.cleanupServices();
  }

  /**
   * Initialize services and set up offline monitoring
   */
  private async initializeServices(): Promise<void> {
    try {
      // Initialize database service
      await this.databaseService.initializeDatabase();
      
      // Set up offline status listener
      this.offlineService.addOnlineStatusListener((isOnline: boolean) => {
        this.dashboardState.isOffline = !isOnline;
        
        if (isOnline && this.dashboardState.currentLocation) {
          // Try to refresh data when coming back online
          this.refreshEnvironmentalData();
        }
      });

      // Update initial offline status
      this.dashboardState.isOffline = !this.offlineService.isDeviceOnline();
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Service initialization failed: ${error}`);
    }
  }

  /**
   * Cleanup services
   */
  private cleanupServices(): void {
    // Remove offline status listener
    this.offlineService.removeOnlineStatusListener(() => {});
  }

  /**
   * Initialize dashboard with location and environmental data
   */
  private async initializeDashboard(): Promise<void> {
    try {
      this.dashboardState.isLoading = true;
      this.dashboardState.errorMessage = '';

      // Request location permission and get current location
      const hasPermission = await this.locationService.requestPermission();
      this.dashboardState.hasLocationPermission = hasPermission;

      if (!hasPermission) {
        this.dashboardState.errorMessage = 'Location permission required for environmental data';
        this.dashboardState.isLoading = false;
        return;
      }

      // Get current location
      const location = await this.locationService.getCurrentPosition();
      this.dashboardState.currentLocation = location;

      // Fetch environmental data
      await this.fetchEnvironmentalData(location);

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Dashboard initialization failed: ${error}`);
      this.dashboardState.errorMessage = 'Failed to load environmental data';
      this.dashboardState.isOffline = true;
      await this.loadCachedData();
    } finally {
      this.dashboardState.isLoading = false;
    }
  }

  /**
   * Fetch environmental data and AI recommendations
   */
  private async fetchEnvironmentalData(location: LocationData): Promise<void> {
    try {
      // Check if device is online
      const isOnline = this.offlineService.isDeviceOnline();
      
      if (!isOnline) {
        // Queue weather request for later sync
        await this.offlineService.queueOperation({
          type: 'weather_request',
          data: { location },
          maxRetries: 3
        });
        
        // Try to use cached data
        throw new Error('Device is offline, using cached data');
      }

      // Fetch weather data and calculate environment score
      const weatherData = await this.weatherService.getWeatherData(location);
      const environmentScore = this.weatherService.calculateEnvironmentScore(weatherData);
      
      this.dashboardState.environmentScore = environmentScore;
      this.dashboardState.lastUpdateTime = Date.now();
      this.dashboardState.isOffline = false;

      // Fetch AI recommendation
      await this.fetchAIRecommendation(location, weatherData, environmentScore);

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to fetch environmental data: ${error}`);
      this.dashboardState.isOffline = true;
      throw error;
    }
  }

  /**
   * Fetch AI recommendation
   */
  private async fetchAIRecommendation(
    location: LocationData, 
    weather: WeatherData, 
    environmentScore: EnvironmentScore
  ): Promise<void> {
    try {
      this.dashboardState.isLoadingAI = true;
      
      // Check if device is online for AI requests
      const isOnline = this.offlineService.isDeviceOnline();
      
      if (!isOnline) {
        // Queue AI request for later sync
        await this.offlineService.queueOperation({
          type: 'ai_request',
          data: { location, weather, environmentScore },
          maxRetries: 3
        });
        
        throw new Error('Device is offline, using fallback recommendation');
      }
      
      const recommendation = await this.aiCoachService.generateRecommendation(
        location, 
        weather, 
        environmentScore
      );
      
      this.dashboardState.aiRecommendation = recommendation;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `AI recommendation failed, using fallback: ${error}`);
      
      // Use fallback recommendation
      const fallback = this.aiCoachService.getFallbackRecommendation(environmentScore.overall);
      this.dashboardState.aiRecommendation = {
        id: `fallback_${Date.now()}`,
        recommendation: fallback.recommendation,
        confidence: 0.6,
        reasoning: fallback.reasoning,
        activityType: fallback.activityType,
        urgency: environmentScore.overall < 40 ? 'high' : 'medium',
        timestamp: Date.now(),
        environmentContext: {
          location: { latitude: location.latitude, longitude: location.longitude },
          weather: {
            temperature: weather.temperature,
            humidity: weather.humidity,
            windSpeed: weather.windSpeed,
            uvIndex: weather.uvIndex,
            airQualityIndex: weather.airQualityIndex
          },
          environmentScore: {
            overall: environmentScore.overall,
            airQuality: environmentScore.airQuality,
            weatherConditions: environmentScore.weatherConditions,
            uvRisk: environmentScore.uvRisk
          },
          timeContext: {
            hour: new Date().getHours(),
            dayOfWeek: new Date().getDay(),
            season: this.getCurrentSeason()
          }
        }
      };
    } finally {
      this.dashboardState.isLoadingAI = false;
    }
  }

  /**
   * Load cached data when offline
   */
  private async loadCachedData(): Promise<void> {
    try {
      if (this.dashboardState.currentLocation) {
        const cachedData = await this.databaseService.getCachedEnvironmentData(
          this.dashboardState.currentLocation.latitude,
          this.dashboardState.currentLocation.longitude
        );
        
        if (cachedData) {
          this.dashboardState.environmentScore = cachedData.environmentScore;
          this.dashboardState.lastUpdateTime = cachedData.cachedAt;
          
          // Check if cache is still valid
          const cacheAgeHours = this.offlineService.getCacheAgeHours(cachedData.cachedAt);
          const isValid = this.offlineService.isCacheValid(cachedData.cachedAt);
          
          hilog.info(DOMAIN, TAG, `Loaded cached environmental data (${cacheAgeHours.toFixed(1)}h old, valid: ${isValid})`);
          
          // Generate fallback AI recommendation for cached data
          if (this.dashboardState.environmentScore) {
            const fallback = this.aiCoachService.getFallbackRecommendation(this.dashboardState.environmentScore.overall);
            this.dashboardState.aiRecommendation = {
              id: `cached_fallback_${Date.now()}`,
              recommendation: fallback.recommendation,
              confidence: 0.5, // Lower confidence for cached data
              reasoning: `${fallback.reasoning} (Based on cached data from ${cacheAgeHours.toFixed(1)} hours ago)`,
              activityType: fallback.activityType,
              urgency: this.dashboardState.environmentScore.overall < 40 ? 'high' : 'medium',
              timestamp: Date.now(),
              environmentContext: {
                location: { 
                  latitude: this.dashboardState.currentLocation.latitude, 
                  longitude: this.dashboardState.currentLocation.longitude 
                },
                weather: cachedData.weatherData,
                environmentScore: this.dashboardState.environmentScore,
                timeContext: {
                  hour: new Date().getHours(),
                  dayOfWeek: new Date().getDay(),
                  season: this.getCurrentSeason()
                }
              }
            };
          }
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load cached data: ${error}`);
    }
  }

  /**
   * Start periodic refresh of environmental data
   */
  private startPeriodicRefresh(): void {
    this.refreshTimer = setInterval(() => {
      if (this.dashboardState.currentLocation && !this.dashboardState.isLoading) {
        this.refreshEnvironmentalData();
      }
    }, 30000); // Refresh every 30 seconds
  }

  /**
   * Stop periodic refresh
   */
  private stopPeriodicRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  /**
   * Refresh environmental data
   */
  private async refreshEnvironmentalData(): Promise<void> {
    if (!this.dashboardState.currentLocation) return;

    try {
      await this.fetchEnvironmentalData(this.dashboardState.currentLocation);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `Refresh failed, using cached data: ${error}`);
      this.dashboardState.isOffline = true;
    }
  }

  /**
   * Handle manual sync request
   */
  private async handleManualSync(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Manual sync requested');
      
      if (!this.offlineService.isDeviceOnline()) {
        hilog.warn(DOMAIN, TAG, 'Cannot sync while offline');
        return;
      }

      // Force synchronization of queued operations
      await this.offlineService.forceSynchronization();
      
      // Also refresh current data
      if (this.dashboardState.currentLocation) {
        await this.refreshEnvironmentalData();
      }
      
      hilog.info(DOMAIN, TAG, 'Manual sync completed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Manual sync failed: ${error}`);
    }
  }

  /**
   * Get current season based on month
   */
  private getCurrentSeason(): 'spring' | 'summer' | 'autumn' | 'winter' {
    const month = new Date().getMonth();
    if (month >= 2 && month <= 4) return 'spring';
    if (month >= 5 && month <= 7) return 'summer';
    if (month >= 8 && month <= 10) return 'autumn';
    return 'winter';
  }

  build() {
    Column() {
      // Header with status indicators
      Row() {
        Column() {
          Text('Dashboard')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
          
          // Status indicators
          if (this.dashboardState.isOffline) {
            Row() {
              Text('📶')
                .fontSize(12)
                .fontColor('#FF6B6B')
              Text('Offline')
                .fontSize(12)
                .fontColor('#FF6B6B')
                .margin({ left: 4 })
            }
            .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // Refresh button and menu
        Row() {
          Button('🔄')
            .fontSize(16)
            .fontColor('#007AFF')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.refreshEnvironmentalData();
            })
            .margin({ right: 10 })

          Button('☰')
            .fontSize(20)
            .fontColor('#007AFF')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              hilog.info(DOMAIN, TAG, 'Menu button clicked');
              // TODO: Trigger slide menu
            })
        }
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      // Offline indicator
      OfflineIndicator({
        showDetails: true,
        compact: false,
        onSyncRequested: () => {
          this.handleManualSync();
        }
      })
        .width('90%')
        .margin({ top: 10 })

      // Content area
      Column() {
        if (this.dashboardState.isLoading) {
          // Loading state
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#007AFF')

            Text('Loading environmental data...')
              .fontSize(16)
              .fontColor('#666666')
              .margin({ top: 20 })

            if (!this.dashboardState.hasLocationPermission) {
              Text('Location permission required')
                .fontSize(14)
                .fontColor('#FF6B6B')
                .margin({ top: 10 })
            }
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else if (this.dashboardState.errorMessage && !this.dashboardState.environmentScore) {
          // Error state
          Column() {
            Text('⚠️')
              .fontSize(48)
              .margin({ bottom: 20 })

            Text(this.dashboardState.errorMessage)
              .fontSize(16)
              .fontColor('#FF6B6B')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 20 })

            Button('Retry')
              .onClick(() => {
                this.initializeDashboard();
              })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else {
          // Main content
          Scroll() {
            Column() {
              // Environment Score Card
              if (this.dashboardState.environmentScore) {
                Column() {
                  Row() {
                    Text('Environment Score')
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#333333')

                    Blank()

                    if (this.dashboardState.isOffline) {
                      Text('📱 Cached')
                        .fontSize(12)
                        .fontColor('#FF9800')
                    }
                  }
                  .width('100%')
                  .margin({ bottom: 10 })

                  Text(this.dashboardState.environmentScore.overall.toString())
                    .fontSize(48)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getScoreColor(this.dashboardState.environmentScore.overall))

                  Text(this.getStatusMessage(this.dashboardState.environmentScore.overall))
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 10 })
                    .textAlign(TextAlign.Center)

                  // Detailed scores
                  Row() {
                    this.buildScoreDetail('Air Quality', this.dashboardState.environmentScore.airQuality)
                    this.buildScoreDetail('Weather', this.dashboardState.environmentScore.weatherConditions)
                    this.buildScoreDetail('UV Risk', this.dashboardState.environmentScore.uvRisk)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceEvenly)
                  .margin({ top: 15 })

                  // Last update time
                  if (this.dashboardState.lastUpdateTime > 0) {
                    Text(`Updated: ${this.formatUpdateTime(this.dashboardState.lastUpdateTime)}`)
                      .fontSize(12)
                      .fontColor('#999999')
                      .margin({ top: 10 })
                  }
                }
                .width('90%')
                .padding(20)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .shadow({
                  radius: 8,
                  color: 'rgba(0, 0, 0, 0.1)',
                  offsetX: 0,
                  offsetY: 2
                })
                .margin({ top: 20 })
              }

              // AI Recommendations Card
              Column() {
                Row() {
                  Text('AI Recommendations')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')

                  Blank()

                  if (this.dashboardState.isLoadingAI) {
                    LoadingProgress()
                      .width(16)
                      .height(16)
                      .color('#007AFF')
                  }
                }
                .width('100%')
                .margin({ bottom: 15 })

                if (this.dashboardState.aiRecommendation) {
                  Column() {
                    // Urgency indicator
                    Row() {
                      Text(this.getUrgencyIndicator(this.dashboardState.aiRecommendation.urgency))
                        .fontSize(16)
                      
                      Text(this.dashboardState.aiRecommendation.urgency.toUpperCase())
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.getUrgencyColor(this.dashboardState.aiRecommendation.urgency))
                        .margin({ left: 8 })

                      Blank()

                      Text(`${Math.round(this.dashboardState.aiRecommendation.confidence * 100)}%`)
                        .fontSize(12)
                        .fontColor('#666666')
                    }
                    .width('100%')
                    .margin({ bottom: 10 })

                    Text(this.dashboardState.aiRecommendation.recommendation)
                      .fontSize(14)
                      .fontColor('#333333')
                      .lineHeight(20)

                    if (this.dashboardState.aiRecommendation.reasoning) {
                      Text(this.dashboardState.aiRecommendation.reasoning)
                        .fontSize(12)
                        .fontColor('#666666')
                        .lineHeight(18)
                        .margin({ top: 10 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                } else if (this.dashboardState.isLoadingAI) {
                  Text('Generating personalized recommendations...')
                    .fontSize(14)
                    .fontColor('#666666')
                } else {
                  Text('AI recommendations unavailable')
                    .fontSize(14)
                    .fontColor('#999999')
                }
              }
              .width('90%')
              .padding(20)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({
                radius: 8,
                color: 'rgba(0, 0, 0, 0.1)',
                offsetX: 0,
                offsetY: 2
              })
              .margin({ top: 20 })
              .alignItems(HorizontalAlign.Start)

              // Location info (if available)
              if (this.dashboardState.currentLocation) {
                Column() {
                  Text('Current Location')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')
                    .margin({ bottom: 10 })

                  Text(`${this.dashboardState.currentLocation.latitude.toFixed(4)}, ${this.dashboardState.currentLocation.longitude.toFixed(4)}`)
                    .fontSize(12)
                    .fontColor('#666666')

                  Text(`Accuracy: ±${this.dashboardState.currentLocation.accuracy.toFixed(0)}m`)
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 5 })
                }
                .width('90%')
                .padding(15)
                .backgroundColor('#F8F9FA')
                .borderRadius(8)
                .margin({ top: 20 })
                .alignItems(HorizontalAlign.Start)
              }

              // Offline mode warning
              if (this.dashboardState.isOffline && this.dashboardState.environmentScore) {
                Row() {
                  Text('⚠️')
                    .fontSize(16)
                    .margin({ right: 8 })

                  Column() {
                    Text('Using cached data')
                      .fontSize(14)
                      .fontColor('#FF9800')
                      .fontWeight(FontWeight.Medium)

                    Text(`Last updated: ${this.formatUpdateTime(this.dashboardState.lastUpdateTime)}`)
                      .fontSize(12)
                      .fontColor('#666666')
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('90%')
                .padding(15)
                .backgroundColor('#FFF3CD')
                .borderRadius(8)
                .margin({ top: 20 })
                .alignItems(VerticalAlign.Center)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .layoutWeight(1)
          .padding({ bottom: 20 })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  buildScoreDetail(label: string, score: number) {
    Column() {
      Text(score.toString())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getScoreColor(score))

      Text(label)
        .fontSize(12)
        .fontColor('#666666')
        .margin({ top: 4 })
    }
  }

  private getScoreColor(score: number): string {
    if (score >= 80) return '#4CAF50'; // Green
    if (score >= 60) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  private getStatusMessage(score: number): string {
    if (score >= 80) return 'Excellent for outdoor exercise';
    if (score >= 60) return 'Good for outdoor exercise';
    if (score >= 40) return 'Fair conditions - consider indoor alternatives';
    return 'Poor conditions - recommend indoor exercise';
  }

  private getUrgencyIndicator(urgency: string): string {
    switch (urgency) {
      case 'high': return '🔴';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
    }
  }

  private getUrgencyColor(urgency: string): string {
    switch (urgency) {
      case 'high': return '#F44336';
      case 'medium': return '#FF9800';
      case 'low': return '#4CAF50';
      default: return '#666666';
    }
  }

  private formatUpdateTime(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} min ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} hr ago`;
    
    return new Date(timestamp).toLocaleTimeString();
  }
}