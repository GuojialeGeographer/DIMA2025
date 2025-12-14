import hilog from '@ohos.hilog';

const TAG = 'NavigationViewModel';
const DOMAIN = 0xFF00;

export enum TabIndex {
  DASHBOARD = 0,
  SMART_MAP = 1,
  HISTORY = 2,
  SETTINGS = 3,
  ABOUT = 4
}

export interface NavigationState {
  currentTab: TabIndex;
  isMenuOpen: boolean;
  previousTab?: TabIndex;
  navigationHistory: TabIndex[];
  isInSettingsFlow: boolean; // Track if user is in settings/about pages
}

@Observed
export class NavigationViewModel {
  private state: NavigationState = {
    currentTab: TabIndex.DASHBOARD,
    isMenuOpen: false,
    navigationHistory: [TabIndex.DASHBOARD],
    isInSettingsFlow: false
  };

  constructor() {
    hilog.info(DOMAIN, TAG, 'NavigationViewModel initialized');
  }

  getCurrentTab(): TabIndex {
    return this.state.currentTab;
  }

  isMenuOpen(): boolean {
    return this.state.isMenuOpen;
  }

  getNavigationHistory(): TabIndex[] {
    return [...this.state.navigationHistory];
  }

  isInSettingsFlow(): boolean {
    return this.state.isInSettingsFlow;
  }

  switchTab(tabIndex: TabIndex): boolean {
    if (tabIndex === this.state.currentTab) {
      hilog.info(DOMAIN, TAG, `Tab ${tabIndex} already active, no switch needed`);
      return false;
    }

    if (!this.isValidTabIndex(tabIndex)) {
      hilog.error(DOMAIN, TAG, `Invalid tab index: ${tabIndex}`);
      return false;
    }

    const previousTab = this.state.currentTab;
    this.state.previousTab = previousTab;
    this.state.currentTab = tabIndex;
    
    // Update settings flow state
    this.state.isInSettingsFlow = (tabIndex === TabIndex.SETTINGS || tabIndex === TabIndex.ABOUT);
    
    // Update navigation history
    this.state.navigationHistory.push(tabIndex);
    
    // Keep history limited to last 10 entries
    if (this.state.navigationHistory.length > 10) {
      this.state.navigationHistory = this.state.navigationHistory.slice(-10);
    }

    hilog.info(DOMAIN, TAG, `Tab switched from ${previousTab} to ${tabIndex}`);
    return true;
  }

  openMenu(): void {
    if (!this.state.isMenuOpen) {
      this.state.isMenuOpen = true;
      hilog.info(DOMAIN, TAG, 'Slide menu opened');
    }
  }

  closeMenu(): void {
    if (this.state.isMenuOpen) {
      this.state.isMenuOpen = false;
      hilog.info(DOMAIN, TAG, 'Slide menu closed');
    }
  }

  toggleMenu(): void {
    if (this.state.isMenuOpen) {
      this.closeMenu();
    } else {
      this.openMenu();
    }
  }

  canGoBack(): boolean {
    return this.state.navigationHistory.length > 1;
  }

  goBack(): boolean {
    if (!this.canGoBack()) {
      hilog.info(DOMAIN, TAG, 'Cannot go back - no previous tab in history');
      return false;
    }

    // Remove current tab from history
    this.state.navigationHistory.pop();
    
    // Get previous tab
    const previousTab = this.state.navigationHistory[this.state.navigationHistory.length - 1];
    
    this.state.previousTab = this.state.currentTab;
    this.state.currentTab = previousTab;

    hilog.info(DOMAIN, TAG, `Navigated back to tab ${previousTab}`);
    return true;
  }

  resetNavigation(): void {
    this.state = {
      currentTab: TabIndex.DASHBOARD,
      isMenuOpen: false,
      navigationHistory: [TabIndex.DASHBOARD],
      isInSettingsFlow: false
    };
    hilog.info(DOMAIN, TAG, 'Navigation state reset to default');
  }

  getState(): NavigationState {
    return {
      currentTab: this.state.currentTab,
      isMenuOpen: this.state.isMenuOpen,
      previousTab: this.state.previousTab,
      navigationHistory: [...this.state.navigationHistory],
      isInSettingsFlow: this.state.isInSettingsFlow
    };
  }

  private isValidTabIndex(tabIndex: TabIndex): boolean {
    return Object.values(TabIndex).includes(tabIndex);
  }
}