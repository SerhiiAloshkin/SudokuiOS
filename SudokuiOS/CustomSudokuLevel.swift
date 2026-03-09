import Foundation
import SwiftData

@Model
final class CustomSudokuLevel: Identifiable {
    @Attribute(.unique) public var id: UUID
    var levelName: String = "Untitled"
    var createdAt: Date
    var bestTime: Double
    var isSolved: Bool
    
    // Board State
    var board: String
    var solution: String?
    var difficulty: String
    
    // Core Rule Type
    var ruleTypeRawValue: String
    var ruleType: SudokuRuleType {
        get { SudokuRuleType(rawValue: ruleTypeRawValue) ?? .classic }
        set { ruleTypeRawValue = newValue.rawValue }
    }
    
    // Variant Toggles
    var isNonConsecutive: Bool
    var isKing: Bool = false
    var isKnight: Bool = false
    
    // Variant Data (Encoded as JSON Strings due to SwiftData nested struct limitations)
    var thermoPathsData: Data?
    var arrowsData: Data?
    var cagesData: Data?
    var whiteDotsData: Data?
    var blackDotsData: Data?
    var sandwichRowCluesData: Data?
    var sandwichColCluesData: Data?
    
    init(
        id: UUID = UUID(),
        levelName: String = "Untitled",
        createdAt: Date = Date(),
        bestTime: Double = 0.0,
        isSolved: Bool = false,
        board: String,
        solution: String? = nil,
        difficulty: String = "Custom",
        ruleType: SudokuRuleType = .classic,
        isNonConsecutive: Bool = false,
        isKing: Bool = false,
        isKnight: Bool = false,
        thermoPathsData: Data? = nil,
        arrowsData: Data? = nil,
        cagesData: Data? = nil,
        whiteDotsData: Data? = nil,
        blackDotsData: Data? = nil,
        sandwichRowCluesData: Data? = nil,
        sandwichColCluesData: Data? = nil
    ) {
        self.id = id
        self.levelName = levelName
        self.createdAt = createdAt
        self.bestTime = bestTime
        self.isSolved = isSolved
        self.board = board
        self.solution = solution
        self.difficulty = difficulty
        self.ruleTypeRawValue = ruleType.rawValue
        self.isNonConsecutive = isNonConsecutive
        self.isKing = isKing
        self.isKnight = isKnight
        self.thermoPathsData = thermoPathsData
        self.arrowsData = arrowsData
        self.cagesData = cagesData
        self.whiteDotsData = whiteDotsData
        self.blackDotsData = blackDotsData
        self.sandwichRowCluesData = sandwichRowCluesData
        self.sandwichColCluesData = sandwichColCluesData
    }
}
