/**
 * Offline service for handling offline mode detection, data queuing, and synchronization
 */
import connection from '@ohos.net.connection';
import { DatabaseService } from './DatabaseService';
import { LocationData } from '../models/LocationData';
import { WeatherData } from '../models/WeatherData';
import { ExerciseSession } from '../models/ExerciseSession';
import { AIRecommendation } from '../models/AIRecommendation';

/**
 * Interface for queued operations that need to be synced when online
 */
export interface QueuedOperation {
  id: string;
  type: 'exercise_session' | 'ai_request' | 'weather_request';
  data: any;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
}

/**
 * Interface for offline mode configuration
 */
export interface OfflineConfig {
  maxQueueSize: number;
  syncRetryDelay: number;
  maxRetries: number;
  cacheExpirationHours: number;
}

/**
 * Default offline configuration
 */
const DEFAULT_OFFLINE_CONFIG: OfflineConfig = {
  maxQueueSize: 100,
  syncRetryDelay: 5000, // 5 seconds
  maxRetries: 3,
  cacheExpirationHours: 24
};

/**
 * Offline service class for managing offline functionality
 */
export class OfflineService {
  private static instance: OfflineService;
  private isOnline: boolean = true;
  private operationQueue: QueuedOperation[] = [];
  private syncInProgress: boolean = false;
  private networkCallback: connection.NetConnection | null = null;
  private onlineStatusListeners: ((isOnline: boolean) => void)[] = [];
  private databaseService: DatabaseService;
  private config: OfflineConfig;

  private constructor(databaseService: DatabaseService, config: OfflineConfig = DEFAULT_OFFLINE_CONFIG) {
    this.databaseService = databaseService;
    this.config = config;
    this.initializeNetworkMonitoring();
  }

  /**
   * Get singleton instance of OfflineService
   */
  public static getInstance(databaseService?: DatabaseService, config?: OfflineConfig): OfflineService {
    if (!OfflineService.instance) {
      if (!databaseService) {
        throw new Error('DatabaseService is required for first initialization');
      }
      OfflineService.instance = new OfflineService(databaseService, config);
    }
    return OfflineService.instance;
  }

  /**
   * Initialize network monitoring
   */
  private async initializeNetworkMonitoring(): Promise<void> {
    try {
      // Check initial network status
      const netHandle = await connection.getDefaultNet();
      const capabilities = await connection.getNetCapabilities(netHandle);
      this.isOnline = capabilities.hasCapability(connection.NetCap.NET_CAPABILITY_INTERNET);

      // Set up network status monitoring
      this.networkCallback = connection.createNetConnection();
      
      this.networkCallback.on('netAvailable', (netHandle) => {
        console.info('Network available:', netHandle);
        this.handleNetworkStatusChange(true);
      });

      this.networkCallback.on('netUnavailable', () => {
        console.info('Network unavailable');
        this.handleNetworkStatusChange(false);
      });

      this.networkCallback.on('netLost', (netHandle) => {
        console.info('Network lost:', netHandle);
        this.handleNetworkStatusChange(false);
      });

      // Register for network events
      await this.networkCallback.register();

      // Load queued operations from database
      await this.loadQueuedOperations();

    } catch (error) {
      console.error('Failed to initialize network monitoring:', error);
      // Assume offline if monitoring fails
      this.isOnline = false;
    }
  }

  /**
   * Handle network status changes
   */
  private handleNetworkStatusChange(isOnline: boolean): void {
    const wasOffline = !this.isOnline;
    this.isOnline = isOnline;

    // Notify listeners
    this.onlineStatusListeners.forEach(listener => {
      try {
        listener(isOnline);
      } catch (error) {
        console.error('Error in online status listener:', error);
      }
    });

    // Start sync when coming back online
    if (wasOffline && isOnline && this.operationQueue.length > 0) {
      this.startSynchronization();
    }
  }

  /**
   * Check if device is currently online
   */
  public isDeviceOnline(): boolean {
    return this.isOnline;
  }

  /**
   * Add listener for online status changes
   */
  public addOnlineStatusListener(listener: (isOnline: boolean) => void): void {
    this.onlineStatusListeners.push(listener);
  }

  /**
   * Remove listener for online status changes
   */
  public removeOnlineStatusListener(listener: (isOnline: boolean) => void): void {
    const index = this.onlineStatusListeners.indexOf(listener);
    if (index > -1) {
      this.onlineStatusListeners.splice(index, 1);
    }
  }

  /**
   * Queue an operation for later synchronization
   */
  public async queueOperation(operation: Omit<QueuedOperation, 'id' | 'timestamp' | 'retryCount'>): Promise<string> {
    const queuedOp: QueuedOperation = {
      id: this.generateOperationId(),
      timestamp: Date.now(),
      retryCount: 0,
      ...operation
    };

    // Add to memory queue
    this.operationQueue.push(queuedOp);

    // Persist to database
    await this.saveQueuedOperation(queuedOp);

    // Clean up old operations if queue is too large
    if (this.operationQueue.length > this.config.maxQueueSize) {
      await this.cleanupOldOperations();
    }

    // Try to sync immediately if online
    if (this.isOnline && !this.syncInProgress) {
      this.startSynchronization();
    }

    return queuedOp.id;
  }

