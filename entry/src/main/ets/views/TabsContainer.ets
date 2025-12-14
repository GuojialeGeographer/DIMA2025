import hilog from '@ohos.hilog';
import { DashboardPage } from './DashboardPage';
import { SmartMapPage } from './SmartMapPage';
import { HistoryPage } from './HistoryPage';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';
import { SlideMenuComponent } from './SlideMenuComponent';
import { NavigationViewModel, TabIndex } from '../viewmodels/NavigationViewModel';

const TAG = 'TabsContainer';
const DOMAIN = 0xFF00;

@Component
export struct TabsContainer {
  private navigationViewModel: NavigationViewModel = new NavigationViewModel();
  @State currentTabIndex: number = this.navigationViewModel.getCurrentTab();
  @State isMenuOpen: boolean = this.navigationViewModel.isMenuOpen();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'TabsContainer aboutToAppear');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Main content area
      Column() {
        // Tab content area
        if (this.currentTabIndex === TabIndex.DASHBOARD) {
          DashboardPage()
        } else if (this.currentTabIndex === TabIndex.SMART_MAP) {
          SmartMapPage()
        } else if (this.currentTabIndex === TabIndex.HISTORY) {
          HistoryPage()
        } else if (this.currentTabIndex === TabIndex.SETTINGS) {
          SettingsPage()
        } else if (this.currentTabIndex === TabIndex.ABOUT) {
          AboutPage()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // Bottom navigation tabs (only show for main tabs, not settings flow)
      if (!this.navigationViewModel.isInSettingsFlow()) {
        Column() {
          Flex({ justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center }) {
            this.TabItem(TabIndex.DASHBOARD, 'Dashboard', $r('sys.symbol.house'))
            this.TabItem(TabIndex.SMART_MAP, 'SmartMap', $r('sys.symbol.map'))
            this.TabItem(TabIndex.HISTORY, 'History', $r('sys.symbol.clock'))
          }
          .width('100%')
          .height(60)
          .backgroundColor('#FFFFFF')
          .border({
            width: { top: 1 },
            color: '#E0E0E0'
          })
        }
        .width('100%')
        .position({ x: 0, y: '100%' })
        .translate({ y: -60 })
      }

      // Back button for settings flow
      if (this.navigationViewModel.isInSettingsFlow()) {
        Row() {
          Button('← Back')
            .fontSize(16)
            .backgroundColor('#007AFF')
            .fontColor('#FFFFFF')
            .margin({ left: 20 })
            .onClick(() => {
              if (this.navigationViewModel.canGoBack()) {
                this.navigationViewModel.goBack();
                this.currentTabIndex = this.navigationViewModel.getCurrentTab();
              } else {
                this.navigationViewModel.switchTab(TabIndex.DASHBOARD);
                this.currentTabIndex = TabIndex.DASHBOARD;
              }
            })

          Blank()
        }
        .width('100%')
        .height(60)
        .backgroundColor('#FFFFFF')
        .alignItems(VerticalAlign.Center)
        .border({
          width: { top: 1 },
          color: '#E0E0E0'
        })
        .position({ x: 0, y: '100%' })
        .translate({ y: -60 })
      }

      // Slide menu overlay
      if (this.isMenuOpen) {
        SlideMenuComponent({
          isOpen: $isMenuOpen,
          currentTabIndex: $currentTabIndex
        })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(
      // Swipe gesture for slide menu
      PanGesture({ fingers: 1, distance: 20, direction: PanDirection.Right })
        .onActionStart(() => {
          if (!this.navigationViewModel.isMenuOpen()) {
            this.navigationViewModel.openMenu();
            this.isMenuOpen = this.navigationViewModel.isMenuOpen();
            hilog.info(DOMAIN, TAG, 'Slide menu opened via swipe');
          }
        })
    )
  }

  @Builder TabItem(index: TabIndex, label: string, icon: Resource) {
    Column() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.currentTabIndex === index ? '#007AFF' : '#8E8E93')

      Text(label)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? '#007AFF' : '#8E8E93')
        .margin({ top: 4 })
    }
    .width(80)
    .height(50)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.navigationViewModel.switchTab(index)) {
        this.currentTabIndex = this.navigationViewModel.getCurrentTab();
        hilog.info(DOMAIN, TAG, `Tab switched to index: ${index}`);
      }
    })
  }
}