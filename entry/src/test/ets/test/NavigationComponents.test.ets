import hilog from '@ohos.hilog';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { NavigationViewModel, TabIndex } from '../../../main/ets/viewmodels/NavigationViewModel';

const TAG = 'NavigationComponents.test';
const DOMAIN = 0xFF00;

export default function navigationComponentsTest() {
  describe('NavigationComponents', () => {
    let navigationViewModel: NavigationViewModel;

    beforeEach(() => {
      navigationViewModel = new NavigationViewModel();
    });

    describe('Tab Switching Functionality', () => {
      it('should switch to valid tab indices', () => {
        hilog.info(DOMAIN, TAG, 'Testing valid tab switching');

        // Test switching to Dashboard
        const dashboardResult = navigationViewModel.switchTab(TabIndex.DASHBOARD);
        expect(dashboardResult).assertEqual(false); // Already on dashboard
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);

        // Test switching to SmartMap
        const smartMapResult = navigationViewModel.switchTab(TabIndex.SMART_MAP);
        expect(smartMapResult).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);

        // Test switching to History
        const historyResult = navigationViewModel.switchTab(TabIndex.HISTORY);
        expect(historyResult).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.HISTORY);
      });

      it('should reject invalid tab indices', () => {
        hilog.info(DOMAIN, TAG, 'Testing invalid tab switching');

        const initialTab = navigationViewModel.getCurrentTab();

        // Test invalid negative index
        const negativeResult = navigationViewModel.switchTab(-1);
        expect(negativeResult).assertEqual(false);
        expect(navigationViewModel.getCurrentTab()).assertEqual(initialTab);

        // Test invalid high index
        const highResult = navigationViewModel.switchTab(99);
        expect(highResult).assertEqual(false);
        expect(navigationViewModel.getCurrentTab()).assertEqual(initialTab);
      });

      it('should maintain navigation history during tab switches', () => {
        hilog.info(DOMAIN, TAG, 'Testing navigation history maintenance');

        // Initial state should have dashboard in history
        let history = navigationViewModel.getNavigationHistory();
        expect(history.length).assertEqual(1);
        expect(history[0]).assertEqual(TabIndex.DASHBOARD);

        // Switch to SmartMap
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        history = navigationViewModel.getNavigationHistory();
        expect(history.length).assertEqual(2);
        expect(history[1]).assertEqual(TabIndex.SMART_MAP);

        // Switch to History
        navigationViewModel.switchTab(TabIndex.HISTORY);
        history = navigationViewModel.getNavigationHistory();
        expect(history.length).assertEqual(3);
        expect(history[2]).assertEqual(TabIndex.HISTORY);

        // Current tab should always be last in history
        expect(history[history.length - 1]).assertEqual(navigationViewModel.getCurrentTab());
      });

      it('should handle back navigation correctly', () => {
        hilog.info(DOMAIN, TAG, 'Testing back navigation');

        // Initially cannot go back
        expect(navigationViewModel.canGoBack()).assertEqual(false);
        expect(navigationViewModel.goBack()).assertEqual(false);

        // Navigate to create history
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.switchTab(TabIndex.HISTORY);

        // Now should be able to go back
        expect(navigationViewModel.canGoBack()).assertEqual(true);
        
        const backResult = navigationViewModel.goBack();
        expect(backResult).assertEqual(true);
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);

        // Should still be able to go back once more
        expect(navigationViewModel.canGoBack()).assertEqual(true);
        navigationViewModel.goBack();
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);

        // Now cannot go back further
        expect(navigationViewModel.canGoBack()).assertEqual(false);
      });
    });

    describe('Slide Menu Interaction', () => {
      it('should open and close menu correctly', () => {
        hilog.info(DOMAIN, TAG, 'Testing menu open/close functionality');

        // Initially menu should be closed
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);

        // Open menu
        navigationViewModel.openMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);

        // Close menu
        navigationViewModel.closeMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
      });

      it('should toggle menu state correctly', () => {
        hilog.info(DOMAIN, TAG, 'Testing menu toggle functionality');

        // Initially closed, toggle should open
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
        navigationViewModel.toggleMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);

        // Now open, toggle should close
        navigationViewModel.toggleMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
      });

      it('should handle redundant menu operations gracefully', () => {
        hilog.info(DOMAIN, TAG, 'Testing redundant menu operations');

        // Opening already closed menu
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
        navigationViewModel.openMenu();
        navigationViewModel.openMenu(); // Redundant open
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);

        // Closing already open menu
        navigationViewModel.closeMenu();
        navigationViewModel.closeMenu(); // Redundant close
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
      });
    });

    describe('State Preservation During Navigation', () => {
      it('should preserve menu state during tab navigation', () => {
        hilog.info(DOMAIN, TAG, 'Testing menu state preservation during navigation');

        // Open menu
        navigationViewModel.openMenu();
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);

        // Navigate between tabs
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        expect(navigationViewModel.isMenuOpen()).assertEqual(true); // Menu should remain open

        navigationViewModel.switchTab(TabIndex.HISTORY);
        expect(navigationViewModel.isMenuOpen()).assertEqual(true); // Menu should remain open

        navigationViewModel.switchTab(TabIndex.DASHBOARD);
        expect(navigationViewModel.isMenuOpen()).assertEqual(true); // Menu should remain open
      });

      it('should maintain consistent state after reset', () => {
        hilog.info(DOMAIN, TAG, 'Testing state consistency after reset');

        // Modify state
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.openMenu();
        navigationViewModel.switchTab(TabIndex.HISTORY);

        // Reset navigation
        navigationViewModel.resetNavigation();

        // Verify reset state
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.DASHBOARD);
        expect(navigationViewModel.isMenuOpen()).assertEqual(false);
        expect(navigationViewModel.canGoBack()).assertEqual(false);
        
        const history = navigationViewModel.getNavigationHistory();
        expect(history.length).assertEqual(1);
        expect(history[0]).assertEqual(TabIndex.DASHBOARD);
      });

      it('should provide consistent state snapshots', () => {
        hilog.info(DOMAIN, TAG, 'Testing state snapshot consistency');

        // Modify state
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.openMenu();

        const state = navigationViewModel.getState();

        // Verify state snapshot matches current state
        expect(state.currentTab).assertEqual(navigationViewModel.getCurrentTab());
        expect(state.isMenuOpen).assertEqual(navigationViewModel.isMenuOpen());
        expect(state.navigationHistory.length).assertEqual(navigationViewModel.getNavigationHistory().length);

        // Verify state snapshot is independent (changes don't affect original)
        state.currentTab = TabIndex.HISTORY;
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP); // Should not change
      });

      it('should handle navigation history size limits', () => {
        hilog.info(DOMAIN, TAG, 'Testing navigation history size limits');

        // Navigate through many tabs to test history limit
        for (let i = 0; i < 15; i++) {
          const targetTab = i % 3; // Cycle through all tabs
          navigationViewModel.switchTab(targetTab);
        }

        const history = navigationViewModel.getNavigationHistory();
        
        // History should be limited to 10 entries
        expect(history.length).assertLessOrEqual(10);
        
        // Current tab should still be the last entry
        expect(history[history.length - 1]).assertEqual(navigationViewModel.getCurrentTab());
      });
    });

    describe('Edge Cases and Error Handling', () => {
      it('should handle concurrent navigation operations', () => {
        hilog.info(DOMAIN, TAG, 'Testing concurrent navigation operations');

        // Simulate rapid tab switching
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.switchTab(TabIndex.HISTORY);
        navigationViewModel.switchTab(TabIndex.DASHBOARD);
        navigationViewModel.switchTab(TabIndex.SMART_MAP);

        // State should be consistent
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.SMART_MAP);
        
        const history = navigationViewModel.getNavigationHistory();
        expect(history[history.length - 1]).assertEqual(TabIndex.SMART_MAP);
      });

      it('should handle mixed navigation and menu operations', () => {
        hilog.info(DOMAIN, TAG, 'Testing mixed navigation and menu operations');

        // Perform mixed operations
        navigationViewModel.openMenu();
        navigationViewModel.switchTab(TabIndex.SMART_MAP);
        navigationViewModel.toggleMenu(); // Should close
        navigationViewModel.switchTab(TabIndex.HISTORY);
        navigationViewModel.toggleMenu(); // Should open

        // Verify final state
        expect(navigationViewModel.getCurrentTab()).assertEqual(TabIndex.HISTORY);
        expect(navigationViewModel.isMenuOpen()).assertEqual(true);
      });
    });
  });
}