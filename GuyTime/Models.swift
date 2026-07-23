import Foundation

enum FeedingSide: String, Codable, CaseIterable, Identifiable {
    case right = "ימין"
    case left = "שמאל"
    var id: String { rawValue }
}

enum BottleType: String, Codable, CaseIterable, Identifiable {
    case expressed = "חלב אם שאוב"
    case formula = "תמ״ל"
    var id: String { rawValue }
}

enum FeedingKind: Codable, Equatable {
    case nursing(side: FeedingSide, duration: TimeInterval)
    case bottle(type: BottleType, milliliters: Int)

    private enum CodingKeys: String, CodingKey { case type, side, duration, bottleType, milliliters }
    private enum KindType: String, Codable { case nursing, bottle }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(KindType.self, forKey: .type) {
        case .nursing:
            self = .nursing(
                side: try c.decode(FeedingSide.self, forKey: .side),
                duration: try c.decode(TimeInterval.self, forKey: .duration)
            )
        case .bottle:
            self = .bottle(
                type: try c.decode(BottleType.self, forKey: .bottleType),
                milliliters: try c.decode(Int.self, forKey: .milliliters)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .nursing(side, duration):
            try c.encode(KindType.nursing, forKey: .type)
            try c.encode(side, forKey: .side)
            try c.encode(duration, forKey: .duration)
        case let .bottle(type, milliliters):
            try c.encode(KindType.bottle, forKey: .type)
            try c.encode(type, forKey: .bottleType)
            try c.encode(milliliters, forKey: .milliliters)
        }
    }
}

struct FeedingEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var kind: FeedingKind
}

struct ActiveNursing: Codable, Equatable {
    var side: FeedingSide
    var startedAt: Date
}
