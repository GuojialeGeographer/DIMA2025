/**
 * Error notification component for displaying user-friendly error messages
 */
import hilog from '@ohos.hilog';
import { AppError, ErrorSeverity, RecoveryAction } from '../utils/ErrorHandler';

const TAG = 'ErrorNotification';
const DOMAIN = 0xFF00;

/**
 * Notification display style
 */
export enum NotificationStyle {
  TOAST = 'toast',
  BANNER = 'banner',
  MODAL = 'modal',
  INLINE = 'inline'
}

/**
 * Notification configuration
 */
export interface NotificationConfig {
  style: NotificationStyle;
  duration?: number; // Auto-dismiss duration in ms (0 = no auto-dismiss)
  position?: 'top' | 'center' | 'bottom';
  showActions?: boolean;
  showDetails?: boolean;
  customActions?: NotificationAction[];
}

/**
 * Custom notification action
 */
export interface NotificationAction {
  label: string;
  action: () => void;
  style?: 'primary' | 'secondary' | 'danger';
}

/**
 * Notification state
 */
interface NotificationState {
  visible: boolean;
  error: AppError | null;
  config: NotificationConfig;
  showDetails: boolean;
  countdown: number;
}

/**
 * Error notification component
 */
@Component
export struct ErrorNotification {
  @State private notificationState: NotificationState = {
    visible: false,
    error: null,
    config: {
      style: NotificationStyle.BANNER,
      duration: 5000,
      position: 'top',
      showActions: true,
      showDetails: false
    },
    showDetails: false,
    countdown: 0
  };

  private countdownTimer: number = -1;
  private onDismiss?: () => void;
  private onRetry?: () => void;

  /**
   * Show error notification
   */
  public showError(error: AppError, config?: Partial<NotificationConfig>): void {
    hilog.info(DOMAIN, TAG, `Showing error notification: ${error.id}`);
    
    this.notificationState.error = error;
    this.notificationState.config = { ...this.notificationState.config, ...config };
    this.notificationState.visible = true;
    this.notificationState.showDetails = false;

    // Start auto-dismiss countdown if duration is set
    if (this.notificationState.config.duration && this.notificationState.config.duration > 0) {
      this.startCountdown();
    }
  }

  /**
   * Hide error notification
   */
  public hideError(): void {
    hilog.info(DOMAIN, TAG, 'Hiding error notification');
    
    this.notificationState.visible = false;
    this.notificationState.error = null;
    this.stopCountdown();

    if (this.onDismiss) {
      this.onDismiss();
    }
  }

  /**
   * Set callback for dismiss event
   */
  public setOnDismiss(callback: () => void): void {
    this.onDismiss = callback;
  }

  /**
   * Set callback for retry action
   */
  public setOnRetry(callback: () => void): void {
    this.onRetry = callback;
  }

  /**
   * Start auto-dismiss countdown
   */
  private startCountdown(): void {
    if (!this.notificationState.config.duration) return;

    this.notificationState.countdown = this.notificationState.config.duration / 1000;
    
    this.countdownTimer = setInterval(() => {
      this.notificationState.countdown--;
      
      if (this.notificationState.countdown <= 0) {
        this.hideError();
      }
    }, 1000);
  }

  /**
   * Stop auto-dismiss countdown
   */
  private stopCountdown(): void {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
    this.notificationState.countdown = 0;
  }

  /**
   * Toggle error details visibility
   */
  private toggleDetails(): void {
    this.notificationState.showDetails = !this.notificationState.showDetails;
    
    // Stop auto-dismiss when showing details
    if (this.notificationState.showDetails) {
      this.stopCountdown();
    }
  }

  /**
   * Handle retry action
   */
  private handleRetry(): void {
    hilog.info(DOMAIN, TAG, 'Retry action triggered');
    
    if (this.onRetry) {
      this.onRetry();
    }
    
    this.hideError();
  }

