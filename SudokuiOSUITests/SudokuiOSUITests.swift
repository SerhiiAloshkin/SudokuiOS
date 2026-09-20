//
//  SudokuiOSUITests.swift
//  SudokuiOSUITests
//
//  End-to-end smoke tests: launch the real app in the simulator and tap through it.
//
//  The app has no accessibility identifiers, launch arguments or in-memory store, so these
//  tests find controls by their visible English labels and share the simulator's real
//  SwiftData store between runs. Every test therefore leaves the app state as it found it
//  (e.g. the digit test undoes its move) and tolerates leftover progress ("Continue Level").
//

import XCTest

final class SudokuiOSUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // Splash (~2.2 s) + level loading before the main menu appears.
        XCTAssertTrue(app.buttons["Play Campaign"].waitForExistence(timeout: 30),
                      "Main menu never appeared after launch")
    }

    // MARK: - Tests

    func testMainMenuShowsPrimaryActions() {
        XCTAssertTrue(app.buttons["Play Campaign"].exists)
        XCTAssertTrue(app.buttons["Level Builder"].exists)
        XCTAssertTrue(app.buttons["My Custom Levels"].exists)
        attachScreenshot("main-menu")
    }

    func testOpenLevelOneAndGoBack() {
        openLevelOne()
        XCTAssertTrue(app.staticTexts["Level 1"].exists)
        XCTAssertTrue(app.staticTexts["CLASSIC"].exists)
        XCTAssertTrue(app.buttons["Pause"].exists)
        attachScreenshot("level-1")

        // Game → level grid → main menu.
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 10),
                      "Back from the game should return to the level grid")
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Play Campaign"].waitForExistence(timeout: 10),
                      "Back from the level grid should return to the main menu")
    }

    /// Level 1 (see Levels.json) is fixed: row 1 is `8 _ 5 _ 9 2 _ 4 7` and the solution's
    /// second digit is 6, so entering 6 in row 1 / column 2 is a correct move (no mistake).
    /// The store persists between runs, so the cell is cleared first in case an earlier
    /// (possibly failed) run left a 6 in it.
    func testEnterCorrectDigitThenUndo() {
        openLevelOne()
        // Select the cell once (a second tap on a selected cell would deselect it).
        cell(row: 0, col: 1).tap()
        app.buttons["Erase"].tap()
        let sixesBefore = boardDigitCount("6")

        app.buttons["6"].firstMatch.tap()

        let undo = app.buttons["Undo"]
        XCTAssertEqual(boardDigitCount("6"), sixesBefore + 1, "The entered 6 should appear on the board")
        XCTAssertTrue(undo.isEnabled, "Undo should be enabled after a move")
        attachScreenshot("digit-entered")

        undo.tap()
        XCTAssertEqual(boardDigitCount("6"), sixesBefore, "Undo should remove the 6 again")
    }

    func testOpenSettingsFromMainMenu() {
        app.buttons["gearshape.fill"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "Settings screen did not open")
        attachScreenshot("settings")
    }

    // MARK: - Navigation helpers

    /// Main menu → Play Campaign → level 1 → Start/Continue Level → game screen.
    private func openLevelOne() {
        app.buttons["Play Campaign"].tap()
        let levelOne = app.buttons["1"]
        XCTAssertTrue(levelOne.waitForExistence(timeout: 10), "Level grid did not appear")
        levelOne.tap()

        let start = app.buttons["Start Level"]
        let resume = app.buttons["Continue Level"]
        XCTAssertTrue(start.waitForExistence(timeout: 10) || resume.exists,
                      "Level preview offered neither Start Level nor Continue Level")
        (start.exists ? start : resume).tap()

        XCTAssertTrue(app.staticTexts["Level 1"].waitForExistence(timeout: 10),
                      "Game screen for level 1 did not appear")
    }

    // MARK: - Board helpers

    /// Board cells are not individual accessibility elements, so cells are tapped by
    /// coordinate: 9 columns spanning the window minus a 12 pt margin on each side, with row 0
    /// aligned to level 1's first given digit (an 8 in row 0, column 0).
    private func cell(row: Int, col: Int) -> XCUICoordinate {
        let width = app.windows.firstMatch.frame.width
        let pitch = (width - 24) / 9
        let x = 12 + pitch * (CGFloat(col) + 0.5)
        let row0MidY = app.staticTexts["8"].firstMatch.frame.midY
        let y = row0MidY + pitch * CGFloat(row)
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// Number of times `digit` is drawn on the board. On the game screen the only
    /// single-digit static texts are board cells (the number pad is made of buttons).
    private func boardDigitCount(_ digit: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", digit)).count
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
