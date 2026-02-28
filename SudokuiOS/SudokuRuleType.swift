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
    
    // Helper for manual initialization from loose strings
    static func from(string: String?) -> SudokuRuleType {
        guard let raw = string?.lowercased() else { return .classic }
        
        let parts = raw.components(separatedBy: ",")
        
        // First Priority: Heavy variant rules (determines the display name)
        for part in parts {
            let cleanPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            switch cleanPart {
            case "sandwich": return .sandwich
            case "arrow": return .arrow
            case "thermo": return .thermo
            case "killer": return .killer
            case "kropki": return .kropki
            case "odd-even", "odd_even": return .oddEven
            case "knight", "knights_move", "knight_sudoku": return .knight
            case "king", "kings_move", "king_sudoku": return .king
            default: continue
            }
        }
        
        // Second Priority: modifiers like non-consecutive
        for part in parts {
            let cleanPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPart == "non-consecutive" || cleanPart == "non_consecutive" {
                return .nonConsecutive
            }
        }
        
        if raw == "variant" {
            return .classic
        }
        
        if parts.contains("classic") {
            return .classic
        }
            
        print("WARNING: Unknown rule type '\(raw)', defaulting to classic.")
        return .classic
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
