import Foundation
import SwiftData
import Combine

/// Manages game state persistence to SwiftData
/// Extracts persistence logic from SudokuGameViewModel
@MainActor
final class GamePersistenceManager {
    
    // MARK: - Dependencies
    
    private weak var levelViewModel: LevelViewModel?
    private let levelID: Int
    private let customLevelUUID: String?
    
    // MARK: - Debouncing
    
    private var saveTimer: Timer?
    private var hasPendingSave: Bool = false
    
    // MARK: - Initialization
    
    init(levelID: Int, customLevelUUID: String?, levelViewModel: LevelViewModel) {
        self.levelID = levelID
        self.customLevelUUID = customLevelUUID
        self.levelViewModel = levelViewModel
    }
    
    // MARK: - Save State (Debounced)
    
    func saveState(
        currentBoard: String,
        notes: [Int: Set<Int>],
        colors: [Int: Int],
        crosses: [Int: Bool],
        markedCombinations: [String: Set<[Int]>],
        markedKillerCombinations: [String: Set<[Int]>],
        timeElapsed: Int
    ) {
        hasPendingSave = true
        saveTimer?.invalidate()
        
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.performSave(
                currentBoard: currentBoard,
                notes: notes,
                colors: colors,
                crosses: crosses,
                markedCombinations: markedCombinations,
                markedKillerCombinations: markedKillerCombinations,
                timeElapsed: timeElapsed
            )
        }
    }
    
    // MARK: - Immediate Save
    
    func saveStateImmediate(
        currentBoard: String,
        notes: [Int: Set<Int>],
        colors: [Int: Int],
        crosses: [Int: Bool],
        markedCombinations: [String: Set<[Int]>],
        markedKillerCombinations: [String: Set<[Int]>],
        timeElapsed: Int
    ) {
        saveTimer?.invalidate()
        hasPendingSave = false
        
        performSave(
            currentBoard: currentBoard,
            notes: notes,
            colors: colors,
            crosses: crosses,
            markedCombinations: markedCombinations,
            markedKillerCombinations: markedKillerCombinations,
            timeElapsed: timeElapsed
        )
    }
    
    // MARK: - Internal Save Logic
    
    private func performSave(
        currentBoard: String,
        notes: [Int: Set<Int>],
        colors: [Int: Int],
        crosses: [Int: Bool],
        markedCombinations: [String: Set<[Int]>],
        markedKillerCombinations: [String: Set<[Int]>],
        timeElapsed: Int
    ) {
        hasPendingSave = false
        
        // Encode data
        let notesDict = Dictionary(uniqueKeysWithValues: notes.map { (String($0.key), $0.value) })
        let colorsDict = Dictionary(uniqueKeysWithValues: colors.map { (String($0.key), $0.value) })
        
        let notesData = try? JSONEncoder().encode(notesDict)
        let colorData = try? JSONEncoder().encode(colorsDict)
        let markedCombinationsData = try? JSONEncoder().encode(markedCombinations)
        let killerMarkedCombinationsData = try? JSONEncoder().encode(markedKillerCombinations)
        let crossData = try? JSONEncoder().encode(crosses)
        
        // Save via LevelViewModel
        levelViewModel?.saveLevelProgress(
            levelId: levelID,
            customUUID: customLevelUUID,
            currentBoard: currentBoard,
            notesData: notesData,
            colorData: colorData,
            markedCombinationsData: markedCombinationsData,
            killerMarkedCombinationsData: killerMarkedCombinationsData,
            crossData: crossData,
            timeElapsed: timeElapsed
        )
    }
    
    // MARK: - Load State
    
    func loadSavedState(for level: SudokuLevel) -> SavedGameState? {
        guard let progress = level.userProgress,
              let timeElapsed = level.timeElapsed as? Int else {
            return nil
        }
        
        var notes: [Int: Set<Int>] = [:]
        var colors: [Int: Int] = [:]
        var crosses: [Int: Bool] = [:]
        var markedCombinations: [String: Set<[Int]>] = [:]
        var markedKillerCombinations: [String: Set<[Int]>] = [:]
        
        // Decode notes
        if let notesData = level.notesData {
            if let decodedStringNotes = try? JSONDecoder().decode([String: Set<Int>].self, from: notesData) {
                notes = Dictionary(uniqueKeysWithValues: decodedStringNotes.compactMap { (key, val) in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, val)
                })
            } else if let decodedNotes = try? JSONDecoder().decode([Int: Set<Int>].self, from: notesData) {
                notes = decodedNotes
            }
        }
        
        // Decode colors
        if let colorData = level.colorData {
            if let decodedStringColors = try? JSONDecoder().decode([String: Int].self, from: colorData) {
                colors = Dictionary(uniqueKeysWithValues: decodedStringColors.compactMap { (key, val) in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, val)
                })
            }
        }
        
        // Decode crosses
        if let crossData = level.crossData {
            crosses = (try? JSONDecoder().decode([Int: Bool].self, from: crossData)) ?? [:]
        }
        
        // Decode marked combinations
        if let markedData = level.markedCombinationsData {
            markedCombinations = (try? JSONDecoder().decode([String: Set<[Int]>].self, from: markedData)) ?? [:]
        }
        
        if let killerMarkedData = level.killerMarkedCombinationsData {
            markedKillerCombinations = (try? JSONDecoder().decode([String: Set<[Int]>].self, from: killerMarkedData)) ?? [:]
        }
        
        return SavedGameState(
            board: progress,
            notes: notes,
            colors: colors,
            crosses: crosses,
            markedCombinations: markedCombinations,
            markedKillerCombinations: markedKillerCombinations,
            timeElapsed: timeElapsed
        )
    }
    
    // MARK: - Game Session
    
    func saveGameSession(
        levelID: Int,
        isCustomLevel: Bool,
        customLevelId: String?,
        userBoard: String,
        notesData: Data?,
        colorData: Data?,
        timeElapsed: Int
    ) {
        let session = GameSession(
            levelID: levelID,
            isCustomLevel: isCustomLevel,
            customLevelId: customLevelId,
            userBoard: userBoard,
            notesData: notesData,
            colorData: colorData,
            timeElapsed: timeElapsed,
            timestamp: Date().timeIntervalSince1970
        )
        
        levelViewModel?.saveActiveSession(session: session)
    }
    
    // MARK: - Cleanup
    
    func flushPendingSave(
        currentBoard: String,
        notes: [Int: Set<Int>],
        colors: [Int: Int],
        crosses: [Int: Bool],
        markedCombinations: [String: Set<[Int]>],
        markedKillerCombinations: [String: Set<[Int]>],
        timeElapsed: Int
    ) {
        if hasPendingSave {
            saveStateImmediate(
                currentBoard: currentBoard,
                notes: notes,
                colors: colors,
                crosses: crosses,
                markedCombinations: markedCombinations,
                markedKillerCombinations: markedKillerCombinations,
                timeElapsed: timeElapsed
            )
        }
    }
    
    deinit {
        saveTimer?.invalidate()
        saveTimer = nil
    }
}

// MARK: - Supporting Types

struct SavedGameState {
    let board: String
    let notes: [Int: Set<Int>]
    let colors: [Int: Int]
    let crosses: [Int: Bool]
    let markedCombinations: [String: Set<[Int]>]
    let markedKillerCombinations: [String: Set<[Int]>]
    let timeElapsed: Int
}
