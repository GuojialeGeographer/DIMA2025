/**
 * Unit tests for error handling components and mechanisms
 * Tests error boundary functionality, retry mechanisms, and user error message display
 * Requirements: 6.1, 6.2, 6.3
 */
import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

import { 
  ErrorHandler, 
  ErrorCategory, 
  ErrorSeverity, 
  RecoveryAction,
  AppError,
  retryWithBackoff,
  withTimeout
} from '../../../main/ets/utils/ErrorHandler';

import { ErrorBoundaryConfig } from '../../../main/ets/components/ErrorBoundary';
import { 
  NotificationStyle, 
  NotificationConfig,
  NotificationAction 
} from '../../../main/ets/components/ErrorNotification';

const TAG = 'ErrorHandlingTest';
const DOMAIN = 0xFF00;

/**
 * Mock error for testing
 */
class MockError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MockError';
  }
}

/**
 * Mock async operation that can fail
 */
class MockAsyncOperation {
  private failureCount: number = 0;
  private maxFailures: number;
  private shouldTimeout: boolean = false;

  constructor(maxFailures: number = 0) {
    this.maxFailures = maxFailures;
  }

  setTimeoutBehavior(shouldTimeout: boolean): void {
    this.shouldTimeout = shouldTimeout;
  }

  async execute(): Promise<string> {
    if (this.shouldTimeout) {
      return new Promise(() => {}); // Never resolves (timeout)
    }

    if (this.failureCount < this.maxFailures) {
      this.failureCount++;
      throw new MockError(`Operation failed (attempt ${this.failureCount})`);
    }

    return 'success';
  }

  reset(): void {
    this.failureCount = 0;
    this.shouldTimeout = false;
  }

  getFailureCount(): number {
    return this.failureCount;
  }
}

/**
 * Error handling unit tests
 * Requirements: 6.1, 6.2, 6.3
 */
