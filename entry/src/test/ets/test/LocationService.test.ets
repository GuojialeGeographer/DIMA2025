import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { LocationService, LocationChangeConfig, DEFAULT_LOCATION_CONFIG } from '../../../main/ets/services/LocationService';
import { LocationData, validateLocationData } from '../../../main/ets/models/LocationData';
import { forAll, Random, PropertyConfig } from './PropertyTestUtils';

const TAG = 'LocationServiceTest';
const DOMAIN = 0xFF00;

/**
 * **Feature: cityzen-app, Property 1: Location-Environment Data Consistency (Location part)**
 * **Validates: Requirements 1.2, 1.5**
 */

export default function LocationServiceTest() {
  describe('LocationService', () => {
    let locationService: LocationService;

    beforeAll(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'LocationService tests starting');
    });

    beforeEach(() => {
      locationService = LocationService.getInstance();
    });

    describe('Property Tests', () => {
      /**
       * **Feature: cityzen-app, Property 1: Location-Environment Data Consistency (Location part)**
       * **Validates: Requirements 1.2, 1.5**
       * 
       * Property: For any valid GPS coordinates, the LocationService should validate them correctly
       * and significant location changes should be detected properly
       */
      it('property_gps_coordinates_validation_consistency', 0, () => {
        hilog.info(DOMAIN, TAG, '%{public}s', 'Testing GPS coordinates validation consistency property');
        const validLocationGenerator = (): LocationData => ({
          latitude: Random.float(-90, 90),
          longitude: Random.float(-180, 180),
          accuracy: Random.float(0.1, 1000), // Reasonable accuracy range
          timestamp: Date.now() - Random.between(0, 3600000), // Within last hour
          altitude: Random.boolean() ? Random.float(-500, 9000) : undefined
        });

        const property = (location: LocationData): boolean => {
          // The location should be valid according to our validation
          const isValid = locationService.validateGPSCoordinates(location);
          
          // It should also pass the model validation
          const modelValid = validateLocationData(location);
          
          // Both validations should agree for valid coordinates
          return isValid === modelValid;
        };

        const result = forAll(validLocationGenerator, property, { iterations: 100 });
        
        if (!result.success) {
          hilog.error(DOMAIN, TAG, 'Property failed with counterexample: %{public}s', 
            JSON.stringify(result.counterExample));
        }
        
        expect(result.success).assertTrue();
        hilog.info(DOMAIN, TAG, 'Completed %{public}d iterations', result.iterations);
      });

      /**
       * Property: Invalid GPS coordinates should always be rejected
       */
      it('property_invalid_gps_coordinates_rejected', 0, () => {
        hilog.info(DOMAIN, TAG, '%{public}s', 'Testing invalid GPS coordinates rejection property');
        const invalidLocationGenerator = (): LocationData => {
          const invalidType = Random.between(1, 5);
          
          switch (invalidType) {
            case 1: // Invalid latitude
              return {
                latitude: Random.boolean() ? Random.float(-180, -90.1) : Random.float(90.1, 180),
                longitude: Random.float(-180, 180),
                accuracy: Random.float(0.1, 1000),
                timestamp: Date.now(),
              };
            case 2: // Invalid longitude
              return {
                latitude: Random.float(-90, 90),
                longitude: Random.boolean() ? Random.float(-360, -180.1) : Random.float(180.1, 360),
                accuracy: Random.float(0.1, 1000),
                timestamp: Date.now(),
              };
            case 3: // Invalid accuracy
              return {
                latitude: Random.float(-90, 90),
                longitude: Random.float(-180, 180),
                accuracy: Random.boolean() ? -Random.float(0.1, 100) : Random.float(10001, 50000),
                timestamp: Date.now(),
              };
            case 4: // Invalid timestamp (future or too old)
              return {
                latitude: Random.float(-90, 90),
                longitude: Random.float(-180, 180),
                accuracy: Random.float(0.1, 1000),
                timestamp: Random.boolean() ? 
                  Date.now() + Random.between(3600000, 86400000) : // Future
                  Date.now() - Random.between(86400000 * 2, 86400000 * 10), // Too old
              };
            default: // Multiple invalid fields
              return {
                latitude: Random.float(100, 200),
                longitude: Random.float(200, 300),
                accuracy: -Random.float(1, 100),
                timestamp: Date.now() + Random.between(3600000, 86400000),
              };
          }
        };

        const property = (location: LocationData): boolean => {
          // Invalid locations should be rejected by validation
          return !locationService.validateGPSCoordinates(location);
        };

        const result = forAll(invalidLocationGenerator, property, { iterations: 100 });
        
        if (!result.success) {
          hilog.error(DOMAIN, TAG, 'Invalid location property failed with counterexample: %{public}s', 
            JSON.stringify(result.counterExample));
        }
        
        expect(result.success).assertTrue();
        hilog.info(DOMAIN, TAG, 'Completed %{public}d iterations', result.iterations);
      });

      /**
       * Property: Location change detection should be consistent with distance calculations
       */
      it('property_location_change_detection_consistency', 0, () => {
        hilog.info(DOMAIN, TAG, '%{public}s', 'Testing location change detection consistency property');
        const locationPairGenerator = (): { first: LocationData; second: LocationData } => {
          const baseLocation: LocationData = {
            latitude: Random.float(-89, 89), // Avoid poles for distance calculations
            longitude: Random.float(-179, 179),
            accuracy: Random.float(1, 100),
            timestamp: Date.now() - Random.between(60000, 3600000), // 1 minute to 1 hour ago
          };

          // Generate second location with varying distance
          const distanceMeters = Random.float(0, 1000); // 0 to 1km
          const bearing = Random.float(0, 360); // Random direction
          
          // Simple approximation for small distances
          const deltaLat = (distanceMeters * Math.cos(bearing * Math.PI / 180)) / 111000; // ~111km per degree
          const deltaLon = (distanceMeters * Math.sin(bearing * Math.PI / 180)) / (111000 * Math.cos(baseLocation.latitude * Math.PI / 180));
          
          const secondLocation: LocationData = {
            latitude: baseLocation.latitude + deltaLat,
            longitude: baseLocation.longitude + deltaLon,
            accuracy: Random.float(1, 100),
            timestamp: baseLocation.timestamp + Random.between(10000, 60000), // 10s to 1min later
          };

          return { first: baseLocation, second: secondLocation };
        };

        const property = (locations: { first: LocationData; second: LocationData }): boolean => {
          // Both locations should be valid
          if (!locationService.validateGPSCoordinates(locations.first) || 
              !locationService.validateGPSCoordinates(locations.second)) {
            return true; // Skip invalid locations
          }

          // Create a new service instance to test location change detection
          const testService = LocationService.getInstance(DEFAULT_LOCATION_CONFIG);
          
          // Simulate setting the first location as last known
          testService['lastKnownLocation'] = locations.first;
          
          // Check if the change detection is consistent
          const isSignificant = testService['isSignificantLocationChange'](locations.second);
          
          // Calculate actual distance
          const distance = testService['calculateDistance'](
            locations.first.latitude,
            locations.first.longitude,
            locations.second.latitude,
            locations.second.longitude
          );
          
          const timeDiff = locations.second.timestamp - locations.first.timestamp;
          
          // The detection should be consistent with thresholds
          const expectedSignificant = distance >= DEFAULT_LOCATION_CONFIG.distanceThreshold && 
                                    timeDiff >= DEFAULT_LOCATION_CONFIG.timeThreshold;
          
          return isSignificant === expectedSignificant;
        };

        const result = forAll(locationPairGenerator, property, { iterations: 50 });
        
        if (!result.success) {
          hilog.error(DOMAIN, TAG, 'Location change detection property failed with counterexample: %{public}s', 
            JSON.stringify(result.counterExample));
        }
        
        expect(result.success).assertTrue();
        hilog.info(DOMAIN, TAG, 'Completed %{public}d iterations', result.iterations);
      });
    });

    describe('Unit Tests', () => {
      /**
       * Test permission request handling
       * Requirements: 1.1, 1.5
       */
      it('should handle permission request gracefully', 0, async () => {
        // Note: In a real test environment, we would mock the permission system
        // For now, we test that the method exists and handles errors
        try {
          const hasPermission = await locationService.requestPermission();
          expect(typeof hasPermission).assertEqual('boolean');
        } catch (error) {
          // Permission request might fail in test environment, which is acceptable
          expect(error).assertInstanceOf(Error);
        }
      });

      /**
       * Test GPS coordinate validation with specific cases
       * Requirements: 1.1, 1.5
       */
      it('should validate GPS coordinates correctly', 0, () => {
        // Valid coordinates
        const validLocation: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 10,
          timestamp: Date.now()
        };
        expect(locationService.validateGPSCoordinates(validLocation)).assertTrue();

        // Invalid latitude (too high)
        const invalidLat: LocationData = {
          latitude: 91,
          longitude: -74.0060,
          accuracy: 10,
          timestamp: Date.now()
        };
        expect(locationService.validateGPSCoordinates(invalidLat)).assertFalse();

        // Invalid longitude (too low)
        const invalidLon: LocationData = {
          latitude: 40.7128,
          longitude: -181,
          accuracy: 10,
          timestamp: Date.now()
        };
        expect(locationService.validateGPSCoordinates(invalidLon)).assertFalse();

        // Invalid accuracy (negative)
        const invalidAcc: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: -5,
          timestamp: Date.now()
        };
        expect(locationService.validateGPSCoordinates(invalidAcc)).assertFalse();
      });

      /**
       * Test location change detection with known values
       * Requirements: 1.1, 1.5
       */
      it('should detect location changes correctly', 0, () => {
        const config: LocationChangeConfig = {
          distanceThreshold: 100, // 100 meters
          timeThreshold: 30000, // 30 seconds
          maxLocationAge: 300000 // 5 minutes
        };
        
        const testService = LocationService.getInstance(config);
        
        const baseTime = Date.now();
        const firstLocation: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 10,
          timestamp: baseTime
        };
        
        // Set first location
        testService['lastKnownLocation'] = firstLocation;
        
        // Location change within threshold (should not be significant)
        const nearbyLocation: LocationData = {
          latitude: 40.7129, // ~11 meters north
          longitude: -74.0060,
          accuracy: 10,
          timestamp: baseTime + 35000 // 35 seconds later
        };
        
        expect(testService['isSignificantLocationChange'](nearbyLocation)).assertFalse();
        
        // Location change beyond threshold (should be significant)
        const farLocation: LocationData = {
          latitude: 40.7138, // ~111 meters north
          longitude: -74.0060,
          accuracy: 10,
          timestamp: baseTime + 35000 // 35 seconds later
        };
        
        expect(testService['isSignificantLocationChange'](farLocation)).assertTrue();
      });

      /**
       * Test configuration management
       */
      it('should manage configuration correctly', 0, () => {
        const customConfig: LocationChangeConfig = {
          distanceThreshold: 200,
          timeThreshold: 60000,
          maxLocationAge: 600000
        };
        
        locationService.updateConfig(customConfig);
        const retrievedConfig = locationService.getConfig();
        
        expect(retrievedConfig.distanceThreshold).assertEqual(200);
        expect(retrievedConfig.timeThreshold).assertEqual(60000);
        expect(retrievedConfig.maxLocationAge).assertEqual(600000);
      });

      /**
       * Test last known location management
       */
      it('should manage last known location correctly', 0, () => {
        const location: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 10,
          timestamp: Date.now()
        };
        
        // Set location manually for testing
        locationService['lastKnownLocation'] = location;
        
        const retrieved = locationService.getLastKnownLocation();
        expect(retrieved).assertNotNull();
        expect(retrieved!.latitude).assertEqual(location.latitude);
        expect(retrieved!.longitude).assertEqual(location.longitude);
        
        // Test old location (should return null)
        const oldLocation: LocationData = {
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 10,
          timestamp: Date.now() - 400000 // 6.67 minutes ago (older than default 5 min threshold)
        };
        
        locationService['lastKnownLocation'] = oldLocation;
        const retrievedOld = locationService.getLastKnownLocation();
        expect(retrievedOld).assertNull();
      });
    });

    afterAll(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'LocationService tests completed');
    });
  });
}