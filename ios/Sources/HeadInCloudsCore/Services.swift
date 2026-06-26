import Foundation

public struct CloudCardRenderer {
    public init() {}

    public func render(post: CloudPost, flightContext: FlightContext?) -> CloudCard {
        let templateID = selectTemplate(for: post.text, requested: post.cardTemplateID)
        let metadata = buildMetadata(flightContext: flightContext)
        return CloudCard(
            postID: post.id,
            templateID: templateID,
            headlineQuote: PublicTextSanitizer.sanitize(post.headlineQuote),
            metadata: metadata,
            publicIdentityLabel: "同机乘客"
        )
    }

    private func selectTemplate(for text: String, requested: String) -> String {
        let ordinarySignals = ["晚点", "累", "烦", "困", "延误"]
        if ordinarySignals.contains(where: { text.contains($0) }) {
            return "flight_log"
        }
        return requested.isEmpty ? "boarding_postcard" : requested
    }

    private func buildMetadata(flightContext: FlightContext?) -> String {
        guard let flightContext else {
            return "航班待确认"
        }

        let flight = flightContext.flightNumber ?? "航班待确认"
        let route = flightContext.route ?? "路线待确认"
        let status = flightContext.verificationStatus == .verified ? "已验证同班机" : "航班待确认"
        return "\(flight) · \(route) · \(status)"
    }
}

public struct SameFlightGate {
    public init() {}

    public func blockReasonForPublishing(
        post: CloudPost,
        flightContext: FlightContext?,
        flightProof: FlightProof?,
        isOnline: Bool
    ) -> SameFlightBlockReason? {
        guard isOnline else { return .noNetwork }
        guard let flightContext else { return .noFlightContext }
        guard flightContext.verificationStatus == .verified, flightProof != nil else {
            return .unverified
        }
        return nil
    }

    public func canComment(flightContext: FlightContext?, flightProof: FlightProof?) -> Bool {
        flightContext?.verificationStatus == .verified && flightProof != nil
    }
}

public final class OfflineSyncQueue {
    private let analytics: AnalyticsTracking
    private let repository: CloudPostRepository

    public init(analytics: AnalyticsTracking, repository: CloudPostRepository) {
        self.analytics = analytics
        self.repository = repository
    }

    public func saveOfflineDraft(_ post: CloudPost) {
        var draft = post
        draft.offlineStatus = .localOnly
        repository.saveDraft(draft)
        analytics.track(
            AnalyticsEvent(
                name: AnalyticsNames.offlineDraftSaved,
                properties: [
                    "content_length": "\(post.text.count)",
                    "has_flight_context": post.flightContextID == nil ? "false" : "true"
                ]
            )
        )
    }

    public func sync(_ post: CloudPost) -> CloudPost {
        analytics.track(
            AnalyticsEvent(
                name: AnalyticsNames.offlineSyncStarted,
                properties: ["queue_id": post.id.uuidString]
            )
        )
        var synced = post
        synced.offlineStatus = .synced
        repository.saveDraft(synced)
        analytics.track(
            AnalyticsEvent(
                name: AnalyticsNames.offlineSyncCompleted,
                properties: ["queue_id": post.id.uuidString]
            )
        )
        return synced
    }
}

public final class HeadInCloudsCore {
    private let analytics: AnalyticsTracking
    private let repository: CloudPostRepository
    private let renderer: CloudCardRenderer
    private let gate: SameFlightGate

    public init(
        analytics: AnalyticsTracking,
        repository: CloudPostRepository,
        renderer: CloudCardRenderer = CloudCardRenderer(),
        gate: SameFlightGate = SameFlightGate()
    ) {
        self.analytics = analytics
        self.repository = repository
        self.renderer = renderer
        self.gate = gate
    }

    public func startCompose(source: String) {
        analytics.track(AnalyticsEvent(name: AnalyticsNames.composeStarted, properties: ["source": source]))
    }

    public func generatePrivateCard(text: String, flightContext: FlightContext? = nil) -> CloudCard {
        let post = CloudPost(text: text)
        repository.saveDraft(post)
        analytics.track(
            AnalyticsEvent(
                name: AnalyticsNames.privateCardGenerated,
                properties: [
                    "template_id": post.cardTemplateID,
                    "has_flight_context": flightContext == nil ? "false" : "true",
                    "verified": flightContext?.verificationStatus == .verified ? "true" : "false"
                ]
            )
        )
        return renderer.render(post: post, flightContext: flightContext)
    }

    public func publishSameFlight(
        post: CloudPost,
        flightContext: FlightContext?,
        flightProof: FlightProof?,
        isOnline: Bool
    ) -> SameFlightBlockReason? {
        if let reason = gate.blockReasonForPublishing(
            post: post,
            flightContext: flightContext,
            flightProof: flightProof,
            isOnline: isOnline
        ) {
            analytics.track(
                AnalyticsEvent(
                    name: AnalyticsNames.sameFlightPublishBlocked,
                    properties: ["reason": reason.rawValue]
                )
            )
            return reason
        }

        repository.publishSameFlight(post)
        analytics.track(
            AnalyticsEvent(
                name: AnalyticsNames.sameFlightPublishCompleted,
                properties: [
                    "flight_space_id": flightContext?.id.uuidString ?? "unknown",
                    "template_id": post.cardTemplateID
                ]
            )
        )
        return nil
    }
}
