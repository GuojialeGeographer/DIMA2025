import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import abilityTest from './Ability.test';
import dataModelValidationTest from './DataModelValidation.test';
import databaseServiceTest from './DatabaseService.test';
import navigationStateManagementTest from './NavigationStateManagement.test';
import navigationComponentsTest from './NavigationComponents.test';
import dashboardUIConsistencyTest from './DashboardUIConsistency.test';
import dashboardFunctionalityTest from './DashboardFunctionality.test';
import historyFunctionalityTest from './HistoryFunctionality.test';
import errorHandlingTest from './ErrorHandling.test';
import systemIntegrationTest from './SystemIntegration.test';
import correctnessPropertiesTest from './CorrectnessProperties.test';
import testValidationTest from './TestValidation.test';

const TAG = 'ListTest';
const DOMAIN = 0xFF00;

export default function testsuite() {
  hilog.info(DOMAIN, TAG, '%{public}s', 'testsuite begin');
  
  // Run all test suites
  abilityTest();
  dataModelValidationTest();
  databaseServiceTest();
  navigationStateManagementTest();
  navigationComponentsTest();
  dashboardUIConsistencyTest();
  dashboardFunctionalityTest();
  historyFunctionalityTest();
  errorHandlingTest();
  
  // Integration and system tests
  testValidationTest();
  systemIntegrationTest();
  correctnessPropertiesTest();
  
  hilog.info(DOMAIN, TAG, '%{public}s', 'testsuite end');
}