  /**
   * Get queued operations count
   */
  public getQueuedOperationsCount(): number {
    return this.operationQueue.length;
  }

  /**
   * Get queued operations by type
   */
  public getQueuedOperationsByType(type: string): QueuedOperation[] {
    return this.operationQueue.filter(op => op.type === type);
  }

  /**
   * Start synchronization process
   */
  public async startSynchronization(): Promise<void> {
    if (this.syncInProgress || !this.isOnline || this.operationQueue.length === 0) {
      return;
    }

    this.syncInProgress = true;
    console.info(`Starting synchronization of ${this.operationQueue.length} operations`);

    try {
      // Process operations in batches
      const batchSize = 5;
      for (let i = 0; i < this.operationQueue.length; i += batchSize) {
        const batch = this.operationQueue.slice(i, i + batchSize);
        await this.processBatch(batch);
        
        // Check if still online
        if (!this.isOnline) {
          console.info('Device went offline during sync, stopping');
          break;
        }
      }

      // Remove successfully synced operations
      await this.cleanupSyncedOperations();

    } catch (error) {
      console.error('Synchronization failed:', error);
    } finally {
      this.syncInProgress = false;
    }
  }

  /**
   * Process a batch of operations
   */
  private async processBatch(operations: QueuedOperation[]): Promise<void> {
    const promises = operations.map(op => this.processOperation(op));
    await Promise.allSettled(promises);
  }

  /**
   * Process a single operation
   */
  private async processOperation(operation: QueuedOperation): Promise<void> {
    try {
      switch (operation.type) {
        case 'exercise_session':
          await this.syncExerciseSession(operation);
          break;
        case 'ai_request':
          await this.syncAIRequest(operation);
          break;
        case 'weather_request':
          await this.syncWeatherRequest(operation);
          break;
        default:
          console.warn(`Unknown operation type: ${operation.type}`);
      }

      // Mark as synced
      operation.retryCount = -1; // Special value to indicate success
      
    } catch (error) {
      console.error(`Failed to sync operation ${operation.id}:`, error);
      operation.retryCount++;
      
      if (operation.retryCount >= operation.maxRetries) {
        console.warn(`Operation ${operation.id} exceeded max retries, removing from queue`);
        operation.retryCount = -1; // Mark for removal
      }
    }
  }

  /**
   * Sync exercise session data
   */
  private async syncExerciseSession(operation: QueuedOperation): Promise<void> {
    // In a real implementation, this would upload to a cloud service
    console.info(`Syncing exercise session: ${operation.id}`);
    
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // For now, just log the sync (in real app, would call cloud API)
    console.info(`Exercise session ${operation.id} synced successfully`);
  }

  /**
   * Sync AI request data
   */
  private async syncAIRequest(operation: QueuedOperation): Promise<void> {
    console.info(`Syncing AI request: ${operation.id}`);
    
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    console.info(`AI request ${operation.id} synced successfully`);
  }

