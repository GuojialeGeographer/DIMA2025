import hilog from '@ohos.hilog';

const TAG = 'LoadingIndicator';
const DOMAIN = 0xFF00;

/**
 * Loading indicator types
 */
export enum LoadingType {
  SPINNER = 'spinner',
  PROGRESS = 'progress',
  SKELETON = 'skeleton',
  DOTS = 'dots'
}

/**
 * Loading indicator configuration
 */
export interface LoadingConfig {
  type: LoadingType;
  size: number;
  color: string;
  message?: string;
  progress?: number; // 0-100 for progress type
  showPercentage?: boolean;
}

/**
 * Default loading configuration
 */
export const DEFAULT_LOADING_CONFIG: LoadingConfig = {
  type: LoadingType.SPINNER,
  size: 40,
  color: '#007AFF',
  message: 'Loading...'
};

/**
 * Reusable loading indicator component with multiple styles
 * Optimized for performance and battery usage
 */
@Component
export struct LoadingIndicator {
  @Prop config: LoadingConfig = DEFAULT_LOADING_CONFIG;
  @State private animationProgress: number = 0;
  private animationTimer: number | null = null;

  aboutToAppear(): void {
    if (this.config.type === LoadingType.DOTS) {
      this.startDotsAnimation();
    }
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  /**
   * Start dots animation with optimized timing
   */
  private startDotsAnimation(): void {
    this.animationTimer = setInterval(() => {
      this.animationProgress = (this.animationProgress + 1) % 4;
    }, 500); // Slower animation for better battery life
  }

  /**
   * Stop all animations
   */
  private stopAnimation(): void {
    if (this.animationTimer) {
      clearInterval(this.animationTimer);
      this.animationTimer = null;
    }
  }

  build() {
    Column() {
      // Loading indicator based on type
      if (this.config.type === LoadingType.SPINNER) {
        this.SpinnerIndicator()
      } else if (this.config.type === LoadingType.PROGRESS) {
        this.ProgressIndicator()
      } else if (this.config.type === LoadingType.SKELETON) {
        this.SkeletonIndicator()
      } else if (this.config.type === LoadingType.DOTS) {
        this.DotsIndicator()
      }

      // Loading message
      if (this.config.message) {
        Text(this.config.message)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 15 })
          .textAlign(TextAlign.Center)
      }

      // Progress percentage
      if (this.config.type === LoadingType.PROGRESS && 
          this.config.showPercentage && 
          this.config.progress !== undefined) {
        Text(`${Math.round(this.config.progress)}%`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 5 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder SpinnerIndicator() {
    LoadingProgress()
      .width(this.config.size)
      .height(this.config.size)
      .color(this.config.color)
  }

  @Builder ProgressIndicator() {
    Column() {
      Progress({
        value: this.config.progress || 0,
        total: 100,
        type: ProgressType.Linear
      })
      .width(this.config.size * 3)
      .height(8)
      .color(this.config.color)
      .backgroundColor('#E0E0E0')
    }
  }

  @Builder SkeletonIndicator() {
    Column() {
      // Skeleton loading animation
      ForEach([1, 2, 3], (item: number) => {
        Row() {
          // Avatar placeholder
          Circle({ width: 40, height: 40 })
            .fill('#E0E0E0')
            .margin({ right: 15 })

          Column() {
            // Title placeholder
            Rect({ width: '70%', height: 16 })
              .fill('#E0E0E0')
              .borderRadius(4)
              .margin({ bottom: 8 })

            // Subtitle placeholder
            Rect({ width: '50%', height: 12 })
              .fill('#F0F0F0')
              .borderRadius(4)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(15)
        .margin({ bottom: 10 })
      })
    }
    .width('100%')
  }

  @Builder DotsIndicator() {
    Row() {
      ForEach([0, 1, 2], (index: number) => {
        Circle({ width: 8, height: 8 })
          .fill(this.animationProgress === index ? this.config.color : '#E0E0E0')
          .margin({ left: index > 0 ? 8 : 0 })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
      })
    }
  }
}

/**
 * Optimized loading overlay component
 */
@Component
export struct LoadingOverlay {
  @Prop isVisible: boolean = false;
  @Prop config: LoadingConfig = DEFAULT_LOADING_CONFIG;
  @Prop backgroundColor: string = 'rgba(255, 255, 255, 0.8)';

  build() {
    if (this.isVisible) {
      Stack() {
        // Semi-transparent background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.backgroundColor)

        // Loading indicator
        LoadingIndicator({ config: this.config })
      }
      .width('100%')
      .height('100%')
      .zIndex(1000)
    }
  }
}

/**
 * Performance-optimized loading states for different scenarios
 */
export class LoadingStates {
  static readonly MAP_LOADING: LoadingConfig = {
    type: LoadingType.SPINNER,
    size: 40,
    color: '#007AFF',
    message: 'Loading map...'
  };

  static readonly DATA_LOADING: LoadingConfig = {
    type: LoadingType.DOTS,
    size: 30,
    color: '#4CAF50',
    message: 'Fetching data...'
  };

  static readonly HISTORY_LOADING: LoadingConfig = {
    type: LoadingType.SKELETON,
    size: 50,
    color: '#FF9800',
    message: 'Loading exercise history...'
  };

  static readonly SYNC_PROGRESS: LoadingConfig = {
    type: LoadingType.PROGRESS,
    size: 40,
    color: '#9C27B0',
    message: 'Syncing data...',
    showPercentage: true
  };

  static readonly LOCATION_LOADING: LoadingConfig = {
    type: LoadingType.SPINNER,
    size: 30,
    color: '#FF5722',
    message: 'Getting location...'
  };

  static readonly AI_PROCESSING: LoadingConfig = {
    type: LoadingType.DOTS,
    size: 35,
    color: '#607D8B',
    message: 'AI is thinking...'
  };
}

/**
 * Loading state manager for performance optimization
 */
export class LoadingManager {
  private static activeLoadings: Set<string> = new Set();
  private static loadingStartTimes: Map<string, number> = new Map();

  /**
   * Start loading with performance tracking
   */
  static startLoading(id: string): void {
    this.activeLoadings.add(id);
    this.loadingStartTimes.set(id, Date.now());
    
    hilog.info(DOMAIN, TAG, `Loading started: ${id}`);
  }

  /**
   * Stop loading and log performance metrics
   */
  static stopLoading(id: string): void {
    if (this.activeLoadings.has(id)) {
      this.activeLoadings.delete(id);
      
      const startTime = this.loadingStartTimes.get(id);
      if (startTime) {
        const duration = Date.now() - startTime;
        this.loadingStartTimes.delete(id);
        
        hilog.info(DOMAIN, TAG, `Loading completed: ${id} (${duration}ms)`);
        
        // Log performance warning for slow operations
        if (duration > 5000) {
          hilog.warn(DOMAIN, TAG, `Slow loading detected: ${id} took ${duration}ms`);
        }
      }
    }
  }

  /**
   * Check if any loading is active
   */
  static hasActiveLoading(): boolean {
    return this.activeLoadings.size > 0;
  }

  /**
   * Get active loading count
   */
  static getActiveLoadingCount(): number {
    return this.activeLoadings.size;
  }

  /**
   * Clear all loading states (for cleanup)
   */
  static clearAll(): void {
    this.activeLoadings.clear();
    this.loadingStartTimes.clear();
  }
}