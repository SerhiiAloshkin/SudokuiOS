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
    
    // MARK: - Parity Data (for Odd/Even)
    var parityData: Data? = nil
    
    // MARK: - Adapter: CustomSudokuLevel → SudokuLevel
    
    func toSudokuLevel() -> SudokuLevel {
        // Determine primary rule type
        var primaryRule: SudokuRuleType = ruleType
        var typesArray: [SudokuRuleType] = []
        
        // Build types array from toggle flags
        if isNonConsecutive {
            typesArray.append(.nonConsecutive)
            primaryRule = .nonConsecutive
        }
        if isKing {
            typesArray.append(.king)
            if primaryRule == .classic { primaryRule = .king }
        }
        if isKnight {
            typesArray.append(.knight)
            if primaryRule == .classic { primaryRule = .knight }
        }
        
        // Decode variant data
        let thermos: [[[Int]]]? = {
            guard let data = thermoPathsData else { return nil }
            return try? JSONDecoder().decode([[[Int]]].self, from: data)
        }()
        
        let arrowsList: [SudokuLevel.Arrow]? = {
            guard let data = arrowsData else { return nil }
            return try? JSONDecoder().decode([SudokuLevel.Arrow].self, from: data)
        }()
        
        let cagesList: [SudokuLevel.Cage]? = {
            guard let data = cagesData else { return nil }
            return try? JSONDecoder().decode([SudokuLevel.Cage].self, from: data)
        }()
        
        let whiteDotsList: [SudokuLevel.KropkiDot]? = {
            guard let data = whiteDotsData else { return nil }
            return try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: data)
        }()
        
        let blackDotsList: [SudokuLevel.KropkiDot]? = {
            guard let data = blackDotsData else { return nil }
            return try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: data)
        }()
        
        let rowClues: [Int]? = {
            guard let data = sandwichRowCluesData else { return nil }
            return try? JSONDecoder().decode([Int].self, from: data)
        }()
        
        let colClues: [Int]? = {
            guard let data = sandwichColCluesData else { return nil }
            return try? JSONDecoder().decode([Int].self, from: data)
        }()
        
        // Build parity string from parityData
        let parityString: String? = {
            guard let data = parityData else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        
        // Add variant-specific primary rules ONLY when data actually exists
        if let t = thermos, !t.isEmpty, !typesArray.contains(.thermo) {
            typesArray.append(.thermo)
        }
        if let a = arrowsList, !a.isEmpty, !typesArray.contains(.arrow) {
            typesArray.append(.arrow)
        }
        if let c = cagesList, !c.isEmpty, !typesArray.contains(.killer) {
            typesArray.append(.killer)
        }
        // Only add Kropki if dots actually exist and are non-empty
        let hasWhiteDots = whiteDotsList != nil && !whiteDotsList!.isEmpty
        let hasBlackDots = blackDotsList != nil && !blackDotsList!.isEmpty
        if (hasWhiteDots || hasBlackDots) && !typesArray.contains(.kropki) {
            typesArray.append(.kropki)
        }
        if let p = parityString, p.contains(where: { $0 != "0" }), !typesArray.contains(.oddEven) {
            typesArray.append(.oddEven)
        }
        
        // Dynamic Sandwich Inference
        let hasRowClues = rowClues != nil && !rowClues!.isEmpty && rowClues!.contains(where: { $0 > 0 })
        let hasColClues = colClues != nil && !colClues!.isEmpty && colClues!.contains(where: { $0 > 0 })
        if (hasRowClues || hasColClues) && !typesArray.contains(.sandwich) {
            typesArray.append(.sandwich)
        }
        
        // De-duplicate types array
        typesArray = Array(Set(typesArray)).sorted(by: { $0.rawValue < $1.rawValue }) // Set for uniqueness, sort for stability
        
        // Use unique negative ID from UUID hash to avoid collisions
        let uniqueID = -abs(id.hashValue % 1_000) - 1
        
        var level = SudokuLevel(
            id: uniqueID,
            customTitle: levelName,
            customUUID: self.id.uuidString,
            isLocked: false,
            isSolved: isSolved,
            board: board,
            solution: solution,
            difficulty: difficulty,
            ruleType: primaryRule
        )
        
        level.types = typesArray
        level.thermoPaths = thermos
        level.arrows = arrowsList
        level.cages = cagesList
        level.white_dots = whiteDotsList
        level.black_dots = blackDotsList
        level.rowClues = rowClues
        level.colClues = colClues
        level.parity = parityString
        
        return level
    }
}
