import Foundation

public enum VerificationStatus: String, Codable, Equatable, Sendable {
    case unverified
    case pending
    case verified
    case failed
}

public enum VerificationMethod: String, Codable, Equatable, Sendable {
    case manual
    case boardingPassPhoto = "boarding_pass_photo"
    case ticketScreenshot = "ticket_screenshot"
    case itineraryScreenshot = "itinerary_screenshot"
}

public enum PublishScope: String, Codable, Equatable, Sendable {
    case privateCard = "private_card"
    case sameFlight = "same_flight"
}

public enum TextMode: String, Codable, Equatable, Sendable {
    case oneLine = "one_line"
    case template
    case voiceTranscript = "voice_transcript"
    case freeText = "free_text"
}

public enum OfflineStatus: String, Codable, Equatable, Sendable {
    case localOnly = "local_only"
    case syncing
    case synced
    case syncFailed = "sync_failed"
}

public struct FlightContext: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var flightNumber: String?
    public var route: String?
    public var departureDate: Date?
    public var verificationStatus: VerificationStatus

    public init(
        id: UUID = UUID(),
        flightNumber: String? = nil,
        route: String? = nil,
        departureDate: Date? = nil,
        verificationStatus: VerificationStatus = .unverified
    ) {
        self.id = id
        self.flightNumber = flightNumber
        self.route = route
        self.departureDate = departureDate
        self.verificationStatus = verificationStatus
    }
}

public struct FlightProof: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let flightContextID: UUID
    public let method: VerificationMethod
    public let sourceImageHash: String?
    public let redactedImagePath: String?
    public let verifiedAt: Date

    public init(
        id: UUID = UUID(),
        flightContextID: UUID,
        method: VerificationMethod,
        sourceImageHash: String? = nil,
        redactedImagePath: String? = nil,
        verifiedAt: Date = Date()
    ) {
        self.id = id
        self.flightContextID = flightContextID
        self.method = method
        self.sourceImageHash = sourceImageHash
        self.redactedImagePath = redactedImagePath
        self.verifiedAt = verifiedAt
    }
}

public struct CloudPost: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var flightContextID: UUID?
    public var flightProofID: UUID?
    public var publishScope: PublishScope
    public var text: String
    public var textMode: TextMode
    public var headlineQuote: String
    public var cardTemplateID: String
    public var offlineStatus: OfflineStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        flightContextID: UUID? = nil,
        flightProofID: UUID? = nil,
        publishScope: PublishScope = .privateCard,
        text: String,
        textMode: TextMode = .oneLine,
        headlineQuote: String? = nil,
        cardTemplateID: String = "boarding_postcard",
        offlineStatus: OfflineStatus = .localOnly,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.flightContextID = flightContextID
        self.flightProofID = flightProofID
        self.publishScope = publishScope
        self.text = text
        self.textMode = textMode
        self.headlineQuote = headlineQuote ?? CloudPost.defaultHeadline(from: text)
        self.cardTemplateID = cardTemplateID
        self.offlineStatus = offlineStatus
        self.createdAt = createdAt
    }

    private static func defaultHeadline(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 28 else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 28)
        return String(trimmed[..<end]) + "..."
    }
}

public struct CloudCard: Codable, Equatable, Sendable {
    public let postID: UUID
    public let templateID: String
    public let headlineQuote: String
    public let metadata: String
    public let publicIdentityLabel: String

    public init(
        postID: UUID,
        templateID: String,
        headlineQuote: String,
        metadata: String,
        publicIdentityLabel: String
    ) {
        self.postID = postID
        self.templateID = templateID
        self.headlineQuote = headlineQuote
        self.metadata = metadata
        self.publicIdentityLabel = publicIdentityLabel
    }
}

public struct FlightSpacePost: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let flightContextID: UUID?
    public let publishScope: PublishScope
    public let text: String
    public let headlineQuote: String
    public let textMode: TextMode
    public let cardTemplateID: String
    public let publicIdentityLabel: String
    public let commentCount: Int
    public let createdAt: Date
    public let publishedAt: Date?

    public init(
        id: UUID,
        flightContextID: UUID?,
        publishScope: PublishScope,
        text: String,
        headlineQuote: String,
        textMode: TextMode,
        cardTemplateID: String,
        publicIdentityLabel: String,
        commentCount: Int,
        createdAt: Date,
        publishedAt: Date?
    ) {
        self.id = id
        self.flightContextID = flightContextID
        self.publishScope = publishScope
        self.text = text
        self.headlineQuote = headlineQuote
        self.textMode = textMode
        self.cardTemplateID = cardTemplateID
        self.publicIdentityLabel = publicIdentityLabel
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case flightContextID = "flight_context_id"
        case publishScope = "publish_scope"
        case text
        case headlineQuote = "headline_quote"
        case textMode = "text_mode"
        case cardTemplateID = "card_template_id"
        case publicIdentityLabel = "public_identity_label"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }
}

public enum SameFlightBlockReason: String, Codable, Equatable, Sendable {
    case unverified
    case noFlightContext
    case noNetwork
}
