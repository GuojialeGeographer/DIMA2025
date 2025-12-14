/**
 * Comprehensive logging system for debugging and monitoring
 */
import hilog from '@ohos.hilog';
import { ErrorHandler, ErrorCategory, ErrorSeverity } from './ErrorHandler';

const DOMAIN = 0xFF00;

/**
 * Log levels
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4
}

/**
 * Log entry structure
 */
export interface LogEntry {
  id: string;
  timestamp: number;
  level: LogLevel;
  tag: string;
  message: string;
  context?: Record<string, any>;
  stackTrace?: string;
  userId?: string;
  sessionId?: string;
}

/**
 * Logger configuration
 */
export interface LoggerConfig {
  enableConsoleLogging: boolean;
  enableFileLogging: boolean;
  enableRemoteLogging: boolean;
  minLogLevel: LogLevel;
  maxLogEntries: number;
  logRotationSize: number; // in bytes
  includeStackTrace: boolean;
  sensitiveDataKeys: string[]; // Keys to redact from logs
}

/**
 * Remote logging configuration
 */
export interface RemoteLoggingConfig {
  endpoint: string;
  apiKey: string;
  batchSize: number;
  flushInterval: number; // in milliseconds
  retryAttempts: number;
}

/**
 * Default logger configuration
 */
const DEFAULT_CONFIG: LoggerConfig = {
  enableConsoleLogging: true,
  enableFileLogging: false,
  enableRemoteLogging: false,
  minLogLevel: LogLevel.INFO,
  maxLogEntries: 1000,
  logRotationSize: 10 * 1024 * 1024, // 10MB
  includeStackTrace: true,
  sensitiveDataKeys: ['password', 'token', 'apiKey', 'secret', 'credential']
};

/**
 * Comprehensive logger class
 */
export class Logger {
  private static instance: Logger;
  private config: LoggerConfig;
  private logEntries: LogEntry[] = [];
  private sessionId: string;
  private userId?: string;
  private remoteConfig?: RemoteLoggingConfig;
  private remoteBatch: LogEntry[] = [];
  private flushTimer: number = -1;

