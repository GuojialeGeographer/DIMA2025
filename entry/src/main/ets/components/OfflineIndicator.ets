/**
 * Offline indicator component for displaying network status and sync information
 */
import { OfflineService } from '../services/OfflineService';

/**
 * Props for OfflineIndicator component
 */
interface OfflineIndicatorProps {
  showDetails?: boolean;
  compact?: boolean;
  onSyncRequested?: () => void;
}

/**
 * State for offline indicator
 */
interface OfflineIndicatorState {
  isOnline: boolean;
  queuedOperations: number;
  syncInProgress: boolean;
  lastSyncAttempt: number | null;
}

@Component
export struct OfflineIndicator {
  @Prop showDetails: boolean = false;
  @Prop compact: boolean = false;
  @Prop onSyncRequested?: () => void;
  
  @State private indicatorState: OfflineIndicatorState = {
    isOnline: true,
    queuedOperations: 0,
    syncInProgress: false,
    lastSyncAttempt: null
  };

  private offlineService: OfflineService | null = null;
  private statusUpdateTimer: number = -1;

  aboutToAppear(): void {
    this.initializeOfflineService();
    this.startStatusUpdates();
  }

  aboutToDisappear(): void {
    this.stopStatusUpdates();
    this.cleanupOfflineService();
  }

  /**
   * Initialize offline service and set up listeners
   */
  private initializeOfflineService(): void {
    try {
      // Get offline service instance (assumes it's already initialized)
      this.offlineService = OfflineService.getInstance();
      
      // Add listener for online status changes
      this.offlineService.addOnlineStatusListener(this.handleOnlineStatusChange.bind(this));
      
      // Update initial state
      this.updateIndicatorState();
    } catch (error) {
      console.error('Failed to initialize offline service in indicator:', error);
    }
  }

  /**
   * Handle online status changes
   */
  private handleOnlineStatusChange(isOnline: boolean): void {
    this.indicatorState.isOnline = isOnline;
    this.updateIndicatorState();
  }

  /**
   * Update indicator state from offline service
   */
  private updateIndicatorState(): void {
    if (!this.offlineService) return;

    const stats = this.offlineService.getOfflineStats();
    this.indicatorState = {
      isOnline: stats.isOnline,
      queuedOperations: stats.queuedOperations,
      syncInProgress: stats.syncInProgress,
      lastSyncAttempt: stats.lastSyncAttempt
    };
  }

  /**
   * Start periodic status updates
   */
  private startStatusUpdates(): void {
    this.statusUpdateTimer = setInterval(() => {
      this.updateIndicatorState();
    }, 5000); // Update every 5 seconds
  }

  /**
   * Stop periodic status updates
   */
  private stopStatusUpdates(): void {
    if (this.statusUpdateTimer !== -1) {
      clearInterval(this.statusUpdateTimer);
      this.statusUpdateTimer = -1;
    }
  }

  /**
   * Cleanup offline service listener
   */
  private cleanupOfflineService(): void {
    if (this.offlineService) {
      this.offlineService.removeOnlineStatusListener(this.handleOnlineStatusChange.bind(this));
    }
  }

  /**
   * Handle sync button click
   */
  private handleSyncClick(): void {
    if (this.onSyncRequested) {
      this.onSyncRequested();
    } else if (this.offlineService && this.indicatorState.isOnline) {
      this.offlineService.forceSynchronization().catch(error => {
        console.error('Manual sync failed:', error);
      });
    }
  }

  /**
   * Get status icon based on current state
   */
  private getStatusIcon(): string {
    if (this.indicatorState.syncInProgress) {
      return '🔄'; // Syncing
    } else if (!this.indicatorState.isOnline) {
      return '📶'; // Offline
    } else if (this.indicatorState.queuedOperations > 0) {
      return '⏳'; // Pending sync
    } else {
      return '✅'; // Online and synced
    }
  }

