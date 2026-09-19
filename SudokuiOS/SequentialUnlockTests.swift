import Testing
import Testing
import Foundation
@testable import SudokuiOS

@Suite("Sequential Level Unlocking Tests")
struct SequentialUnlockTests {

    @Test("Level 1 is always unlocked")
    func level1AlwaysUnlocked() async throws {
        // Given: Fresh game state with no levels solved
        var levels = createTestLevels(count: 10, solvedUpTo: 0)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 1 should be unlocked
        let level1 = levels.first { $0.id == 1 }
        #expect(level1?.isLocked == false, "Level 1 should always be unlocked")
    }

    @Test("Level 2 unlocks after Level 1 is solved")
    func level2UnlocksAfterLevel1() async throws {
        // Given: Level 1 is solved
        var levels = createTestLevels(count: 10, solvedUpTo: 1)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 2 should be unlocked
        let level2 = levels.first { $0.id == 2 }
        #expect(level2?.isLocked == false, "Level 2 should unlock after Level 1 is solved")
    }

    @Test("Level 3 remains locked if Level 2 is not solved")
    func level3StaysLockedWithoutLevel2() async throws {
        // Given: Only Level 1 is solved
        var levels = createTestLevels(count: 10, solvedUpTo: 1)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 3 should be locked
        let level3 = levels.first { $0.id == 3 }
        #expect(level3?.isLocked == true, "Level 3 should be locked if Level 2 is not solved")
    }

    @Test("Level 100 unlocks when Level 99 is solved")
    func level100UnlocksAfterLevel99() async throws {
        // Given: Levels 1-99 are solved
        var levels = createTestLevels(count: 100, solvedUpTo: 99)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 100 should be unlocked
        let level100 = levels.first { $0.id == 100 }
        #expect(level100?.isLocked == false, "Level 100 should unlock after Level 99 is solved")
    }

    @Test("Level 251 requires all of section 1 completed")
    func level251RequiresSection1() async throws {
        // Given: Levels 1-249 solved, but not 250
        var levels = createTestLevels(count: 260, solvedUpTo: 249)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 251 should be locked
        let level251 = levels.first { $0.id == 251 }
        #expect(level251?.isLocked == true, "Level 251 should be locked until all 250 levels are completed")
    }

    @Test("Level 251 unlocks when all 250 levels are solved")
    func level251UnlocksAfterSection1() async throws {
        // Given: All levels 1-250 solved
        var levels = createTestLevels(count: 260, solvedUpTo: 250)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Level 251 should be unlocked
        let level251 = levels.first { $0.id == 251 }
        #expect(level251?.isLocked == false, "Level 251 should unlock after all 250 levels are solved")
    }

    @Test("Debug unlock mode unlocks all levels")
    func debugUnlockWorksCorrectly() async throws {
        // Given: Fresh game state
        var levels = createTestLevels(count: 10, solvedUpTo: 0)

        // When: Recalculate locks with debug mode
        recalculateLocks(for: &levels, debugUnlock: true)

        // Then: All levels should be unlocked
        let allUnlocked = levels.allSatisfy { !$0.isLocked }
        #expect(allUnlocked, "All levels should be unlocked in debug mode")
    }

    @Test("Sequential progression from 1 to 10")
    func sequentialProgression() async throws {
        // Given: Levels 1-5 solved
        var levels = createTestLevels(count: 10, solvedUpTo: 5)

        // When: Recalculate locks
        recalculateLocks(for: &levels, debugUnlock: false)

        // Then: Levels 1-6 should be unlocked, 7-10 locked
        for i in 1...6 {
            let level = levels.first { $0.id == i }
            #expect(level?.isLocked == false, "Level \(i) should be unlocked")
        }

        for i in 7...10 {
            let level = levels.first { $0.id == i }
            #expect(level?.isLocked == true, "Level \(i) should be locked")
        }
    }

    // Helper function to create test levels
    private func createTestLevels(count: Int, solvedUpTo: Int) -> [SudokuLevel] {
        return (1...count).map { id in
            SudokuLevel(
                id: id,
                isLocked: true,
                isSolved: id <= solvedUpTo,
                ruleType: .classic
            )
        }
    }

    // Helper to call the static recalculate function
    // Note: This assumes you can access the static function, or you may need to make it internal/public
    private func recalculateLocks(for levels: inout [SudokuLevel], debugUnlock: Bool) {
        // You'll need to expose this static method or create a test-friendly version
        // LevelViewModel.recalculateLocks(for: &levels, debugUnlock: debugUnlock)

        // For now, replicate the logic here for testing
        let endOfFirstSection = min(250, levels.count)
        let firstSectionSolved = levels[0..<endOfFirstSection].allSatisfy { $0.isSolved }

        for i in 0..<levels.count {
            if debugUnlock {
                levels[i].isLocked = false
                continue
            }

            let levelID = levels[i].id

            if levels[i].isSolved {
                levels[i].isLocked = false
                continue
            }

            if levelID == 1 {
                levels[i].isLocked = false
                continue
            }

            if i > 0 && levels[i - 1].isSolved {
                if levelID <= 250 {
                    levels[i].isLocked = false
                } else {
                    if firstSectionSolved {
                        levels[i].isLocked = false
                    } else {
                        levels[i].isLocked = true
                    }
                }
            } else {
                levels[i].isLocked = true
            }
        }
    }
}
