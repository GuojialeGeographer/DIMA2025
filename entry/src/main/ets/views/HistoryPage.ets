import hilog from '@ohos.hilog';
import { DatabaseService } from '../services/DatabaseService';
import { ExerciseSession } from '../models/ExerciseSession';
import { LocationData } from '../models/LocationData';
import { EnvironmentScore } from '../models/EnvironmentScore';

const TAG = 'HistoryPage';
const DOMAIN = 0xFF00;

interface ExerciseHistoryItem {
  id: number;
  date: string;
  duration: string;
  distance: string;
  environmentScore: number;
  type: string;
  session: ExerciseSession;
}

interface LazyLoadingConfig {
  pageSize: number;
  preloadThreshold: number; // Load more when this many items from end
  maxCacheSize: number; // Maximum items to keep in memory
}

enum SortOption {
  DATE_DESC = 'date_desc',
  DATE_ASC = 'date_asc',
  DISTANCE_DESC = 'distance_desc',
  DISTANCE_ASC = 'distance_asc',
  ENV_SCORE_DESC = 'env_score_desc',
  ENV_SCORE_ASC = 'env_score_asc'
}

enum FilterOption {
  ALL = 'all',
  HIGH_SCORE = 'high_score', // >= 80
  MEDIUM_SCORE = 'medium_score', // 60-79
  LOW_SCORE = 'low_score' // < 60
}

@Component
export struct HistoryPage {
  @State historyItems: ExerciseHistoryItem[] = [];
  @State filteredItems: ExerciseHistoryItem[] = [];
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State selectedSession: ExerciseSession | null = null;
  @State showDetailView: boolean = false;
  @State sortOption: SortOption = SortOption.DATE_DESC;
  @State filterOption: FilterOption = FilterOption.ALL;
  @State showFilters: boolean = false;
  @State hasMoreData: boolean = true;
  @State currentPage: number = 0;
  
