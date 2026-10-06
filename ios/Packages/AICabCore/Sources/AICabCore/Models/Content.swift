import Foundation

/// How deep a definition goes. Every term ships with one definition per level.
public enum Level: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, builder, research

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .beginner: "Beginner"
        case .builder: "Builder"
        case .research: "Research"
        }
    }

    public var blurb: String {
        switch self {
        case .beginner: "Plain English, everyday analogies"
        case .builder: "How engineers actually use it"
        case .research: "The math and the papers"
        }
    }

    /// Research-depth definitions are part of Pro.
    public var isPremium: Bool { self == .research }
}

/// How advanced a term is. Drives which terms the feed favours for each level.
public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case beginner, intermediate, pro

    public var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .pro: "Pro"
        }
    }
}

public struct Definitions: Codable, Hashable, Sendable {
    public var beginner: String
    public var builder: String
    public var research: String

    public init(beginner: String, builder: String, research: String) {
        self.beginner = beginner
        self.builder = builder
        self.research = research
    }

    public subscript(level: Level) -> String {
        switch level {
        case .beginner: beginner
        case .builder: builder
        case .research: research
        }
    }
}

public struct Term: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var term: String
    public var expansion: String?
    public var ipa: String?
    public var pos: String
    public var definitions: Definitions
    public var analogy: String?
    public var example: String?
    public var origin: String?
    public var difficulty: Difficulty
    public var topics: [String]
    public var related: [String]
    public var contrastWith: [String]
    public var isPremium: Bool
    public var trendingScore: Double
    /// `yyyy-MM-dd` the term entered the catalog; drives the "New" tag.
    public var addedAt: String?
    /// User-authored ("Your own words").
    public var isCustom: Bool

    public init(
        id: String,
        term: String,
        expansion: String? = nil,
        ipa: String? = nil,
        pos: String = "n.",
        definitions: Definitions,
        analogy: String? = nil,
        example: String? = nil,
        origin: String? = nil,
        difficulty: Difficulty = .beginner,
        topics: [String] = [],
        related: [String] = [],
        contrastWith: [String] = [],
        isPremium: Bool = false,
        trendingScore: Double = 0,
        addedAt: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.term = term
        self.expansion = expansion
        self.ipa = ipa
        self.pos = pos
        self.definitions = definitions
        self.analogy = analogy
        self.example = example
        self.origin = origin
        self.difficulty = difficulty
        self.topics = topics
        self.related = related
        self.contrastWith = contrastWith
        self.isPremium = isPremium
        self.trendingScore = trendingScore
        self.addedAt = addedAt
        self.isCustom = isCustom
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, expansion, ipa, pos, definitions, analogy, example, origin, difficulty
        case topics, related, contrastWith, isPremium, trendingScore, addedAt, isCustom
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        term = try c.decode(String.self, forKey: .term)
        expansion = try c.decodeIfPresent(String.self, forKey: .expansion)
        ipa = try c.decodeIfPresent(String.self, forKey: .ipa)
        pos = try c.decodeIfPresent(String.self, forKey: .pos) ?? "n."
        definitions = try c.decode(Definitions.self, forKey: .definitions)
        analogy = try c.decodeIfPresent(String.self, forKey: .analogy)
        example = try c.decodeIfPresent(String.self, forKey: .example)
        origin = try c.decodeIfPresent(String.self, forKey: .origin)
        difficulty = try c.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .beginner
        topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        related = try c.decodeIfPresent([String].self, forKey: .related) ?? []
        contrastWith = try c.decodeIfPresent([String].self, forKey: .contrastWith) ?? []
        isPremium = try c.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        trendingScore = try c.decodeIfPresent(Double.self, forKey: .trendingScore) ?? 0
        addedAt = try c.decodeIfPresent(String.self, forKey: .addedAt)
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    public func definition(at level: Level) -> String { definitions[level] }

    /// `RAG (n.)` style heading used by notifications and widgets.
    public var headline: String { "\(term) (\(pos))" }

    public func isNew(relativeTo now: Date, within days: Int = 14, calendar: Calendar = .current) -> Bool {
        guard let addedAt, let date = DayKey.date(from: addedAt, calendar: calendar) else { return false }
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else { return false }
        return date >= cutoff
    }
}

public enum TopicSection: String, Codable, CaseIterable, Sendable {
    case trending, foundations, build, frontier, world

    public var title: String {
        switch self {
        case .trending: "Trending"
        case .foundations: "Foundations"
        case .build: "Build"
        case .frontier: "Frontier"
        case .world: "AI & the world"
        }
    }
}

/// Colour family used by a topic's illustration.
public enum ArtPalette: String, Codable, CaseIterable, Sendable {
    case teal, coral, cream, olive
}

public struct Topic: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var eyebrow: String?
    public var section: TopicSection
    /// SF Symbol name for the illustration's hero object.
    public var symbol: String
    public var palette: ArtPalette
    public var isPremium: Bool
    public var order: Int

    public init(id: String, title: String, eyebrow: String? = nil, section: TopicSection,
                symbol: String, palette: ArtPalette = .teal, isPremium: Bool = false, order: Int = 0) {
        self.id = id
        self.title = title
        self.eyebrow = eyebrow
        self.section = section
        self.symbol = symbol
        self.palette = palette
        self.isPremium = isPremium
        self.order = order
    }
}

public struct Chapter: Codable, Hashable, Identifiable, Sendable {
    public var number: Int
    public var title: String
    public var subtitle: String
    public var termIds: [String]
    public var isPremium: Bool
    /// SF Symbols scattered around the chapter's path.
    public var decorations: [String]

    public var id: Int { number }

    public init(number: Int, title: String, subtitle: String, termIds: [String],
                isPremium: Bool = false, decorations: [String] = []) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.termIds = termIds
        self.isPremium = isPremium
        self.decorations = decorations
    }
}

/// The unit of content delivery: bundled in the app and refreshed from the CDN.
public struct ContentPack: Codable, Sendable {
    public var version: Int
    public var generatedAt: String
    public var terms: [Term]
    public var topics: [Topic]
    public var chapters: [Chapter]

    public init(version: Int, generatedAt: String, terms: [Term], topics: [Topic], chapters: [Chapter]) {
        self.version = version
        self.generatedAt = generatedAt
        self.terms = terms
        self.topics = topics
        self.chapters = chapters
    }

    public static let empty = ContentPack(version: 0, generatedAt: "", terms: [], topics: [], chapters: [])
}
