import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PreferencesService } from '../../../main/ets/services/PreferencesService';
import { 
  UserPreferences, 
  DEFAULT_USER_PREFERENCES, 
  PreferencesValidator,
  SyncFrequency,
  AppTheme,
  TemperatureUnit,
  DistanceUnit,
  MapStyle
} from '../../../main/ets/models/UserPreferences';

const TAG = 'SettingsFunctionalityTest';
const DOMAIN = 0xFF00;

/**
 * Unit tests for Settings functionality
 * Tests preference saving and loading, configuration validation, and settings UI interactions
 * Validates Requirements 5.5: Settings configuration and data sync options
 */
export default function settingsFunctionalityTest() {
  describe('SettingsFunctionalityTests', () => {
    let preferencesService: PreferencesService;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Settings functionality tests starting');
      preferencesService = PreferencesService.getInstance();
      
      try {
        await preferencesService.initialize();
        hilog.info(DOMAIN, TAG, '%{public}s', 'Preferences service initialized successfully');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to initialize preferences service: %{public}s', error.message);
      }
    });

    beforeEach(async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Starting individual test');
      // Clear preferences before each test
      try {
        await preferencesService.clearPreferences();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Failed to clear preferences: %{public}s', error.message);
      }
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Completed individual test');
    });

    /**
     * Test preference saving and loading
     * Validates Requirements 5.5: User preference persistence
     */
    it('should_save_and_load_preferences_successfully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing preference saving and loading');
      
      // Create test preferences
      const testPreferences: UserPreferences = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          enablePushNotifications: false,
          enableLocationAlerts: false,
          quietHoursStart: "23:00",
          quietHoursEnd: "06:00"
        },
        dataSync: {
          ...DEFAULT_USER_PREFERENCES.dataSync,
          enableAutoSync: false,
          syncFrequency: SyncFrequency.HOURLY,
          maxCacheSize: 200
        },
        display: {
          ...DEFAULT_USER_PREFERENCES.display,
          theme: AppTheme.DARK,
          temperatureUnit: TemperatureUnit.FAHRENHEIT,
          distanceUnit: DistanceUnit.IMPERIAL
        }
      };

      // Save preferences
      await preferencesService.savePreferences(testPreferences);

      // Load preferences
      const loadedPreferences = await preferencesService.getPreferences();

      // Verify preferences were saved and loaded correctly
      expect(loadedPreferences.notifications.enablePushNotifications).assertEqual(false);
      expect(loadedPreferences.notifications.enableLocationAlerts).assertEqual(false);
      expect(loadedPreferences.notifications.quietHoursStart).assertEqual("23:00");
      expect(loadedPreferences.notifications.quietHoursEnd).assertEqual("06:00");
      
      expect(loadedPreferences.dataSync.enableAutoSync).assertEqual(false);
      expect(loadedPreferences.dataSync.syncFrequency).assertEqual(SyncFrequency.HOURLY);
      expect(loadedPreferences.dataSync.maxCacheSize).assertEqual(200);
      
      expect(loadedPreferences.display.theme).assertEqual(AppTheme.DARK);
      expect(loadedPreferences.display.temperatureUnit).assertEqual(TemperatureUnit.FAHRENHEIT);
      expect(loadedPreferences.display.distanceUnit).assertEqual(DistanceUnit.IMPERIAL);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Preference saving and loading test passed');
    });

    /**
     * Test default preferences initialization
     * Validates Requirements 5.5: Default configuration values
     */
    it('should_initialize_with_default_preferences', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing default preferences initialization');
      
      // Get preferences (should return defaults on first use)
      const preferences = await preferencesService.getPreferences();

      // Verify default values
      expect(preferences.notifications.enablePushNotifications).assertEqual(true);
      expect(preferences.notifications.enableLocationAlerts).assertEqual(true);
      expect(preferences.notifications.enableWeatherAlerts).assertEqual(true);
      expect(preferences.notifications.enableExerciseReminders).assertEqual(false);
      expect(preferences.notifications.quietHoursStart).assertEqual("22:00");
      expect(preferences.notifications.quietHoursEnd).assertEqual("07:00");

      expect(preferences.dataSync.enableAutoSync).assertEqual(true);
      expect(preferences.dataSync.syncOnWifiOnly).assertEqual(false);
      expect(preferences.dataSync.syncFrequency).assertEqual(SyncFrequency.EVERY_15_MINUTES);
      expect(preferences.dataSync.enableOfflineMode).assertEqual(true);
      expect(preferences.dataSync.maxCacheSize).assertEqual(100);

      expect(preferences.privacy.shareLocationData).assertEqual(false);
      expect(preferences.privacy.shareUsageAnalytics).assertEqual(false);
      expect(preferences.privacy.enableCrashReporting).assertEqual(true);
      expect(preferences.privacy.dataRetentionDays).assertEqual(90);

      expect(preferences.display.theme).assertEqual(AppTheme.SYSTEM);
      expect(preferences.display.language).assertEqual('en');
      expect(preferences.display.temperatureUnit).assertEqual(TemperatureUnit.CELSIUS);
      expect(preferences.display.distanceUnit).assertEqual(DistanceUnit.METRIC);
      expect(preferences.display.mapStyle).assertEqual(MapStyle.STANDARD);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Default preferences initialization test passed');
    });

    /**
     * Test configuration validation
     * Validates Requirements 5.5: Input validation for settings
     */
    it('should_validate_preferences_correctly', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing preference validation');
      
      // Test valid preferences
      const validPreferences = { ...DEFAULT_USER_PREFERENCES };
      const validationErrors = PreferencesValidator.validateUserPreferences(validPreferences);
      expect(validationErrors.length).assertEqual(0);

      // Test invalid notification preferences
      const invalidNotificationPrefs = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          quietHoursStart: "25:00", // Invalid time
          quietHoursEnd: "invalid" // Invalid format
        }
      };
      const notificationErrors = PreferencesValidator.validateUserPreferences(invalidNotificationPrefs);
      expect(notificationErrors.length).assertLarger(0);

      // Test invalid data sync preferences
      const invalidDataSyncPrefs = {
        ...DEFAULT_USER_PREFERENCES,
        dataSync: {
          ...DEFAULT_USER_PREFERENCES.dataSync,
          maxCacheSize: 5000, // Too large
          syncFrequency: 'invalid' as SyncFrequency
        }
      };
      const dataSyncErrors = PreferencesValidator.validateUserPreferences(invalidDataSyncPrefs);
      expect(dataSyncErrors.length).assertLarger(0);

      // Test invalid privacy preferences
      const invalidPrivacyPrefs = {
        ...DEFAULT_USER_PREFERENCES,
        privacy: {
          ...DEFAULT_USER_PREFERENCES.privacy,
          dataRetentionDays: 500 // Too large
        }
      };
      const privacyErrors = PreferencesValidator.validateUserPreferences(invalidPrivacyPrefs);
      expect(privacyErrors.length).assertLarger(0);

      // Test invalid display preferences
      const invalidDisplayPrefs = {
        ...DEFAULT_USER_PREFERENCES,
        display: {
          ...DEFAULT_USER_PREFERENCES.display,
          language: "invalid_lang", // Invalid language code
          theme: 'invalid' as AppTheme
        }
      };
      const displayErrors = PreferencesValidator.validateUserPreferences(invalidDisplayPrefs);
      expect(displayErrors.length).assertLarger(0);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Preference validation test passed');
    });

    /**
     * Test individual preference section updates
     * Validates Requirements 5.5: Granular preference updates
     */
    it('should_update_individual_preference_sections', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing individual preference section updates');
      
      // Initialize with defaults
      await preferencesService.getPreferences();

      // Update notification preferences
      const newNotificationPrefs = {
        ...DEFAULT_USER_PREFERENCES.notifications,
        enablePushNotifications: false,
        quietHoursStart: "21:00"
      };
      await preferencesService.updateNotificationPreferences(newNotificationPrefs);

      // Update data sync preferences
      const newDataSyncPrefs = {
        ...DEFAULT_USER_PREFERENCES.dataSync,
        syncFrequency: SyncFrequency.MANUAL,
        maxCacheSize: 50
      };
      await preferencesService.updateDataSyncPreferences(newDataSyncPrefs);

      // Update privacy preferences
      const newPrivacyPrefs = {
        ...DEFAULT_USER_PREFERENCES.privacy,
        shareUsageAnalytics: true,
        dataRetentionDays: 30
      };
      await preferencesService.updatePrivacyPreferences(newPrivacyPrefs);

      // Update display preferences
      const newDisplayPrefs = {
        ...DEFAULT_USER_PREFERENCES.display,
        theme: AppTheme.LIGHT,
        temperatureUnit: TemperatureUnit.FAHRENHEIT
      };
      await preferencesService.updateDisplayPreferences(newDisplayPrefs);

      // Verify all updates
      const updatedPreferences = await preferencesService.getPreferences();
      
      expect(updatedPreferences.notifications.enablePushNotifications).assertEqual(false);
      expect(updatedPreferences.notifications.quietHoursStart).assertEqual("21:00");
      
      expect(updatedPreferences.dataSync.syncFrequency).assertEqual(SyncFrequency.MANUAL);
      expect(updatedPreferences.dataSync.maxCacheSize).assertEqual(50);
      
      expect(updatedPreferences.privacy.shareUsageAnalytics).assertEqual(true);
      expect(updatedPreferences.privacy.dataRetentionDays).assertEqual(30);
      
      expect(updatedPreferences.display.theme).assertEqual(AppTheme.LIGHT);
      expect(updatedPreferences.display.temperatureUnit).assertEqual(TemperatureUnit.FAHRENHEIT);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Individual preference section updates test passed');
    });

    /**
     * Test preferences export and import functionality
     * Validates Requirements 5.5: Settings backup and restore
     */
    it('should_export_and_import_preferences', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing preferences export and import');
      
      // Create custom preferences
      const customPreferences: UserPreferences = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          enablePushNotifications: false
        },
        dataSync: {
          ...DEFAULT_USER_PREFERENCES.dataSync,
          syncFrequency: SyncFrequency.HOURLY
        }
      };
      
      await preferencesService.savePreferences(customPreferences);

      // Export preferences
      const exportedJson = await preferencesService.exportPreferences();
      expect(exportedJson).assertInstanceOf('string');
      expect(exportedJson.length).assertLarger(0);

      // Clear preferences
      await preferencesService.clearPreferences();

      // Import preferences
      await preferencesService.importPreferences(exportedJson);

      // Verify imported preferences
      const importedPreferences = await preferencesService.getPreferences();
      expect(importedPreferences.notifications.enablePushNotifications).assertEqual(false);
      expect(importedPreferences.dataSync.syncFrequency).assertEqual(SyncFrequency.HOURLY);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Preferences export and import test passed');
    });

    /**
     * Test preferences reset functionality
     * Validates Requirements 5.5: Reset to default settings
     */
    it('should_reset_preferences_to_defaults', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing preferences reset to defaults');
      
      // Create custom preferences
      const customPreferences: UserPreferences = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          enablePushNotifications: false,
          enableLocationAlerts: false
        },
        display: {
          ...DEFAULT_USER_PREFERENCES.display,
          theme: AppTheme.DARK
        }
      };
      
      await preferencesService.savePreferences(customPreferences);

      // Verify custom preferences are saved
      let preferences = await preferencesService.getPreferences();
      expect(preferences.notifications.enablePushNotifications).assertEqual(false);
      expect(preferences.display.theme).assertEqual(AppTheme.DARK);

      // Reset to defaults
      await preferencesService.resetToDefaults();

      // Verify preferences are reset
      preferences = await preferencesService.getPreferences();
      expect(preferences.notifications.enablePushNotifications).assertEqual(true);
      expect(preferences.notifications.enableLocationAlerts).assertEqual(true);
      expect(preferences.display.theme).assertEqual(AppTheme.SYSTEM);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Preferences reset test passed');
    });

    /**
     * Test error handling for invalid operations
     * Validates Requirements 5.5: Robust error handling
     */
    it('should_handle_invalid_operations_gracefully', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing error handling for invalid operations');
      
      // Test saving invalid preferences
      const invalidPreferences = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          quietHoursStart: "invalid_time"
        }
      };

      try {
        await preferencesService.savePreferences(invalidPreferences);
        expect(false).assertTrue(); // Should not reach here
      } catch (error) {
        expect(error).assertInstanceOf('Error');
        hilog.info(DOMAIN, TAG, 'Correctly caught validation error: %{public}s', error.message);
      }

      // Test importing invalid JSON
      try {
        await preferencesService.importPreferences("invalid json");
        expect(false).assertTrue(); // Should not reach here
      } catch (error) {
        expect(error).assertInstanceOf('Error');
        hilog.info(DOMAIN, TAG, 'Correctly caught import error: %{public}s', error.message);
      }

      // Test importing preferences with invalid structure
      try {
        const invalidJson = JSON.stringify({ invalid: "structure" });
        await preferencesService.importPreferences(invalidJson);
        expect(false).assertTrue(); // Should not reach here
      } catch (error) {
        expect(error).assertInstanceOf('Error');
        hilog.info(DOMAIN, TAG, 'Correctly caught structure validation error: %{public}s', error.message);
      }

      hilog.info(DOMAIN, TAG, '%{public}s', 'Error handling test passed');
    });

    /**
     * Test preferences service singleton behavior
     * Validates Requirements 5.5: Consistent service instance
     */
    it('should_maintain_singleton_instance', 0, async () => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Testing singleton behavior');
      
      const service1 = PreferencesService.getInstance();
      const service2 = PreferencesService.getInstance();
      
      expect(service1).assertEqual(service2);
      
      // Test that both instances share the same state
      const testPrefs = {
        ...DEFAULT_USER_PREFERENCES,
        notifications: {
          ...DEFAULT_USER_PREFERENCES.notifications,
          enablePushNotifications: false
        }
      };
      
      await service1.savePreferences(testPrefs);
      const loadedPrefs = await service2.getPreferences();
      
      expect(loadedPrefs.notifications.enablePushNotifications).assertEqual(false);

      hilog.info(DOMAIN, TAG, '%{public}s', 'Singleton behavior test passed');
    });
  });
}