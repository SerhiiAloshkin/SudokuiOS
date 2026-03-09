import Foundation
import SwiftData
import Combine

enum LevelFilter: String, CaseIterable {
    case all = "All Levels"
    case solved = "Solved"
    case unsolved = "Unsolved"
    case classic = "Classic"
    case nonConsecutive = "Non-Consecutive"
    case sandwich = "Sandwich"
    case thermo = "Thermo"
    case arrow = "Arrow"
    case killer = "Killer"
    case kropki = "Kropki"
    case oddEven = "Odd-Even"
    case knight = "Knight"
    case king = "King"
    case custom = "Custom"
    
    var next: LevelFilter {
        let all = LevelFilter.allCases
        if let index = all.firstIndex(of: self) {
            let nextIndex = (index + 1) % all.count
            return all[nextIndex]
        }
        return .all
    }
}

class LevelSelectionViewModel: ObservableObject {
    @Published var currentFilter: LevelFilter = .all
    @Published var levels: [SudokuLevel] = []
    @Published var customLevels: [CustomSudokuLevel] = []
    
    init(levels: [SudokuLevel] = [], customLevels: [CustomSudokuLevel] = []) {
        self.levels = levels
        self.customLevels = customLevels
    }
    
    var filteredLevels: [SudokuLevel] {
        switch currentFilter {
        case .all:
            return levels
        case .solved:
            return levels.filter { $0.isSolved }
        case .unsolved:
            return levels.filter { !$0.isSolved }
        case .classic:
            return levels.filter { $0.ruleType == .classic }
        case .nonConsecutive:
            return levels.filter { $0.ruleType == .nonConsecutive }
        case .sandwich:
            return levels.filter { $0.ruleType == .sandwich }
        case .thermo:
            return levels.filter { $0.ruleType == .thermo }
        case .arrow:
            return levels.filter { $0.ruleType == .arrow }
        case .killer:
            return levels.filter { $0.ruleType == .killer }
        case .kropki:
            return levels.filter { $0.ruleType == .kropki }
        case .oddEven:
            return levels.filter { $0.ruleType == .oddEven }
        case .knight:
            return levels.filter { $0.ruleType == .knight }
        case .king:
            return levels.filter { $0.ruleType == .king }
        case .custom:
            return customLevels.enumerated().map { index, custom in
                SudokuLevel(
                    id: 9000 + index, // Offset for custom IDs so they dont overlap with 1-600
                    isLocked: false,
                    isSolved: custom.isSolved,
                    board: custom.board,
                    ruleType: custom.ruleType
                )
            }
        }
    }
    
    // Returns the ID of the first unsolved level in the current filtered list
    var firstUnsolvedLevelID: Int? {
        return filteredLevels.first(where: { !$0.isSolved })?.id
    }
    
    func cycleFilter() {
        currentFilter = currentFilter.next
    }
    
    func updateLevels(_ newLevels: [SudokuLevel], customLevels: [CustomSudokuLevel] = []) {
        self.levels = newLevels
        self.customLevels = customLevels
    }
}
