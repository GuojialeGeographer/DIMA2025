# CityZen Design Document

## Overview

CityZen is a GeoAI-powered urban well-being application built on the OpenHarmony/Oniro ecosystem using ArkTS. The application combines real-time environmental data with AI-driven recommendations to help users make informed decisions about outdoor exercise in urban environments.

The core innovation lies in shifting focus from exercise quantity metrics to environmental quality assessment, leveraging the team's GIS expertise to provide spatial intelligence for urban health optimization.

## Architecture

### High-Level Architecture

The application follows the **MVVM (Model-View-ViewModel)** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Dashboard  │  │  Smart Map  │  │   History   │         │
│  │   (Tab 1)   │  │   (Tab 2)   │  │   (Tab 3)   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Environment │  │    Map      │  │   History   │         │
│  │  ViewModel  │  │  ViewModel  │  │  ViewModel  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Location   │  │   Weather   │  │     AI      │         │
│  │   Service   │  │   Service   │  │   Service   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    Local    │  │   Remote    │  │    Cache    │         │
│  │  Database   │  │     API     │  │   Manager   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack Integration

- **ArkTS Framework**: Leveraging declarative UI with @Component decorators
- **OpenHarmony API 18**: Using Location Kit, Map Kit, and RelationalStore
- **Huawei Map Kit**: For map rendering and GeoJSON overlay visualization
- **RESTful APIs**: Weather data (OpenWeatherMap) and AI services (DeepSeek/OpenAI)
- **SQLite via RelationalStore**: Local data persistence and offline functionality

## Components and Interfaces

### Core Components

#### 1. MainAbility (Entry Point)
```typescript
interface MainAbilityConfig {
  launchType: LaunchType.SINGLETON;
  permissions: ['ohos.permission.LOCATION', 'ohos.permission.INTERNET'];
}
```

#### 2. TabsContainer (Navigation Framework)
```typescript
interface TabConfiguration {
  tabs: [
    { name: 'Dashboard', icon: 'dashboard.svg', component: DashboardPage },
    { name: 'SmartMap', icon: 'map.svg', component: SmartMapPage },
    { name: 'History', icon: 'history.svg', component: HistoryPage }
  ];
  slideMenu: SlideMenuComponent;
}
```

#### 3. Environmental Data Service
```typescript
interface EnvironmentalService {
  getCurrentLocation(): Promise<LocationData>;
  getWeatherData(coordinates: Coordinates): Promise<WeatherData>;
  calculateEnvironmentScore(weather: WeatherData, aqi: number): EnvironmentScore;
  getCachedData(coordinates: Coordinates): CachedEnvironmentData | null;
}
```

#### 4. AI Coach Service
```typescript
interface AICoachService {
  generateRecommendation(context: EnvironmentContext): Promise<AIRecommendation>;
  getFallbackRecommendation(environmentScore: number): LocalRecommendation;
  validateAPIResponse(response: any): boolean;
}
```

#### 5. GeoJSON Layer Manager
```typescript
interface GeoLayerManager {
  loadStaticLayers(): Promise<GeoJSONFeatureCollection>;
  renderEnvironmentalZones(map: MapComponent): void;
  handleZoneInteraction(feature: GeoJSONFeature): ZoneInfo;
}
```

### Service Interfaces

#### Location Service
```typescript
interface LocationService {
  requestPermission(): Promise<boolean>;
  getCurrentPosition(): Promise<LocationData>;
  watchPosition(callback: (location: LocationData) => void): number;
  clearWatch(watchId: number): void;
}
```

#### Database Service
```typescript
interface DatabaseService {
  initializeDatabase(): Promise<void>;
  saveExerciseSession(session: ExerciseSession): Promise<number>;
  getExerciseHistory(limit?: number): Promise<ExerciseSession[]>;
  cacheEnvironmentData(data: EnvironmentData): Promise<void>;
  getCachedEnvironmentData(coordinates: Coordinates): Promise<EnvironmentData | null>;
}
```

## Data Models

### Core Data Structures

#### LocationData
```typescript
interface LocationData {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
  altitude?: number;
}
```

#### WeatherData
```typescript
interface WeatherData {
  temperature: number;
  humidity: number;
  windSpeed: number;
  windDirection: number;
  uvIndex: number;
  airQualityIndex: number;
  visibility: number;
  timestamp: number;
}
```

#### EnvironmentScore
```typescript
interface EnvironmentScore {
  overall: number; // 0-100 scale
  airQuality: number;
  weatherConditions: number;
  uvRisk: number;
  noiseLevel?: number;
  greenSpaceProximity?: number;
  calculatedAt: number;
}
```

