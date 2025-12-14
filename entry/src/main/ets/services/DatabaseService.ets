import relationalStore from '@ohos.data.relationalStore';
import { ExerciseSession } from '../models/ExerciseSession';
import { LocationData } from '../models/LocationData';
import { EnvironmentScore } from '../models/EnvironmentScore';
import { WeatherData } from '../models/WeatherData';

/**
 * Interface for cached environment data
 */
export interface CachedEnvironmentData {
  latitude: number;
  longitude: number;
  weatherData: WeatherData;
  environmentScore: EnvironmentScore;
  cachedAt: number;
  expiresAt: number;
}

/**
 * Database service for managing local data storage using RelationalStore
 */
export class DatabaseService {
  private static instance: DatabaseService;
  private store: relationalStore.RdbStore | null = null;
  private readonly DATABASE_NAME = 'cityzen.db';
  private readonly DATABASE_VERSION = 1;

  private constructor() {}

  /**
   * Get singleton instance of DatabaseService
   */
  public static getInstance(): DatabaseService {
    if (!DatabaseService.instance) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  /**
   * Initialize the database and create tables
   */
  public async initializeDatabase(): Promise<void> {
    try {
      const config: relationalStore.StoreConfig = {
        name: this.DATABASE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };

      this.store = await relationalStore.getRdbStore(getContext(), config);
      await this.createTables();
    } catch (error) {
      console.error('Failed to initialize database:', error);
      throw new Error('Database initialization failed');
    }
  }

  /**
   * Create database tables
   */
  private async createTables(): Promise<void> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    // Create exercise_sessions table
    const createExerciseSessionsTable = `
      CREATE TABLE IF NOT EXISTS exercise_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        route_data TEXT NOT NULL,
        environment_data TEXT NOT NULL,
        average_score REAL NOT NULL,
        distance REAL NOT NULL,
        duration INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    `;

    // Create environment_cache table
    const createEnvironmentCacheTable = `
      CREATE TABLE IF NOT EXISTS environment_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        weather_data TEXT NOT NULL,
        environment_score TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    `;

    await this.store.executeSql(createExerciseSessionsTable);
    await this.store.executeSql(createEnvironmentCacheTable);
  }

  /**
   * Save an exercise session to the database
   */
  public async saveExerciseSession(session: ExerciseSession): Promise<number> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const valueBucket: relationalStore.ValuesBucket = {
      start_time: session.startTime,
      end_time: session.endTime,
      route_data: JSON.stringify(session.route),
      environment_data: JSON.stringify(session.environmentalConditions),
      average_score: session.averageEnvironmentScore,
      distance: session.distance,
      duration: session.duration,
      notes: session.notes || null
    };

