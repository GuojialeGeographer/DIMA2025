/**
 * Error boundary component for catching and handling UI errors
 */
import hilog from '@ohos.hilog';
import { ErrorHandler, ErrorCategory, AppError } from '../utils/ErrorHandler';

const TAG = 'ErrorBoundary';
const DOMAIN = 0xFF00;

/**
 * Error boundary state
 */
interface ErrorBoundaryState {
  hasError: boolean;
  error: AppError | null;
  errorInfo: string | null;
  retryCount: number;
  showDetails: boolean;
}

/**
 * Error boundary configuration
 */
export interface ErrorBoundaryConfig {
  fallbackComponent?: () => void;
  onError?: (error: AppError, errorInfo: string) => void;
  maxRetries?: number;
  enableRetry?: boolean;
  showErrorDetails?: boolean;
  customErrorMessage?: string;
}

/**
 * Error boundary component that catches JavaScript errors in child components
 */
@Component
export struct ErrorBoundary {
  @State private errorState: ErrorBoundaryState = {
    hasError: false,
    error: null,
    errorInfo: null,
    retryCount: 0,
    showDetails: false
  };

  private config: ErrorBoundaryConfig;
  private errorHandler: ErrorHandler = ErrorHandler.getInstance();
  private childBuilder: () => void;

