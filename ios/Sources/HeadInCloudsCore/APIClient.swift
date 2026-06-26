import Foundation

public struct APIRequestBuilder: Sendable {
    private let baseURL: URL
    private let accountTokenProvider: @Sendable () -> String

    public init(baseURL: URL, accountTokenProvider: @escaping @Sendable () -> String) {
        self.baseURL = baseURL
        self.accountTokenProvider = accountTokenProvider
    }

    public func createFlightContext(_ payload: CreateFlightContextPayload) throws -> URLRequest {
        try post(path: "/api/flight-contexts/create", payload: payload)
    }

    public func createFlightProof(_ payload: CreateFlightProofPayload) throws -> URLRequest {
        try post(path: "/api/flight-proof/create", payload: payload)
    }

    public func createBoardingReminder(_ payload: CreateBoardingReminderPayload) throws -> URLRequest {
        try post(path: "/api/notification-jobs/boarding-reminder/create", payload: payload)
    }

    public func createPost(_ payload: CreatePostPayload) throws -> URLRequest {
        try post(path: "/api/posts/create", payload: payload)
    }

    public func deletePost(postID: UUID) -> URLRequest {
        authorizedRequest(path: "/api/posts/\(postID.uuidString)", method: "DELETE")
    }

    public func createComment(_ payload: CreateCommentPayload) throws -> URLRequest {
        try post(path: "/api/comments/create", payload: payload)
    }

    public func createReport(_ payload: CreateReportPayload) throws -> URLRequest {
        try post(path: "/api/reports/create", payload: payload)
    }

    public func createBlock(_ payload: CreateBlockPayload) throws -> URLRequest {
        try post(path: "/api/blocks/create", payload: payload)
    }

    public func registerPushToken(_ payload: RegisterPushTokenPayload) throws -> URLRequest {
        try post(path: "/api/push-tokens/register", payload: payload)
    }

    public func upgradeAccount(_ payload: UpgradeAccountPayload) throws -> URLRequest {
        try post(path: "/api/accounts/upgrade", payload: payload)
    }

    public func deleteAccount(_ payload: DeleteAccountPayload) throws -> URLRequest {
        try post(path: "/api/accounts/delete", payload: payload)
    }

    public func sendSMSCode(_ payload: SendSMSCodePayload) throws -> URLRequest {
        try post(path: "/api/auth/sms/send", payload: payload)
    }

    public func verifySMSCode(_ payload: VerifySMSCodePayload) throws -> URLRequest {
        try post(path: "/api/auth/sms/verify", payload: payload)
    }

    public func exchangeWeChatCode(_ payload: ExchangeWeChatCodePayload) throws -> URLRequest {
        try post(path: "/api/auth/wechat/exchange", payload: payload)
    }

    public func verifyIAPTransaction(_ payload: VerifyIAPTransactionPayload) throws -> URLRequest {
        try post(path: "/api/iap/transactions/verify", payload: payload)
    }

    public func renderShareCard(_ payload: RenderShareCardPayload) throws -> URLRequest {
        try post(path: "/api/share-cards/render", payload: payload)
    }

    public func flightSpacePosts(flightContextID: UUID) -> URLRequest {
        authorizedRequest(path: "/api/flight-spaces/\(flightContextID.uuidString)/posts", method: "GET")
    }

    public func shareCardURL(postID: UUID) -> URL {
        baseURL.appendingPathComponent("/share/cards/\(postID.uuidString)")
    }