  private databaseService: DatabaseService = DatabaseService.getInstance();
  private lazyLoadConfig: LazyLoadingConfig = {
    pageSize: 20,
    preloadThreshold: 5,
    maxCacheSize: 100
  };
  private allSessionsCache: ExerciseSession[] = [];
  private totalSessionCount: number = 0;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'HistoryPage aboutToAppear');
    this.initializeLazyLoading();
  }

  /**
   * Initialize lazy loading system
   */
  private async initializeLazyLoading(): Promise<void> {
    try {
      this.isLoading = true;
      
      // Get total count first for pagination
      const allSessions = await this.databaseService.getExerciseHistory();
      this.totalSessionCount = allSessions.length;
      this.allSessionsCache = allSessions;
      
      // Load first page
      await this.loadNextPage();
      
      this.isLoading = false;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to initialize lazy loading: ${error}`);
      this.isLoading = false;
    }
  }

  /**
   * Load next page of exercise history
   */
  private async loadNextPage(): Promise<void> {
    if (!this.hasMoreData || this.isLoadingMore) {
      return;
    }

    try {
      this.isLoadingMore = true;
      
      const startIndex = this.currentPage * this.lazyLoadConfig.pageSize;
      const endIndex = Math.min(startIndex + this.lazyLoadConfig.pageSize, this.totalSessionCount);
      
      if (startIndex >= this.totalSessionCount) {
        this.hasMoreData = false;
        this.isLoadingMore = false;
        return;
      }
      
      // Get sessions for current page from cache
      const pageSessions = this.allSessionsCache.slice(startIndex, endIndex);
      
      const pageItems = pageSessions.map(session => ({
        id: session.id,
        date: this.formatDate(session.startTime),
        duration: this.formatDuration(session.duration),
        distance: this.formatDistance(session.distance),
        environmentScore: Math.round(session.averageEnvironmentScore),
        type: this.getExerciseType(session),
        session: session
      }));
      
      // Add to existing items
      this.historyItems = [...this.historyItems, ...pageItems];
      
      // Update pagination state
      this.currentPage++;
      this.hasMoreData = endIndex < this.totalSessionCount;
      
      // Apply filters and sorting
      this.applyFiltersAndSort();
      
      // Manage memory by limiting cache size
      if (this.historyItems.length > this.lazyLoadConfig.maxCacheSize) {
        const excessItems = this.historyItems.length - this.lazyLoadConfig.maxCacheSize;
        this.historyItems = this.historyItems.slice(excessItems);
        hilog.info(DOMAIN, TAG, `Trimmed ${excessItems} items from cache for memory management`);
      }
      
      hilog.info(DOMAIN, TAG, `Loaded page ${this.currentPage}, total items: ${this.historyItems.length}/${this.totalSessionCount}`);
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load next page: ${error}`);
    } finally {
      this.isLoadingMore = false;
    }
  }

  /**
   * Check if more data should be loaded based on scroll position
   */
  private checkLoadMore(currentIndex: number): void {
    const remainingItems = this.filteredItems.length - currentIndex;
    
    if (remainingItems <= this.lazyLoadConfig.preloadThreshold && this.hasMoreData && !this.isLoadingMore) {
      hilog.info(DOMAIN, TAG, `Preload threshold reached, loading more data`);
      this.loadNextPage();
    }
  }

  /**
   * Reset lazy loading state (used when filters change)
   */
  private resetLazyLoading(): void {
    this.historyItems = [];
    this.currentPage = 0;
    this.hasMoreData = true;
    this.loadNextPage();
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  private formatDuration(durationMs: number): string {
    const minutes = Math.floor(durationMs / 60000);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes % 60}m`;
    }
    return `${minutes}m`;
  }

  private formatDistance(distanceKm: number): string {
    if (distanceKm < 1) {
      return `${Math.round(distanceKm * 1000)}m`;
    }
    return `${distanceKm.toFixed(1)}km`;
  }

  private getExerciseType(session: ExerciseSession): string {
    const hour = new Date(session.startTime).getHours();
    const distance = session.distance;
    
    if (hour >= 5 && hour < 10) {
      return distance > 3 ? 'Morning Run' : 'Morning Walk';
    } else if (hour >= 17 && hour < 21) {
      return distance > 3 ? 'Evening Run' : 'Evening Walk';
    } else {
      return distance > 3 ? 'Run' : 'Walk';
    }
  }

  private applyFiltersAndSort(): void {
    let filtered = [...this.historyItems];

    // Apply filter
    switch (this.filterOption) {
      case FilterOption.HIGH_SCORE:
        filtered = filtered.filter(item => item.environmentScore >= 80);
        break;
      case FilterOption.MEDIUM_SCORE:
        filtered = filtered.filter(item => item.environmentScore >= 60 && item.environmentScore < 80);
        break;
      case FilterOption.LOW_SCORE:
        filtered = filtered.filter(item => item.environmentScore < 60);
        break;
      default:
        // ALL - no filtering
        break;
    }

    // Apply sort
    switch (this.sortOption) {
      case SortOption.DATE_ASC:
        filtered.sort((a, b) => a.session.startTime - b.session.startTime);
        break;
      case SortOption.DISTANCE_DESC:
        filtered.sort((a, b) => b.session.distance - a.session.distance);
        break;
      case SortOption.DISTANCE_ASC:
        filtered.sort((a, b) => a.session.distance - b.session.distance);
        break;
      case SortOption.ENV_SCORE_DESC:
        filtered.sort((a, b) => b.environmentScore - a.environmentScore);
        break;
      case SortOption.ENV_SCORE_ASC:
        filtered.sort((a, b) => a.environmentScore - b.environmentScore);
        break;
      default: // DATE_DESC
        filtered.sort((a, b) => b.session.startTime - a.session.startTime);
        break;
    }

    this.filteredItems = filtered;
  }

  private onSortChange(newSort: SortOption): void {
    this.sortOption = newSort;
    
    // Reset lazy loading when sort changes
    this.resetLazyLoading();
    this.showFilters = false;
  }

  private onFilterChange(newFilter: FilterOption): void {
    this.filterOption = newFilter;
    
    // Reset lazy loading when filter changes
    this.resetLazyLoading();
    this.showFilters = false;
  }

  private showSessionDetail(session: ExerciseSession): void {
    this.selectedSession = session;
    this.showDetailView = true;
  }

  private closeDetailView(): void {
    this.showDetailView = false;
    this.selectedSession = null;
  }

  build() {
    if (this.showDetailView && this.selectedSession) {
      this.DetailView()
    } else {
      this.ListView()
    }
  }

  @Builder ListView() {
    Column() {
      // Header with filters
      Column() {
        Row() {
          Text('Exercise History')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Blank()

          Button('🔍')
            .fontSize(20)
            .fontColor('#007AFF')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showFilters = !this.showFilters;
            })
        }
        .width('100%')
        .height(60)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)

        // Filter and sort controls
        if (this.showFilters) {
          Column() {
            // Sort options
            Row() {
              Text('Sort by:')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ right: 10 })

              Button(this.getSortLabel())
                .fontSize(12)
                .fontColor('#007AFF')
                .backgroundColor('#F0F8FF')
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.showSortOptions();
                })
            }
            .width('100%')
            .margin({ bottom: 10 })

            // Filter options
            Row() {
              Text('Filter:')
                .fontSize(14)
                .fontColor('#666666')
                .margin({ right: 10 })

              Button(this.getFilterLabel())
                .fontSize(12)
                .fontColor('#007AFF')
                .backgroundColor('#F0F8FF')
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.showFilterOptions();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 10 })
          .backgroundColor('#FFFFFF')
        }
      }
      .backgroundColor('#FFFFFF')

      // Content area
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#007AFF')

          Text('Loading exercise history...')
            .fontSize(16)
            .fontColor('#666666')
            .margin({ top: 20 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.filteredItems.length === 0) {
        Column() {
          Text('🏃‍♂️')
            .fontSize(64)
            .margin({ bottom: 20 })

          Text(this.historyItems.length === 0 ? 'No Exercise History' : 'No Matching Sessions')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .margin({ bottom: 10 })

          Text(this.historyItems.length === 0 ? 
            'Start your first exercise session to see your history here' :
            'Try adjusting your filters to see more sessions')
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // History list with lazy loading
        List() {
          ForEach(this.filteredItems, (item: ExerciseHistoryItem, index: number) => {
            ListItem() {
              this.HistoryItemCard(item)
            }
            .margin({ bottom: 10 })
            .onAppear(() => {
              // Check if we need to load more data
              this.checkLoadMore(index);
            })
          })
          
          // Loading more indicator
          if (this.isLoadingMore) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#007AFF')
                  .margin({ right: 10 })
                
                Text('Loading more...')
                  .fontSize(14)
                  .fontColor('#666666')
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
          }
          
          // End of data indicator
          if (!this.hasMoreData && this.filteredItems.length > 0) {
            ListItem() {
              Text('No more sessions')
                .fontSize(12)
                .fontColor('#999999')
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(40)
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 10 })
        .onScrollIndex((start: number, end: number) => {
          // Additional check for loading more data on scroll
          if (end >= this.filteredItems.length - this.lazyLoadConfig.preloadThreshold) {
            this.checkLoadMore(end);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder HistoryItemCard(item: ExerciseHistoryItem) {
    Row() {
      Column() {
        Text(item.type)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)

        Text(item.date)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
          .alignSelf(ItemAlign.Start)

        Row() {
          Text(`${item.duration} • ${item.distance}`)
            .fontSize(12)
            .fontColor('#666666')
        }
        .margin({ top: 8 })
        .alignSelf(ItemAlign.Start)

        // Environmental conditions summary
        Row() {
          Text('Avg Conditions: ')
            .fontSize(10)
            .fontColor('#888888')
          
          Text(this.getEnvironmentSummary(item.session))
            .fontSize(10)
            .fontColor('#666666')
        }
        .margin({ top: 4 })
        .alignSelf(ItemAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text('Env Score')
          .fontSize(10)
          .fontColor('#666666')
          .margin({ bottom: 4 })

        Text(item.environmentScore.toString())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor(item.environmentScore))

        // Route points indicator
        Text(`${item.session.route.length} pts`)
          .fontSize(8)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
      .width(80)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: 'rgba(0, 0, 0, 0.1)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      hilog.info(DOMAIN, TAG, `History item clicked: ${item.id}`);
      this.showSessionDetail(item.session);
    })
  }

  @Builder DetailView() {
    Column() {
      // Header
      Row() {
        Button('← Back')
          .fontSize(16)
          .fontColor('#007AFF')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.closeDetailView();
          })

        Blank()

        Text('Session Details')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      // Session details content
      if (this.selectedSession) {
        Scroll() {
          Column() {
            // Session overview
            this.SessionOverviewCard()

            // Route visualization
            this.RouteVisualizationCard()

            // Environmental data overlay
            this.EnvironmentalDataCard()

            // Route details
            this.RouteDetailsCard()
          }
          .padding(20)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder SessionOverviewCard() {
    Column() {
      Text('Session Overview')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 15 })

      Row() {
        Column() {
          Text('Duration')
            .fontSize(12)
            .fontColor('#666666')
          Text(this.formatDuration(this.selectedSession!.duration))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)

        Column() {
          Text('Distance')
            .fontSize(12)
            .fontColor('#666666')
          Text(this.formatDistance(this.selectedSession!.distance))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)

        Column() {
          Text('Avg Score')
            .fontSize(12)
            .fontColor('#666666')
          Text(Math.round(this.selectedSession!.averageEnvironmentScore).toString())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(this.selectedSession!.averageEnvironmentScore))
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.selectedSession!.notes) {
        Text('Notes')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 15, bottom: 5 })

        Text(this.selectedSession!.notes)
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 15 })
  }

  @Builder RouteVisualizationCard() {
    Column() {
      Text('Route Visualization')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 15 })

      // Simple route visualization (text-based for now)
      Column() {
        Text('📍 Route Map')
          .fontSize(48)
          .margin({ bottom: 10 })

        Text(`${this.selectedSession!.route.length} GPS points recorded`)
          .fontSize(14)
          .fontColor('#666666')

        if (this.selectedSession!.route.length > 0) {
          Text(`Start: ${this.formatCoordinate(this.selectedSession!.route[0])}`)
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 5 })

          if (this.selectedSession!.route.length > 1) {
            Text(`End: ${this.formatCoordinate(this.selectedSession!.route[this.selectedSession!.route.length - 1])}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 2 })
          }
        }
      }
      .width('100%')
      .height(150)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F8F8F8')
      .borderRadius(8)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 15 })
  }

  @Builder EnvironmentalDataCard() {
    Column() {
      Text('Environmental Conditions')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 15 })

      if (this.selectedSession!.environmentalConditions.length > 0) {
        // Show environmental data statistics
        Column() {
          this.EnvironmentalStatsRow('Air Quality', this.getAverageScore('airQuality'))
          this.EnvironmentalStatsRow('Weather', this.getAverageScore('weatherConditions'))
          this.EnvironmentalStatsRow('UV Risk', this.getAverageScore('uvRisk'))
          
          if (this.hasNoiseData()) {
            this.EnvironmentalStatsRow('Noise Level', this.getAverageScore('noiseLevel'))
          }
          
          if (this.hasGreenSpaceData()) {
            this.EnvironmentalStatsRow('Green Space', this.getAverageScore('greenSpaceProximity'))
          }
        }
        .width('100%')

        // Environmental conditions over time
        Text('Conditions Timeline')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 15, bottom: 10 })

        List() {
          ForEach(this.selectedSession!.environmentalConditions.slice(0, 5), (condition: EnvironmentScore, index: number) => {
            ListItem() {
              Row() {
                Text(`Point ${index + 1}`)
                  .fontSize(12)
                  .fontColor('#666666')
                  .width(60)

                Text(Math.round(condition.overall).toString())
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getScoreColor(condition.overall))
                  .width(40)

                Text(this.formatTimestamp(condition.calculatedAt))
                  .fontSize(10)
                  .fontColor('#999999')
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }
          })
        }
        .height(120)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .padding(8)
      } else {
        Text('No environmental data recorded')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(60)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 15 })
  }

  @Builder RouteDetailsCard() {
    Column() {
      Text('Route Details')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 15 })

      Text(`Total GPS Points: ${this.selectedSession!.route.length}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 5 })

      Text(`Session Duration: ${this.formatDuration(this.selectedSession!.duration)}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 5 })

      Text(`Total Distance: ${this.formatDistance(this.selectedSession!.distance)}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })

      if (this.selectedSession!.route.length > 0) {
        Text('Route Summary')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 5 })

        List() {
          ForEach(this.selectedSession!.route.slice(0, 10), (point: LocationData, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}.`)
                  .fontSize(12)
                  .fontColor('#666666')
                  .width(30)

                Text(this.formatCoordinate(point))
                  .fontSize(12)
                  .fontColor('#333333')
                  .layoutWeight(1)

                Text(`±${point.accuracy.toFixed(1)}m`)
                  .fontSize(10)
                  .fontColor('#999999')
                  .width(60)
              }
              .width('100%')
              .padding({ top: 2, bottom: 2 })
            }
          })
        }
        .height(200)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .padding(8)

        if (this.selectedSession!.route.length > 10) {
          Text(`... and ${this.selectedSession!.route.length - 10} more points`)
            .fontSize(12)
            .fontColor('#999999')
            .alignSelf(ItemAlign.Center)
            .margin({ top: 5 })
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder EnvironmentalStatsRow(label: string, value: number) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .layoutWeight(1)

      Text(Math.round(value).toString())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getScoreColor(value))
        .width(40)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  private getScoreColor(score: number): string {
    if (score >= 80) return '#4CAF50'; // Green
    if (score >= 60) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  private getSortLabel(): string {
    switch (this.sortOption) {
      case SortOption.DATE_ASC: return 'Date (Old First)';
      case SortOption.DISTANCE_DESC: return 'Distance (High)';
      case SortOption.DISTANCE_ASC: return 'Distance (Low)';
      case SortOption.ENV_SCORE_DESC: return 'Env Score (High)';
      case SortOption.ENV_SCORE_ASC: return 'Env Score (Low)';
      default: return 'Date (Recent)';
    }
  }

  private getFilterLabel(): string {
    switch (this.filterOption) {
      case FilterOption.HIGH_SCORE: return 'High Score (80+)';
      case FilterOption.MEDIUM_SCORE: return 'Medium Score (60-79)';
      case FilterOption.LOW_SCORE: return 'Low Score (<60)';
      default: return 'All Sessions';
    }
  }

  private showSortOptions(): void {
    // In a real implementation, this would show a picker dialog
    // For now, cycle through options
    const options = [
      SortOption.DATE_DESC,
      SortOption.DATE_ASC,
      SortOption.DISTANCE_DESC,
      SortOption.DISTANCE_ASC,
      SortOption.ENV_SCORE_DESC,
      SortOption.ENV_SCORE_ASC
    ];
    
    const currentIndex = options.indexOf(this.sortOption);
    const nextIndex = (currentIndex + 1) % options.length;
    this.onSortChange(options[nextIndex]);
  }

  private showFilterOptions(): void {
    // In a real implementation, this would show a picker dialog
    // For now, cycle through options
    const options = [
      FilterOption.ALL,
      FilterOption.HIGH_SCORE,
      FilterOption.MEDIUM_SCORE,
      FilterOption.LOW_SCORE
    ];
    
    const currentIndex = options.indexOf(this.filterOption);
    const nextIndex = (currentIndex + 1) % options.length;
    this.onFilterChange(options[nextIndex]);
  }

  private getEnvironmentSummary(session: ExerciseSession): string {
    if (session.environmentalConditions.length === 0) {
      return 'No data';
    }

    const avgAirQuality = this.getAverageScore('airQuality');
    const avgWeather = this.getAverageScore('weatherConditions');
    
    let summary = '';
    if (avgAirQuality >= 80) summary += 'Clean Air';
    else if (avgAirQuality >= 60) summary += 'Moderate Air';
    else summary += 'Poor Air';
    
    summary += ', ';
    
    if (avgWeather >= 80) summary += 'Great Weather';
    else if (avgWeather >= 60) summary += 'Good Weather';
    else summary += 'Poor Weather';
    
    return summary;
  }

  private formatCoordinate(location: LocationData): string {
    return `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`;
  }

  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  }

  private getAverageScore(field: keyof EnvironmentScore): number {
    if (!this.selectedSession || this.selectedSession.environmentalConditions.length === 0) {
      return 0;
    }

    const validScores = this.selectedSession.environmentalConditions
      .map(condition => condition[field])
      .filter(score => typeof score === 'number') as number[];

    if (validScores.length === 0) {
      return 0;
    }

    return validScores.reduce((sum, score) => sum + score, 0) / validScores.length;
  }

  private hasNoiseData(): boolean {
    return this.selectedSession?.environmentalConditions.some(
      condition => typeof condition.noiseLevel === 'number'
    ) ?? false;
  }

  private hasGreenSpaceData(): boolean {
    return this.selectedSession?.environmentalConditions.some(
      condition => typeof condition.greenSpaceProximity === 'number'
    ) ?? false;
  }
}