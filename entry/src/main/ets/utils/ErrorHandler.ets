/**
 * Comprehensive error handling and recovery system for CityZen app
 */
import hilog from '@ohos.hilog';

const TAG = 'ErrorHandler';
const DOMAIN = 0xFF00;

/**
 * Error severity levels
 */
export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

/**
 * Error categories for classification
 */
export enum ErrorCategory {
  NETWORK = 'network',
  LOCATION = 'location',
  DATABASE = 'database',
  API = 'api',
  UI = 'ui',
  PERMISSION = 'permission',
  VALIDATION = 'validation',
  SYSTEM = 'system'
}

/**
 * Recovery action types
 */
export enum RecoveryAction {
  RETRY = 'retry',
  FALLBACK = 'fallback',
  CACHE = 'cache',
  MANUAL = 'manual',
  NONE = 'none'
}

/**
 * Structured error information
 */
export interface AppError {
  id: string;
  message: string;
  category: ErrorCategory;
  severity: ErrorSeverity;
  timestamp: number;
  context?: Record<string, any>;
  originalError?: Error;
  recoveryActions: RecoveryAction[];
  userMessage: string;
  technicalDetails?: string;
}

/**
 * Error recovery strategy
 */
export interface ErrorRecoveryStrategy {
  maxRetries: number;
  retryDelay: number;
  backoffMultiplier: number;
  fallbackAction?: () => Promise<any>;
  cacheAction?: () => Promise<any>;
  userNotification?: {
    title: string;
    message: string;
    actions: string[];
  };
}

/**
 * Error handler configuration
 */
export interface ErrorHandlerConfig {
  enableLogging: boolean;
  enableUserNotifications: boolean;
  maxErrorHistory: number;
  defaultRetryStrategy: ErrorRecoveryStrategy;
}

/**
 * Default error handler configuration
 */
const DEFAULT_CONFIG: ErrorHandlerConfig = {
  enableLogging: true,
  enableUserNotifications: true,
  maxErrorHistory: 100,
  defaultRetryStrategy: {
    maxRetries: 3,
    retryDelay: 1000,
    backoffMultiplier: 2,
    userNotification: {
      title: 'Operation Failed',
      message: 'An error occurred. Please try again.',
      actions: ['Retry', 'Cancel']
    }
  }
};

/**
 * Central error handler for the application
 */
export class ErrorHandler {
  private static instance: ErrorHandler;
  private config: ErrorHandlerConfig;
  private errorHistory: AppError[] = [];
  private errorListeners: ((error: AppError) => void)[] = [];

  private constructor(config: ErrorHandlerConfig = DEFAULT_CONFIG) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Get singleton instance
   */
  public static getInstance(config?: ErrorHandlerConfig): ErrorHandler {
    if (!ErrorHandler.instance) {
      ErrorHandler.instance = new ErrorHandler(config);
    }
    return ErrorHandler.instance;
  }

  /**
   * Handle an error with automatic recovery attempts
   */
  public async handleError(
    error: Error | string,
    category: ErrorCategory,
    context?: Record<string, any>,
    recoveryStrategy?: Partial<ErrorRecoveryStrategy>
  ): Promise<AppError> {
    const appError = this.createAppError(error, category, context);
    
    // Log the error
    if (this.config.enableLogging) {
      this.logError(appError);
    }

    // Add to error history
    this.addToHistory(appError);

    // Notify listeners
    this.notifyListeners(appError);

    // Attempt recovery if strategy provided
    if (recoveryStrategy) {
      await this.attemptRecovery(appError, recoveryStrategy);
    }

    return appError;
  }

  /**
   * Create structured error from raw error
   */
  private createAppError(
    error: Error | string,
    category: ErrorCategory,
    context?: Record<string, any>
  ): AppError {
    const errorMessage = typeof error === 'string' ? error : error.message;
    const originalError = typeof error === 'string' ? undefined : error;
    
    const severity = this.determineSeverity(category, errorMessage);
    const recoveryActions = this.determineRecoveryActions(category, severity);
    const userMessage = this.generateUserMessage(category, severity, errorMessage);

    return {
      id: this.generateErrorId(),
      message: errorMessage,
      category,
      severity,
      timestamp: Date.now(),
      context,
      originalError,
      recoveryActions,
      userMessage,
      technicalDetails: originalError?.stack
    };
  }

