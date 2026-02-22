import Foundation
import SwiftData
import Observation

@Model
final class MoveHistory {
    var timestamp: Date
    var orderIndex: Int
    var cellIndex: Int
    var moveType: String // "Value", "Note", "Color"
    var oldValue: String?
    var newValue: String?
    var batchID: UUID?
    
    var levelProgress: UserLevelProgress?
    
    init(timestamp: Date = Date(), orderIndex: Int = 0, cellIndex: Int, moveType: String, oldValue: String? = nil, newValue: String? = nil, batchID: UUID? = nil) {
        self.timestamp = timestamp
        self.orderIndex = orderIndex
        self.cellIndex = cellIndex
        self.moveType = moveType
        self.oldValue = oldValue
        self.newValue = newValue
        self.batchID = batchID
    }
}