#### ExerciseSession
```typescript
interface ExerciseSession {
  id: number;
  startTime: number;
  endTime: number;
  route: LocationData[];
  environmentalConditions: EnvironmentScore[];
  averageEnvironmentScore: number;
  distance: number;
  duration: number;
  notes?: string;
}
```

#### GeoJSONFeature
```typescript
interface EnvironmentalZone extends GeoJSONFeature {
  properties: {
    zoneType: 'green' | 'red' | 'gray';
    name: string;
    description: string;
    environmentalFactors: {
      airQuality?: 'good' | 'moderate' | 'poor';
      noiseLevel?: 'low' | 'medium' | 'high';
      gpsSignal?: 'strong' | 'weak' | 'blocked';
    };
  };
}
```

### Database Schema

#### ExerciseSessions Table
```sql
CREATE TABLE exercise_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time INTEGER NOT NULL,
  end_time INTEGER NOT NULL,
  route_data TEXT NOT NULL, -- JSON array of LocationData
  environment_data TEXT NOT NULL, -- JSON array of EnvironmentScore
  average_score REAL NOT NULL,
  distance REAL NOT NULL,
  duration INTEGER NOT NULL,
  notes TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

#### EnvironmentCache Table
```sql
CREATE TABLE environment_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  weather_data TEXT NOT NULL, -- JSON WeatherData
  environment_score TEXT NOT NULL, -- JSON EnvironmentScore
  cached_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis and property reflection to eliminate redundancy, the following correctness properties have been identified:

**Property 1: Location-Environment Data Consistency**
*For any* valid GPS coordinates, fetching weather data and calculating Environment_Score should produce a valid score within acceptable ranges (0-100), and significant location changes should trigger data updates within 30 seconds
**Validates: Requirements 1.2, 1.5, 4.1**

**Property 2: AI Recommendation Generation**
*For any* valid environmental context (time, location, weather, Environment_Score), the AI_Coach should generate contextual exercise recommendations within 10 seconds, and hazardous conditions should always produce safety warnings
**Validates: Requirements 2.1, 2.4, 2.5**

**Property 3: UI Data Display Consistency**
*For any* valid data (Environment_Score, AI recommendations, GeoJSON zones, exercise history), the UI should display the information with appropriate visual feedback and formatting
**Validates: Requirements 1.3, 2.2, 3.2, 4.3**

**Property 4: Interactive Map Behavior**
*For any* user interaction with map zones, appropriate zone information should be displayed, and location changes should update position markers in real-time
**Validates: Requirements 3.3, 3.4**

**Property 5: Exercise Session Data Integrity**
*For any* exercise session (start to end), all GPS coordinates and environmental data should be recorded to RelationalStore, and session completion should save complete data including route, duration, and environmental conditions
**Validates: Requirements 4.1, 4.2**

**Property 6: Historical Data Visualization**
*For any* saved exercise session, selecting it should display detailed route visualization with environmental data overlay, and the history list should show sessions with environmental quality indicators
**Validates: Requirements 4.5, 4.3**

**Property 7: API Failure Resilience**
*For any* external API failure, the system should implement exponential backoff retry (max 3 attempts), provide appropriate fallback mechanisms, and maintain functionality using cached data
**Validates: Requirements 6.1, 6.2, 6.3**

**Property 8: Navigation State Management**
*For any* tab transition or navigation action, the application should maintain state consistency and provide smooth user experience
**Validates: Requirements 5.4**

**Property 9: Input Data Validation**
*For any* user input or external data, the system should validate and sanitize all inputs before processing or storage
**Validates: Requirements 7.4**

## Error Handling

### Error Categories and Strategies

#### Network-Related Errors
- **Connection Timeout**: Implement exponential backoff with jitter (1s, 2s, 4s intervals)
- **API Rate Limiting**: Queue requests and implement respectful retry logic
- **Invalid API Responses**: Validate response schemas and provide meaningful error messages

#### Location-Related Errors
- **Permission Denied**: Guide user to settings with clear instructions
- **GPS Signal Weak**: Suggest moving to open area, use last known location with timestamp
- **Location Unavailable**: Provide manual location input option

#### Data-Related Errors
- **Database Corruption**: Implement database repair and backup restoration
- **Cache Expiry**: Graceful degradation with stale data indicators
- **Storage Full**: Implement data cleanup policies and user notifications

#### UI-Related Errors
- **Map Loading Failures**: Provide retry mechanism and fallback to list view
- **Rendering Errors**: Implement error boundaries with graceful fallback UI
- **Performance Issues**: Implement lazy loading and data pagination

### Error Recovery Mechanisms