  /**
   * Determine error severity based on category and message
   */
  private determineSeverity(category: ErrorCategory, message: string): ErrorSeverity {
    // Critical errors that prevent core functionality
    if (category === ErrorCategory.DATABASE && message.includes('initialization')) {
      return ErrorSeverity.CRITICAL;
    }
    
    if (category === ErrorCategory.PERMISSION && message.includes('denied')) {
      return ErrorSeverity.HIGH;
    }

    // High severity errors
    if (category === ErrorCategory.LOCATION && message.includes('unavailable')) {
      return ErrorSeverity.HIGH;
    }

    if (category === ErrorCategory.SYSTEM) {
      return ErrorSeverity.HIGH;
    }

    // Medium severity errors
    if (category === ErrorCategory.NETWORK || category === ErrorCategory.API) {
      return ErrorSeverity.MEDIUM;
    }

    // Low severity errors
    return ErrorSeverity.LOW;
  }

  /**
   * Determine appropriate recovery actions
   */
  private determineRecoveryActions(category: ErrorCategory, severity: ErrorSeverity): RecoveryAction[] {
    const actions: RecoveryAction[] = [];

    switch (category) {
      case ErrorCategory.NETWORK:
      case ErrorCategory.API:
        actions.push(RecoveryAction.RETRY, RecoveryAction.CACHE, RecoveryAction.FALLBACK);
        break;
      
      case ErrorCategory.LOCATION:
        actions.push(RecoveryAction.RETRY, RecoveryAction.MANUAL);
        break;
      
      case ErrorCategory.DATABASE:
        if (severity === ErrorSeverity.CRITICAL) {
          actions.push(RecoveryAction.FALLBACK, RecoveryAction.MANUAL);
        } else {
          actions.push(RecoveryAction.RETRY, RecoveryAction.FALLBACK);
        }
        break;
      
      case ErrorCategory.PERMISSION:
        actions.push(RecoveryAction.MANUAL);
        break;
      
      case ErrorCategory.UI:
        actions.push(RecoveryAction.FALLBACK, RecoveryAction.RETRY);
        break;
      
      default:
        actions.push(RecoveryAction.RETRY);
    }

    return actions;
  }

