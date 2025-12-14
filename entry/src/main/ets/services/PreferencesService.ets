import preferences from '@ohos.data.preferences';
import { UserPreferences, DEFAULT_USER_PREFERENCES, PreferencesValidator } from '../models/UserPreferences';
import hilog from '@ohos.hilog';

const TAG = 'PreferencesService';
const DOMAIN = 0xFF00;

/**
 * Service for managing user preferences persistence
 * Validates Requirements 5.5: Settings configuration and data sync options
 */
export class PreferencesService {
  private static instance: PreferencesService;
  private preferencesStore: preferences.Preferences | null = null;
  private readonly PREFERENCES_NAME = 'cityzen_preferences';
  private readonly PREFERENCES_KEY = 'user_preferences';
  private cachedPreferences: UserPreferences | null = null;

  private constructor() {}

  /**
   * Get singleton instance of PreferencesService
   */
  public static getInstance(): PreferencesService {
    if (!PreferencesService.instance) {
      PreferencesService.instance = new PreferencesService();
    }
    return PreferencesService.instance;
  }

  /**
   * Initialize the preferences store
   */
  public async initialize(): Promise<void> {
    try {
      this.preferencesStore = await preferences.getPreferences(getContext(), this.PREFERENCES_NAME);
      hilog.info(DOMAIN, TAG, 'Preferences store initialized successfully');
      
      // Load cached preferences
      await this.loadPreferences();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to initialize preferences store: ${error}`);
      throw new Error('Preferences initialization failed');
    }
  }

  /**
   * Get user preferences (from cache or storage)
   */
  public async getPreferences(): Promise<UserPreferences> {
    if (this.cachedPreferences) {
      return { ...this.cachedPreferences };
    }
    
    return await this.loadPreferences();
  }

  /**
   * Save user preferences to storage
   */
  public async savePreferences(preferences: UserPreferences): Promise<void> {
    if (!this.preferencesStore) {
      throw new Error('Preferences store not initialized');
    }

    // Validate preferences before saving
    const validationErrors = PreferencesValidator.validateUserPreferences(preferences);
    if (validationErrors.length > 0) {
      const errorMessage = `Invalid preferences: ${validationErrors.join(', ')}`;
      hilog.error(DOMAIN, TAG, errorMessage);
      throw new Error(errorMessage);
    }

    try {
      // Update timestamp
      preferences.lastUpdated = Date.now();
      
      // Save to storage
      await this.preferencesStore.put(this.PREFERENCES_KEY, JSON.stringify(preferences));
      await this.preferencesStore.flush();
      
      // Update cache
      this.cachedPreferences = { ...preferences };
      
      hilog.info(DOMAIN, TAG, 'Preferences saved successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to save preferences: ${error}`);
      throw new Error('Failed to save preferences');
    }
  }

  /**
   * Update specific preference section
   */
  public async updateNotificationPreferences(notificationPrefs: UserPreferences['notifications']): Promise<void> {
    const currentPrefs = await this.getPreferences();
    currentPrefs.notifications = notificationPrefs;
    await this.savePreferences(currentPrefs);
  }

  public async updateDataSyncPreferences(dataSyncPrefs: UserPreferences['dataSync']): Promise<void> {
    const currentPrefs = await this.getPreferences();
    currentPrefs.dataSync = dataSyncPrefs;
    await this.savePreferences(currentPrefs);
  }

  public async updatePrivacyPreferences(privacyPrefs: UserPreferences['privacy']): Promise<void> {
    const currentPrefs = await this.getPreferences();
    currentPrefs.privacy = privacyPrefs;
    await this.savePreferences(currentPrefs);
  }

  public async updateDisplayPreferences(displayPrefs: UserPreferences['display']): Promise<void> {
    const currentPrefs = await this.getPreferences();
    currentPrefs.display = displayPrefs;
    await this.savePreferences(currentPrefs);
  }

  /**
   * Reset preferences to default values
   */
  public async resetToDefaults(): Promise<void> {
    const defaultPrefs = { ...DEFAULT_USER_PREFERENCES };
    defaultPrefs.lastUpdated = Date.now();
    await this.savePreferences(defaultPrefs);
    hilog.info(DOMAIN, TAG, 'Preferences reset to defaults');
  }

  /**
   * Export preferences as JSON string
   */
  public async exportPreferences(): Promise<string> {
    const preferences = await this.getPreferences();
    return JSON.stringify(preferences, null, 2);
  }

  /**
   * Import preferences from JSON string
   */
  public async importPreferences(preferencesJson: string): Promise<void> {
    try {
      const importedPrefs = JSON.parse(preferencesJson) as UserPreferences;
      
      // Validate imported preferences
      const validationErrors = PreferencesValidator.validateUserPreferences(importedPrefs);
      if (validationErrors.length > 0) {
        throw new Error(`Invalid imported preferences: ${validationErrors.join(', ')}`);
      }
      
      await this.savePreferences(importedPrefs);
      hilog.info(DOMAIN, TAG, 'Preferences imported successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to import preferences: ${error}`);
      throw new Error('Failed to import preferences');
    }
  }

  /**
   * Check if preferences exist in storage
   */
  public async hasPreferences(): Promise<boolean> {
    if (!this.preferencesStore) {
      return false;
    }
    
    try {
      return await this.preferencesStore.has(this.PREFERENCES_KEY);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to check preferences existence: ${error}`);
      return false;
    }
  }

  /**
   * Get preferences version for migration purposes
   */
  public async getPreferencesVersion(): Promise<number> {
    const preferences = await this.getPreferences();
    return preferences.version;
  }

  /**
   * Migrate preferences to newer version if needed
   */
  public async migratePreferences(): Promise<void> {
    const currentVersion = await this.getPreferencesVersion();
    const latestVersion = DEFAULT_USER_PREFERENCES.version;
    
    if (currentVersion < latestVersion) {
      hilog.info(DOMAIN, TAG, `Migrating preferences from version ${currentVersion} to ${latestVersion}`);
      
      // For now, just merge with defaults to add any missing fields
      const currentPrefs = await this.getPreferences();
      const migratedPrefs = this.mergeWithDefaults(currentPrefs);
      migratedPrefs.version = latestVersion;
      
      await this.savePreferences(migratedPrefs);
      hilog.info(DOMAIN, TAG, 'Preferences migration completed');
    }
  }

  /**
   * Clear all preferences
   */
  public async clearPreferences(): Promise<void> {
    if (!this.preferencesStore) {
      throw new Error('Preferences store not initialized');
    }
    
    try {
      await this.preferencesStore.delete(this.PREFERENCES_KEY);
      await this.preferencesStore.flush();
      this.cachedPreferences = null;
      hilog.info(DOMAIN, TAG, 'Preferences cleared successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to clear preferences: ${error}`);
      throw new Error('Failed to clear preferences');
    }
  }

  /**
   * Load preferences from storage
   */
  private async loadPreferences(): Promise<UserPreferences> {
    if (!this.preferencesStore) {
      throw new Error('Preferences store not initialized');
    }

    try {
      const hasPrefs = await this.preferencesStore.has(this.PREFERENCES_KEY);
      
      if (!hasPrefs) {
        // First time use - return defaults and save them
        const defaultPrefs = { ...DEFAULT_USER_PREFERENCES };
        defaultPrefs.lastUpdated = Date.now();
        await this.savePreferences(defaultPrefs);
        return defaultPrefs;
      }

      const preferencesJson = await this.preferencesStore.get(this.PREFERENCES_KEY, '');
      if (!preferencesJson) {
        throw new Error('Empty preferences data');
      }

      const loadedPrefs = JSON.parse(preferencesJson as string) as UserPreferences;
      
      // Validate loaded preferences
      const validationErrors = PreferencesValidator.validateUserPreferences(loadedPrefs);
      if (validationErrors.length > 0) {
        hilog.warn(DOMAIN, TAG, `Loaded preferences have validation errors: ${validationErrors.join(', ')}`);
        // Merge with defaults to fix any issues
        const fixedPrefs = this.mergeWithDefaults(loadedPrefs);
        await this.savePreferences(fixedPrefs);
        this.cachedPreferences = fixedPrefs;
        return fixedPrefs;
      }

      this.cachedPreferences = loadedPrefs;
      return loadedPrefs;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to load preferences: ${error}`);
      // Return defaults on error
      const defaultPrefs = { ...DEFAULT_USER_PREFERENCES };
      defaultPrefs.lastUpdated = Date.now();
      return defaultPrefs;
    }
  }

  /**
   * Merge loaded preferences with defaults to handle missing fields
   */
  private mergeWithDefaults(loadedPrefs: Partial<UserPreferences>): UserPreferences {
    return {
      notifications: { ...DEFAULT_USER_PREFERENCES.notifications, ...loadedPrefs.notifications },
      dataSync: { ...DEFAULT_USER_PREFERENCES.dataSync, ...loadedPrefs.dataSync },
      privacy: { ...DEFAULT_USER_PREFERENCES.privacy, ...loadedPrefs.privacy },
      display: { ...DEFAULT_USER_PREFERENCES.display, ...loadedPrefs.display },
      version: loadedPrefs.version || DEFAULT_USER_PREFERENCES.version,
      lastUpdated: loadedPrefs.lastUpdated || Date.now()
    };
  }
}