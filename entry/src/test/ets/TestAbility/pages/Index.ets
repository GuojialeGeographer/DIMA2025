import hilog from '@ohos.hilog';

const TAG = 'TestIndex';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'TestAbility Index aboutToAppear');
  }

  @State message: string = 'CityZen Test Runner';

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)

        Text('Running unit tests...')
          .fontSize(16)
          .margin({ top: 20 })
      }
      .width('100%')
    }
    .height('100%')
  }
}