    private func post<T: Encodable>(path: String, payload: T) throws -> URLRequest {
        var request = authorizedRequest(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func authorizedRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(accountTokenProvider())", forHTTPHeaderField: "authorization")
        return request
    }
}

public enum APIClientError: Error, Equatable {
    case invalidHTTPResponse
    case httpStatus(Int)
    case rejectedResponse
    case invalidDate(String)
}

public protocol URLRequestDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLRequestDataLoading {}

public protocol CloudPostSyncing: Sendable {
    func sync(post: CloudPost) async throws -> CloudPost
}

public protocol FlightSpaceLoading: Sendable {
    func posts(flightContextID: UUID) async throws -> [FlightSpacePost]
}

public protocol FlightContextSyncing: Sendable {
    func sync(_ payload: CreateFlightContextPayload) async throws
}

public protocol FlightProofSyncing: Sendable {
    func sync(_ payload: CreateFlightProofPayload) async throws
}

public protocol BoardingReminderScheduling: Sendable {
    func schedule(_ payload: CreateBoardingReminderPayload) async throws
}

public protocol PushTokenRegistering: Sendable {
    func register(_ payload: RegisterPushTokenPayload) async throws
}

public protocol AccountUpgrading: Sendable {
    func upgrade(_ payload: UpgradeAccountPayload) async throws -> AccountUpgradeResult
}

public protocol AccountDeleting: Sendable {
    func delete(_ payload: DeleteAccountPayload) async throws -> AccountDeletionResult
}

public protocol SMSChallengeHandling: Sendable {
    func send(_ payload: SendSMSCodePayload) async throws -> SMSChallengeResult
    func verify(_ payload: VerifySMSCodePayload) async throws -> SMSVerificationResult
}

public protocol WeChatAuthorizationExchanging: Sendable {
    func exchange(code: String) async throws -> AccountUpgradeResult
}

public protocol ContentReporting: Sendable {
    func report(_ payload: CreateReportPayload) async throws
}

public protocol UserBlocking: Sendable {
    func block(_ payload: CreateBlockPayload) async throws
}

public protocol CommentCreating: Sendable {
    func create(_ payload: CreateCommentPayload) async throws
}

public protocol OwnPostDeleting: Sendable {
    func delete(postID: UUID) async throws
}

public protocol PurchaseVerifying: Sendable {
    func verify(_ payload: VerifyIAPTransactionPayload) async throws -> PurchaseVerificationResult
}

public protocol ShareCardRendering: Sendable {
    func render(_ payload: RenderShareCardPayload) async throws -> ShareCardRenderResult
}

public final class RemoteCloudPostSyncClient: CloudPostSyncing {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func sync(post: CloudPost) async throws -> CloudPost {
        let request = try api.createPost(
            CreatePostPayload(
                id: post.id,
                flightContextID: post.flightContextID,
                flightProofID: post.flightProofID,
                publishScope: post.publishScope,
                text: post.text,
                headlineQuote: post.headlineQuote,
                textMode: post.textMode,
                cardTemplateID: post.cardTemplateID,
                offlineStatus: .synced
            )
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeCreatePostResponse(data)
    }
}

public final class RemoteFlightContextClient: FlightContextSyncing {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func sync(_ payload: CreateFlightContextPayload) async throws {
        let request = try api.createFlightContext(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteFlightProofClient: FlightProofSyncing {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func sync(_ payload: CreateFlightProofPayload) async throws {
        let request = try api.createFlightProof(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteBoardingReminderClient: BoardingReminderScheduling {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func schedule(_ payload: CreateBoardingReminderPayload) async throws {
        let request = try api.createBoardingReminder(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteFlightSpaceClient: FlightSpaceLoading {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func posts(flightContextID: UUID) async throws -> [FlightSpacePost] {
        let request = api.flightSpacePosts(flightContextID: flightContextID)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeFlightSpacePostsResponse(data)
    }
}

public final class RemotePushTokenClient: PushTokenRegistering {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func register(_ payload: RegisterPushTokenPayload) async throws {
        let request = try api.registerPushToken(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteAccountUpgradeClient: AccountUpgrading {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func upgrade(_ payload: UpgradeAccountPayload) async throws -> AccountUpgradeResult {
        let request = try api.upgradeAccount(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeAccountUpgradeResponse(data)
    }
}

public final class RemoteAccountDeletionClient: AccountDeleting {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func delete(_ payload: DeleteAccountPayload) async throws -> AccountDeletionResult {
        let request = try api.deleteAccount(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeAccountDeletionResponse(data)
    }
}

public final class RemoteSMSChallengeClient: SMSChallengeHandling {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func send(_ payload: SendSMSCodePayload) async throws -> SMSChallengeResult {
        let request = try api.sendSMSCode(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeSMSChallengeResponse(data)
    }

    public func verify(_ payload: VerifySMSCodePayload) async throws -> SMSVerificationResult {
        let request = try api.verifySMSCode(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeSMSVerificationResponse(data)
    }
}

public final class RemoteWeChatAuthClient: WeChatAuthorizationExchanging {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func exchange(code: String) async throws -> AccountUpgradeResult {
        let request = try api.exchangeWeChatCode(ExchangeWeChatCodePayload(code: code))
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeAccountUpgradeResponse(data)
    }
}

public final class RemoteReportClient: ContentReporting {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func report(_ payload: CreateReportPayload) async throws {
        let request = try api.createReport(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteBlockClient: UserBlocking {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func block(_ payload: CreateBlockPayload) async throws {
        let request = try api.createBlock(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteCommentClient: CommentCreating {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func create(_ payload: CreateCommentPayload) async throws {
        let request = try api.createComment(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemoteOwnPostDeletionClient: OwnPostDeleting {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func delete(postID: UUID) async throws {
        let request = api.deletePost(postID: postID)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(OKResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.rejectedResponse
        }
    }
}

public final class RemotePurchaseClient: PurchaseVerifying {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func verify(_ payload: VerifyIAPTransactionPayload) async throws -> PurchaseVerificationResult {
        let request = try api.verifyIAPTransaction(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodePurchaseVerificationResponse(data)
    }
}

public final class RemoteShareCardRenderClient: ShareCardRendering {
    private let api: APIRequestBuilder
    private let session: URLRequestDataLoading

    public init(api: APIRequestBuilder, session: URLRequestDataLoading = URLSession.shared) {
        self.api = api
        self.session = session
    }

    public func render(_ payload: RenderShareCardPayload) async throws -> ShareCardRenderResult {
        let request = try api.renderShareCard(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return try APIResponseDecoder.decodeShareCardRenderResponse(data)
    }
}

private struct OKResponse: Decodable {
    let ok: Bool
}

public enum APIResponseDecoder {
    public static func decodeCreatePostResponse(_ data: Data) throws -> CloudPost {
        let response = try makeDecoder().decode(CreatePostResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return response.post.toCloudPost()
    }

    public static func decodeFlightSpacePostsResponse(_ data: Data) throws -> [FlightSpacePost] {
        let response = try makeDecoder().decode(FlightSpacePostsResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return response.posts
    }

    public static func decodeAccountUpgradeResponse(_ data: Data) throws -> AccountUpgradeResult {
        let response = try makeDecoder().decode(AccountUpgradeResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return AccountUpgradeResult(
            accountID: response.account.id,
            authMethod: response.account.authMethod,
            mergedWithExisting: response.merge.mergedWithExisting,
            previousAccountID: response.merge.previousAccountID,
            mergedPostCount: response.merge.mergedPostCount
        )
    }

    public static func decodeAccountDeletionResponse(_ data: Data) throws -> AccountDeletionResult {
        let response = try makeDecoder().decode(AccountDeletionResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return AccountDeletionResult(
            accountID: response.account.id,
            deletedAt: response.account.deletedAt,
            recoveryDeadline: response.recoveryDeadline
        )
    }

    public static func decodeSMSChallengeResponse(_ data: Data) throws -> SMSChallengeResult {
        let response = try makeDecoder().decode(SMSChallengeResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return response.smsChallenge.toChallengeResult(
            deliveryProvider: response.delivery?.provider,
            deliveryStatus: response.delivery?.status
        )
    }

    public static func decodeSMSVerificationResponse(_ data: Data) throws -> SMSVerificationResult {
        let response = try makeDecoder().decode(SMSVerificationResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        guard response.smsChallenge.providerUserHash != nil, response.smsChallenge.verifiedAt != nil else {
            throw APIClientError.rejectedResponse
        }
        return response.smsChallenge.toVerificationResult()
    }

    public static func decodePurchaseVerificationResponse(_ data: Data) throws -> PurchaseVerificationResult {
        let response = try makeDecoder().decode(PurchaseVerificationResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return PurchaseVerificationResult(
            transactionID: response.subscription.transactionID,
            productID: response.subscription.productID,
            plan: response.subscription.plan,
            amount: response.subscription.amount,
            currency: response.subscription.currency,
            environment: response.subscription.environment,
            created: response.created
        )
    }

    public static func decodeShareCardRenderResponse(_ data: Data) throws -> ShareCardRenderResult {
        let response = try makeDecoder().decode(ShareCardRenderResponse.self, from: data)
        guard response.ok else {
            throw APIClientError.rejectedResponse
        }
        return ShareCardRenderResult(
            postID: response.shareCard.postID,
            shareImageURL: response.shareCard.shareImageURL,
            objectKey: response.shareCard.objectKey,
            contentType: response.shareCard.contentType,
            channel: response.shareCard.channel
        )
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            return try parseISODate(value)
        }
        return decoder
    }

    private static func parseISODate(_ value: String) throws -> Date {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        throw APIClientError.invalidDate(value)
    }
}

public struct CreateFlightContextPayload: Encodable, Equatable, Sendable {
    public let id: UUID?
    public let flightNumberHash: String
    public let route: String
    public let departureDate: String?
    public let verificationStatus: VerificationStatus

    public init(
        id: UUID? = nil,
        flightNumberHash: String,
        route: String,
        departureDate: String? = nil,
        verificationStatus: VerificationStatus = .unverified
    ) {
        self.id = id
        self.flightNumberHash = flightNumberHash
        self.route = route
        self.departureDate = departureDate
        self.verificationStatus = verificationStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case flightNumberHash = "flight_number_hash"
        case route
        case departureDate = "departure_date"
        case verificationStatus = "verification_status"
    }
}

public struct CreateFlightProofPayload: Encodable, Equatable, Sendable {
    public let flightContextID: UUID
    public let method: VerificationMethod
    public let sourceImageHash: String?
    public let redactedObjectKey: String?

    public init(
        flightContextID: UUID,
        method: VerificationMethod,
        sourceImageHash: String? = nil,
        redactedObjectKey: String? = nil
    ) {
        self.flightContextID = flightContextID
        self.method = method
        self.sourceImageHash = sourceImageHash
        self.redactedObjectKey = redactedObjectKey
    }

    private enum CodingKeys: String, CodingKey {
        case flightContextID = "flight_context_id"
        case method
        case sourceImageHash = "source_image_hash"
        case redactedObjectKey = "redacted_object_key"
    }
}

public struct CreateBoardingReminderPayload: Encodable, Equatable, Sendable {
    public let id: UUID?
    public let flightContextID: UUID
    public let scheduledFor: Date
    public let reminderOffsetMinutes: Int

    public init(
        id: UUID? = nil,
        flightContextID: UUID,
        scheduledFor: Date,
        reminderOffsetMinutes: Int = 30
    ) {
        self.id = id
        self.flightContextID = flightContextID
        self.scheduledFor = scheduledFor
        self.reminderOffsetMinutes = reminderOffsetMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case flightContextID = "flight_context_id"
        case scheduledFor = "scheduled_for"
        case reminderOffsetMinutes = "reminder_offset_minutes"
    }
}

public struct CreatePostPayload: Encodable, Equatable, Sendable {
    public let id: UUID?
    public let flightContextID: UUID?
    public let flightProofID: UUID?
    public let publishScope: PublishScope
    public let text: String
    public let headlineQuote: String
    public let textMode: TextMode
    public let cardTemplateID: String
    public let offlineStatus: OfflineStatus

    public init(
        id: UUID? = nil,
        flightContextID: UUID? = nil,
        flightProofID: UUID? = nil,
        publishScope: PublishScope,
        text: String,
        headlineQuote: String,
        textMode: TextMode = .oneLine,
        cardTemplateID: String = "boarding_postcard",
        offlineStatus: OfflineStatus = .synced
    ) {
        self.id = id
        self.flightContextID = flightContextID
        self.flightProofID = flightProofID
        self.publishScope = publishScope
        self.text = text
        self.headlineQuote = headlineQuote
        self.textMode = textMode
        self.cardTemplateID = cardTemplateID
        self.offlineStatus = offlineStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case flightContextID = "flight_context_id"
        case flightProofID = "flight_proof_id"
        case publishScope = "publish_scope"
        case text
        case headlineQuote = "headline_quote"
        case textMode = "text_mode"
        case cardTemplateID = "card_template_id"
        case offlineStatus = "offline_status"
    }
}

public struct CreateCommentPayload: Encodable, Equatable, Sendable {
    public let id: UUID?
    public let postID: UUID
    public let flightContextID: UUID
    public let body: String

    public init(id: UUID? = nil, postID: UUID, flightContextID: UUID, body: String) {
        self.id = id
        self.postID = postID
        self.flightContextID = flightContextID
        self.body = body
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case flightContextID = "flight_context_id"
        case body
    }
}

public struct CreateReportPayload: Encodable, Equatable, Sendable {
    public let id: UUID?
    public let targetType: String
    public let targetID: UUID
    public let reason: String

    public init(id: UUID? = nil, targetType: String, targetID: UUID, reason: String) {
        self.id = id
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case targetType = "target_type"
        case targetID = "target_id"
        case reason
    }
}

public struct CreateBlockPayload: Encodable, Equatable, Sendable {
    public let blockedAccountID: UUID?
    public let postID: UUID?

    public init(blockedAccountID: UUID) {
        self.blockedAccountID = blockedAccountID
        self.postID = nil
    }

    public init(postID: UUID) {
        self.blockedAccountID = nil
        self.postID = postID
    }

    private enum CodingKeys: String, CodingKey {
        case blockedAccountID = "blocked_account_id"
        case postID = "post_id"
    }
}

public struct RegisterPushTokenPayload: Encodable, Equatable, Sendable {
    public let platform: String
    public let token: String

    public init(platform: String = "ios", token: String) {
        self.platform = platform
        self.token = token
    }
}

public struct UpgradeAccountPayload: Encodable, Equatable, Sendable {
    public let method: String
    public let providerUserHash: String
    public let wechatOpenIDHash: String?

    public init(method: String, providerUserHash: String, wechatOpenIDHash: String? = nil) {
        self.method = method
        self.providerUserHash = providerUserHash
        self.wechatOpenIDHash = wechatOpenIDHash
    }

    private enum CodingKeys: String, CodingKey {
        case method
        case providerUserHash = "provider_user_hash"
        case wechatOpenIDHash = "wechat_open_id_hash"
    }
}

public struct DeleteAccountPayload: Encodable, Equatable, Sendable {
    public let reauthMethod: String

    public init(reauthMethod: String) {
        self.reauthMethod = reauthMethod
    }

    private enum CodingKeys: String, CodingKey {
        case reauthMethod = "reauth_method"
    }
}

public struct SendSMSCodePayload: Encodable, Equatable, Sendable {
    public let phoneCountryCode: String
    public let phone: String

    public init(phoneCountryCode: String = "+86", phone: String) {
        self.phoneCountryCode = phoneCountryCode
        self.phone = phone
    }

    private enum CodingKeys: String, CodingKey {
        case phoneCountryCode = "phone_country_code"
        case phone
    }
}

public struct VerifySMSCodePayload: Encodable, Equatable, Sendable {
    public let challengeID: UUID
    public let code: String

    public init(challengeID: UUID, code: String) {
        self.challengeID = challengeID
        self.code = code
    }

    private enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case code
    }
}

public struct ExchangeWeChatCodePayload: Encodable, Equatable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

public struct VerifyIAPTransactionPayload: Encodable, Equatable, Sendable {
    public let transactionID: String
    public let originalTransactionID: String?
    public let productID: String
    public let plan: String
    public let amount: Int
    public let currency: String
    public let environment: String
    public let signedTransactionJWS: String?

    public init(
        transactionID: String,
        originalTransactionID: String? = nil,
        productID: String,
        plan: String,
        amount: Int,
        currency: String = "CNY",
        environment: String = "local_mock",
        signedTransactionJWS: String? = nil
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.productID = productID
        self.plan = plan
        self.amount = amount
        self.currency = currency
        self.environment = environment
        self.signedTransactionJWS = signedTransactionJWS
    }

    private enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case originalTransactionID = "original_transaction_id"
        case productID = "product_id"
        case plan
        case amount
        case currency
        case environment
        case signedTransactionJWS = "signed_transaction_jws"
    }
}

public struct RenderShareCardPayload: Encodable, Equatable, Sendable {
    public let postID: UUID
    public let channel: String?

    public init(postID: UUID, channel: String? = nil) {
        self.postID = postID
        self.channel = channel
    }

    private enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case channel
    }
}

public struct AccountUpgradeResult: Equatable, Sendable {
    public let accountID: UUID
    public let authMethod: String
    public let mergedWithExisting: Bool
    public let previousAccountID: UUID?
    public let mergedPostCount: Int

    public init(
        accountID: UUID,
        authMethod: String,
        mergedWithExisting: Bool,
        previousAccountID: UUID?,
        mergedPostCount: Int
    ) {
        self.accountID = accountID
        self.authMethod = authMethod
        self.mergedWithExisting = mergedWithExisting
        self.previousAccountID = previousAccountID
        self.mergedPostCount = mergedPostCount
    }
}

public struct AccountDeletionResult: Equatable, Sendable {
    public let accountID: UUID
    public let deletedAt: Date?
    public let recoveryDeadline: Date

    public init(accountID: UUID, deletedAt: Date?, recoveryDeadline: Date) {
        self.accountID = accountID
        self.deletedAt = deletedAt
        self.recoveryDeadline = recoveryDeadline
    }
}

public struct SMSChallengeResult: Equatable, Sendable {
    public let challengeID: UUID
    public let status: String
    public let phoneCountryCode: String
    public let expiresAt: Date
    public let resendAvailableAt: Date
    public let maxAttempts: Int
    public let deliveryProvider: String?
    public let deliveryStatus: String?

    public init(
        challengeID: UUID,
        status: String,
        phoneCountryCode: String,
        expiresAt: Date,
        resendAvailableAt: Date,
        maxAttempts: Int,
        deliveryProvider: String? = nil,
        deliveryStatus: String? = nil
    ) {
        self.challengeID = challengeID
        self.status = status
        self.phoneCountryCode = phoneCountryCode
        self.expiresAt = expiresAt
        self.resendAvailableAt = resendAvailableAt
        self.maxAttempts = maxAttempts
        self.deliveryProvider = deliveryProvider
        self.deliveryStatus = deliveryStatus
    }
}

public struct SMSVerificationResult: Equatable, Sendable {
    public let challengeID: UUID
    public let status: String
    public let verifiedAt: Date
    public let providerUserHash: String

    public init(challengeID: UUID, status: String, verifiedAt: Date, providerUserHash: String) {
        self.challengeID = challengeID
        self.status = status
        self.verifiedAt = verifiedAt
        self.providerUserHash = providerUserHash
    }
}

public struct PurchaseVerificationResult: Equatable, Sendable {
    public let transactionID: String
    public let productID: String
    public let plan: String
    public let amount: Int
    public let currency: String
    public let environment: String
    public let created: Bool

    public init(
        transactionID: String,
        productID: String,
        plan: String,
        amount: Int,
        currency: String,
        environment: String,
        created: Bool
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.plan = plan
        self.amount = amount
        self.currency = currency
        self.environment = environment
        self.created = created
    }
}

public struct ShareCardRenderResult: Equatable, Sendable {
    public let postID: UUID
    public let shareImageURL: URL
    public let objectKey: String
    public let contentType: String
    public let channel: String?

    public init(postID: UUID, shareImageURL: URL, objectKey: String, contentType: String, channel: String?) {
        self.postID = postID
        self.shareImageURL = shareImageURL
        self.objectKey = objectKey
        self.contentType = contentType
        self.channel = channel
    }
}

private struct CreatePostResponse: Decodable {
    let ok: Bool
    let post: APICloudPost
}

private struct AccountUpgradeResponse: Decodable {
    let ok: Bool
    let account: APIAccount
    let merge: APIAccountMerge
}

private struct AccountDeletionResponse: Decodable {
    let ok: Bool
    let account: APIAccount
    let recoveryDeadline: Date

    private enum CodingKeys: String, CodingKey {
        case ok
        case account
        case recoveryDeadline = "recovery_deadline"
    }
}

private struct PurchaseVerificationResponse: Decodable {
    let ok: Bool
    let subscription: APISubscription
    let created: Bool
}

private struct ShareCardRenderResponse: Decodable {
    let ok: Bool
    let shareCard: APIShareCardRender

    private enum CodingKeys: String, CodingKey {
        case ok
        case shareCard = "share_card"
    }
}

private struct APIShareCardRender: Decodable {
    let postID: UUID
    let shareImageURL: URL
    let objectKey: String
    let contentType: String
    let channel: String?

    private enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case shareImageURL = "share_image_url"
        case objectKey = "object_key"
        case contentType = "content_type"
        case channel
    }
}

private struct SMSChallengeResponse: Decodable {
    let ok: Bool
    let smsChallenge: APISMSChallenge
    let delivery: APISMSDelivery?

    private enum CodingKeys: String, CodingKey {
        case ok
        case smsChallenge = "sms_challenge"
        case delivery
    }
}

private struct SMSVerificationResponse: Decodable {
    let ok: Bool
    let smsChallenge: APISMSChallenge

    private enum CodingKeys: String, CodingKey {
        case ok
        case smsChallenge = "sms_challenge"
    }
}

private struct APISMSDelivery: Decodable {
    let provider: String
    let status: String
}

private struct APISMSChallenge: Decodable {
    let id: UUID
    let status: String
    let phoneCountryCode: String
    let expiresAt: Date
    let resendAvailableAt: Date
    let maxAttempts: Int
    let verifiedAt: Date?
    let providerUserHash: String?

    func toChallengeResult(deliveryProvider: String?, deliveryStatus: String?) -> SMSChallengeResult {
        SMSChallengeResult(
            challengeID: id,
            status: status,
            phoneCountryCode: phoneCountryCode,
            expiresAt: expiresAt,
            resendAvailableAt: resendAvailableAt,
            maxAttempts: maxAttempts,
            deliveryProvider: deliveryProvider,
            deliveryStatus: deliveryStatus
        )
    }

    func toVerificationResult() -> SMSVerificationResult {
        SMSVerificationResult(
            challengeID: id,
            status: status,
            verifiedAt: verifiedAt ?? expiresAt,
            providerUserHash: providerUserHash ?? ""
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case phoneCountryCode = "phone_country_code"
        case expiresAt = "expires_at"
        case resendAvailableAt = "resend_available_at"
        case maxAttempts = "max_attempts"
        case verifiedAt = "verified_at"
        case providerUserHash = "provider_user_hash"
    }
}

private struct APIAccount: Decodable {
    let id: UUID
    let authMethod: String
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case authMethod = "auth_method"
        case deletedAt = "deleted_at"
    }
}

private struct APIAccountMerge: Decodable {
    let mergedWithExisting: Bool
    let previousAccountID: UUID?
    let mergedPostCount: Int

    private enum CodingKeys: String, CodingKey {
        case mergedWithExisting = "merged_with_existing"
        case previousAccountID = "previous_account_id"
        case mergedPostCount = "merged_post_count"
    }
}

private struct APISubscription: Decodable {
    let transactionID: String
    let productID: String
    let plan: String
    let amount: Int
    let currency: String
    let environment: String

    private enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case productID = "product_id"
        case plan
        case amount
        case currency
        case environment
    }
}

private struct FlightSpacePostsResponse: Decodable {
    let ok: Bool
    let posts: [FlightSpacePost]
}

private struct APICloudPost: Decodable {
    let id: UUID
    let flightContextID: UUID?
    let flightProofID: UUID?
    let publishScope: PublishScope
    let text: String
    let headlineQuote: String
    let textMode: TextMode
    let cardTemplateID: String
    let offlineStatus: OfflineStatus
    let createdAt: Date

    func toCloudPost() -> CloudPost {
        CloudPost(
            id: id,
            flightContextID: flightContextID,
            flightProofID: flightProofID,
            publishScope: publishScope,
            text: text,
            textMode: textMode,
            headlineQuote: headlineQuote,
            cardTemplateID: cardTemplateID,
            offlineStatus: offlineStatus,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case flightContextID = "flight_context_id"
        case flightProofID = "flight_proof_id"
        case publishScope = "publish_scope"
        case text
        case headlineQuote = "headline_quote"
        case textMode = "text_mode"
        case cardTemplateID = "card_template_id"
        case offlineStatus = "offline_status"
        case createdAt = "created_at"
    }
}
