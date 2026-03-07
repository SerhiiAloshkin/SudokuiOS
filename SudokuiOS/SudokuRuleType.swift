import Foundation

enum SudokuRuleType: String, Codable, CaseIterable {
    case classic = "classic"
    case sandwich = "sandwich"
    case arrow = "arrow"
    case thermo = "thermo"
    case killer = "killer"
    case nonConsecutive = "non-consecutive"
    case kropki = "kropki"
    case oddEven = "odd-even"
    case knight = "knight"
    case king = "king"
    
    // Custom initializer to map legacy/variant strings to the strict Enum
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self).lowercased()
        
        self = SudokuRuleType.from(string: rawString)
    }
    
    // Helper for manual initialization from loose strings (Legacy single-return)
    static func from(string: String?) -> SudokuRuleType {
        let rules = allRules(from: string)
        return rules.first ?? .classic
    }
    
    // Parses and returns ALL valid rule types from a comma-separated string, removing duplicates
    static func allRules(from string: String?) -> [SudokuRuleType] {
        guard let raw = string?.lowercased() else { return [.classic] }
        
        let parts = raw.components(separatedBy: ",")
        var results: [SudokuRuleType] = []
        
        // 1. Parse Heavy Variant Rules
        for part in parts {
            let cleanPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            switch cleanPart {
            case "sandwich": results.append(.sandwich)
            case "arrow": results.append(.arrow)
            case "thermo": results.append(.thermo)
            case "killer": results.append(.killer)
            case "kropki": results.append(.kropki)
            case "odd-even", "odd_even": results.append(.oddEven)
            case "knight", "knights_move", "knight_sudoku": results.append(.knight)
            case "king", "kings_move", "king_sudoku": results.append(.king)
            default: continue
            }
        }
        
        // 2. Parse Modifiers
        for part in parts {
            let cleanPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPart == "non-consecutive" || cleanPart == "non_consecutive" {
                results.append(.nonConsecutive)
            }
        }
        
        // 3. Fallbacks
        if results.isEmpty {
            if raw == "variant" || parts.contains("classic") {
                results.append(.classic)
            } else {
                print("WARNING: Unknown rule type(s) '\(raw)', defaulting to classic.")
                results.append(.classic)
            }
        }
        
        // Filter duplicates while preserving order
        var uniqueResults: [SudokuRuleType] = []
        var seen = Set<SudokuRuleType>()
        
        for rule in results {
            if !seen.contains(rule) {
                seen.insert(rule)
                uniqueResults.append(rule)
            }
        }
        
        return uniqueResults
    }
    
    // Helper to get display name
    var displayName: String {
        switch self {
        case .classic: return "Classic Sudoku"
        case .sandwich: return "Sandwich Sudoku"
        case .arrow: return "Arrow Sudoku"
        case .thermo: return "Thermo Sudoku"
        case .killer: return "Killer Sudoku"
        case .nonConsecutive: return "Non-Consecutive"
        case .kropki: return "Kropki Sudoku"
        case .oddEven: return "Odd-Even Sudoku"
        case .knight: return "Knight Sudoku"
        case .king: return "King Sudoku"
        }
    }
    
    // Helper for concise labels
    var shortName: String {
        switch self {
        case .classic: return "Classic"
        case .sandwich: return "Sandwich"
        case .arrow: return "Arrow"
        case .thermo: return "Thermo"
        case .killer: return "Killer"
        case .nonConsecutive: return "Non-Cons"
        case .kropki: return "Kropki"
        case .oddEven: return "Odd/Even"
        case .knight: return "Knight"
        case .king: return "King"
        }
    }
    
    // Helper for icons (Centralized)
    var iconName: String {
        switch self {
        case .classic: return "square.grid.3x3.fill"
        case .sandwich: return "square.stack.3d.up"
        case .arrow: return "arrow.up.forward.circle"
        case .thermo: return "thermometer"
        case .killer: return "square.dashed"
        case .nonConsecutive: return "squareshape.split.2x2"
        case .kropki: return "circle.grid.2x1" // Needs custom or specific
        case .oddEven: return "circle.square"
        case .knight: return "knight_icon"
        case .king: return "crown.fill"
        }
    }
}