  private constructor(config: LoggerConfig = DEFAULT_CONFIG) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.sessionId = this.generateSessionId();
  }

  /**
   * Get singleton instance
   */
  public static getInstance(config?: LoggerConfig): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger(config);
    }
    return Logger.instance;
  }

  /**
   * Set user ID for logging context
   */
  public setUserId(userId: string): void {
    this.userId = userId;
  }

  /**
   * Configure remote logging
   */
  public configureRemoteLogging(config: RemoteLoggingConfig): void {
    this.remoteConfig = config;
    this.config.enableRemoteLogging = true;
    
    // Start periodic flush timer
    if (this.flushTimer === -1) {
      this.flushTimer = setInterval(() => {
        this.flushRemoteLogs();
      }, config.flushInterval);
    }
  }

  /**
   * Log debug message
   */
  public debug(tag: string, message: string, context?: Record<string, any>): void {
    this.log(LogLevel.DEBUG, tag, message, context);
  }

  /**
   * Log info message
   */
  public info(tag: string, message: string, context?: Record<string, any>): void {
    this.log(LogLevel.INFO, tag, message, context);
  }

  /**
   * Log warning message
   */
  public warn(tag: string, message: string, context?: Record<string, any>): void {
    this.log(LogLevel.WARN, tag, message, context);
  }

  /**
   * Log error message
   */
  public error(tag: string, message: string, context?: Record<string, any>, error?: Error): void {
    const logContext = { ...context };
    
    if (error) {
      logContext.error = {
        name: error.name,
        message: error.message,
        stack: error.stack
      };
    }
    
    this.log(LogLevel.ERROR, tag, message, logContext, error?.stack);
  }

  /**
   * Log fatal error message
   */
  public fatal(tag: string, message: string, context?: Record<string, any>, error?: Error): void {
    const logContext = { ...context };
    
    if (error) {
      logContext.error = {
        name: error.name,
        message: error.message,
        stack: error.stack
      };
    }
    
    this.log(LogLevel.FATAL, tag, message, logContext, error?.stack);
  }

  /**
   * Log performance metrics
   */
  public performance(tag: string, operation: string, duration: number, context?: Record<string, any>): void {
    this.info(tag, `Performance: ${operation}`, {
      ...context,
      operation,
      duration,
      type: 'performance'
    });
  }

  /**
   * Log user action
   */
  public userAction(tag: string, action: string, context?: Record<string, any>): void {
    this.info(tag, `User Action: ${action}`, {
      ...context,
      action,
      type: 'user_action'
    });
  }

  /**
   * Log API call
   */
  public apiCall(
    tag: string, 
    method: string, 
    url: string, 
    statusCode?: number, 
    duration?: number,
    context?: Record<string, any>
  ): void {
    const level = statusCode && statusCode >= 400 ? LogLevel.ERROR : LogLevel.INFO;
    
    this.log(level, tag, `API Call: ${method} ${url}`, {
      ...context,
      method,
      url,
      statusCode,
      duration,
      type: 'api_call'
    });
  }

  /**
   * Core logging method
   */
  private log(
    level: LogLevel, 
    tag: string, 
    message: string, 
    context?: Record<string, any>,
    stackTrace?: string
  ): void {
    // Check if log level meets minimum threshold
    if (level < this.config.minLogLevel) {
      return;
    }

    // Create log entry
    const logEntry: LogEntry = {
      id: this.generateLogId(),
      timestamp: Date.now(),
      level,
      tag,
      message,
      context: context ? this.sanitizeContext(context) : undefined,
      stackTrace: this.config.includeStackTrace ? stackTrace : undefined,
      userId: this.userId,
      sessionId: this.sessionId
    };

    // Add to local log entries
    this.addToLogEntries(logEntry);

    // Console logging
    if (this.config.enableConsoleLogging) {
      this.logToConsole(logEntry);
    }

    // File logging (if enabled)
    if (this.config.enableFileLogging) {
      this.logToFile(logEntry);
    }

    // Remote logging (if enabled)
    if (this.config.enableRemoteLogging && this.remoteConfig) {
      this.addToRemoteBatch(logEntry);
    }
  }

  /**
   * Log to console using hilog
   */
  private logToConsole(entry: LogEntry): void {
    const contextStr = entry.context ? ` Context: ${JSON.stringify(entry.context)}` : '';
    const fullMessage = `[${entry.tag}] ${entry.message}${contextStr}`;

    switch (entry.level) {
      case LogLevel.DEBUG:
        hilog.debug(DOMAIN, entry.tag, fullMessage);
        break;
      case LogLevel.INFO:
        hilog.info(DOMAIN, entry.tag, fullMessage);
        break;
      case LogLevel.WARN:
        hilog.warn(DOMAIN, entry.tag, fullMessage);
        break;
      case LogLevel.ERROR:
        hilog.error(DOMAIN, entry.tag, fullMessage);
        break;
      case LogLevel.FATAL:
        hilog.fatal(DOMAIN, entry.tag, fullMessage);
        break;
    }

    // Log stack trace separately if available
    if (entry.stackTrace) {
      hilog.debug(DOMAIN, entry.tag, `Stack trace: ${entry.stackTrace}`);
    }
  }

  /**
   * Log to file (placeholder - would need file system implementation)
   */
  private logToFile(entry: LogEntry): void {
    // TODO: Implement file logging using OpenHarmony file system APIs
    // This would write logs to app's private storage
  }

  /**
   * Add log entry to remote batch
   */
  private addToRemoteBatch(entry: LogEntry): void {
    if (!this.remoteConfig) return;

    this.remoteBatch.push(entry);

    // Flush if batch is full
    if (this.remoteBatch.length >= this.remoteConfig.batchSize) {
      this.flushRemoteLogs();
    }
  }

  /**
   * Flush remote logs to server
   */
  private async flushRemoteLogs(): Promise<void> {
    if (!this.remoteConfig || this.remoteBatch.length === 0) {
      return;
    }

    const batch = [...this.remoteBatch];
    this.remoteBatch = [];

    try {
      const response = await fetch(this.remoteConfig.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.remoteConfig.apiKey}`
        },
        body: JSON.stringify({
          logs: batch,
          sessionId: this.sessionId,
          userId: this.userId,
          timestamp: Date.now()
        })
      });

      if (!response.ok) {
        throw new Error(`Remote logging failed: ${response.status}`);
      }

    } catch (error) {
      // Re-add failed logs to batch for retry
      this.remoteBatch.unshift(...batch);
      
      // Limit batch size to prevent memory issues
      if (this.remoteBatch.length > this.remoteConfig.batchSize * 3) {
        this.remoteBatch = this.remoteBatch.slice(0, this.remoteConfig.batchSize * 2);
      }

      hilog.error(DOMAIN, 'Logger', `Failed to flush remote logs: ${error}`);
    }
  }

  /**
   * Add log entry to local storage with size management
   */
  private addToLogEntries(entry: LogEntry): void {
    this.logEntries.unshift(entry);

    // Maintain maximum log entries
    if (this.logEntries.length > this.config.maxLogEntries) {
      this.logEntries = this.logEntries.slice(0, this.config.maxLogEntries);
    }
  }

  /**
   * Sanitize context to remove sensitive data
   */
  private sanitizeContext(context: Record<string, any>): Record<string, any> {
    const sanitized = { ...context };

    for (const key of this.config.sensitiveDataKeys) {
      if (key in sanitized) {
        sanitized[key] = '[REDACTED]';
      }
    }

    return sanitized;
  }

  /**
   * Get log entries with optional filtering
   */
  public getLogEntries(
    level?: LogLevel,
    tag?: string,
    limit?: number,
    since?: number
  ): LogEntry[] {
    let filtered = this.logEntries;

    if (level !== undefined) {
      filtered = filtered.filter(entry => entry.level >= level);
    }

    if (tag) {
      filtered = filtered.filter(entry => entry.tag === tag);
    }

    if (since) {
      filtered = filtered.filter(entry => entry.timestamp >= since);
    }

    if (limit) {
      filtered = filtered.slice(0, limit);
    }

    return filtered;
  }

  /**
   * Get log statistics
   */
  public getLogStats(): {
    total: number;
    byLevel: Record<LogLevel, number>;
    byTag: Record<string, number>;
    recentErrors: number;
    sessionDuration: number;
  } {
    const now = Date.now();
    const oneHourAgo = now - (60 * 60 * 1000);
    
    const byLevel = {} as Record<LogLevel, number>;
    const byTag = {} as Record<string, number>;
    let recentErrors = 0;

    // Initialize counters
    Object.values(LogLevel).forEach(level => {
      if (typeof level === 'number') {
        byLevel[level] = 0;
      }
    });

    // Count entries
    this.logEntries.forEach(entry => {
      byLevel[entry.level]++;
      byTag[entry.tag] = (byTag[entry.tag] || 0) + 1;
      
      if (entry.level >= LogLevel.ERROR && entry.timestamp > oneHourAgo) {
        recentErrors++;
      }
    });

    return {
      total: this.logEntries.length,
      byLevel,
      byTag,
      recentErrors,
      sessionDuration: now - this.getSessionStartTime()
    };
  }

  /**
   * Export logs for debugging
   */
  public exportLogs(format: 'json' | 'csv' = 'json'): string {
    if (format === 'json') {
      return JSON.stringify(this.logEntries, null, 2);
    } else {
      // CSV format
      const headers = ['timestamp', 'level', 'tag', 'message', 'context'];
      const rows = this.logEntries.map(entry => [
        new Date(entry.timestamp).toISOString(),
        LogLevel[entry.level],
        entry.tag,
        entry.message,
        entry.context ? JSON.stringify(entry.context) : ''
      ]);
      
      return [headers, ...rows].map(row => row.join(',')).join('\n');
    }
  }

  /**
   * Clear log entries
   */
  public clearLogs(): void {
    this.logEntries = [];
    this.remoteBatch = [];
  }

  /**
   * Generate unique log ID
   */
  private generateLogId(): string {
    return `log_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate unique session ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Get session start time
   */
  private getSessionStartTime(): number {
    // Extract timestamp from session ID
    const parts = this.sessionId.split('_');
    return parseInt(parts[1]) || Date.now();
  }

  /**
   * Cleanup resources
   */
  public cleanup(): void {
    if (this.flushTimer !== -1) {
      clearInterval(this.flushTimer);
      this.flushTimer = -1;
    }

    // Flush any remaining remote logs
    if (this.remoteBatch.length > 0) {
      this.flushRemoteLogs();
    }
  }
}

/**
 * Performance measurement utility
 */
export class PerformanceLogger {
  private static measurements: Map<string, number> = new Map();
  private static logger: Logger = Logger.getInstance();

  /**
   * Start performance measurement
   */
  public static start(operation: string): void {
    this.measurements.set(operation, Date.now());
  }

  /**
   * End performance measurement and log result
   */
  public static end(operation: string, tag: string = 'Performance', context?: Record<string, any>): number {
    const startTime = this.measurements.get(operation);
    if (!startTime) {
      this.logger.warn(tag, `Performance measurement not found for operation: ${operation}`);
      return 0;
    }

    const duration = Date.now() - startTime;
    this.measurements.delete(operation);

    this.logger.performance(tag, operation, duration, context);
    return duration;
  }

  /**
   * Measure async operation
   */
  public static async measure<T>(
    operation: string,
    asyncFn: () => Promise<T>,
    tag: string = 'Performance',
    context?: Record<string, any>
  ): Promise<T> {
    this.start(operation);
    try {
      const result = await asyncFn();
      this.end(operation, tag, context);
      return result;
    } catch (error) {
      this.end(operation, tag, { ...context, error: true });
      throw error;
    }
  }
}

/**
 * Create logger instance for a specific component
 */
export function createLogger(tag: string, config?: Partial<LoggerConfig>): {
  debug: (message: string, context?: Record<string, any>) => void;
  info: (message: string, context?: Record<string, any>) => void;
  warn: (message: string, context?: Record<string, any>) => void;
  error: (message: string, context?: Record<string, any>, error?: Error) => void;
  fatal: (message: string, context?: Record<string, any>, error?: Error) => void;
  performance: (operation: string, duration: number, context?: Record<string, any>) => void;
  userAction: (action: string, context?: Record<string, any>) => void;
  apiCall: (method: string, url: string, statusCode?: number, duration?: number, context?: Record<string, any>) => void;
} {
  const logger = Logger.getInstance(config);

  return {
    debug: (message: string, context?: Record<string, any>) => logger.debug(tag, message, context),
    info: (message: string, context?: Record<string, any>) => logger.info(tag, message, context),
    warn: (message: string, context?: Record<string, any>) => logger.warn(tag, message, context),
    error: (message: string, context?: Record<string, any>, error?: Error) => logger.error(tag, message, context, error),
    fatal: (message: string, context?: Record<string, any>, error?: Error) => logger.fatal(tag, message, context, error),
    performance: (operation: string, duration: number, context?: Record<string, any>) => logger.performance(tag, operation, duration, context),
    userAction: (action: string, context?: Record<string, any>) => logger.userAction(tag, action, context),
    apiCall: (method: string, url: string, statusCode?: number, duration?: number, context?: Record<string, any>) => logger.apiCall(tag, method, url, statusCode, duration, context)
  };
}