  constructor(childBuilder: () => void, config: ErrorBoundaryConfig = {}) {
    this.childBuilder = childBuilder;
    this.config = {
      maxRetries: 3,
      enableRetry: true,
      showErrorDetails: false,
      ...config
    };
  }

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'ErrorBoundary initialized');
    
    // Set up global error handler
    this.setupGlobalErrorHandler();
  }

  /**
   * Set up global error handler for unhandled errors
   */
  private setupGlobalErrorHandler(): void {
    // Note: In a real implementation, this would hook into the ArkTS error handling system
    // For now, we'll simulate error boundary behavior
  }

  /**
   * Handle caught error
   */
  public handleError(error: Error, errorInfo?: string): void {
    hilog.error(DOMAIN, TAG, `Error caught by boundary: ${error.message}`);
    
    // Create structured error
    this.errorHandler.handleError(
      error,
      ErrorCategory.UI,
      {
        component: 'ErrorBoundary',
        errorInfo: errorInfo || 'No additional info',
        retryCount: this.errorState.retryCount
      }
    ).then((appError) => {
      this.errorState.hasError = true;
      this.errorState.error = appError;
      this.errorState.errorInfo = errorInfo || null;

      // Call custom error handler if provided
      if (this.config.onError) {
        this.config.onError(appError, errorInfo || '');
      }
    });
  }

  /**
   * Retry rendering the component
   */
  private retry(): void {
    if (this.errorState.retryCount >= (this.config.maxRetries || 3)) {
      hilog.warn(DOMAIN, TAG, 'Maximum retry attempts reached');
      return;
    }

    hilog.info(DOMAIN, TAG, `Retrying component render (attempt ${this.errorState.retryCount + 1})`);
    
    this.errorState.retryCount++;
    this.errorState.hasError = false;
    this.errorState.error = null;
    this.errorState.errorInfo = null;
  }

  /**
   * Reset error boundary state
   */
  public reset(): void {
    hilog.info(DOMAIN, TAG, 'Resetting error boundary');
    
    this.errorState.hasError = false;
    this.errorState.error = null;
    this.errorState.errorInfo = null;
    this.errorState.retryCount = 0;
    this.errorState.showDetails = false;
  }

  /**
   * Toggle error details visibility
   */
  private toggleDetails(): void {
    this.errorState.showDetails = !this.errorState.showDetails;
  }

  build() {
    if (this.errorState.hasError && this.errorState.error) {
      // Error state UI
      Column() {
        // Error icon and title
        Column() {
          Text('⚠️')
            .fontSize(48)
            .margin({ bottom: 16 })

          Text('Something went wrong')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F44336')
            .margin({ bottom: 8 })

          Text(this.config.customErrorMessage || this.errorState.error.userMessage)
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 20 })
            .padding({ left: 20, right: 20 })
        }
        .alignItems(HorizontalAlign.Center)

        // Action buttons
        Column() {
          if (this.config.enableRetry && this.errorState.retryCount < (this.config.maxRetries || 3)) {
            Button('Try Again')
              .width('80%')
              .height(44)
              .backgroundColor('#007AFF')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .margin({ bottom: 12 })
              .onClick(() => {
                this.retry();
              })
          }

          Button('Go Back')
            .width('80%')
            .height(44)
            .backgroundColor('#F8F9FA')
            .fontColor('#333333')
            .borderRadius(8)
            .border({ width: 1, color: '#E9ECEF' })
            .margin({ bottom: 12 })
            .onClick(() => {
              // Navigate back or reset to safe state
              this.reset();
            })

          if (this.config.showErrorDetails) {
            Button(this.errorState.showDetails ? 'Hide Details' : 'Show Details')
              .width('80%')
              .height(36)
              .backgroundColor(Color.Transparent)
              .fontColor('#666666')
              .fontSize(12)
              .onClick(() => {
                this.toggleDetails();
              })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // Error details (if enabled and visible)
        if (this.config.showErrorDetails && this.errorState.showDetails && this.errorState.error) {
          Column() {
            Text('Error Details')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .margin({ bottom: 8 })

            Text(`Error ID: ${this.errorState.error.id}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ bottom: 4 })

            Text(`Category: ${this.errorState.error.category}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ bottom: 4 })

            Text(`Severity: ${this.errorState.error.severity}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ bottom: 4 })

            Text(`Time: ${new Date(this.errorState.error.timestamp).toLocaleString()}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            if (this.errorState.error.technicalDetails) {
              Text('Technical Details:')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ bottom: 4 })

              Text(this.errorState.error.technicalDetails)
                .fontSize(10)
                .fontColor('#999999')
                .fontFamily('monospace')
                .maxLines(10)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('90%')
          .padding(12)
          .backgroundColor('#F8F9FA')
          .borderRadius(8)
          .margin({ top: 20 })
          .alignItems(HorizontalAlign.Start)
        }

        // Retry count indicator
        if (this.errorState.retryCount > 0) {
          Text(`Retry attempts: ${this.errorState.retryCount}/${this.config.maxRetries || 3}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFFFFF')
      .padding(20)
    } else {
      // Normal state - render children
      try {
        this.childBuilder();
      } catch (error) {
        // Catch synchronous errors during render
        this.handleError(error as Error, 'Render error');
        
        // Return error UI immediately
        Column() {
          Text('⚠️')
            .fontSize(48)
            .margin({ bottom: 16 })

          Text('Render Error')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F44336')

          Text('Failed to render component')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#FFFFFF')
      }
    }
  }
}

/**
 * Higher-order component wrapper for error boundaries
 */
export function withErrorBoundary<T>(
  component: () => T,
  config?: ErrorBoundaryConfig
): () => void {
  return () => {
    ErrorBoundary(component, config);
  };
}

/**
 * Error boundary for specific component types
 */
@Component
export struct ServiceErrorBoundary {
  @State private hasError: boolean = false;
  @State private errorMessage: string = '';
  
  private serviceName: string;
  private childBuilder: () => void;
  private onRetry?: () => void;

  constructor(serviceName: string, childBuilder: () => void, onRetry?: () => void) {
    this.serviceName = serviceName;
    this.childBuilder = childBuilder;
    this.onRetry = onRetry;
  }

  /**
   * Handle service-specific errors
   */
  public handleServiceError(error: Error): void {
    hilog.error(DOMAIN, TAG, `Service error in ${this.serviceName}: ${error.message}`);
    
    this.hasError = true;
    this.errorMessage = `${this.serviceName} service is currently unavailable. Please try again later.`;
  }

  /**
   * Retry service operation
   */
  private retryService(): void {
    this.hasError = false;
    this.errorMessage = '';
    
    if (this.onRetry) {
      try {
        this.onRetry();
      } catch (error) {
        this.handleServiceError(error as Error);
      }
    }
  }

  build() {
    if (this.hasError) {
      Column() {
        Text('🔧')
          .fontSize(32)
          .margin({ bottom: 12 })

        Text(`${this.serviceName} Error`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F44336')
          .margin({ bottom: 8 })

        Text(this.errorMessage)
          .fontSize(12)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 16 })

        if (this.onRetry) {
          Button('Retry')
            .fontSize(14)
            .backgroundColor('#007AFF')
            .fontColor('#FFFFFF')
            .borderRadius(6)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .onClick(() => {
              this.retryService();
            })
        }
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFF5F5')
      .borderRadius(8)
    } else {
      try {
        this.childBuilder();
      } catch (error) {
        this.handleServiceError(error as Error);
        
        // Fallback UI
        Text('Service temporarily unavailable')
          .fontSize(12)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .padding(16);
      }
    }
  }
}