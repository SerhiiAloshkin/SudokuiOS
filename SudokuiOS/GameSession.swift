import Foundation

struct GameSession: Codable {
    let levelID: Int
    let isCustomLevel: Bool
    let customLevelId: String? // UUID string
    let timestamp: Double
    
    enum CodingKeys: String, CodingKey {
        case levelID
        case isCustomLevel
        case customLevelId
        case timestamp
    }
    
    init(levelID: Int, isCustomLevel: Bool, customLevelId: String?, timestamp: Double = Date().timeIntervalSince1970) {
        self.levelID = levelID
        self.isCustomLevel = isCustomLevel
        self.customLevelId = customLevelId
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelID = try container.decode(Int.self, forKey: .levelID)
        isCustomLevel = try container.decodeIfPresent(Bool.self, forKey: .isCustomLevel) ?? false
        customLevelId = try container.decodeIfPresent(String.self, forKey: .customLevelId)
        timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp) ?? Date().timeIntervalSince1970
    }
}