    const rowId = await this.store.insert('exercise_sessions', valueBucket);
    return rowId;
  }

  /**
   * Get exercise history from the database
   */
  public async getExerciseHistory(limit?: number): Promise<ExerciseSession[]> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    let sql = 'SELECT * FROM exercise_sessions ORDER BY start_time DESC';
    if (limit) {
      sql += ` LIMIT ${limit}`;
    }

    const resultSet = await this.store.querySql(sql);
    const sessions: ExerciseSession[] = [];

    if (resultSet.goToFirstRow()) {
      do {
        const session: ExerciseSession = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          startTime: resultSet.getLong(resultSet.getColumnIndex('start_time')),
          endTime: resultSet.getLong(resultSet.getColumnIndex('end_time')),
          route: JSON.parse(resultSet.getString(resultSet.getColumnIndex('route_data'))),
          environmentalConditions: JSON.parse(resultSet.getString(resultSet.getColumnIndex('environment_data'))),
          averageEnvironmentScore: resultSet.getDouble(resultSet.getColumnIndex('average_score')),
          distance: resultSet.getDouble(resultSet.getColumnIndex('distance')),
          duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
          notes: resultSet.getString(resultSet.getColumnIndex('notes'))
        };
        sessions.push(session);
      } while (resultSet.goToNextRow());
    }

    resultSet.close();
    return sessions;
  }

  /**
   * Get a specific exercise session by ID
   */
  public async getExerciseSessionById(id: number): Promise<ExerciseSession | null> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const predicates = new relationalStore.RdbPredicates('exercise_sessions');
    predicates.equalTo('id', id);

    const resultSet = await this.store.query(predicates);
    
    if (resultSet.goToFirstRow()) {
      const session: ExerciseSession = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        startTime: resultSet.getLong(resultSet.getColumnIndex('start_time')),
        endTime: resultSet.getLong(resultSet.getColumnIndex('end_time')),
        route: JSON.parse(resultSet.getString(resultSet.getColumnIndex('route_data'))),
        environmentalConditions: JSON.parse(resultSet.getString(resultSet.getColumnIndex('environment_data'))),
        averageEnvironmentScore: resultSet.getDouble(resultSet.getColumnIndex('average_score')),
        distance: resultSet.getDouble(resultSet.getColumnIndex('distance')),
        duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
        notes: resultSet.getString(resultSet.getColumnIndex('notes'))
      };
      resultSet.close();
      return session;
    }

    resultSet.close();
    return null;
  }

  /**
   * Cache environment data for a location
   */
  public async cacheEnvironmentData(data: CachedEnvironmentData): Promise<void> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    // First, clean up expired cache entries
    await this.cleanExpiredCache();

    const valueBucket: relationalStore.ValuesBucket = {
      latitude: data.latitude,
      longitude: data.longitude,
      weather_data: JSON.stringify(data.weatherData),
      environment_score: JSON.stringify(data.environmentScore),
      cached_at: data.cachedAt,
      expires_at: data.expiresAt
    };

    await this.store.insert('environment_cache', valueBucket);
  }

  /**
   * Get cached environment data for a location
   */
  public async getCachedEnvironmentData(latitude: number, longitude: number, radiusKm: number = 1): Promise<CachedEnvironmentData | null> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const currentTime = Date.now();
    
    // Query for non-expired cache entries within the specified radius
    // Using a simple bounding box approximation for location proximity
    const latDelta = radiusKm / 111; // Approximate degrees per km for latitude
    const lonDelta = radiusKm / (111 * Math.cos(latitude * Math.PI / 180)); // Adjust for longitude

    const sql = `
      SELECT * FROM environment_cache 
      WHERE expires_at > ? 
      AND latitude BETWEEN ? AND ? 
      AND longitude BETWEEN ? AND ?
      ORDER BY cached_at DESC 
      LIMIT 1
    `;

    const resultSet = await this.store.querySql(sql, [
      currentTime,
      latitude - latDelta,
      latitude + latDelta,
      longitude - lonDelta,
      longitude + lonDelta
    ]);

    if (resultSet.goToFirstRow()) {
      const cachedData: CachedEnvironmentData = {
        latitude: resultSet.getDouble(resultSet.getColumnIndex('latitude')),
        longitude: resultSet.getDouble(resultSet.getColumnIndex('longitude')),
        weatherData: JSON.parse(resultSet.getString(resultSet.getColumnIndex('weather_data'))),
        environmentScore: JSON.parse(resultSet.getString(resultSet.getColumnIndex('environment_score'))),
        cachedAt: resultSet.getLong(resultSet.getColumnIndex('cached_at')),
        expiresAt: resultSet.getLong(resultSet.getColumnIndex('expires_at'))
      };
      resultSet.close();
      return cachedData;
    }

    resultSet.close();
    return null;
  }

  /**
   * Clean up expired cache entries
   */
  private async cleanExpiredCache(): Promise<void> {
    if (!this.store) {
      return;
    }

    const currentTime = Date.now();
    const predicates = new relationalStore.RdbPredicates('environment_cache');
    predicates.lessThan('expires_at', currentTime);

    await this.store.delete(predicates);
  }

  /**
   * Delete an exercise session
   */
  public async deleteExerciseSession(id: number): Promise<boolean> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const predicates = new relationalStore.RdbPredicates('exercise_sessions');
    predicates.equalTo('id', id);

    const deletedRows = await this.store.delete(predicates);
    return deletedRows > 0;
  }

  /**
   * Update an exercise session
   */
  public async updateExerciseSession(session: ExerciseSession): Promise<boolean> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const valueBucket: relationalStore.ValuesBucket = {
      start_time: session.startTime,
      end_time: session.endTime,
      route_data: JSON.stringify(session.route),
      environment_data: JSON.stringify(session.environmentalConditions),
      average_score: session.averageEnvironmentScore,
      distance: session.distance,
      duration: session.duration,
      notes: session.notes || null
    };

    const predicates = new relationalStore.RdbPredicates('exercise_sessions');
    predicates.equalTo('id', session.id);

    const updatedRows = await this.store.update(valueBucket, predicates);
    return updatedRows > 0;
  }

  /**
   * Get database statistics
   */
  public async getDatabaseStats(): Promise<{ exerciseCount: number; cacheCount: number }> {
    if (!this.store) {
      throw new Error('Database not initialized');
    }

    const exerciseCountResult = await this.store.querySql('SELECT COUNT(*) as count FROM exercise_sessions');
    const cacheCountResult = await this.store.querySql('SELECT COUNT(*) as count FROM environment_cache');

    let exerciseCount = 0;
    let cacheCount = 0;

    if (exerciseCountResult.goToFirstRow()) {
      exerciseCount = exerciseCountResult.getLong(0);
    }
    exerciseCountResult.close();

    if (cacheCountResult.goToFirstRow()) {
      cacheCount = cacheCountResult.getLong(0);
    }
    cacheCountResult.close();

    return { exerciseCount, cacheCount };
  }
}