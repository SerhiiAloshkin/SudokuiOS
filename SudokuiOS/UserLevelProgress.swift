import Foundation
import SwiftData
import Observation

@Model
final class UserLevelProgress {
    @Attribute(.unique) var levelID: Int
    var isSolved: Bool
    var bestTime: Double
    var currentUserBoard: String? // Optional string for mid-game progress
    var notesData: Data? // JSON Encoded [Int: Set<Int>]
    var colorData: Data? // JSON Encoded [Int: String] (Hex or color name)
    var markedCombinationsData: Data? // JSON Encoded [String: Set<[Int]>] (Sandwich Helper State)
    var crossData: Data? // JSON Encoded [Int: Bool] (Sandwich Cross State)
    var isAdUnlocked: Bool = false // Rewarded Ad Unlock Status
    var isUnlocked: Bool = false // Sticky Unlock Status (Maintains access even if prev level reset)
    var timeElapsed: Int = 0 
    
    @Relationship(deleteRule: .cascade, inverse: \MoveHistory.levelProgress)
    var moves: [MoveHistory]? = []
    
    init(levelID: Int, isSolved: Bool = false, bestTime: Double = 0.0, currentUserBoard: String? = nil, notesData: Data? = nil, colorData: Data? = nil, markedCombinationsData: Data? = nil, crossData: Data? = nil, isAdUnlocked: Bool = false, isUnlocked: Bool = false, timeElapsed: Int = 0) {
        self.levelID = levelID
        self.isSolved = isSolved
        self.bestTime = bestTime
        self.currentUserBoard = currentUserBoard
        self.notesData = notesData
        self.colorData = colorData
        self.markedCombinationsData = markedCombinationsData
        self.crossData = crossData
        self.isAdUnlocked = isAdUnlocked
        self.isUnlocked = isUnlocked
        self.timeElapsed = timeElapsed
        self.moves = []
    }
}