  /**
   * Sync weather request data
   */
  private async syncWeatherRequest(operation: QueuedOperation): Promise<void> {
    console.info(`Syncing weather request: ${operation.id}`);
    
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, 300));
    
    console.info(`Weather request ${operation.id} synced successfully`);
  }

  /**
   * Save queued operation to database
   */
  private async saveQueuedOperation(operation: QueuedOperation): Promise<void> {
    try {
      // Create sync_queue table if it doesn't exist
      await this.createSyncQueueTable();
      
      // Insert operation into database
      const store = await this.databaseService['store']; // Access private store
      if (store) {
        const valueBucket = {
          operation_id: operation.id,
          operation_type: operation.type,
          operation_data: JSON.stringify(operation.data),
          timestamp: operation.timestamp,
          retry_count: operation.retryCount,
          max_retries: operation.maxRetries
        };
        
        await store.insert('sync_queue', valueBucket);
      }
    } catch (error) {
      console.error('Failed to save queued operation:', error);
    }
  }

  /**
   * Load queued operations from database
   */
  private async loadQueuedOperations(): Promise<void> {
    try {
      await this.createSyncQueueTable();
      
      const store = await this.databaseService['store'];
      if (store) {
        const resultSet = await store.querySql('SELECT * FROM sync_queue ORDER BY timestamp ASC');
        
        this.operationQueue = [];
        if (resultSet.goToFirstRow()) {
          do {
            const operation: QueuedOperation = {
              id: resultSet.getString(resultSet.getColumnIndex('operation_id')),
              type: resultSet.getString(resultSet.getColumnIndex('operation_type')) as any,
              data: JSON.parse(resultSet.getString(resultSet.getColumnIndex('operation_data'))),
              timestamp: resultSet.getLong(resultSet.getColumnIndex('timestamp')),
              retryCount: resultSet.getLong(resultSet.getColumnIndex('retry_count')),
              maxRetries: resultSet.getLong(resultSet.getColumnIndex('max_retries'))
            };
            this.operationQueue.push(operation);
          } while (resultSet.goToNextRow());
        }
        
        resultSet.close();
        console.info(`Loaded ${this.operationQueue.length} queued operations from database`);
      }
    } catch (error) {
      console.error('Failed to load queued operations:', error);
    }
  }

  /**
   * Create sync queue table
   */
  private async createSyncQueueTable(): Promise<void> {
    try {
      const store = await this.databaseService['store'];
      if (store) {
        const createTableSql = `
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_id TEXT UNIQUE NOT NULL,
            operation_type TEXT NOT NULL,
            operation_data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            max_retries INTEGER DEFAULT 3,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        `;
        
        await store.executeSql(createTableSql);
      }
    } catch (error) {
      console.error('Failed to create sync queue table:', error);
    }
  }

  /**
   * Clean up successfully synced operations
   */
  private async cleanupSyncedOperations(): Promise<void> {
    try {
      // Remove operations marked as synced (retryCount = -1)
      const syncedOperations = this.operationQueue.filter(op => op.retryCount === -1);
      
      if (syncedOperations.length > 0) {
        const store = await this.databaseService['store'];
        if (store) {
          for (const op of syncedOperations) {
            await store.executeSql('DELETE FROM sync_queue WHERE operation_id = ?', [op.id]);
          }
        }
        
        // Remove from memory queue
        this.operationQueue = this.operationQueue.filter(op => op.retryCount !== -1);
        
        console.info(`Cleaned up ${syncedOperations.length} synced operations`);
      }
    } catch (error) {
      console.error('Failed to cleanup synced operations:', error);
    }
  }

  /**
   * Clean up old operations when queue is too large
   */
  private async cleanupOldOperations(): Promise<void> {
    try {
      const excessCount = this.operationQueue.length - this.config.maxQueueSize;
      if (excessCount > 0) {
        // Sort by timestamp and remove oldest
        this.operationQueue.sort((a, b) => a.timestamp - b.timestamp);
        const toRemove = this.operationQueue.splice(0, excessCount);
        
        // Remove from database
        const store = await this.databaseService['store'];
        if (store) {
          for (const op of toRemove) {
            await store.executeSql('DELETE FROM sync_queue WHERE operation_id = ?', [op.id]);
          }
        }
        
        console.info(`Cleaned up ${excessCount} old operations`);
      }
    } catch (error) {
      console.error('Failed to cleanup old operations:', error);
    }
  }

  /**
   * Generate unique operation ID
   */
  private generateOperationId(): string {
    return `op_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Get cache age in hours for given timestamp
   */
  public getCacheAgeHours(timestamp: number): number {
    return (Date.now() - timestamp) / (1000 * 60 * 60);
  }

  /**
   * Check if cached data is still valid
   */
  public isCacheValid(timestamp: number): boolean {
    return this.getCacheAgeHours(timestamp) < this.config.cacheExpirationHours;
  }

  /**
   * Get offline mode statistics
   */
  public getOfflineStats(): {
    isOnline: boolean;
    queuedOperations: number;
    syncInProgress: boolean;
    lastSyncAttempt: number | null;
  } {
    return {
      isOnline: this.isOnline,
      queuedOperations: this.operationQueue.length,
      syncInProgress: this.syncInProgress,
      lastSyncAttempt: this.operationQueue.length > 0 ? 
        Math.max(...this.operationQueue.map(op => op.timestamp)) : null
    };
  }

  /**
   * Force sync attempt (for manual retry)
   */
  public async forceSynchronization(): Promise<void> {
    if (this.isOnline) {
      await this.startSynchronization();
    } else {
      throw new Error('Device is offline, cannot sync');
    }
  }

  /**
   * Clear all queued operations (for testing or reset)
   */
  public async clearQueue(): Promise<void> {
    try {
      const store = await this.databaseService['store'];
      if (store) {
        await store.executeSql('DELETE FROM sync_queue');
      }
      
      this.operationQueue = [];
      console.info('Cleared all queued operations');
    } catch (error) {
      console.error('Failed to clear queue:', error);
    }
  }

  /**
   * Cleanup resources
   */
  public async cleanup(): Promise<void> {
    try {
      if (this.networkCallback) {
        await this.networkCallback.unregister();
        this.networkCallback = null;
      }
      
      this.onlineStatusListeners = [];
      console.info('OfflineService cleanup completed');
    } catch (error) {
      console.error('Error during OfflineService cleanup:', error);
    }
  }
}