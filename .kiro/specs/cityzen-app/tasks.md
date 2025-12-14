# CityZen Implementation Plan

## Overview

This implementation plan converts the CityZen design into actionable coding tasks for ArkTS development on OpenHarmony. Each task builds incrementally on previous work, focusing on core functionality first with optional testing tasks marked for flexibility.

## Task List

- [x] 1. Project Setup and Core Architecture
  - Initialize ArkTS project in DevEco Studio with OpenHarmony API 18 target
  - Configure project permissions (location, internet) in module.json5
  - Set up basic MVVM folder structure: models/, viewmodels/, views/, services/
  - Create main entry point (MainAbility) with proper lifecycle management
  - _Requirements: 7.1, 7.5_

- [x] 1.1 Set up testing framework and basic project structure tests
  - Configure ArkTS unit testing framework
  - Create basic smoke tests for app initialization
  - _Requirements: 7.2_

- [x] 2. Database Layer and Data Models
  - Create RelationalStore database initialization with exercise_sessions and environment_cache tables
  - Implement core data models: LocationData, WeatherData, EnvironmentScore, ExerciseSession interfaces
  - Build DatabaseService with CRUD operations for exercise sessions and environment caching
  - Add data validation functions for all input models
  - _Requirements: 4.1, 4.2, 7.4_

- [x] 2.1 Write property test for data model validation
  - **Property 9: Input Data Validation**
  - **Validates: Requirements 7.4**

- [x] 2.2 Write unit tests for database operations
  - Test database initialization and schema creation
  - Test CRUD operations for exercise sessions
  - Test environment data caching functionality
  - _Requirements: 4.1, 4.2_

- [x] 3. Location and Permission Services
  - Implement LocationService using OpenHarmony Location Kit
  - Create permission request handling with user-friendly prompts
  - Add GPS coordinate validation and accuracy checking
  - Implement location change detection with configurable thresholds
  - _Requirements: 1.1, 1.5, 6.4_

- [x] 3.1 Write property test for location data consistency
  - **Property 1: Location-Environment Data Consistency (Location part)**
  - **Validates: Requirements 1.2, 1.5**

- [x] 3.2 Write unit tests for location service
  - Test permission request handling
  - Test GPS coordinate validation
  - Test location change detection
  - _Requirements: 1.1, 1.5_

- [x] 4. Weather API Integration and Environment Scoring
  - Create WeatherService for OpenWeatherMap API integration
  - Implement environment score calculation algorithm (air quality + weather factors)
  - Add API response validation and error handling with exponential backoff retry
  - Create caching mechanism for weather data with expiration logic
  - _Requirements: 1.2, 6.1, 6.2_

- [x] 4.1 Write property test for environment score calculation
  - **Property 1: Location-Environment Data Consistency (Environment part)**
  - **Validates: Requirements 1.2**

- [x] 4.2 Write property test for API failure resilience
  - **Property 7: API Failure Resilience**
  - **Validates: Requirements 6.1, 6.2, 6.3**

- [x] 4.3 Write unit tests for weather service
  - Test API response parsing
  - Test environment score calculation with various inputs
  - Test caching mechanism and expiration
  - _Requirements: 1.2, 6.1, 6.2_

- [x] 5. AI Coach Service Integration
  - Implement AICoachService with cloud LLM API integration (DeepSeek/OpenAI)
  - Create context prompt generation from environmental data
  - Add rule-based fallback recommendation system for API failures
  - Implement recommendation caching and response validation
  - _Requirements: 2.1, 2.3, 2.4, 2.5_

- [x] 5.1 Write property test for AI recommendation generation
  - **Property 2: AI Recommendation Generation**
  - **Validates: Requirements 2.1, 2.4, 2.5**

- [x] 5.2 Write unit tests for AI coach service
  - Test prompt generation from environmental context
  - Test fallback recommendation logic
  - Test response validation and caching
  - _Requirements: 2.1, 2.3, 2.4_

- [x] 6. Navigation Framework and Main UI Structure
  - Create TabsContainer component with bottom navigation (Dashboard, SmartMap, History)
  - Implement SlideMenuComponent with settings and app information
  - Add navigation state management and tab switching logic
  - Create basic page components for each tab with placeholder content
  - _Requirements: 5.1, 5.2, 5.4_

- [x] 6.1 Write property test for navigation state management
  - **Property 8: Navigation State Management**
  - **Validates: Requirements 5.4**

- [x] 6.2 Write unit tests for navigation components
  - Test tab switching functionality
  - Test slide menu interaction
  - Test state preservation during navigation
  - _Requirements: 5.1, 5.2, 5.4_

- [x] 7. Dashboard Page Implementation
  - Create DashboardPage component with environment score display
  - Implement real-time location and weather data fetching
  - Add AI recommendation display with loading states
  - Create color-coded visual feedback for environment scores
  - Add offline mode indicators and cached data display
  - _Requirements: 1.3, 2.2, 1.4_

- [x] 7.1 Write property test for UI data display consistency
  - **Property 3: UI Data Display Consistency (Dashboard part)**
  - **Validates: Requirements 1.3, 2.2**

- [x] 7.2 Write unit tests for dashboard functionality
  - Test environment score display formatting
  - Test AI recommendation rendering
  - Test offline mode indicators
  - _Requirements: 1.3, 2.2, 1.4_