  /**
   * Get notification icon based on error severity
   */
  private getErrorIcon(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '🚨';
      case ErrorSeverity.HIGH:
        return '❌';
      case ErrorSeverity.MEDIUM:
        return '⚠️';
      case ErrorSeverity.LOW:
        return 'ℹ️';
      default:
        return '⚠️';
    }
  }

  /**
   * Get notification color based on error severity
   */
  private getErrorColor(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '#DC3545'; // Red
      case ErrorSeverity.HIGH:
        return '#FD7E14'; // Orange
      case ErrorSeverity.MEDIUM:
        return '#FFC107'; // Yellow
      case ErrorSeverity.LOW:
        return '#17A2B8'; // Blue
      default:
        return '#6C757D'; // Gray
    }
  }

  /**
   * Get background color based on error severity
   */
  private getBackgroundColor(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '#F8D7DA';
      case ErrorSeverity.HIGH:
        return '#FFE5D0';
      case ErrorSeverity.MEDIUM:
        return '#FFF3CD';
      case ErrorSeverity.LOW:
        return '#D1ECF1';
      default:
        return '#F8F9FA';
    }
  }

  build() {
    if (!this.notificationState.visible || !this.notificationState.error) {
      return;
    }

    Stack() {
      if (this.notificationState.config.style === NotificationStyle.MODAL) {
        // Modal overlay
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.hideError();
          })
      }

      // Notification content
      Column() {
        // Header with icon and message
        Row() {
          Text(this.getErrorIcon(this.notificationState.error.severity))
            .fontSize(20)
            .margin({ right: 12 })

          Column() {
            Text(this.notificationState.error.userMessage)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.notificationState.error.category) {
              Text(`Category: ${this.notificationState.error.category}`)
                .fontSize(12)
                .fontColor('#666666')
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // Close button
          Button('×')
            .fontSize(18)
            .fontColor('#666666')
            .backgroundColor(Color.Transparent)
            .width(24)
            .height(24)
            .onClick(() => {
              this.hideError();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ bottom: this.notificationState.config.showActions ? 12 : 0 })

        // Action buttons
        if (this.notificationState.config.showActions) {
          Row() {
            // Retry button (if retry action is available)
            if (this.notificationState.error.recoveryActions.includes(RecoveryAction.RETRY)) {
              Button('Retry')
                .fontSize(12)
                .backgroundColor('#007AFF')
                .fontColor('#FFFFFF')
                .borderRadius(4)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.handleRetry();
                })
            }

            // Details button
            if (this.notificationState.config.showDetails) {
              Button(this.notificationState.showDetails ? 'Hide Details' : 'Details')
                .fontSize(12)
                .backgroundColor(Color.Transparent)
                .fontColor('#007AFF')
                .border({ width: 1, color: '#007AFF' })
                .borderRadius(4)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.toggleDetails();
                })
            }

            // Custom actions
            if (this.notificationState.config.customActions) {
              ForEach(this.notificationState.config.customActions, (action: NotificationAction) => {
                Button(action.label)
                  .fontSize(12)
                  .backgroundColor(action.style === 'primary' ? '#007AFF' : 
                                 action.style === 'danger' ? '#DC3545' : Color.Transparent)
                  .fontColor(action.style === 'secondary' ? '#007AFF' : '#FFFFFF')
                  .border(action.style === 'secondary' ? { width: 1, color: '#007AFF' } : undefined)
                  .borderRadius(4)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .margin({ right: 8 })
                  .onClick(() => {
                    action.action();
                  })
              })
            }

            Blank()

            // Auto-dismiss countdown
            if (this.notificationState.countdown > 0) {
              Text(`${this.notificationState.countdown}s`)
                .fontSize(12)
                .fontColor('#666666')
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }

        // Error details (if visible)
        if (this.notificationState.showDetails && this.notificationState.error) {
          Column() {
            Text('Error Details')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .margin({ bottom: 8, top: 12 })

            Text(`ID: ${this.notificationState.error.id}`)
              .fontSize(11)
              .fontColor('#666666')
              .margin({ bottom: 2 })

            Text(`Severity: ${this.notificationState.error.severity}`)
              .fontSize(11)
              .fontColor('#666666')
              .margin({ bottom: 2 })

            Text(`Time: ${new Date(this.notificationState.error.timestamp).toLocaleTimeString()}`)
              .fontSize(11)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            if (this.notificationState.error.context) {
              Text('Context:')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ bottom: 4 })

              Text(JSON.stringify(this.notificationState.error.context, null, 2))
                .fontSize(10)
                .fontColor('#999999')
                .fontFamily('monospace')
                .maxLines(5)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#F8F9FA')
          .borderRadius(4)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width(this.notificationState.config.style === NotificationStyle.MODAL ? '90%' : '100%')
      .padding(16)
      .backgroundColor(this.getBackgroundColor(this.notificationState.error.severity))
      .borderRadius(this.notificationState.config.style === NotificationStyle.MODAL ? 8 : 0)
      .border({
        width: 1,
        color: this.getErrorColor(this.notificationState.error.severity)
      })
      .shadow(this.notificationState.config.style === NotificationStyle.MODAL ? {
        radius: 8,
        color: 'rgba(0, 0, 0, 0.2)',
        offsetX: 0,
        offsetY: 4
      } : undefined)
    }
    .width('100%')
    .height(this.notificationState.config.style === NotificationStyle.MODAL ? '100%' : undefined)
    .position(this.getNotificationPosition())
    .zIndex(1000)
  }

  /**
   * Get notification position based on configuration
   */
  private getNotificationPosition(): Position {
    if (this.notificationState.config.style === NotificationStyle.MODAL) {
      return { x: 0, y: 0 };
    }

    switch (this.notificationState.config.position) {
      case 'top':
        return { x: 0, y: 0 };
      case 'center':
        return { x: 0, y: '50%' };
      case 'bottom':
        return { x: 0, y: '90%' };
      default:
        return { x: 0, y: 0 };
    }
  }
}

/**
 * Toast notification for quick messages
 */
@Component
export struct ToastNotification {
  @State private visible: boolean = false;
  @State private message: string = '';
  @State private severity: ErrorSeverity = ErrorSeverity.LOW;
  
  private autoHideTimer: number = -1;

  /**
   * Show toast message
   */
  public show(message: string, severity: ErrorSeverity = ErrorSeverity.LOW, duration: number = 3000): void {
    this.message = message;
    this.severity = severity;
    this.visible = true;

    // Auto-hide after duration
    if (duration > 0) {
      this.autoHideTimer = setTimeout(() => {
        this.hide();
      }, duration);
    }
  }

  /**
   * Hide toast message
   */
  public hide(): void {
    this.visible = false;
    
    if (this.autoHideTimer !== -1) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = -1;
    }
  }

  build() {
    if (this.visible) {
      Row() {
        Text(this.message)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('90%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.getToastColor(this.severity))
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .position({ x: '50%', y: '85%' })
      .translate({ x: '-50%' })
      .zIndex(1001)
      .shadow({
        radius: 8,
        color: 'rgba(0, 0, 0, 0.3)',
        offsetX: 0,
        offsetY: 4
      })
    }
  }

  /**
   * Get toast background color based on severity
   */
  private getToastColor(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '#DC3545';
      case ErrorSeverity.HIGH:
        return '#FD7E14';
      case ErrorSeverity.MEDIUM:
        return '#FFC107';
      case ErrorSeverity.LOW:
        return '#28A745';
      default:
        return '#6C757D';
    }
  }
}