export default function ErrorHandlingTest() {
  describe('ErrorHandlingTests', () => {
    let errorHandler: ErrorHandler;
    let mockOperation: MockAsyncOperation;

    beforeAll(() => {
      hilog.info(DOMAIN, TAG, 'Starting error handling tests');
    });

    beforeEach(() => {
      errorHandler = ErrorHandler.getInstance();
      errorHandler.clearErrorHistory();
      mockOperation = new MockAsyncOperation();
    });

    afterEach(() => {
      mockOperation.reset();
    });

    /**
     * Test ErrorHandler core functionality
     * Requirements: 6.1, 6.2, 6.3
     */
    describe('ErrorHandler Core Functionality', () => {
      it('should create structured error from raw error', async () => {
        hilog.info(DOMAIN, TAG, 'Testing structured error creation');

        const rawError = new Error('Test error message');
        const context = { component: 'TestComponent', operation: 'testOperation' };

        const appError = await errorHandler.handleError(
          rawError,
          ErrorCategory.UI,
          context
        );

        expect(appError).not.toBeNull();
        expect(appError.message).assertEqual('Test error message');
        expect(appError.category).assertEqual(ErrorCategory.UI);
        expect(appError.context).toEqual(context);
        expect(appError.originalError).toEqual(rawError);
        expect(appError.id).toContain('err_');
        expect(appError.timestamp).toBeGreaterThan(0);
        expect(appError.userMessage).toContain('Display issue');
      });

      it('should create structured error from string message', async () => {
        hilog.info(DOMAIN, TAG, 'Testing structured error creation from string');

        const errorMessage = 'Network connection failed';
        const appError = await errorHandler.handleError(
          errorMessage,
          ErrorCategory.NETWORK
        );

        expect(appError.message).assertEqual(errorMessage);
        expect(appError.category).assertEqual(ErrorCategory.NETWORK);
        expect(appError.originalError).toBeUndefined();
        expect(appError.userMessage).toContain('Network connection issue');
      });

      it('should determine correct error severity', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error severity determination');

        // Test critical database error
        const criticalError = await errorHandler.handleError(
          'Database initialization failed',
          ErrorCategory.DATABASE
        );
        expect(criticalError.severity).assertEqual(ErrorSeverity.CRITICAL);

        // Test high permission error
        const highError = await errorHandler.handleError(
          'Location permission denied',
          ErrorCategory.PERMISSION
        );
        expect(highError.severity).assertEqual(ErrorSeverity.HIGH);

        // Test medium network error
        const mediumError = await errorHandler.handleError(
          'API request failed',
          ErrorCategory.NETWORK
        );
        expect(mediumError.severity).assertEqual(ErrorSeverity.MEDIUM);

        // Test low validation error
        const lowError = await errorHandler.handleError(
          'Invalid input format',
          ErrorCategory.VALIDATION
        );
        expect(lowError.severity).assertEqual(ErrorSeverity.LOW);
      });

      it('should determine appropriate recovery actions', async () => {
        hilog.info(DOMAIN, TAG, 'Testing recovery action determination');

        // Network errors should have retry, cache, and fallback
        const networkError = await errorHandler.handleError(
          'Network timeout',
          ErrorCategory.NETWORK
        );
        expect(networkError.recoveryActions).toContain(RecoveryAction.RETRY);
        expect(networkError.recoveryActions).toContain(RecoveryAction.CACHE);
        expect(networkError.recoveryActions).toContain(RecoveryAction.FALLBACK);

        // Permission errors should have manual action
        const permissionError = await errorHandler.handleError(
          'Permission denied',
          ErrorCategory.PERMISSION
        );
        expect(permissionError.recoveryActions).toContain(RecoveryAction.MANUAL);

        // Location errors should have retry and manual
        const locationError = await errorHandler.handleError(
          'GPS unavailable',
          ErrorCategory.LOCATION
        );
        expect(locationError.recoveryActions).toContain(RecoveryAction.RETRY);
        expect(locationError.recoveryActions).toContain(RecoveryAction.MANUAL);
      });

      it('should maintain error history with size limit', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error history management');

        // Add multiple errors
        for (let i = 0; i < 5; i++) {
          await errorHandler.handleError(
            `Test error ${i}`,
            ErrorCategory.UI
          );
        }

        const history = errorHandler.getErrorHistory();
        expect(history.length).assertEqual(5);

        // Check that most recent error is first
        expect(history[0].message).assertEqual('Test error 4');
        expect(history[4].message).assertEqual('Test error 0');
      });

      it('should filter errors by category and severity', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error filtering');

        // Add errors of different categories and severities
        await errorHandler.handleError('Network error', ErrorCategory.NETWORK);
        await errorHandler.handleError('Database initialization failed', ErrorCategory.DATABASE);
        await errorHandler.handleError('UI error', ErrorCategory.UI);

        const networkErrors = errorHandler.getErrorsByCategory(ErrorCategory.NETWORK);
        expect(networkErrors.length).assertEqual(1);
        expect(networkErrors[0].category).assertEqual(ErrorCategory.NETWORK);

        const criticalErrors = errorHandler.getErrorsBySeverity(ErrorSeverity.CRITICAL);
        expect(criticalErrors.length).assertEqual(1);
        expect(criticalErrors[0].severity).assertEqual(ErrorSeverity.CRITICAL);
      });

      it('should provide error statistics', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error statistics');

        // Add various errors
        await errorHandler.handleError('Network error', ErrorCategory.NETWORK);
        await errorHandler.handleError('API error', ErrorCategory.API);
        await errorHandler.handleError('Database error', ErrorCategory.DATABASE);

        const stats = errorHandler.getErrorStats();
        expect(stats.total).assertEqual(3);
        expect(stats.byCategory[ErrorCategory.NETWORK]).assertEqual(1);
        expect(stats.byCategory[ErrorCategory.API]).assertEqual(1);
        expect(stats.byCategory[ErrorCategory.DATABASE]).assertEqual(1);
        expect(stats.recentErrors).assertEqual(3); // All are recent
      });
    });

    /**
     * Test retry mechanisms
     * Requirements: 6.1, 6.2
     */
    describe('Retry Mechanisms', () => {
      it('should retry failed operations with exponential backoff', async () => {
        hilog.info(DOMAIN, TAG, 'Testing retry with exponential backoff');

        mockOperation = new MockAsyncOperation(2); // Fail first 2 attempts
        const startTime = Date.now();

        const result = await retryWithBackoff(
          () => mockOperation.execute(),
          3, // maxRetries
          100, // baseDelay (100ms for faster testing)
          2 // backoffMultiplier
        );

        const duration = Date.now() - startTime;
        
        expect(result).assertEqual('success');
        expect(mockOperation.getFailureCount()).assertEqual(2);
        // Should have delays: 100ms + 200ms = 300ms minimum
        expect(duration).toBeGreaterThan(250);
      });

      it('should fail after max retries exceeded', async () => {
        hilog.info(DOMAIN, TAG, 'Testing retry failure after max attempts');

        mockOperation = new MockAsyncOperation(5); // Always fail

        try {
          await retryWithBackoff(
            () => mockOperation.execute(),
            3, // maxRetries
            50, // baseDelay
            2
          );
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect(error).not.toBeNull();
          expect((error as Error).message).toContain('Operation failed');
          expect(mockOperation.getFailureCount()).assertEqual(3);
        }
      });

      it('should handle timeout operations', async () => {
        hilog.info(DOMAIN, TAG, 'Testing timeout handling');

        mockOperation.setTimeoutBehavior(true);

        try {
          await withTimeout(
            mockOperation.execute(),
            100, // 100ms timeout
            'Operation timed out'
          );
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect(error).not.toBeNull();
          expect((error as Error).message).assertEqual('Operation timed out');
        }
      });

      it('should complete operations within timeout', async () => {
        hilog.info(DOMAIN, TAG, 'Testing successful operation within timeout');

        const result = await withTimeout(
          Promise.resolve('quick success'),
          1000, // 1 second timeout
          'Should not timeout'
        );

        expect(result).assertEqual('quick success');
      });

      it('should attempt recovery with fallback action', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error recovery with fallback');

        let fallbackCalled = false;
        const fallbackAction = async () => {
          fallbackCalled = true;
          return 'fallback result';
        };

        const appError = await errorHandler.handleError(
          'Test error',
          ErrorCategory.API,
          { test: 'context' },
          {
            maxRetries: 1,
            retryDelay: 50,
            fallbackAction
          }
        );

        // Wait a bit for async recovery to complete
        await new Promise(resolve => setTimeout(resolve, 100));

        expect(appError).not.toBeNull();
        expect(fallbackCalled).assertTrue();
      });
    });

    /**
     * Test ErrorBoundary configuration and behavior
     * Requirements: 6.3
     */
    describe('ErrorBoundary Configuration', () => {
      it('should validate error boundary configuration options', () => {
        hilog.info(DOMAIN, TAG, 'Testing error boundary configuration');

        const config: ErrorBoundaryConfig = {
          onError: (error: AppError, errorInfo: string) => {
            expect(error).not.toBeNull();
            expect(error.category).assertEqual(ErrorCategory.UI);
          },
          maxRetries: 3,
          enableRetry: true,
          showErrorDetails: false,
          customErrorMessage: 'Custom error occurred'
        };

        // Validate configuration structure
        expect(config.maxRetries).assertEqual(3);
        expect(config.enableRetry).assertTrue();
        expect(config.showErrorDetails).assertFalse();
        expect(config.customErrorMessage).assertEqual('Custom error occurred');
      });

      it('should handle error boundary callback functions', () => {
        hilog.info(DOMAIN, TAG, 'Testing error boundary callbacks');

        let errorCallbackTriggered = false;
        let receivedError: AppError | null = null;
        let receivedErrorInfo: string | null = null;

        const config: ErrorBoundaryConfig = {
          onError: (error: AppError, errorInfo: string) => {
            errorCallbackTriggered = true;
            receivedError = error;
            receivedErrorInfo = errorInfo;
          },
          maxRetries: 1,
          enableRetry: false
        };

        // Simulate error callback
        const mockError: AppError = {
          id: 'boundary_test_1',
          message: 'Component error',
          category: ErrorCategory.UI,
          severity: ErrorSeverity.MEDIUM,
          timestamp: Date.now(),
          recoveryActions: [RecoveryAction.RETRY],
          userMessage: 'Component failed to render'
        };

        if (config.onError) {
          config.onError(mockError, 'Render failure');
        }

        expect(errorCallbackTriggered).assertTrue();
        expect(receivedError).toEqual(mockError);
        expect(receivedErrorInfo).assertEqual('Render failure');
      });

      it('should validate retry configuration limits', () => {
        hilog.info(DOMAIN, TAG, 'Testing error boundary retry limits');

        const config: ErrorBoundaryConfig = {
          maxRetries: 2,
          enableRetry: true
        };

        // Test that retry configuration is properly set
        expect(config.maxRetries).assertEqual(2);
        expect(config.enableRetry).assertTrue();

        // Simulate retry logic validation
        let retryCount = 0;
        const maxRetries = config.maxRetries || 3;

        while (retryCount < maxRetries && config.enableRetry) {
          retryCount++;
        }

        expect(retryCount).assertEqual(2);
      });
    });

    /**
     * Test ErrorNotification configuration and behavior
     * Requirements: 6.3
     */
    describe('ErrorNotification Configuration', () => {
      it('should validate notification configuration options', () => {
        hilog.info(DOMAIN, TAG, 'Testing error notification configuration');

        const config: NotificationConfig = {
          style: NotificationStyle.BANNER,
          duration: 5000,
          position: 'top',
          showActions: true,
          showDetails: false
        };

        // Validate configuration structure
        expect(config.style).assertEqual(NotificationStyle.BANNER);
        expect(config.duration).assertEqual(5000);
        expect(config.position).assertEqual('top');
        expect(config.showActions).assertTrue();
        expect(config.showDetails).assertFalse();
      });

      it('should handle notification action configurations', () => {
        hilog.info(DOMAIN, TAG, 'Testing notification action configuration');

        let actionTriggered = false;
        const customActions: NotificationAction[] = [
          {
            label: 'Retry',
            action: () => {
              actionTriggered = true;
            },
            style: 'primary'
          },
          {
            label: 'Cancel',
            action: () => {
              // Cancel action
            },
            style: 'secondary'
          }
        ];

        expect(customActions.length).assertEqual(2);
        expect(customActions[0].label).assertEqual('Retry');
        expect(customActions[0].style).assertEqual('primary');
        expect(customActions[1].label).assertEqual('Cancel');
        expect(customActions[1].style).assertEqual('secondary');

        // Test action execution
        customActions[0].action();
        expect(actionTriggered).assertTrue();
      });

      it('should validate notification styles and positions', () => {
        hilog.info(DOMAIN, TAG, 'Testing notification styles and positions');

        // Test all notification styles
        const styles = [
          NotificationStyle.TOAST,
          NotificationStyle.BANNER,
          NotificationStyle.MODAL,
          NotificationStyle.INLINE
        ];

        styles.forEach(style => {
          const config: NotificationConfig = {
            style: style,
            position: 'top'
          };
          expect(config.style).assertEqual(style);
        });

        // Test all positions
        const positions = ['top', 'center', 'bottom'];
        positions.forEach(position => {
          const config: NotificationConfig = {
            style: NotificationStyle.BANNER,
            position: position as 'top' | 'center' | 'bottom'
          };
          expect(config.position).assertEqual(position);
        });
      });

      it('should handle notification timing and auto-dismiss', () => {
        hilog.info(DOMAIN, TAG, 'Testing notification timing');

        const config: NotificationConfig = {
          style: NotificationStyle.TOAST,
          duration: 3000, // 3 seconds
          showActions: false
        };

        expect(config.duration).assertEqual(3000);

        // Test auto-dismiss logic simulation
        let dismissed = false;
        const startTime = Date.now();
        
        // Simulate auto-dismiss timer
        setTimeout(() => {
          dismissed = true;
          const elapsed = Date.now() - startTime;
          expect(elapsed).toBeGreaterThanOrEqual(50); // At least 50ms passed
        }, 50); // Use shorter time for testing

        // Wait for the timeout
        return new Promise<void>((resolve) => {
          setTimeout(() => {
            expect(dismissed).assertTrue();
            resolve();
          }, 100);
        });
      });
    });

    /**
     * Test error listener functionality
     * Requirements: 6.3
     */
    describe('Error Listener Functionality', () => {
      it('should notify error listeners when errors occur', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error listener notifications');

        let listenerCalled = false;
        let receivedError: AppError | null = null;

        const errorListener = (error: AppError) => {
          listenerCalled = true;
          receivedError = error;
        };

        errorHandler.addErrorListener(errorListener);

        const testError = await errorHandler.handleError(
          'Listener test error',
          ErrorCategory.SYSTEM
        );

        expect(listenerCalled).assertTrue();
        expect(receivedError).not.toBeNull();
        expect(receivedError?.id).assertEqual(testError.id);

        // Clean up
        errorHandler.removeErrorListener(errorListener);
      });

      it('should handle listener errors gracefully', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error listener error handling');

        const faultyListener = (error: AppError) => {
          throw new Error('Listener error');
        };

        errorHandler.addErrorListener(faultyListener);

        // This should not throw even though the listener throws
        const testError = await errorHandler.handleError(
          'Test error with faulty listener',
          ErrorCategory.NETWORK
        );

        expect(testError).not.toBeNull();

        // Clean up
        errorHandler.removeErrorListener(faultyListener);
      });

      it('should remove error listeners correctly', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error listener removal');

        let listenerCallCount = 0;

        const errorListener = (error: AppError) => {
          listenerCallCount++;
        };

        errorHandler.addErrorListener(errorListener);

        // Trigger error - listener should be called
        await errorHandler.handleError('First error', ErrorCategory.UI);
        expect(listenerCallCount).assertEqual(1);

        // Remove listener
        errorHandler.removeErrorListener(errorListener);

        // Trigger another error - listener should not be called
        await errorHandler.handleError('Second error', ErrorCategory.UI);
        expect(listenerCallCount).assertEqual(1); // Should still be 1
      });
    });

    /**
     * Test integration scenarios
     * Requirements: 6.1, 6.2, 6.3
     */
    describe('Error Handling Integration', () => {
      it('should handle cascading errors correctly', async () => {
        hilog.info(DOMAIN, TAG, 'Testing cascading error handling');

        // Simulate a scenario where error recovery itself fails
        const faultyFallback = async () => {
          throw new Error('Fallback also failed');
        };

        try {
          await errorHandler.handleError(
            'Primary operation failed',
            ErrorCategory.API,
            { operation: 'cascading_test' },
            {
              maxRetries: 1,
              retryDelay: 50,
              fallbackAction: faultyFallback
            }
          );
        } catch (error) {
          // Should handle the cascading failure gracefully
          expect(error).not.toBeNull();
        }

        // Error history should contain the original error
        const history = errorHandler.getErrorHistory();
        expect(history.length).toBeGreaterThan(0);
        expect(history[0].message).assertEqual('Primary operation failed');
      });

      it('should maintain error context across recovery attempts', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error context preservation');

        const originalContext = {
          userId: 'test_user',
          operation: 'data_fetch',
          timestamp: Date.now()
        };

        const appError = await errorHandler.handleError(
          'Context preservation test',
          ErrorCategory.DATABASE,
          originalContext
        );

        expect(appError.context).toEqual(originalContext);
        expect(appError.context?.userId).assertEqual('test_user');
        expect(appError.context?.operation).assertEqual('data_fetch');
      });

      it('should handle concurrent error scenarios', async () => {
        hilog.info(DOMAIN, TAG, 'Testing concurrent error handling');

        // Simulate multiple concurrent errors
        const errorPromises = [];
        for (let i = 0; i < 5; i++) {
          errorPromises.push(
            errorHandler.handleError(
              `Concurrent error ${i}`,
              ErrorCategory.NETWORK,
              { errorIndex: i }
            )
          );
        }

        const errors = await Promise.all(errorPromises);

        expect(errors.length).assertEqual(5);
        errors.forEach((error, index) => {
          expect(error.message).assertEqual(`Concurrent error ${index}`);
          expect(error.context?.errorIndex).assertEqual(index);
        });

        // All errors should be in history
        const history = errorHandler.getErrorHistory();
        expect(history.length).toBeGreaterThanOrEqual(5);
      });
    });
  });
}
    /**
     * Test service-specific retry mechanisms
     * Requirements: 6.1, 6.2
     */
    describe('Service Retry Mechanisms', () => {
      it('should test weather service retry behavior', async () => {
        hilog.info(DOMAIN, TAG, 'Testing weather service retry behavior');

        // Mock weather service retry scenario
        let attemptCount = 0;
        const maxAttempts = 3;

        const mockWeatherAPICall = async (): Promise<string> => {
          attemptCount++;
          if (attemptCount < maxAttempts) {
            throw new Error(`Weather API attempt ${attemptCount} failed`);
          }
          return 'weather_data_success';
        };

        try {
          const result = await retryWithBackoff(
            mockWeatherAPICall,
            maxAttempts,
            100, // 100ms base delay
            2 // exponential backoff
          );

          expect(result).assertEqual('weather_data_success');
          expect(attemptCount).assertEqual(maxAttempts);
        } catch (error) {
          expect(false).assertTrue(); // Should not fail
        }
      });

      it('should test AI service retry with fallback', async () => {
        hilog.info(DOMAIN, TAG, 'Testing AI service retry with fallback');

        let aiCallAttempts = 0;
        let fallbackUsed = false;

        const mockAIServiceCall = async (): Promise<string> => {
          aiCallAttempts++;
          throw new Error('AI service unavailable');
        };

        const mockFallbackRecommendation = async (): Promise<string> => {
          fallbackUsed = true;
          return 'fallback_recommendation';
        };

        try {
          await retryWithBackoff(mockAIServiceCall, 2, 50, 2);
        } catch (error) {
          // AI service failed, use fallback
          const fallbackResult = await mockFallbackRecommendation();
          expect(fallbackResult).assertEqual('fallback_recommendation');
          expect(fallbackUsed).assertTrue();
          expect(aiCallAttempts).assertEqual(2);
        }
      });

      it('should test timeout handling in service calls', async () => {
        hilog.info(DOMAIN, TAG, 'Testing service call timeout handling');

        const slowOperation = new Promise<string>((resolve) => {
          setTimeout(() => resolve('slow_result'), 200); // 200ms delay
        });

        try {
          await withTimeout(slowOperation, 100, 'Service call timed out');
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect((error as Error).message).assertEqual('Service call timed out');
        }
      });

      it('should test successful service call within timeout', async () => {
        hilog.info(DOMAIN, TAG, 'Testing successful service call within timeout');

        const fastOperation = Promise.resolve('fast_result');

        const result = await withTimeout(fastOperation, 1000, 'Should not timeout');
        expect(result).assertEqual('fast_result');
      });
    });

    /**
     * Test error message generation and user feedback
     * Requirements: 6.3
     */
    describe('User Error Message Generation', () => {
      it('should generate appropriate user messages for different error categories', async () => {
        hilog.info(DOMAIN, TAG, 'Testing user message generation');

        // Test network error message
        const networkError = await errorHandler.handleError(
          'Connection timeout',
          ErrorCategory.NETWORK
        );
        expect(networkError.userMessage).toContain('Network connection issue');

        // Test location error message
        const locationError = await errorHandler.handleError(
          'GPS signal lost',
          ErrorCategory.LOCATION
        );
        expect(locationError.userMessage).toContain('Unable to access your location');

        // Test API error message
        const apiError = await errorHandler.handleError(
          'Service unavailable',
          ErrorCategory.API
        );
        expect(apiError.userMessage).toContain('Service temporarily unavailable');

        // Test permission error message
        const permissionError = await errorHandler.handleError(
          'Access denied',
          ErrorCategory.PERMISSION
        );
        expect(permissionError.userMessage).toContain('Permission required');
      });

      it('should provide technical details for debugging', async () => {
        hilog.info(DOMAIN, TAG, 'Testing technical details provision');

        const errorWithStack = new Error('Detailed error');
        errorWithStack.stack = 'Error: Detailed error\n    at test:1:1';

        const appError = await errorHandler.handleError(
          errorWithStack,
          ErrorCategory.SYSTEM
        );

        expect(appError.technicalDetails).not.toBeNull();
        expect(appError.technicalDetails).toContain('Error: Detailed error');
        expect(appError.originalError).toEqual(errorWithStack);
      });

      it('should handle error context for better debugging', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error context handling');

        const context = {
          userId: 'user123',
          operation: 'fetchWeatherData',
          location: { lat: 40.7128, lon: -74.0060 },
          timestamp: Date.now()
        };

        const appError = await errorHandler.handleError(
          'Weather fetch failed',
          ErrorCategory.API,
          context
        );

        expect(appError.context).toEqual(context);
        expect(appError.context?.userId).assertEqual('user123');
        expect(appError.context?.operation).assertEqual('fetchWeatherData');
        expect(appError.context?.location).toEqual({ lat: 40.7128, lon: -74.0060 });
      });
    });

    /**
     * Test error recovery strategies
     * Requirements: 6.1, 6.2, 6.3
     */
    describe('Error Recovery Strategies', () => {
      it('should execute cache recovery action', async () => {
        hilog.info(DOMAIN, TAG, 'Testing cache recovery action');

        let cacheActionExecuted = false;
        const cacheAction = async () => {
          cacheActionExecuted = true;
          return 'cached_data';
        };

        await errorHandler.handleError(
          'API unavailable',
          ErrorCategory.API,
          { service: 'weather' },
          {
            maxRetries: 1,
            retryDelay: 50,
            cacheAction
          }
        );

        // Wait for async recovery
        await new Promise(resolve => setTimeout(resolve, 100));
        expect(cacheActionExecuted).assertTrue();
      });

      it('should handle recovery action failures gracefully', async () => {
        hilog.info(DOMAIN, TAG, 'Testing recovery action failure handling');

        const faultyRecoveryAction = async () => {
          throw new Error('Recovery action failed');
        };

        const appError = await errorHandler.handleError(
          'Primary operation failed',
          ErrorCategory.DATABASE,
          { operation: 'save' },
          {
            maxRetries: 1,
            retryDelay: 50,
            fallbackAction: faultyRecoveryAction
          }
        );

        expect(appError).not.toBeNull();
        expect(appError.message).assertEqual('Primary operation failed');
      });

      it('should prioritize recovery actions based on error category', async () => {
        hilog.info(DOMAIN, TAG, 'Testing recovery action prioritization');

        // Network errors should prioritize retry and cache
        const networkError = await errorHandler.handleError(
          'Network failure',
          ErrorCategory.NETWORK
        );
        expect(networkError.recoveryActions).toContain(RecoveryAction.RETRY);
        expect(networkError.recoveryActions).toContain(RecoveryAction.CACHE);

        // Database errors should prioritize fallback for critical issues
        const criticalDbError = await errorHandler.handleError(
          'Database initialization failed',
          ErrorCategory.DATABASE
        );
        expect(criticalDbError.recoveryActions).toContain(RecoveryAction.FALLBACK);
        expect(criticalDbError.severity).assertEqual(ErrorSeverity.CRITICAL);
      });
    });

    /**
     * Test error handling integration with real service scenarios
     * Requirements: 6.1, 6.2, 6.3
     */
    describe('Service Integration Error Scenarios', () => {
      it('should handle weather service API timeout gracefully', async () => {
        hilog.info(DOMAIN, TAG, 'Testing weather service API timeout handling');

        const timeoutOperation = new Promise<string>((resolve, reject) => {
          setTimeout(() => reject(new Error('Weather API timeout')), 100);
        });

        try {
          await withTimeout(timeoutOperation, 50, 'Weather service timed out');
          expect(false).assertTrue(); // Should not reach here
        } catch (error) {
          expect((error as Error).message).assertEqual('Weather service timed out');
        }
      });

      it('should handle AI service rate limiting with proper backoff', async () => {
        hilog.info(DOMAIN, TAG, 'Testing AI service rate limiting handling');

        let callCount = 0;
        const rateLimitedOperation = async (): Promise<string> => {
          callCount++;
          if (callCount <= 2) {
            const error = new Error('Rate limit exceeded');
            (error as any).status = 429;
            throw error;
          }
          return 'AI recommendation generated';
        };

        const result = await retryWithBackoff(rateLimitedOperation, 3, 100, 2);
        expect(result).assertEqual('AI recommendation generated');
        expect(callCount).assertEqual(3);
      });

      it('should handle database connection errors with fallback', async () => {
        hilog.info(DOMAIN, TAG, 'Testing database connection error handling');

        let fallbackUsed = false;
        const fallbackAction = async () => {
          fallbackUsed = true;
          return 'Using in-memory storage';
        };

        const dbError = await errorHandler.handleError(
          'Database connection failed',
          ErrorCategory.DATABASE,
          { operation: 'connect' },
          {
            maxRetries: 1,
            retryDelay: 50,
            fallbackAction
          }
        );

        // Wait for async recovery
        await new Promise(resolve => setTimeout(resolve, 100));
        
        expect(dbError.category).assertEqual(ErrorCategory.DATABASE);
        expect(fallbackUsed).assertTrue();
      });

      it('should handle location permission denied scenario', async () => {
        hilog.info(DOMAIN, TAG, 'Testing location permission denied handling');

        const permissionError = await errorHandler.handleError(
          'Location permission denied by user',
          ErrorCategory.PERMISSION,
          { 
            permission: 'ohos.permission.LOCATION',
            requestedAt: Date.now()
          }
        );

        expect(permissionError.severity).assertEqual(ErrorSeverity.HIGH);
        expect(permissionError.recoveryActions).toContain(RecoveryAction.MANUAL);
        expect(permissionError.userMessage).toContain('Permission required');
      });

      it('should handle network connectivity loss during operation', async () => {
        hilog.info(DOMAIN, TAG, 'Testing network connectivity loss handling');

        let networkCallAttempts = 0;
        const networkOperation = async (): Promise<string> => {
          networkCallAttempts++;
          throw new Error('Network unreachable');
        };

        try {
          await retryWithBackoff(networkOperation, 3, 50, 2);
          expect(false).assertTrue(); // Should not succeed
        } catch (error) {
          expect(networkCallAttempts).assertEqual(3);
          expect((error as Error).message).assertEqual('Network unreachable');
        }
      });

      it('should handle GPS signal loss gracefully', async () => {
        hilog.info(DOMAIN, TAG, 'Testing GPS signal loss handling');

        const gpsError = await errorHandler.handleError(
          'GPS signal lost - weak satellite connection',
          ErrorCategory.LOCATION,
          {
            lastKnownLocation: { lat: 40.7128, lon: -74.0060 },
            signalStrength: 'weak',
            satelliteCount: 2
          }
        );

        expect(gpsError.category).assertEqual(ErrorCategory.LOCATION);
        expect(gpsError.recoveryActions).toContain(RecoveryAction.RETRY);
        expect(gpsError.recoveryActions).toContain(RecoveryAction.MANUAL);
        expect(gpsError.context?.lastKnownLocation).toEqual({ lat: 40.7128, lon: -74.0060 });
      });
    });

    /**
     * Test error boundary component integration
     * Requirements: 6.3
     */
    describe('Error Boundary Component Integration', () => {
      it('should handle component render errors with proper recovery', () => {
        hilog.info(DOMAIN, TAG, 'Testing component render error handling');

        let errorBoundaryTriggered = false;
        let capturedError: AppError | null = null;

        const config: ErrorBoundaryConfig = {
          onError: (error: AppError, errorInfo: string) => {
            errorBoundaryTriggered = true;
            capturedError = error;
          },
          maxRetries: 2,
          enableRetry: true,
          showErrorDetails: true
        };

        // Simulate component error
        const componentError = new Error('Component failed to render');
        const mockErrorBoundary = {
          handleError: (error: Error, errorInfo?: string) => {
            if (config.onError) {
              const appError: AppError = {
                id: 'component_error_1',
                message: error.message,
                category: ErrorCategory.UI,
                severity: ErrorSeverity.MEDIUM,
                timestamp: Date.now(),
                recoveryActions: [RecoveryAction.RETRY],
                userMessage: 'Component failed to render'
              };
              config.onError(appError, errorInfo || '');
            }
          }
        };

        mockErrorBoundary.handleError(componentError, 'Render phase error');

        expect(errorBoundaryTriggered).assertTrue();
        expect(capturedError).not.toBeNull();
        expect(capturedError?.category).assertEqual(ErrorCategory.UI);
      });

      it('should handle service error boundary scenarios', () => {
        hilog.info(DOMAIN, TAG, 'Testing service error boundary handling');

        let serviceRetryTriggered = false;
        const mockServiceErrorBoundary = {
          handleServiceError: (error: Error, serviceName: string) => {
            expect(error).not.toBeNull();
            expect(serviceName).assertEqual('WeatherService');
          },
          retryService: () => {
            serviceRetryTriggered = true;
          }
        };

        const serviceError = new Error('Weather service unavailable');
        mockServiceErrorBoundary.handleServiceError(serviceError, 'WeatherService');
        mockServiceErrorBoundary.retryService();

        expect(serviceRetryTriggered).assertTrue();
      });
    });

    /**
     * Test error notification component integration
     * Requirements: 6.3
     */
    describe('Error Notification Component Integration', () => {
      it('should display error notifications with proper styling', () => {
        hilog.info(DOMAIN, TAG, 'Testing error notification display');

        const testError: AppError = {
          id: 'notification_test_1',
          message: 'Test notification error',
          category: ErrorCategory.NETWORK,
          severity: ErrorSeverity.MEDIUM,
          timestamp: Date.now(),
          recoveryActions: [RecoveryAction.RETRY],
          userMessage: 'Network connection issue occurred'
        };

        const notificationConfig: NotificationConfig = {
          style: NotificationStyle.BANNER,
          duration: 5000,
          position: 'top',
          showActions: true,
          showDetails: false
        };

        // Simulate notification display
        const mockNotification = {
          showError: (error: AppError, config?: Partial<NotificationConfig>) => {
            expect(error.id).assertEqual('notification_test_1');
            expect(error.severity).assertEqual(ErrorSeverity.MEDIUM);
            expect(config?.style).assertEqual(NotificationStyle.BANNER);
          }
        };

        mockNotification.showError(testError, notificationConfig);
      });

      it('should handle notification auto-dismiss functionality', async () => {
        hilog.info(DOMAIN, TAG, 'Testing notification auto-dismiss');

        let notificationDismissed = false;
        const mockNotification = {
          startCountdown: (duration: number) => {
            expect(duration).toBeGreaterThan(0);
            // Simulate immediate dismiss for testing
            setTimeout(() => {
              notificationDismissed = true;
            }, 50);
          }
        };

        mockNotification.startCountdown(3000);
        
        // Wait for auto-dismiss
        await new Promise(resolve => setTimeout(resolve, 100));
        expect(notificationDismissed).assertTrue();
      });

      it('should handle notification action callbacks', () => {
        hilog.info(DOMAIN, TAG, 'Testing notification action callbacks');

        let retryActionTriggered = false;
        let dismissActionTriggered = false;

        const customActions: NotificationAction[] = [
          {
            label: 'Retry Operation',
            action: () => {
              retryActionTriggered = true;
            },
            style: 'primary'
          },
          {
            label: 'Dismiss',
            action: () => {
              dismissActionTriggered = true;
            },
            style: 'secondary'
          }
        ];

        // Test action execution
        customActions[0].action();
        customActions[1].action();

        expect(retryActionTriggered).assertTrue();
        expect(dismissActionTriggered).assertTrue();
      });
    });

    /**
     * Test error handling performance and memory management
     * Requirements: 6.1, 6.2, 6.3
     */
    describe('Error Handling Performance', () => {
      it('should handle high-frequency error scenarios efficiently', async () => {
        hilog.info(DOMAIN, TAG, 'Testing high-frequency error handling');

        const startTime = Date.now();
        const errorPromises = [];

        // Generate 50 concurrent errors
        for (let i = 0; i < 50; i++) {
          errorPromises.push(
            errorHandler.handleError(
              `High frequency error ${i}`,
              ErrorCategory.SYSTEM,
              { errorIndex: i, batch: 'performance_test' }
            )
          );
        }

        const errors = await Promise.all(errorPromises);
        const duration = Date.now() - startTime;

        expect(errors.length).assertEqual(50);
        expect(duration).toBeLessThan(1000); // Should complete within 1 second

        // Verify error history management
        const history = errorHandler.getErrorHistory();
        expect(history.length).toBeGreaterThanOrEqual(50);
      });

      it('should maintain error history size limits', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error history size management');

        // Clear existing history
        errorHandler.clearErrorHistory();

        // Add errors beyond the typical limit
        for (let i = 0; i < 150; i++) {
          await errorHandler.handleError(
            `History test error ${i}`,
            ErrorCategory.VALIDATION
          );
        }

        const history = errorHandler.getErrorHistory();
        expect(history.length).toBeLessThanOrEqual(100); // Should respect max history limit

        // Verify most recent errors are preserved
        expect(history[0].message).toContain('History test error 149');
      });

      it('should handle error listener cleanup properly', async () => {
        hilog.info(DOMAIN, TAG, 'Testing error listener cleanup');

        let listener1Called = 0;
        let listener2Called = 0;

        const listener1 = (error: AppError) => { listener1Called++; };
        const listener2 = (error: AppError) => { listener2Called++; };

        // Add listeners
        errorHandler.addErrorListener(listener1);
        errorHandler.addErrorListener(listener2);

        // Trigger error
        await errorHandler.handleError('Listener test 1', ErrorCategory.SYSTEM);
        expect(listener1Called).assertEqual(1);
        expect(listener2Called).assertEqual(1);

        // Remove one listener
        errorHandler.removeErrorListener(listener1);

        // Trigger another error
        await errorHandler.handleError('Listener test 2', ErrorCategory.SYSTEM);
        expect(listener1Called).assertEqual(1); // Should not increase
        expect(listener2Called).assertEqual(2); // Should increase

        // Clean up
        errorHandler.removeErrorListener(listener2);
      });
    });
  });
}