- [x] 8. Checkpoint - Core Services Integration Test
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Map Integration and GeoJSON Visualization
  - Integrate Huawei Map Kit into SmartMapPage component
  - Create GeoLayerManager for loading and rendering environmental zones
  - Implement static GeoJSON data for green/red/gray zones
  - Add zone interaction handling with popup information display
  - Implement real-time user location marker updates
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 9.1 Write property test for interactive map behavior
  - **Property 4: Interactive Map Behavior**
  - **Validates: Requirements 3.3, 3.4**

- [x] 9.2 Write unit tests for map functionality
  - Test GeoJSON layer loading and rendering
  - Test zone interaction and popup display
  - Test location marker updates
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 10. Exercise Tracking Implementation
  - Create exercise session start/stop functionality with GPS tracking
  - Implement real-time route recording with location and environment data
  - Add exercise session completion with data persistence to database
  - Create exercise session data validation and integrity checks
  - _Requirements: 4.1, 4.2_

- [x] 10.1 Write property test for exercise session data integrity
  - **Property 5: Exercise Session Data Integrity**
  - **Validates: Requirements 4.1, 4.2**

- [x] 10.2 Write unit tests for exercise tracking
  - Test session start/stop functionality
  - Test GPS route recording
  - Test session data persistence
  - _Requirements: 4.1, 4.2_

- [x] 11. History Page and Data Visualization
  - Create HistoryPage component with exercise session list display
  - Implement detailed session view with route visualization
  - Add environmental data overlay on historical routes
  - Create session filtering and sorting functionality
  - _Requirements: 4.3, 4.5_

- [x] 11.1 Write property test for historical data visualization
  - **Property 6: Historical Data Visualization**
  - **Validates: Requirements 4.3, 4.5**

- [x] 11.2 Write unit tests for history functionality
  - Test session list display and formatting
  - Test detailed session view rendering
  - Test environmental data overlay
  - _Requirements: 4.3, 4.5_

- [x] 12. Offline Mode and Data Synchronization
  - Implement offline detection and mode switching
  - Create data queuing system for offline operations
  - Add sync functionality for when connectivity returns
  - Implement offline indicators throughout the UI
  - _Requirements: 1.4, 4.4, 5.3, 6.5_

- [x] 12.1 Write unit tests for offline functionality
  - Test offline mode detection and switching
  - Test data queuing and synchronization
  - Test offline UI indicators
  - _Requirements: 1.4, 4.4, 5.3_

- [x] 13. Error Handling and Recovery Implementation
  - Implement comprehensive error boundaries for all major components
  - Add user-friendly error messages and recovery suggestions
  - Create retry mechanisms for failed operations
  - Add logging system for debugging and monitoring
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 13.1 Write unit tests for error handling
  - Test error boundary functionality
  - Test retry mechanisms
  - Test user error message display
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 14. Settings and Configuration
  - Implement settings page with notification preferences
  - Add data sync configuration options
  - Create about page with app information and privacy policy
  - Add user preference persistence and validation
  - _Requirements: 5.5_

- [x] 14.1 Write unit tests for settings functionality
  - Test preference saving and loading
  - Test configuration validation
  - Test settings UI interactions
  - _Requirements: 5.5_

- [x] 15. Performance Optimization and Polish
  - Optimize map rendering performance for large GeoJSON datasets
  - Implement lazy loading for exercise history
  - Add loading states and progress indicators throughout the app
  - Optimize battery usage for location tracking
  - _Requirements: Performance aspects of all requirements_

- [x] 15.1 Write performance tests
  - Test map rendering performance with large datasets
  - Test memory usage during extended operation
  - Test battery impact of location tracking
  - _Requirements: Performance aspects_

- [x] 16. Final Integration and System Testing
  - Perform end-to-end testing of complete user workflows
  - Test cross-component data flow and state management
  - Verify all correctness properties are satisfied
  - Test on OpenHarmony emulator and real devices if available
  - _Requirements: All requirements integration_

- [x] 16.1 Write integration tests
  - Test complete user workflows from start to finish
  - Test cross-component communication
  - Test data consistency across app lifecycle
  - _Requirements: All requirements_

- [x] 17. Final Checkpoint - Complete System Validation
  - Ensure all tests pass, ask the user if questions arise.

## Implementation Notes

### Development Environment Setup
- Use DevEco Studio with OpenHarmony API 18 SDK
- Configure ArkTS strict mode for better type safety
- Set up ESLint for code quality enforcement
- Use Git for version control with feature branch workflow

### Testing Configuration
- Property-based tests should run minimum 100 iterations
- Unit test coverage target: 80% for business logic
- All property tests must include requirement validation comments
- Integration tests should cover complete user workflows

### API Integration Guidelines
- Use environment variables for API keys (stored securely)
- Implement proper rate limiting respect for external APIs
- Always provide fallback mechanisms for API failures
- Cache API responses appropriately to reduce calls

### Performance Considerations
- Implement efficient GeoJSON rendering for map layers
- Use pagination for large exercise history datasets
- Optimize location tracking frequency based on user activity
- Implement proper memory management for long-running sessions

### Security Requirements
- Validate and sanitize all user inputs
- Use HTTPS for all external API communications
- Store sensitive data using OpenHarmony secure storage APIs
- Implement proper permission handling with user education