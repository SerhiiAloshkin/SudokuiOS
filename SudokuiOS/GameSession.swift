import Foundation

struct GameSession: Codable, Hashable {
    let levelID: Int
    let isCustomLevel: Bool
    let customLevelId: String? // UUID string
    let timestamp: Double
    
    // State Persistence
    var userBoard: String?
    var notesData: Data?
    var colorData: Data?
    var markedCombinationsData: Data?
    var killerMarkedCombinationsData: Data?
    var crossData: Data?
    var timeElapsed: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case levelID
        case isCustomLevel
        case customLevelId
        case timestamp
        case userBoard
        case notesData
        case colorData
        case markedCombinationsData
        case killerMarkedCombinationsData
        case crossData
        case timeElapsed
    }
    
    init(levelID: Int, isCustomLevel: Bool, customLevelId: String?, userBoard: String? = nil, timeElapsed: Int = 0, timestamp: Double = Date().timeIntervalSince1970) {
        self.levelID = levelID
        self.isCustomLevel = isCustomLevel
        self.customLevelId = customLevelId
        self.userBoard = userBoard
        self.timeElapsed = timeElapsed
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelID = try container.decode(Int.self, forKey: .levelID)
        isCustomLevel = try container.decodeIfPresent(Bool.self, forKey: .isCustomLevel) ?? false
        customLevelId = try container.decodeIfPresent(String.self, forKey: .customLevelId)
        timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp) ?? Date().timeIntervalSince1970
        userBoard = try container.decodeIfPresent(String.self, forKey: .userBoard)
        notesData = try container.decodeIfPresent(Data.self, forKey: .notesData)
        colorData = try container.decodeIfPresent(Data.self, forKey: .colorData)
        markedCombinationsData = try container.decodeIfPresent(Data.self, forKey: .markedCombinationsData)
        killerMarkedCombinationsData = try container.decodeIfPresent(Data.self, forKey: .killerMarkedCombinationsData)
        crossData = try container.decodeIfPresent(Data.self, forKey: .crossData)
        timeElapsed = try container.decodeIfPresent(Int.self, forKey: .timeElapsed) ?? 0
    }
}
