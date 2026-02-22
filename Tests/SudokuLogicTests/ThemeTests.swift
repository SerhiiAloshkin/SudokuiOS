import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class ThemeTests: XCTestCase {
    
    func testAppThemeDefaultsToSystem() {
        let settings = AppSettings()
        XCTAssertEqual(settings.appTheme, .system)
    }
    
    func testAppThemePersistence() {
        let settings = AppSettings()
        
        // Change to Dark
        settings.appTheme = .dark
        XCTAssertEqual(settings.appThemeRaw, "dark")
        XCTAssertEqual(settings.appTheme, .dark)
        
        // Change to Light
        settings.appTheme = .light
        XCTAssertEqual(settings.appThemeRaw, "light")
        XCTAssertEqual(settings.appTheme, .light)
    }
    
    func testAppThemeColorSchemeMapping() {
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
        XCTAssertNil(AppTheme.system.colorScheme)
    }
}
