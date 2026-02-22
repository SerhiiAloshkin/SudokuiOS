#if canImport(XCTest)
import XCTest
import SwiftData
@testable import SudokuiOS

@MainActor
final class PersistenceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, AppSettings.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testUserLevelProgressPersistence() throws {
        // 1. Create a progress record
        let progress = UserLevelProgress(id: 1, isSolved: true, timeElapsed: 120, stars: 3)
        context.insert(progress)
        
        // 2. Save
        try context.save()
        
        // 3. Fetch
        let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.id == 1 })
        let fetchedProgress = try context.fetch(descriptor)
        
        // 4. Verify
        XCTAssertEqual(fetchedProgress.count, 1)
        XCTAssertEqual(fetchedProgress.first?.isSolved, true)
        XCTAssertEqual(fetchedProgress.first?.timeElapsed, 120)
    }
    
    func testAppSettingsPersistence() throws {
        // 1. Create Settings
        let settings = AppSettings()
        // settings.isSoundEnabled = false // Removed
        // settings.isHapticsEnabled = false // Removed/Not present
        settings.hasSeenTutorial = true // Test Tutorial Flag
        context.insert(settings)
        
        // 2. Save
        try context.save()
        
        // 3. Fetch
        let descriptor = FetchDescriptor<AppSettings>()
        let fetchedSettings = try context.fetch(descriptor)
        
        // 4. Verify
        XCTAssertEqual(fetchedSettings.count, 1)
        // XCTAssertEqual(fetchedSettings.first?.isSoundEnabled, false)
        XCTAssertEqual(fetchedSettings.first?.hasSeenTutorial, true, "Tutorial flag should be persisted")
    }
    
    func testHasSeenTutorialPersistence() throws {
        // 1. Create Settings with tutorial seen
        let settings = AppSettings()
        settings.hasSeenTutorial = true
        context.insert(settings)
        
        // 2. Save
        try context.save()
        
        // 3. Fetch
        let descriptor = FetchDescriptor<AppSettings>()
        let fetchedSettings = try context.fetch(descriptor)
        
        // 4. Verify
        XCTAssertEqual(fetchedSettings.count, 1)
        XCTAssertEqual(fetchedSettings.first?.hasSeenTutorial, true, "Tutorial flag should be persisted")
    }
}
#endif
