// Export all data models and their validation functions
export { LocationData, validateLocationData } from './LocationData';
export { WeatherData, validateWeatherData } from './WeatherData';
export { EnvironmentScore, validateEnvironmentScore } from './EnvironmentScore';
export { ExerciseSession, validateExerciseSession } from './ExerciseSession';
export { 
  AIRecommendation, 
  EnvironmentContext, 
  LocalRecommendation,
  validateAIRecommendation,
  validateEnvironmentContext,
  validateLocalRecommendation 
} from './AIRecommendation';
export {
  GeoJSONGeometry,
  GeoJSONProperties,
  GeoJSONFeature,
  GeoJSONFeatureCollection,
  ZoneInfo,
  STATIC_ENVIRONMENTAL_ZONES,
  validateGeoJSONFeature
} from './GeoJSONData';
export { 
  UserPreferences, 
  NotificationPreferences, 
  DataSyncPreferences, 
  PrivacyPreferences, 
  DisplayPreferences, 
  SyncFrequency, 
  AppTheme, 
  TemperatureUnit, 
  DistanceUnit, 
  MapStyle, 
  DEFAULT_USER_PREFERENCES, 
  PreferencesValidator 
} from './UserPreferences';