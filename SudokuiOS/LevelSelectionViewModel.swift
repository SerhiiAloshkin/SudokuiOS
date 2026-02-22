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
    
    init(levels: [SudokuLevel] = []) {
        self.levels = levels
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
        }
    }
    
    // Returns the ID of the first unsolved level in the current filtered list
    var firstUnsolvedLevelID: Int? {
        return filteredLevels.first(where: { !$0.isSolved })?.id
    }
    
    func cycleFilter() {
        currentFilter = currentFilter.next
    }
    
    func updateLevels(_ newLevels: [SudokuLevel]) {
        self.levels = newLevels
    }
}