```typescript
interface ErrorRecoveryStrategy {
  retryPolicy: {
    maxAttempts: number;
    backoffStrategy: 'exponential' | 'linear' | 'fixed';
    baseDelay: number;
  };
  fallbackAction: () => Promise<void>;
  userNotification: {
    message: string;
    severity: 'info' | 'warning' | 'error';
    actionable: boolean;
  };
}
```

## Testing Strategy

### Dual Testing Approach

The CityZen application will implement both unit testing and property-based testing to ensure comprehensive coverage and correctness validation.

#### Unit Testing Strategy

Unit tests will focus on:
- **Component Integration**: Testing interactions between ViewModels and Services
- **API Response Handling**: Verifying correct parsing of weather and AI API responses
- **Database Operations**: Testing CRUD operations and data integrity
- **UI Component Behavior**: Testing specific user interactions and state changes
- **Error Scenarios**: Testing specific error conditions and recovery mechanisms

**Testing Framework**: ArkTS Unit Testing Framework (built into DevEco Studio)
**Coverage Target**: Minimum 80% code coverage for business logic components

#### Property-Based Testing Strategy

Property-based tests will verify universal properties across all valid inputs:
- **Data Consistency Properties**: Environment score calculations, location data processing
- **UI Consistency Properties**: Display formatting, visual feedback consistency
- **API Resilience Properties**: Retry mechanisms, fallback behavior
- **State Management Properties**: Navigation consistency, data persistence

**Testing Framework**: fast-check (JavaScript/TypeScript property testing library)
**Configuration**: Minimum 100 iterations per property test to ensure statistical confidence
**Property Test Annotations**: Each property-based test must include a comment with the format:
`**Feature: cityzen-app, Property {number}: {property_text}**`

#### Integration Testing

- **End-to-End User Flows**: Complete user journeys from app launch to exercise completion
- **External API Integration**: Testing with real API endpoints and mock failure scenarios
- **Cross-Component Communication**: Testing data flow between different application layers
- **Offline-Online Transitions**: Testing sync behavior and data consistency

#### Performance Testing

- **Map Rendering Performance**: Testing GeoJSON layer rendering with large datasets
- **Database Query Performance**: Testing query response times with large exercise history
- **Memory Usage**: Monitoring memory consumption during extended use
- **Battery Impact**: Testing location tracking and API call frequency impact

### Test Data Management

#### Static Test Data
- **GeoJSON Fixtures**: Predefined environmental zones for consistent testing
- **Weather Data Mocks**: Standardized weather responses for predictable testing
- **Exercise Session Samples**: Representative exercise data for history testing

#### Dynamic Test Data Generation
- **Location Generators**: Random but valid GPS coordinates within test boundaries
- **Weather Condition Generators**: Realistic weather parameter combinations
- **User Input Generators**: Valid and invalid user input scenarios

### Continuous Integration

- **Automated Test Execution**: All tests run on every commit
- **Performance Regression Detection**: Automated performance benchmarking
- **Code Quality Gates**: Minimum test coverage and code quality requirements
- **Device Compatibility Testing**: Testing across different OpenHarmony device configurations

## Implementation Guidelines

### Development Phases

#### Phase 1: Core Infrastructure (Week 1)
- Set up ArkTS project structure with MVVM architecture
- Implement basic navigation framework (TabsContainer, SlideMenu)
- Create database schema and basic CRUD operations
- Set up location services and permission handling

#### Phase 2: Environmental Data Integration (Week 2)
- Implement weather API integration with error handling
- Create environment score calculation algorithms
- Develop caching mechanisms for offline functionality
- Build dashboard UI with real-time data display

#### Phase 3: Map and AI Features (Week 3)
- Integrate Huawei Map Kit with GeoJSON overlay rendering
- Implement AI Coach service with fallback mechanisms
- Create exercise tracking and history functionality
- Develop comprehensive error handling and recovery

#### Phase 4: Testing and Optimization (Week 4)
- Implement comprehensive unit and property-based test suites
- Performance optimization and memory management
- User experience refinement and accessibility improvements
- Documentation and deployment preparation

### Code Quality Standards

- **TypeScript Strict Mode**: Enable all strict type checking options
- **ESLint Configuration**: Enforce consistent code style and best practices
- **Code Documentation**: JSDoc comments for all public interfaces and complex logic
- **Git Workflow**: Feature branches with pull request reviews
- **Dependency Management**: Minimize external dependencies, prefer OpenHarmony native APIs

### Security Considerations

- **API Key Management**: Secure storage of API keys using OpenHarmony secure storage
- **Data Encryption**: Encrypt sensitive user data in local database
- **Permission Management**: Request minimal necessary permissions with clear justification
- **Input Validation**: Comprehensive validation and sanitization of all user inputs
- **Network Security**: Use HTTPS for all external API communications