  /**
   * Get status color based on current state
   */
  private getStatusColor(): string {
    if (this.indicatorState.syncInProgress) {
      return '#007AFF'; // Blue for syncing
    } else if (!this.indicatorState.isOnline) {
      return '#FF6B6B'; // Red for offline
    } else if (this.indicatorState.queuedOperations > 0) {
      return '#FF9800'; // Orange for pending
    } else {
      return '#4CAF50'; // Green for online
    }
  }

  /**
   * Get status text
   */
  private getStatusText(): string {
    if (this.indicatorState.syncInProgress) {
      return 'Syncing...';
    } else if (!this.indicatorState.isOnline) {
      return 'Offline';
    } else if (this.indicatorState.queuedOperations > 0) {
      return `${this.indicatorState.queuedOperations} pending`;
    } else {
      return 'Online';
    }
  }

  /**
   * Format last sync time
   */
  private formatLastSync(): string {
    if (!this.indicatorState.lastSyncAttempt) {
      return 'Never';
    }

    const now = Date.now();
    const diff = now - this.indicatorState.lastSyncAttempt;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    
    return new Date(this.indicatorState.lastSyncAttempt).toLocaleDateString();
  }

  build() {
    if (this.compact) {
      // Compact mode - just icon and basic status
      Row() {
        Text(this.getStatusIcon())
          .fontSize(12)
          .fontColor(this.getStatusColor())

        if (!this.indicatorState.isOnline || this.indicatorState.queuedOperations > 0) {
          Text(this.getStatusText())
            .fontSize(10)
            .fontColor(this.getStatusColor())
            .margin({ left: 4 })
        }
      }
      .padding({ horizontal: 6, vertical: 2 })
      .backgroundColor(this.indicatorState.isOnline ? 'transparent' : 'rgba(255, 107, 107, 0.1)')
      .borderRadius(4)
      .onClick(() => {
        if (this.indicatorState.queuedOperations > 0 && this.indicatorState.isOnline) {
          this.handleSyncClick();
        }
      })
    } else {
      // Full mode - detailed status information
      Column() {
        Row() {
          Text(this.getStatusIcon())
            .fontSize(16)
            .fontColor(this.getStatusColor())
            .margin({ right: 8 })

          Column() {
            Text(this.getStatusText())
              .fontSize(14)
              .fontColor(this.getStatusColor())
              .fontWeight(FontWeight.Medium)

            if (this.showDetails) {
              if (this.indicatorState.queuedOperations > 0) {
                Text(`${this.indicatorState.queuedOperations} operations queued`)
                  .fontSize(12)
                  .fontColor('#666666')
                  .margin({ top: 2 })
              }

              if (this.indicatorState.lastSyncAttempt) {
                Text(`Last sync: ${this.formatLastSync()}`)
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 2 })
              }
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // Sync button (only show when there are pending operations and online)
          if (this.indicatorState.queuedOperations > 0 && 
              this.indicatorState.isOnline && 
              !this.indicatorState.syncInProgress) {
            Button('Sync')
              .fontSize(12)
              .padding({ horizontal: 12, vertical: 6 })
              .backgroundColor('#007AFF')
              .fontColor(Color.White)
              .borderRadius(4)
              .onClick(() => this.handleSyncClick())
          }

          // Loading indicator when syncing
          if (this.indicatorState.syncInProgress) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#007AFF')
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // Additional details for offline mode
        if (!this.indicatorState.isOnline && this.showDetails) {
          Column() {
            Text('Working offline with cached data')
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 8 })

            if (this.indicatorState.queuedOperations > 0) {
              Text('Changes will sync when connection is restored')
                .fontSize(11)
                .fontColor('#999999')
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.indicatorState.isOnline ? '#F8F9FA' : '#FFF3CD')
      .borderRadius(8)
      .border({
        width: 1,
        color: this.indicatorState.isOnline ? '#E9ECEF' : '#FFE082'
      })
    }
  }
}