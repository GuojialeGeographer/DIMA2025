import hilog from '@ohos.hilog';
import { NavigationViewModel, TabIndex } from '../viewmodels/NavigationViewModel';

const TAG = 'SlideMenuComponent';
const DOMAIN = 0xFF00;

@Component
export struct SlideMenuComponent {
  @Link isOpen: boolean;
  @Link currentTabIndex: number;
  private navigationViewModel: NavigationViewModel = new NavigationViewModel();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'SlideMenuComponent aboutToAppear');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Semi-transparent overlay
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.isOpen = false;
          hilog.info(DOMAIN, TAG, 'Menu closed via overlay click');
        })

      // Slide menu content
      Column() {
        // Menu header
        Row() {
          Text('CityZen')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ left: 20 })

          Blank()

          Button('×')
            .fontSize(24)
            .fontColor('#FFFFFF')
            .backgroundColor(Color.Transparent)
            .margin({ right: 20 })
            .onClick(() => {
              this.isOpen = false;
              hilog.info(DOMAIN, TAG, 'Menu closed via close button');
            })
        }
        .width('100%')
        .height(60)
        .backgroundColor('#007AFF')
        .alignItems(VerticalAlign.Center)

        // Menu items
        Column() {
          this.MenuItem('Settings', $r('sys.symbol.gear'), () => {
            hilog.info(DOMAIN, TAG, 'Settings clicked');
            this.navigationViewModel.switchTab(TabIndex.SETTINGS);
            this.currentTabIndex = TabIndex.SETTINGS;
          })

          this.MenuItem('Offline Maps', $r('sys.symbol.map_fill'), () => {
            hilog.info(DOMAIN, TAG, 'Offline Maps clicked');
            // TODO: Navigate to offline maps page (future feature)
          })

          this.MenuItem('About', $r('sys.symbol.info_circle'), () => {
            hilog.info(DOMAIN, TAG, 'About clicked');
            this.navigationViewModel.switchTab(TabIndex.ABOUT);
            this.currentTabIndex = TabIndex.ABOUT;
          })

          this.MenuItem('Privacy Policy', $r('sys.symbol.doc_text'), () => {
            hilog.info(DOMAIN, TAG, 'Privacy Policy clicked');
            this.navigationViewModel.switchTab(TabIndex.ABOUT);
            this.currentTabIndex = TabIndex.ABOUT;
          })

          Divider()
            .margin({ top: 20, bottom: 20 })
            .color('#E0E0E0')

          // App information
          Column() {
            Text('CityZen v1.0.0')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 8 })

            Text('Urban Well-being Assistant')
              .fontSize(12)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 20, right: 20 })
        }
        .width('100%')
        .padding({ top: 20 })
        .layoutWeight(1)
      }
      .width(280)
      .height('100%')
      .backgroundColor('#FFFFFF')
      .animation({
        duration: 300,
        curve: Curve.EaseInOut
      })
      .translate({ x: this.isOpen ? 0 : -280 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder MenuItem(title: string, icon: Resource, onClick: () => void) {
    Row() {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor('#666666')
        .margin({ right: 15 })

      Text(title)
        .fontSize(16)
        .fontColor('#333333')

      Blank()

      Image($r('sys.symbol.chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(50)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      onClick();
      this.isOpen = false;
    })
    .gesture(
      TapGesture()
        .onAction(() => {
          // Add visual feedback
        })
    )
  }
}