  /**
   * Generate user-friendly error message
   */
  private generateUserMessage(category: ErrorCategory, severity: ErrorSeverity, message: string): string {
    switch (category) {
      case ErrorCategory.NETWORK:
        return 'Network connection issue. Please check your internet connection and try again.';
      
      case ErrorCategory.LOCATION:
        return 'Unable to access your location. Please ensure location services are enabled.';
      
      case ErrorCategory.API:
        return 'Service temporarily unavailable. Using cached data where possible.';
      
      case ErrorCategory.DATABASE:
        if (severity === ErrorSeverity.CRITICAL) {
          return 'Data storage issue detected. Please restart the app.';
        }
        return 'Data access issue. Some features may be limited.';
      
      case ErrorCategory.PERMISSION:
        return 'Permission required to access this feature. Please grant the necessary permissions.';
      
      case ErrorCategory.UI:
        return 'Display issue encountered. Refreshing the interface.';
      
      case ErrorCategory.VALIDATION:
        return 'Invalid data detected. Please check your input and try again.';
      
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /**
   * Attempt error recovery using provided strategy
   */
  private async attemptRecovery(
    error: AppError,
    strategy: Partial<ErrorRecoveryStrategy>
  ): Promise<boolean> {
    const fullStrategy = { ...this.config.defaultRetryStrategy, ...strategy };
    
    for (let attempt = 1; attempt <= fullStrategy.maxRetries; attempt++) {
      try {
        hilog.info(DOMAIN, TAG, `Recovery attempt ${attempt} for error ${error.id}`);
        
        // Wait before retry (with exponential backoff)
        if (attempt > 1) {
          const delay = fullStrategy.retryDelay * Math.pow(fullStrategy.backoffMultiplier, attempt - 2);
          await this.sleep(delay);
        }

        // Try fallback action if available
        if (fullStrategy.fallbackAction) {
          await fullStrategy.fallbackAction();
          hilog.info(DOMAIN, TAG, `Recovery successful for error ${error.id}`);
          return true;
        }

        // Try cache action if available
        if (fullStrategy.cacheAction) {
          await fullStrategy.cacheAction();
          hilog.info(DOMAIN, TAG, `Cache recovery successful for error ${error.id}`);
          return true;
        }

      } catch (recoveryError) {
        hilog.warn(DOMAIN, TAG, `Recovery attempt ${attempt} failed: ${recoveryError}`);
        
        if (attempt === fullStrategy.maxRetries) {
          hilog.error(DOMAIN, TAG, `All recovery attempts failed for error ${error.id}`);
          return false;
        }
      }
    }

    return false;
  }

  /**
   * Log error with appropriate level
   */
  private logError(error: AppError): void {
    const logMessage = `[${error.category}] ${error.message}`;
    const contextStr = error.context ? JSON.stringify(error.context) : '';
    
    switch (error.severity) {
      case ErrorSeverity.CRITICAL:
        hilog.fatal(DOMAIN, TAG, `${logMessage} Context: ${contextStr}`);
        break;
      case ErrorSeverity.HIGH:
        hilog.error(DOMAIN, TAG, `${logMessage} Context: ${contextStr}`);
        break;
      case ErrorSeverity.MEDIUM:
        hilog.warn(DOMAIN, TAG, `${logMessage} Context: ${contextStr}`);
        break;
      case ErrorSeverity.LOW:
        hilog.info(DOMAIN, TAG, `${logMessage} Context: ${contextStr}`);
        break;
    }

    // Log technical details if available
    if (error.technicalDetails) {
      hilog.debug(DOMAIN, TAG, `Technical details: ${error.technicalDetails}`);
    }
  }

  /**
   * Add error to history with size limit
   */
  private addToHistory(error: AppError): void {
    this.errorHistory.unshift(error);
    
    // Maintain history size limit
    if (this.errorHistory.length > this.config.maxErrorHistory) {
      this.errorHistory = this.errorHistory.slice(0, this.config.maxErrorHistory);
    }
  }

  /**
   * Notify error listeners
   */
  private notifyListeners(error: AppError): void {
    this.errorListeners.forEach(listener => {
      try {
        listener(error);
      } catch (listenerError) {
        hilog.error(DOMAIN, TAG, `Error listener failed: ${listenerError}`);
      }
    });
  }

  /**
   * Add error listener
   */
  public addErrorListener(listener: (error: AppError) => void): void {
    this.errorListeners.push(listener);
  }

  /**
   * Remove error listener
   */
  public removeErrorListener(listener: (error: AppError) => void): void {
    const index = this.errorListeners.indexOf(listener);
    if (index > -1) {
      this.errorListeners.splice(index, 1);
    }
  }

  /**
   * Get error history
   */
  public getErrorHistory(): AppError[] {
    return [...this.errorHistory];
  }

  /**
   * Get errors by category
   */
  public getErrorsByCategory(category: ErrorCategory): AppError[] {
    return this.errorHistory.filter(error => error.category === category);
  }

  /**
   * Get errors by severity
   */
  public getErrorsBySeverity(severity: ErrorSeverity): AppError[] {
    return this.errorHistory.filter(error => error.severity === severity);
  }

  /**
   * Clear error history
   */
  public clearErrorHistory(): void {
    this.errorHistory = [];
  }

  /**
   * Generate unique error ID
   */
  private generateErrorId(): string {
    return `err_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Sleep utility for retry delays
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Get error statistics
   */
  public getErrorStats(): {
    total: number;
    byCategory: Record<ErrorCategory, number>;
    bySeverity: Record<ErrorSeverity, number>;
    recentErrors: number;
  } {
    const now = Date.now();
    const oneHourAgo = now - (60 * 60 * 1000);
    
    const byCategory = {} as Record<ErrorCategory, number>;
    const bySeverity = {} as Record<ErrorSeverity, number>;
    let recentErrors = 0;

    // Initialize counters
    Object.values(ErrorCategory).forEach(category => {
      byCategory[category] = 0;
    });
    Object.values(ErrorSeverity).forEach(severity => {
      bySeverity[severity] = 0;
    });

    // Count errors
    this.errorHistory.forEach(error => {
      byCategory[error.category]++;
      bySeverity[error.severity]++;
      
      if (error.timestamp > oneHourAgo) {
        recentErrors++;
      }
    });

    return {
      total: this.errorHistory.length,
      byCategory,
      bySeverity,
      recentErrors
    };
  }
}

/**
 * Retry utility with exponential backoff
 */
export async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000,
  backoffMultiplier: number = 2
): Promise<T> {
  let lastError: Error;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;
      
      if (attempt === maxRetries) {
        break;
      }

      const delay = baseDelay * Math.pow(backoffMultiplier, attempt - 1);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError!;
}

/**
 * Timeout wrapper for operations
 */
export async function withTimeout<T>(
  operation: Promise<T>,
  timeoutMs: number,
  timeoutMessage: string = 'Operation timed out'
): Promise<T> {
  return Promise.race([
    operation,
    new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
    })
  ]);
}