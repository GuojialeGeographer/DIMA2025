# CityZen - Urban Well-being App

CityZen is an innovative health and well-being application for the OpenHarmony/Oniro ecosystem that focuses on environmental quality assessment for urban exercise. The app combines real-time environmental data with AI-powered recommendations to help users find the healthiest locations for physical activities.

## Project Structure

This project follows the MVVM (Model-View-ViewModel) architecture pattern:

```
entry/src/main/ets/
├── entryability/          # Main application entry point
├── models/                # Data structures and interfaces
├── viewmodels/            # Business logic and state management
├── views/                 # UI components and pages
├── services/              # External API integrations and data services
└── pages/                 # Main application pages
```

## Development Environment

- **Platform**: OpenHarmony API 18 / HarmonyOS NEXT
- **Language**: ArkTS (TypeScript for OpenHarmony)
- **IDE**: DevEco Studio
- **Architecture**: MVVM pattern

## Permissions

The application requires the following permissions:
- `ohos.permission.LOCATION` - For GPS positioning and environmental data
- `ohos.permission.APPROXIMATELY_LOCATION` - For approximate location when precise location is not needed
- `ohos.permission.INTERNET` - For weather API and AI service integration

## Features

- Real-time environmental quality assessment
- AI-powered exercise recommendations
- Interactive map with environmental zones
- Exercise tracking with environmental context
- Offline functionality with data synchronization

## Getting Started

1. Open the project in DevEco Studio
2. Ensure OpenHarmony API 18 SDK is installed
3. Build and run the application on an OpenHarmony device or emulator

## Testing

The project includes comprehensive unit tests using the ArkTS testing framework:
- Run tests through DevEco Studio test runner
- Tests cover application initialization, MVVM structure, and core functionality

## License

MIT License - see LICENSE file for details