/**
 * User preferences data model for CityZen application
 * Validates Requirements 5.5: Settings and configuration management
 */

export interface NotificationPreferences {
  enablePushNotifications: boolean;
  enableLocationAlerts: boolean;
  enableWeatherAlerts: boolean;
  enableExerciseReminders: boolean;
  quietHoursStart: string; // Format: "HH:MM"
  quietHoursEnd: string; // Format: "HH:MM"
}

export interface DataSyncPreferences {
  enableAutoSync: boolean;
  syncOnWifiOnly: boolean;
  syncFrequency: SyncFrequency;
  enableOfflineMode: boolean;
  maxCacheSize: number; // In MB
}

export enum SyncFrequency {
  REAL_TIME = 'real_time',
  EVERY_5_MINUTES = 'every_5_minutes',
  EVERY_15_MINUTES = 'every_15_minutes',
  EVERY_30_MINUTES = 'every_30_minutes',
  HOURLY = 'hourly',
  MANUAL = 'manual'
}

export interface PrivacyPreferences {
  shareLocationData: boolean;
  shareUsageAnalytics: boolean;
  enableCrashReporting: boolean;
  dataRetentionDays: number;
}

export interface DisplayPreferences {
  theme: AppTheme;
  language: string;
  temperatureUnit: TemperatureUnit;
  distanceUnit: DistanceUnit;
  mapStyle: MapStyle;
}

export enum AppTheme {
  LIGHT = 'light',
  DARK = 'dark',
  SYSTEM = 'system'
}

export enum TemperatureUnit {
  CELSIUS = 'celsius',
  FAHRENHEIT = 'fahrenheit'
}

export enum DistanceUnit {
  METRIC = 'metric',
  IMPERIAL = 'imperial'
}

export enum MapStyle {
  STANDARD = 'standard',
  SATELLITE = 'satellite',
  TERRAIN = 'terrain'
}

export interface UserPreferences {
  notifications: NotificationPreferences;
  dataSync: DataSyncPreferences;
  privacy: PrivacyPreferences;
  display: DisplayPreferences;
  version: number; // For migration purposes
  lastUpdated: number; // Timestamp
}

/**
 * Default user preferences
 */
export const DEFAULT_USER_PREFERENCES: UserPreferences = {
  notifications: {
    enablePushNotifications: true,
    enableLocationAlerts: true,
    enableWeatherAlerts: true,
    enableExerciseReminders: false,
    quietHoursStart: "22:00",
    quietHoursEnd: "07:00"
  },
  dataSync: {
    enableAutoSync: true,
    syncOnWifiOnly: false,
    syncFrequency: SyncFrequency.EVERY_15_MINUTES,
    enableOfflineMode: true,
    maxCacheSize: 100
  },
  privacy: {
    shareLocationData: false,
    shareUsageAnalytics: false,
    enableCrashReporting: true,
    dataRetentionDays: 90
  },
  display: {
    theme: AppTheme.SYSTEM,
    language: 'en',
    temperatureUnit: TemperatureUnit.CELSIUS,
    distanceUnit: DistanceUnit.METRIC,
    mapStyle: MapStyle.STANDARD
  },
  version: 1,
  lastUpdated: Date.now()
};

/**
 * Validation functions for user preferences
 */
export class PreferencesValidator {
  
  static validateNotificationPreferences(prefs: NotificationPreferences): string[] {
    const errors: string[] = [];
    
    if (!this.isValidTimeFormat(prefs.quietHoursStart)) {
      errors.push('Invalid quiet hours start time format. Expected HH:MM');
    }
    
    if (!this.isValidTimeFormat(prefs.quietHoursEnd)) {
      errors.push('Invalid quiet hours end time format. Expected HH:MM');
    }
    
    return errors;
  }
  
  static validateDataSyncPreferences(prefs: DataSyncPreferences): string[] {
    const errors: string[] = [];
    
    if (!Object.values(SyncFrequency).includes(prefs.syncFrequency)) {
      errors.push('Invalid sync frequency');
    }
    
    if (prefs.maxCacheSize < 10 || prefs.maxCacheSize > 1000) {
      errors.push('Cache size must be between 10 and 1000 MB');
    }
    
    return errors;
  }
  
  static validatePrivacyPreferences(prefs: PrivacyPreferences): string[] {
    const errors: string[] = [];
    
    if (prefs.dataRetentionDays < 1 || prefs.dataRetentionDays > 365) {
      errors.push('Data retention days must be between 1 and 365');
    }
    
    return errors;
  }
  
  static validateDisplayPreferences(prefs: DisplayPreferences): string[] {
    const errors: string[] = [];
    
    if (!Object.values(AppTheme).includes(prefs.theme)) {
      errors.push('Invalid theme selection');
    }
    
    if (!Object.values(TemperatureUnit).includes(prefs.temperatureUnit)) {
      errors.push('Invalid temperature unit');
    }
    
    if (!Object.values(DistanceUnit).includes(prefs.distanceUnit)) {
      errors.push('Invalid distance unit');
    }
    
    if (!Object.values(MapStyle).includes(prefs.mapStyle)) {
      errors.push('Invalid map style');
    }
    
    if (!prefs.language || prefs.language.length !== 2) {
      errors.push('Language must be a valid 2-character code');
    }
    
    return errors;
  }
  
  static validateUserPreferences(prefs: UserPreferences): string[] {
    const errors: string[] = [];
    
    errors.push(...this.validateNotificationPreferences(prefs.notifications));
    errors.push(...this.validateDataSyncPreferences(prefs.dataSync));
    errors.push(...this.validatePrivacyPreferences(prefs.privacy));
    errors.push(...this.validateDisplayPreferences(prefs.display));
    
    if (prefs.version < 1) {
      errors.push('Invalid preferences version');
    }
    
    if (prefs.lastUpdated <= 0) {
      errors.push('Invalid last updated timestamp');
    }
    
    return errors;
  }
  
  private static isValidTimeFormat(time: string): boolean {
    const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    return timeRegex.test(time);
  }
}