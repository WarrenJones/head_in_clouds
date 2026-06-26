import Foundation

public struct AnalyticsEvent: Equatable {
    public let name: String
    public let properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

public protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

public final class FanoutAnalyticsTracker: AnalyticsTracking {
    private let trackers: [AnalyticsTracking]

    public init(trackers: [AnalyticsTracking]) {
        self.trackers = trackers
    }

    public func track(_ event: AnalyticsEvent) {
        trackers.forEach { tracker in
            tracker.track(event)
        }
    }
}

public enum EventPropertySanitizer {
    private static let exactSeatPattern = #"(^|[^0-9A-Za-z])(?:[1-9]|[1-9]\d)[A-F](?=$|[^0-9A-Za-z])"#

    public static let forbiddenKeys: Set<String> = [
        "password",
        "email",
        "phone_e164",
        "credit_card",
        "id_card",
        "passport_no",
        "ticket_no",
        "api_token",
        "seat_number",
        "ocr_raw_text"
    ]

    public static func sanitize(_ properties: [String: String]) -> [String: String] {
        properties.filter { key, value in
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !forbiddenKeys.contains(normalizedKey) &&
                !value.contains("@") &&
                value.range(of: exactSeatPattern, options: [.regularExpression, .caseInsensitive]) == nil
        }
    }
}

public enum PublicTextSanitizer {
    private static let exactSeatTextPattern = #"(^|[^0-9A-Za-z])(?:[1-9]|[1-9]\d)[A-F](?=$|[^0-9A-Za-z])"#

    public static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: exactSeatTextPattern,
                with: "$1某个座位",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"[^\s@]+@[^\s@]+\.[^\s@]+"#,
                with: "已隐藏联系方式",
                options: .regularExpression
            )
    }
}

public struct EventEnvelope: Codable, Equatable {
    public let id: UUID
    public let eventName: String
    public let properties: [String: String]
    public let clientTime: Date
    public let appVersion: String
    public let platform: String
    public let userIDHash: String?
    public let deviceIDHash: String?

    public init(
        id: UUID = UUID(),
        eventName: String,
        properties: [String: String],
        clientTime: Date = Date(),
        appVersion: String,
        platform: String = "ios",
        userIDHash: String? = nil,
        deviceIDHash: String? = nil
    ) {
        self.id = id
        self.eventName = eventName
        self.properties = EventPropertySanitizer.sanitize(properties)
        self.clientTime = clientTime
        self.appVersion = appVersion
        self.platform = platform
        self.userIDHash = userIDHash
        self.deviceIDHash = deviceIDHash
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case eventName = "event_name"
        case properties
        case clientTime = "client_time"
        case appVersion = "app_version"
        case platform
        case userIDHash = "user_id_hash"
        case deviceIDHash = "device_id_hash"
    }
}

public protocol EventIngestionClient {
    func send(_ envelope: EventEnvelope) throws
}

public struct EventIngestionRequest {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let body: Data

    public init(url: URL, method: String, headers: [String: String], body: Data) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct EventIngestionRequestBuilder {
    private let endpointURL: URL
    private let encoder: JSONEncoder

    public init(endpointURL: URL) {
        self.endpointURL = endpointURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func build(envelope: EventEnvelope, authorizationToken: String? = nil) throws -> EventIngestionRequest {
        var headers = ["content-type": "application/json"]
        if let authorizationToken,
           !authorizationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["authorization"] = "Bearer \(authorizationToken)"
        }

        return EventIngestionRequest(
            url: endpointURL,
            method: "POST",
            headers: headers,
            body: try encoder.encode(envelope)
        )
    }
}

public final class URLSessionEventIngestionClient: EventIngestionClient {
    private let builder: EventIngestionRequestBuilder
    private let session: URLSession
    private let authorizationTokenProvider: () -> String?

    public init(
        endpointURL: URL,
        session: URLSession = .shared,
        authorizationTokenProvider: @escaping () -> String? = { nil }
    ) {
        self.builder = EventIngestionRequestBuilder(endpointURL: endpointURL)
        self.session = session
        self.authorizationTokenProvider = authorizationTokenProvider
    }

    public func send(_ envelope: EventEnvelope) throws {
        let eventRequest = try builder.build(
            envelope: envelope,
            authorizationToken: authorizationTokenProvider()
        )
        var request = URLRequest(url: eventRequest.url)
        request.httpMethod = eventRequest.method
        eventRequest.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        session.uploadTask(with: request, from: eventRequest.body).resume()
    }
}

public final class InMemoryEventIngestionClient: EventIngestionClient {
    public private(set) var envelopes: [EventEnvelope] = []

    public init() {}

    public func send(_ envelope: EventEnvelope) throws {
        envelopes.append(envelope)
    }
}

public final class EventPipelineAnalyticsTracker: AnalyticsTracking {
    public private(set) var failedEnvelopes: [EventEnvelope] = []

    private let client: EventIngestionClient
    private let appVersion: String
    private let platform: String
    private let userIDHashProvider: () -> String?
    private let deviceIDHashProvider: () -> String?

    public init(
        client: EventIngestionClient,
        appVersion: String,
        platform: String = "ios",
        userIDHashProvider: @escaping () -> String? = { nil },
        deviceIDHashProvider: @escaping () -> String? = { nil }
    ) {
        self.client = client
        self.appVersion = appVersion
        self.platform = platform
        self.userIDHashProvider = userIDHashProvider
        self.deviceIDHashProvider = deviceIDHashProvider
    }

    public func track(_ event: AnalyticsEvent) {
        let envelope = EventEnvelope(
            eventName: event.name,
            properties: event.properties,
            appVersion: appVersion,
            platform: platform,
            userIDHash: userIDHashProvider(),
            deviceIDHash: deviceIDHashProvider()
        )

        do {
            try client.send(envelope)
        } catch {
            failedEnvelopes.append(envelope)
        }
    }
}

public final class InMemoryAnalyticsTracker: AnalyticsTracking {
    public private(set) var events: [AnalyticsEvent] = []

    public init() {}

    public func track(_ event: AnalyticsEvent) {
        events.append(
            AnalyticsEvent(
                name: event.name,
                properties: EventPropertySanitizer.sanitize(event.properties)
            )
        )
    }
}

public enum AnalyticsNames {
    public static let composeStarted = "compose_started"
    public static let privateCardGenerated = "private_card_generated"
    public static let sameFlightPublishBlocked = "same_flight_publish_blocked"
    public static let sameFlightPublishCompleted = "same_flight_publish_completed"
    public static let offlineDraftSaved = "offline_draft_saved"
    public static let offlineSyncStarted = "offline_sync_started"
    public static let offlineSyncCompleted = "offline_sync_completed"
    public static let offlineSyncFailed = "offline_sync_failed"
}
