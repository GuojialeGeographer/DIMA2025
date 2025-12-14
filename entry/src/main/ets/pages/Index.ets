import hilog from '@ohos.hilog';
import { TabsContainer } from '../views/TabsContainer';

const TAG = 'Index';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Index page aboutToAppear - CityZen App Starting');
  }

  build() {
    TabsContainer()
  }
}