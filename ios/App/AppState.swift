import AVFoundation
import Foundation
import CryptoKit
import Network
import Photos
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class CloudAppState: ObservableObject {
    @Published private(set) var account: LocalAccount
    @Published var draftText: String {
        didSet { persistDraft() }
    }
    @Published var currentFlightContext: FlightContext? {
        didSet { persistFlightContext() }
    }
    @Published private(set) var currentFlightProof: FlightProof? {
        didSet { persistFlightProof() }
    }
    @Published private(set) var generatedCard: CloudCard?
    @Published private(set) var currentPost: CloudPost?
    @Published private(set) var posts: [LocalPostRecord]
    @Published private(set) var flightSpacePosts: [FlightSpacePost]
    @Published private(set) var selectedFlightSpacePost: FlightSpacePost?
    @Published private(set) var isFlightSpaceLoading = false
    @Published private(set) var reminders: [LocalReminder]
    @Published private(set) var blockedUsers: Set<String>
    @Published private(set) var hiddenPostIDs: Set<String>
    @Published private(set) var accountUpgradePrompt: AccountUpgradePrompt?
    @Published private(set) var isWeChatSignInInProgress = false
    @Published var isOffline = false
    @Published var lastFeedback: String?

    let analytics = InMemoryAnalyticsTracker()

    private let repository = InMemoryCloudPostRepository()
    private lazy var analyticsSink: AnalyticsTracking = Self.defaultAnalyticsSink(
        localAnalytics: analytics,
        userIDHashProvider: { [weak self] in
            guard let self else { return nil }
            return self.stableHash(self.account.id.uuidString)
        },
        deviceIDHashProvider: { [weak self] in
            guard let self else { return nil }
            return self.stableHash(self.account.id.uuidString)
        },
        authorizationTokenProvider: { [weak self] in
            self?.accountTokenProvider.currentToken()
        }
    )
    private lazy var core = HeadInCloudsCore(analytics: analyticsSink, repository: repository)
    private let renderer = CloudCardRenderer()
    private lazy var queue = OfflineSyncQueue(analytics: analyticsSink, repository: repository)
    private let notificationScheduler: NotificationScheduling
    private let postSyncClient: CloudPostSyncing?
    private let flightContextSyncClient: FlightContextSyncing?
    private let flightProofSyncClient: FlightProofSyncing?
    private let boardingReminderClient: BoardingReminderScheduling?
    private let flightSpaceClient: FlightSpaceLoading?
    private let pushTokenClient: PushTokenRegistering?
    private let accountUpgradeClient: AccountUpgrading?
    private let weChatAuthClient: WeChatAuthorizationExchanging?
    private let accountDeletionClient: AccountDeleting?
    private let smsChallengeClient: SMSChallengeHandling?
    private let reportClient: ContentReporting?
    private let blockClient: UserBlocking?
    private let commentClient: CommentCreating?
    private let postDeletionClient: OwnPostDeleting?
    private let purchaseClient: PurchaseVerifying?
    private let shareCardRenderClient: ShareCardRendering?
    private let storeKitPurchaseCoordinator: StoreKitPurchaseCoordinating?
    private let networkMonitor: NetworkMonitoring
    private let accountTokenProvider: LocalAccountTokenProvider
    private var shownAccountUpgradePromptThresholds: Set<Int>
    private var draftUpdatedAt: Date?
    private var isSyncingQueuedDraft = false
    private var pendingWeChatAuthState: String?
    private var pendingWeChatAuthSource: String?
    private let defaults: UserDefaults

    var privacyPolicyURL: URL? {
        Self.configuredAPIBaseURL()?.appendingPathComponent("privacy")
    }

    var termsOfServiceURL: URL? {
        Self.configuredAPIBaseURL()?.appendingPathComponent("terms")
    }

    init(
        defaults: UserDefaults = .standard,
        notificationScheduler: NotificationScheduling = UserNotificationScheduler(),
        postSyncClient: CloudPostSyncing? = nil,
        flightContextSyncClient: FlightContextSyncing? = nil,
        flightProofSyncClient: FlightProofSyncing? = nil,
        boardingReminderClient: BoardingReminderScheduling? = nil,
        flightSpaceClient: FlightSpaceLoading? = nil,
        pushTokenClient: PushTokenRegistering? = nil,
        accountUpgradeClient: AccountUpgrading? = nil,
        weChatAuthClient: WeChatAuthorizationExchanging? = nil,
        accountDeletionClient: AccountDeleting? = nil,
        smsChallengeClient: SMSChallengeHandling? = nil,
        reportClient: ContentReporting? = nil,
        blockClient: UserBlocking? = nil,
        commentClient: CommentCreating? = nil,
        postDeletionClient: OwnPostDeleting? = nil,
        purchaseClient: PurchaseVerifying? = nil,
        shareCardRenderClient: ShareCardRendering? = nil,
        storeKitPurchaseCoordinator: StoreKitPurchaseCoordinating? = nil,
        networkMonitor: NetworkMonitoring = NetworkPathMonitor()
    ) {
        var loadedAccount = defaults.decode(LocalAccount.self, forKey: Keys.account)
            ?? LocalAccount(id: UUID(), authMethod: .guest, createdAt: Date(), postCount: 0)
        var loadedDraftText = defaults.string(forKey: Keys.draftText) ?? ""
        var loadedDraftUpdatedAt = defaults.object(forKey: Keys.draftUpdatedAt) as? Date
        var loadedFlightContext = defaults.decode(FlightContext.self, forKey: Keys.flightContext)
        var loadedFlightProof = defaults.decode(FlightProof.self, forKey: Keys.flightProof)
        var loadedPosts = defaults.decode([LocalPostRecord].self, forKey: Keys.posts) ?? []
        var loadedReminders = defaults.decode([LocalReminder].self, forKey: Keys.reminders) ?? []
        let shouldDiscardUITestResidue = Self.shouldDiscardUITestResidue(
            draftText: loadedDraftText,
            context: loadedFlightContext,
            proof: loadedFlightProof,
            posts: loadedPosts,
            reminders: loadedReminders
        )
        let shouldDiscardLegacyFlightState = Self.shouldDiscardLegacyFixtureFlightState(
            context: loadedFlightContext,
            proof: loadedFlightProof,
            posts: loadedPosts,
            reminders: loadedReminders
        )

        if shouldDiscardUITestResidue {
            loadedAccount = Self.clearUITestResidueState(defaults, preserving: loadedAccount)
            loadedDraftText = ""
            loadedDraftUpdatedAt = nil
            loadedFlightContext = nil
            loadedFlightProof = nil
            loadedPosts = []
            loadedReminders = []
        }

        let tokenProvider = LocalAccountTokenProvider(accountID: loadedAccount.id)

        self.defaults = defaults
        self.notificationScheduler = notificationScheduler
        self.postSyncClient = postSyncClient ?? Self.defaultPostSyncClient(accountTokenProvider: tokenProvider)
        self.flightContextSyncClient = flightContextSyncClient ?? Self.defaultFlightContextSyncClient(accountTokenProvider: tokenProvider)
        self.flightProofSyncClient = flightProofSyncClient ?? Self.defaultFlightProofSyncClient(accountTokenProvider: tokenProvider)
        self.boardingReminderClient = boardingReminderClient ?? Self.defaultBoardingReminderClient(accountTokenProvider: tokenProvider)
        self.flightSpaceClient = flightSpaceClient ?? Self.defaultFlightSpaceClient(accountTokenProvider: tokenProvider)
        self.pushTokenClient = pushTokenClient ?? Self.defaultPushTokenClient(accountTokenProvider: tokenProvider)
        self.accountUpgradeClient = accountUpgradeClient ?? Self.defaultAccountUpgradeClient(accountTokenProvider: tokenProvider)
        self.weChatAuthClient = weChatAuthClient ?? Self.defaultWeChatAuthClient(accountTokenProvider: tokenProvider)
        self.accountDeletionClient = accountDeletionClient ?? Self.defaultAccountDeletionClient(accountTokenProvider: tokenProvider)
        self.smsChallengeClient = smsChallengeClient ?? Self.defaultSMSChallengeClient(accountTokenProvider: tokenProvider)
        self.reportClient = reportClient ?? Self.defaultReportClient(accountTokenProvider: tokenProvider)
        self.blockClient = blockClient ?? Self.defaultBlockClient(accountTokenProvider: tokenProvider)
        self.commentClient = commentClient ?? Self.defaultCommentClient(accountTokenProvider: tokenProvider)
        self.postDeletionClient = postDeletionClient ?? Self.defaultPostDeletionClient(accountTokenProvider: tokenProvider)
        self.purchaseClient = purchaseClient ?? Self.defaultPurchaseClient(accountTokenProvider: tokenProvider)
        self.shareCardRenderClient = shareCardRenderClient ?? Self.defaultShareCardRenderClient(accountTokenProvider: tokenProvider)
        self.storeKitPurchaseCoordinator = storeKitPurchaseCoordinator ?? StoreKitPurchaseCoordinator(environment: Self.configuredIAPEnvironment())
        self.networkMonitor = networkMonitor
        self.accountTokenProvider = tokenProvider

        self.account = loadedAccount
        self.draftText = loadedDraftText
        self.draftUpdatedAt = loadedDraftUpdatedAt
        self.currentFlightContext = shouldDiscardLegacyFlightState ? nil : loadedFlightContext
        self.currentFlightProof = shouldDiscardLegacyFlightState ? nil : loadedFlightProof
        self.posts = loadedPosts
        self.flightSpacePosts = []
        self.selectedFlightSpacePost = nil
        self.reminders = loadedReminders
        self.blockedUsers = Set(defaults.stringArray(forKey: Keys.blockedUsers) ?? [])
        self.hiddenPostIDs = Set(defaults.stringArray(forKey: Keys.hiddenPostIDs) ?? [])
        self.shownAccountUpgradePromptThresholds = Set(defaults.array(forKey: Keys.accountUpgradePromptThresholds) as? [Int] ?? [])

        if shouldDiscardLegacyFlightState {
            defaults.removeObject(forKey: Keys.flightContext)
            defaults.removeObject(forKey: Keys.flightProof)
        }

        if !defaults.bool(forKey: Keys.firstLaunchTracked) {
            track(AnalyticsAppEvent.appFirstLaunched, properties: [
                "device_id": account.id.uuidString,
                "app_version": "dev"
            ])
            defaults.set(true, forKey: Keys.firstLaunchTracked)
        }
        trackUserReturnedIfNeeded()
        trackDraftResumeIfNeeded()

        NotificationCenter.default.addObserver(
            forName: .didReceiveRemotePushToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                self?.registerRemotePushToken(token)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .didFailToRegisterRemotePush,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.object as? String ?? "unknown"
            Task { @MainActor in
                self?.lastFeedback = "APNs token 暂时不可用：\(reason)"
            }
        }
        NotificationCenter.default.addObserver(
            forName: .didReceiveWeChatShareResponse,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let message = notification.object as? String else { return }
            Task { @MainActor in
                self?.lastFeedback = message
            }
        }
        NotificationCenter.default.addObserver(
            forName: .didReceiveWeChatAuthResponse,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let response = notification.object as? WeChatAuthResponse else { return }
            Task { @MainActor in
                self?.handleWeChatAuthResponse(response)
            }
        }
        networkMonitor.start { [weak self] isOffline in
            Task { @MainActor in
                guard let self else { return }
                self.isOffline = isOffline
                if !isOffline {
                    self.syncQueuedDrafts()
                }
            }
        }
    }

    deinit {
        networkMonitor.cancel()
    }

    private static func shouldDiscardLegacyFixtureFlightState(
        context: FlightContext?,
        proof: FlightProof?,
        posts: [LocalPostRecord],
        reminders: [LocalReminder]
    ) -> Bool {
        guard let context, isFixtureFlight(context.flightNumber, route: context.route) else {
            return false
        }

        let hasUserFlightArtifact =
            posts.contains { isFixtureFlight($0.flightNumber, route: $0.route) } ||
            reminders.contains { isFixtureFlight($0.flightNumber, route: $0.route) }
        if hasUserFlightArtifact {
            return false
        }

        guard let proof else {
            return true
        }
        return proof.sourceImageHash == "local-fixture-hash" || proof.method == .ticketScreenshot
    }

    private static func isFixtureFlight(_ flightNumber: String?, route: String?) -> Bool {
        normalizeFlightToken(flightNumber) == "MU5301" &&
            normalizeFlightToken(route) == "SHACTU"
    }

    private static func normalizeFlightToken(_ value: String?) -> String {
        (value ?? "")
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func shouldDiscardUITestResidue(
        draftText: String,
        context: FlightContext?,
        proof: FlightProof?,
        posts: [LocalPostRecord],
        reminders: [LocalReminder]
    ) -> Bool {
        if isUITestResidueText(draftText) {
            return true
        }

        if posts.contains(where: { isUITestResidueText($0.text) || isUITestResidueText($0.headlineQuote) }) {
            return true
        }

        if proof?.sourceImageHash == "local-fixture-hash" {
            return true
        }

        if let context,
           isFixtureFlight(context.flightNumber, route: context.route),
           proof?.method == .ticketScreenshot {
            return true
        }

        if let context,
           normalizeFlightToken(context.flightNumber) == "CA9999",
           normalizeFlightToken(context.route) == "PVGHAK",
           posts.isEmpty,
           reminders.isEmpty {
            return true
        }

        return false
    }

    private static func isUITestResidueText(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return uiTestResidueTexts.contains(trimmed)
    }

    private static let uiTestResidueTexts: Set<String> = [
        "I left one sentence above the clouds.",
        "I am landing with one thing left unsaid.",
        "I want real proof, not a local fixture.",
        "A button should always prove it worked.",
        "I want to add the real flight myself.",
        "I am checking a migrated app state.",
        "I should not inherit the old flight in the form."
    ]

    private static func clearLocalUserState(_ defaults: UserDefaults) {
        [
            Keys.account,
            Keys.draftText,
            Keys.draftUpdatedAt,
            Keys.flightContext,
            Keys.flightProof,
            Keys.posts,
            Keys.reminders,
            Keys.blockedUsers,
            Keys.hiddenPostIDs,
            Keys.firstLaunchTracked,
            Keys.lastUserReturnedDate,
            Keys.accountUpgradePromptThresholds
        ].forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }

    private static func clearUITestResidueState(_ defaults: UserDefaults, preserving account: LocalAccount) -> LocalAccount {
        [
            Keys.draftText,
            Keys.draftUpdatedAt,
            Keys.flightContext,
            Keys.flightProof,
            Keys.posts,
            Keys.reminders,
            Keys.blockedUsers,
            Keys.hiddenPostIDs,
            Keys.accountUpgradePromptThresholds
        ].forEach { defaults.removeObject(forKey: $0) }

        var sanitizedAccount = account
        sanitizedAccount.postCount = 0
        sanitizedAccount.hasCompletedOnboarding = account.hasCompletedOnboarding
        defaults.encode(sanitizedAccount, forKey: Keys.account)
        defaults.synchronize()
        return sanitizedAccount
    }

    var flightChipTitle: String {
        guard let currentFlightContext else {
            return "未添加航班 · 稍后补"
        }

        let flight = currentFlightContext.flightNumber ?? "航班待确认"
        let route = currentFlightContext.route ?? "路线待确认"
        if currentFlightContext.verificationStatus == .verified {
            return "\(flight) · 已验证同班机"
        }
        return "\(flight) · \(route)"
    }

    var syncStatusTitle: String {
        if isOffline {
            return "已离线保存，落地后自动同步"
        }
        return "草稿已保存"
    }

    var canCommentInSameFlight: Bool {
        currentFlightContext?.verificationStatus == .verified && currentFlightProof != nil
    }

    var canDeleteCurrentPost: Bool {
        currentPost != nil
    }

    var currentShareCardURL: URL? {
        guard let currentPost else { return nil }
        let baseURL = Self.configuredShareBaseURL()
            ?? Self.configuredAPIBaseURL()
            ?? URL(string: "https://headinclouds.cn")
        return baseURL?.appendingPathComponent("share/cards/\(currentPost.id.uuidString)")
    }

    var myFlightRecords: [FlightRecordViewModel] {
        let localRecords = posts.sorted { $0.createdAt > $1.createdAt }.map {
            FlightRecordViewModel(
                flightNumber: $0.flightNumber,
                date: $0.dateLabel,
                route: $0.route,
                cityRoute: $0.cityRoute,
                mood: $0.mood,
                quote: $0.headlineQuote
            )
        }

        return localRecords
    }

    var flightSpaceCards: [FlightSpacePostViewModel] {
        let remoteCards = flightSpacePosts.filter {
            !hiddenPostIDs.contains($0.id.uuidString)
        }.map {
            FlightSpacePostViewModel(
                id: $0.id,
                identity: $0.publicIdentityLabel,
                quote: $0.headlineQuote,
                status: $0.commentCount > 0 ? "\($0.commentCount) 条回应" : "同机乘客"
            )
        }
        if !remoteCards.isEmpty {
            return remoteCards
        }

        let localCards = myFlightRecords.prefix(1).map {
            FlightSpacePostViewModel(
                identity: "同机乘客",
                quote: $0.quote,
                status: isOffline ? "待同步" : "已发布"
            )
        }
        return Array(localCards)
    }

    func selectFlightSpacePost(id: UUID?) {
        guard let id else {
            selectedFlightSpacePost = nil
            return
        }
        selectedFlightSpacePost = flightSpacePosts.first { $0.id == id }
    }

    func onboardingStepViewed(_ step: String) {
        track(AnalyticsAppEvent.onboardingStepViewed, properties: ["step": step])
    }

    func completeOnboarding() {
        account.hasCompletedOnboarding = true
        persistAccount()
        track(AnalyticsAppEvent.guestModeChosen, properties: ["source": "00d", "device_id": account.id.uuidString])
        track(AnalyticsAppEvent.onboardingCompleted, properties: ["guest": "true"])
    }

    func landingViewed(returning: Bool) {
        track(returning ? AnalyticsAppEvent.landingReturningViewed : AnalyticsAppEvent.landingFirstViewed, properties: [
            "is_returning": returning ? "true" : "false",
            "post_count": "\(posts.count)"
        ])
        track(AnalyticsAppEvent.landingViewed, properties: [
            "is_returning": returning ? "true" : "false",
            "post_count": "\(posts.count)"
        ])
    }

    func startCompose(source: String) {
        core.startCompose(source: source)
    }

    func updateDraft(_ text: String) {
        draftText = text
        if isOffline {
            let post = CloudPost(
                flightContextID: currentFlightContext?.id,
                text: text,
                offlineStatus: .localOnly
            )
            queue.saveOfflineDraft(post)
        }
    }

    func composeModeSelected(_ mode: String) {
        track(AnalyticsAppEvent.composeModeSelected, properties: ["mode": mode])
    }

    func templateSelected(_ template: String) {
        track(AnalyticsAppEvent.templatePromptSelected, properties: ["template_id": template])
    }

    func voiceTranscribed(length: Int) {
        track(AnalyticsAppEvent.voiceRecordingStarted)
        track(AnalyticsAppEvent.voiceTranscribed, properties: [
            "success": "true",
            "duration_ms": "1200",
            "content_length": "\(length)"
        ])
    }

    func generatePrivateCard() {
        let text = draftText.cloudFallback
        var post = CloudPost(
            flightContextID: currentFlightContext?.id,
            flightProofID: currentFlightProof?.id,
            publishScope: .privateCard,
            text: text,
            textMode: .oneLine,
            cardTemplateID: text.shouldUseFlightLogFallback ? "flight_log" : "boarding_postcard",
            offlineStatus: isOffline ? .localOnly : .synced
        )

        if isOffline {
            queue.saveOfflineDraft(post)
        } else {
            repository.saveDraft(post)
        }

        let card = core.generatePrivateCard(text: text, flightContext: currentFlightContext)
        post.cardTemplateID = card.templateID
        generatedCard = renderer.render(post: post, flightContext: currentFlightContext)
        currentPost = post
        upsertPostRecord(from: post)
        if !isOffline {
            syncPostIfPossible(post, successFeedback: "私人明信片已同步")
        }
        track(AnalyticsAppEvent.cloudCardRendered, properties: [
            "template_id": post.cardTemplateID,
            "offline": isOffline ? "true" : "false"
        ])
        track(AnalyticsAppEvent.coreActionCompleted, properties: ["action_name": "private_card_generated"])
    }

    func editHeadlineQuote(_ quote: String) {
        guard var post = currentPost else { return }
        post.headlineQuote = quote.cloudFallback
        currentPost = post
        generatedCard = renderer.render(post: post, flightContext: currentFlightContext)
        upsertPostRecord(from: post)
        track(AnalyticsAppEvent.headlineQuoteEdited, properties: [
            "auto_generated_before": "true",
            "length": "\(quote.count)"
        ])
    }

    func sharePrivateCard(channel: ShareChannel) {
        let properties = [
            "channel": channel.rawValue,
            "template_id": currentPost?.cardTemplateID ?? "boarding_postcard"
        ]
        if channel == .saveImage {
            renderRemoteShareCardIfPossible(channel: channel)
        } else {
            track(AnalyticsAppEvent.privateCardShared, properties: properties)
            track(AnalyticsAppEvent.cardShared, properties: properties)
            renderRemoteShareCardIfPossible(channel: channel)
            lastFeedback = channel.feedback
        }
    }

    private func renderRemoteShareCardIfPossible(channel: ShareChannel) {
        guard let currentPost, let shareCardRenderClient else { return }
        let postID = currentPost.id
        let payload = RenderShareCardPayload(postID: postID, channel: channel.rawValue)
        Task {
            _ = try? await shareCardRenderClient.render(payload)
        }
    }

    func savePrivateCardImage(_ image: UIImage?) {
        let properties = [
            "channel": ShareChannel.saveImage.rawValue,
            "template_id": currentPost?.cardTemplateID ?? "boarding_postcard"
        ]
        requestPhotoLibrarySavePermission(properties: properties, image: image)
    }

    private func requestPhotoLibrarySavePermission(properties: [String: String], image: UIImage?) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completePrivateCardSave(properties: properties, image: image)
        case .denied, .restricted:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "photo_library",
                "source_screen": "private_share",
                "reason": status == .restricted ? "restricted" : "denied"
            ])
            lastFeedback = "相册权限未开启；可以改用复制链接"
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                Task { @MainActor in
                    self?.handlePhotoLibrarySaveAuthorization(newStatus, properties: properties, image: image)
                }
            }
        @unknown default:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "photo_library",
                "source_screen": "private_share",
                "reason": "unknown"
            ])
            lastFeedback = "相册权限状态未知；可以改用复制链接"
        }
    }

    private func handlePhotoLibrarySaveAuthorization(
        _ status: PHAuthorizationStatus,
        properties: [String: String],
        image: UIImage?
    ) {
        switch status {
        case .authorized, .limited:
            completePrivateCardSave(properties: properties, image: image)
        case .denied, .restricted:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "photo_library",
                "source_screen": "private_share",
                "reason": status == .restricted ? "restricted" : "denied"
            ])
            lastFeedback = "相册权限未开启；可以改用复制链接"
        case .notDetermined:
            lastFeedback = "相册权限尚未确认"
        @unknown default:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "photo_library",
                "source_screen": "private_share",
                "reason": "unknown"
            ])
            lastFeedback = "相册权限状态未知；可以改用复制链接"
        }
    }

    private func completePrivateCardSave(properties: [String: String], image: UIImage?) {
        track(AnalyticsAppEvent.permissionGranted, properties: [
            "type": "photo_library",
            "source_screen": "private_share"
        ])

        guard let image else {
            lastFeedback = "图片生成失败；可以改用复制链接"
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.track(AnalyticsAppEvent.privateCardSaved, properties: properties)
                    self.track(AnalyticsAppEvent.cloudCardSaved, properties: properties)
                    self.lastFeedback = ShareChannel.saveImage.feedback
                } else {
                    self.lastFeedback = "图片没有保存成功；可以改用复制链接"
                }
            }
        }
    }

    func requestCameraScanPermission(
        sourceScreen: String = "02",
        onAllowed: @escaping @MainActor @Sendable () -> Void,
        onDenied: @escaping @MainActor @Sendable (String) -> Void
    ) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            track(AnalyticsAppEvent.permissionGranted, properties: [
                "type": "camera",
                "source_screen": sourceScreen
            ])
            onAllowed()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.track(AnalyticsAppEvent.permissionGranted, properties: [
                            "type": "camera",
                            "source_screen": sourceScreen
                        ])
                        onAllowed()
                    } else {
                        self.handleCameraPermissionDenied(
                            reason: "denied_after_prompt",
                            sourceScreen: sourceScreen,
                            onDenied: onDenied
                        )
                    }
                }
            }
        case .denied, .restricted:
            handleCameraPermissionDenied(
                reason: status == .restricted ? "restricted" : "denied",
                sourceScreen: sourceScreen,
                onDenied: onDenied
            )
        @unknown default:
            handleCameraPermissionDenied(
                reason: "unknown",
                sourceScreen: sourceScreen,
                onDenied: onDenied
            )
        }
    }

    private func handleCameraPermissionDenied(
        reason: String,
        sourceScreen: String,
        onDenied: @MainActor @Sendable (String) -> Void
    ) {
        track(AnalyticsAppEvent.permissionDenied, properties: [
            "type": "camera",
            "source_screen": sourceScreen,
            "reason": reason
        ])
        lastFeedback = "相机权限未开启；可以选择票证截图或手动添加航班"
        onDenied(reason)
    }

    @discardableResult
    func createManualFlightContext(flightNumber: String, route: String, date: Date = Date()) -> Bool {
        guard let normalizedFlightNumber = flightNumber.trimmedOrNil else {
            lastFeedback = "请先填写航班号"
            return false
        }

        let context = FlightContext(
            flightNumber: normalizedFlightNumber,
            route: route.trimmedOrNil,
            departureDate: date,
            verificationStatus: .unverified
        )
        currentFlightContext = context
        syncFlightContextIfPossible(context)
        track(AnalyticsAppEvent.flightIntentCreated, properties: [
            "source": "manual",
            "flight_number_hash": safeHash(normalizedFlightNumber),
            "reminder_offset_minutes": "30"
        ])
        lastFeedback = "航班信息已添加，发布同班机前再验证"
        return true
    }

    func startFlightVerification(method: VerificationMethod = .manual) {
        track(AnalyticsAppEvent.flightVerificationStarted, properties: [
            "source": "add_flight_info",
            "method": method.rawValue
        ])
    }

    func applyBoardingPassScan(
        text: String,
        method: VerificationMethod = .boardingPassPhoto,
        fallbackFlightNumber: String = "",
        fallbackRoute: String = ""
    ) {
        startFlightVerification(method: method)
        track(AnalyticsAppEvent.captureStarted, properties: [
            "proof_source_type": method.rawValue,
            "upload_method": "local_vision"
        ])

        let parsed = BoardingPassTextParser().parse(text)
        track(AnalyticsAppEvent.captureCompleted, properties: [
            "proof_source_type": method.rawValue,
            "upload_method": "local_vision",
            "ocr_confidence": String(format: "%.2f", parsed.confidence)
        ])
        if parsed.confidence < 0.67 {
            track(AnalyticsAppEvent.ocrFailed, properties: [
                "proof_source_type": method.rawValue,
                "reason": "low_confidence"
            ])
        }

        guard let resolvedFlightNumber = parsed.flightNumber ?? fallbackFlightNumber.trimmedOrNil else {
            lastFeedback = "没有识别到航班号，请手动补充"
            return
        }

        let context = FlightContext(
            flightNumber: resolvedFlightNumber,
            route: parsed.route ?? fallbackRoute.trimmedOrNil,
            departureDate: parsed.departureDate ?? Date(),
            verificationStatus: .verified
        )
        currentFlightContext = context

        let proof = FlightProof(
            flightContextID: context.id,
            method: method,
            sourceImageHash: stableHash(text)
        )
        currentFlightProof = proof
        syncFlightVerificationIfPossible(context: context, proof: proof)
        track(AnalyticsAppEvent.flightProofCreated, properties: [
            "method": method.rawValue,
            "source_image_hash_present": proof.sourceImageHash == nil ? "false" : "true"
        ])
        track(AnalyticsAppEvent.flightConfirmed, properties: [
            "method": method.rawValue,
            "success": "true",
            "ocr_confidence": String(format: "%.2f", parsed.confidence)
        ])
        track(AnalyticsAppEvent.flightVerificationCompleted, properties: [
            "method": method.rawValue,
            "success": "true",
            "ocr_corrected": parsed.confidence < 1.0 ? "true" : "false"
        ])
        lastFeedback = parsed.confidence >= 0.67 ? "票证已识别并验证" : "已保留可识别字段，请检查航班信息"
    }

    func verifyCurrentFlight(method: VerificationMethod = .manual) {
        guard var context = currentFlightContext else {
            lastFeedback = "请先添加航班信息"
            return
        }

        context.verificationStatus = .verified
        currentFlightContext = context
        let proof = FlightProof(flightContextID: context.id, method: method, sourceImageHash: nil)
        currentFlightProof = proof
        syncFlightVerificationIfPossible(context: context, proof: proof)
        track(AnalyticsAppEvent.flightProofCreated, properties: [
            "method": method.rawValue,
            "source_image_hash_present": "false"
        ])
        track(AnalyticsAppEvent.flightConfirmed, properties: [
            "method": method.rawValue,
            "success": "true",
            "ocr_corrected": "false"
        ])
        track(AnalyticsAppEvent.flightVerificationCompleted, properties: [
            "method": method.rawValue,
            "success": "true",
            "ocr_corrected": "false"
        ])
        lastFeedback = "已验证同班机"
    }

    func publishSameFlight() -> SameFlightBlockReason? {
        let post = currentPost ?? CloudPost(
            flightContextID: currentFlightContext?.id,
            flightProofID: currentFlightProof?.id,
            text: draftText.cloudFallback
        )

        track(AnalyticsAppEvent.sameFlightPublishStarted, properties: [
            "verified": canCommentInSameFlight ? "true" : "false"
        ])

        let reason = core.publishSameFlight(
            post: post,
            flightContext: currentFlightContext,
            flightProof: currentFlightProof,
            isOnline: !isOffline
        )

        if reason == nil {
            var published = post
            published.publishScope = .sameFlight
            published.offlineStatus = .synced
            currentPost = published
            upsertPostRecord(from: published)
            if !isOffline {
                syncPostIfPossible(published, successFeedback: "已发布到本航班")
            }
            track(AnalyticsAppEvent.coreActionCompleted, properties: ["action_name": "same_flight_publish_completed"])
            maybeShowAccountUpgradePromptAfterSameFlightPost()
            lastFeedback = "已发布到本航班"
        } else {
            lastFeedback = "发布到同班机需要先验证航班"
        }

        return reason
    }

    func loadFlightSpacePosts(source: String = "09") {
        track(AnalyticsAppEvent.flightSpaceViewed, properties: [
            "source": source,
            "verified": canCommentInSameFlight ? "true" : "false"
        ])
        track(AnalyticsAppEvent.sameFlightNotesViewed, properties: [
            "source": source,
            "verified": canCommentInSameFlight ? "true" : "false"
        ])
        guard let contextID = currentFlightContext?.id, let flightSpaceClient else {
            return
        }

        isFlightSpaceLoading = true
        Task {
            do {
                let posts = try await flightSpaceClient.posts(flightContextID: contextID)
                flightSpacePosts = posts
                if let selectedFlightSpacePost,
                   !posts.contains(where: { $0.id == selectedFlightSpacePost.id }) {
                    self.selectedFlightSpacePost = nil
                }
                lastFeedback = "同班机笔记已更新"
            } catch {
                lastFeedback = "同班机笔记暂时无法更新，已显示本地内容"
            }
            isFlightSpaceLoading = false
        }
    }

    func discoveryViewed(tabName: String = "same_journey") {
        track(AnalyticsAppEvent.discoveryViewed, properties: [
            "tab_name": tabName
        ])
    }

    func registerRemotePushToken(_ token: String) {
        guard let pushTokenClient else {
            lastFeedback = "APNs token 已获取，等待服务端配置"
            return
        }
        Task {
            do {
                try await pushTokenClient.register(RegisterPushTokenPayload(token: token))
                lastFeedback = "通知设备已注册"
            } catch {
                lastFeedback = "通知设备注册失败，稍后重试"
            }
        }
    }

    private func syncFlightContextIfPossible(_ context: FlightContext) {
        guard let flightContextSyncClient else { return }
        let payload = createFlightContextPayload(from: context)
        Task {
            do {
                try await flightContextSyncClient.sync(payload)
            } catch {
                lastFeedback = "航班信息暂时只保存在本机"
            }
        }
    }

    private func syncFlightVerificationIfPossible(context: FlightContext, proof: FlightProof) {
        guard flightContextSyncClient != nil || flightProofSyncClient != nil else { return }
        let contextPayload = createFlightContextPayload(from: context)
        let proofPayload = CreateFlightProofPayload(
            flightContextID: proof.flightContextID,
            method: proof.method,
            sourceImageHash: proof.sourceImageHash
        )

        Task {
            do {
                try await flightContextSyncClient?.sync(contextPayload)
                try await flightProofSyncClient?.sync(proofPayload)
                lastFeedback = "航班验证已同步"
            } catch {
                lastFeedback = "航班验证暂时只保存在本机"
            }
        }
    }

    private func syncPostIfPossible(_ post: CloudPost, successFeedback: String) {
        guard let postSyncClient else { return }
        let context = currentFlightContext
        let proof = currentFlightProof

        Task {
            do {
                if let context {
                    try await flightContextSyncClient?.sync(createFlightContextPayload(from: context))
                }
                if post.publishScope == .sameFlight, let proof {
                    try await flightProofSyncClient?.sync(
                        CreateFlightProofPayload(
                            flightContextID: proof.flightContextID,
                            method: proof.method,
                            sourceImageHash: proof.sourceImageHash
                        )
                    )
                }
                let synced = try await postSyncClient.sync(post: post)
                currentPost = synced
                upsertPostRecord(from: synced)
                lastFeedback = successFeedback
            } catch {
                lastFeedback = "内容暂时只保存在本机"
            }
        }
    }

    func scheduleBoardingReminder(flightNumber: String, route: String) {
        guard createManualFlightContext(flightNumber: flightNumber, route: route) else { return }
        guard let context = currentFlightContext else { return }
        notificationScheduler.scheduleBoardingReminder(flightContext: context, minutesBeforeBoarding: 30) { [weak self] result in
            Task { @MainActor in
                self?.handleBoardingReminderScheduleResult(result, flightNumber: flightNumber, route: route)
            }
        }
    }

    private func handleBoardingReminderScheduleResult(
        _ result: NotificationScheduleResult,
        flightNumber: String,
        route: String
    ) {
        switch result {
        case .scheduled:
            let reminder = LocalReminder(
                flightNumber: currentFlightContext?.flightNumber ?? "待确认",
                route: currentFlightContext?.route ?? "路线待确认",
                reminderAt: Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            )
            reminders.append(reminder)
            persistReminders()
            track(AnalyticsAppEvent.permissionGranted, properties: [
                "type": "notification",
                "source_screen": "15"
            ])
            track(AnalyticsAppEvent.boardingReminderScheduled, properties: [
                "flight_number_hash": safeHash(flightNumber),
                "reminder_offset_minutes": "30"
            ])
            lastFeedback = "登机前 30 分钟提醒已保存"
            if let context = currentFlightContext {
                syncBoardingReminderIfPossible(context: context, reminder: reminder)
            }
        case .denied:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "notification",
                "source_screen": "15",
                "reason": "system_denied"
            ])
            lastFeedback = "通知权限未开启，航班已保存；你仍可继续写卡"
        case .failed:
            track(AnalyticsAppEvent.permissionDenied, properties: [
                "type": "notification",
                "source_screen": "15",
                "reason": "schedule_failed"
            ])
            lastFeedback = "提醒暂时没有保存成功，航班已保存在本机"
        }
    }

    private func syncBoardingReminderIfPossible(context: FlightContext, reminder: LocalReminder) {
        guard let boardingReminderClient else { return }
        Task {
            do {
                try await flightContextSyncClient?.sync(createFlightContextPayload(from: context))
                try await boardingReminderClient.schedule(
                    CreateBoardingReminderPayload(
                        flightContextID: context.id,
                        scheduledFor: reminder.reminderAt,
                        reminderOffsetMinutes: 30
                    )
                )
                lastFeedback = "登机提醒已同步"
            } catch {
                lastFeedback = "提醒已保存在本机，服务端稍后重试"
            }
        }
    }

    func openBoardingReminder() {
        track(AnalyticsAppEvent.boardingReminderOpened, properties: [
            "flight_number_hash": safeHash(currentFlightContext?.flightNumber ?? "none")
        ])
        lastFeedback = "已从登机提醒回到写作"
    }

    func smsCodeSent(isResend: Bool) {
        track(isResend ? AnalyticsAppEvent.smsCodeResend : AnalyticsAppEvent.smsCodeSent, properties: [
            "phone_country_code": "+86"
        ])
    }

    func smsCodeVerified() {
        track(AnalyticsAppEvent.smsCodeVerified, properties: [
            "phone_country_code": "+86"
        ])
    }

    func requestSMSCode(phone: String, isResend: Bool) async -> SMSChallengeResult? {
        let phoneDigits = phone.filter(\.isNumber)
        guard isValidChinesePhoneDigits(phoneDigits) else {
            phoneSignInFailed(reason: "invalid_phone")
            lastFeedback = "请输入 11 位中国大陆手机号"
            return nil
        }
        guard let smsChallengeClient else {
            phoneSignInFailed(reason: "sms_client_unavailable")
            lastFeedback = "短信服务暂未接入，内容仍保存在本机"
            return nil
        }

        do {
            let challenge = try await smsChallengeClient.send(SendSMSCodePayload(phone: phoneDigits))
            smsCodeSent(isResend: isResend)
            lastFeedback = "验证码已发送"
            return challenge
        } catch APIClientError.httpStatus(let status) {
            phoneSignInFailed(reason: status == 429 ? "rate_limited" : "sms_provider_unavailable")
            lastFeedback = status == 429 ? "验证码请求太频繁，请稍后再试" : "短信服务还没配置好，请稍后再试"
            return nil
        } catch {
            phoneSignInFailed(reason: "sms_network_or_server")
            lastFeedback = "验证码暂时发送失败，请稍后再试"
            return nil
        }
    }

    func verifySMSCode(challengeID: UUID, code: String) async -> SMSVerificationResult? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            phoneSignInFailed(reason: "empty_code")
            lastFeedback = "请输入验证码"
            return nil
        }
        guard let smsChallengeClient else {
            phoneSignInFailed(reason: "sms_client_unavailable")
            lastFeedback = "短信服务暂未接入，内容仍保存在本机"
            return nil
        }

        do {
            let result = try await smsChallengeClient.verify(
                VerifySMSCodePayload(challengeID: challengeID, code: trimmedCode)
            )
            smsCodeVerified()
            lastFeedback = "手机号已验证"
            return result
        } catch APIClientError.httpStatus(let status) {
            phoneSignInFailed(reason: status == 429 ? "rate_limited" : "invalid_code")
            lastFeedback = status == 429 ? "验证码错误次数过多，请稍后再试" : "验证码不正确或已过期"
            return nil
        } catch {
            phoneSignInFailed(reason: "sms_verify_network_or_server")
            lastFeedback = "验证码暂时无法校验，请稍后再试"
            return nil
        }
    }

    func phoneSignInFailed(reason: String) {
        track(AnalyticsAppEvent.signInFailed, properties: [
            "method": AuthMethod.phone.rawValue,
            "source": "sign_in_sheet",
            "reason": reason
        ])
    }

    func beginWeChatSignIn(source: String) {
        track(AnalyticsAppEvent.wechatAuthInitiated, properties: [
            "source": source,
            "method": AuthMethod.wechat.rawValue
        ])

        guard !isWeChatSignInInProgress else {
            lastFeedback = "正在等待微信授权"
            return
        }

        guard weChatAuthClient != nil else {
            finishWeChatSignInFailure(
                source: source,
                reason: "wechat_exchange_client_unavailable",
                message: "账号服务暂时不可用，请稍后再试"
            )
            return
        }

        guard WeChatSharing.isAvailable else {
            finishWeChatSignInFailure(
                source: source,
                reason: "wechat_unavailable",
                message: "未检测到可用微信，请使用手机号验证码"
            )
            return
        }

        let state = "hic-\(UUID().uuidString)"
        pendingWeChatAuthState = state
        pendingWeChatAuthSource = source
        isWeChatSignInInProgress = true
        lastFeedback = "正在打开微信授权..."

        WeChatSharing.requestAuthorization(state: state) { [weak self] success in
            Task { @MainActor in
                guard let self, !success, self.pendingWeChatAuthState == state else { return }
                self.finishWeChatSignInFailure(
                    source: source,
                    reason: "wechat_auth_request_failed",
                    message: "微信授权页没有打开，请稍后重试"
                )
            }
        }
    }

    private func handleWeChatAuthResponse(_ response: WeChatAuthResponse) {
        let source = pendingWeChatAuthSource ?? "unknown"
        track(AnalyticsAppEvent.wechatAuthCallbackReceived, properties: [
            "source": source,
            "err_code": "\(response.errorCode)",
            "has_code": response.hasAuthorizationCode ? "true" : "false"
        ])

        guard let expectedState = pendingWeChatAuthState, response.state == expectedState else {
            finishWeChatSignInFailure(
                source: source,
                reason: "wechat_state_mismatch",
                message: "微信登录状态校验失败，请重新登录"
            )
            return
        }

        guard response.errorCode == WXSuccess.rawValue else {
            let reason = response.errorCode == WXErrCodeUserCancel.rawValue ? "wechat_user_cancelled" : "wechat_auth_error"
            finishWeChatSignInFailure(
                source: source,
                reason: reason,
                message: response.errorCode == WXErrCodeUserCancel.rawValue ? "已取消微信登录" : "微信授权没有完成，请重试"
            )
            return
        }

        guard let code = response.code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            finishWeChatSignInFailure(
                source: source,
                reason: "wechat_code_missing",
                message: "微信没有返回授权码，请重试"
            )
            return
        }

        guard let weChatAuthClient else {
            finishWeChatSignInFailure(
                source: source,
                reason: "wechat_exchange_client_unavailable",
                message: "账号服务暂时不可用，请稍后再试"
            )
            return
        }

        Task {
            do {
                let result = try await weChatAuthClient.exchange(code: code)
                let resolvedMethod = AuthMethod(rawValue: result.authMethod) ?? .wechat
                applyAccountUpgrade(
                    accountID: result.accountID,
                    method: resolvedMethod,
                    source: source,
                    mergedWithExisting: result.mergedWithExisting,
                    mergedPostCount: result.mergedPostCount
                )
                clearPendingWeChatSignIn()
            } catch APIClientError.httpStatus(let status) {
                let reason = status == 400 ? "wechat_code_rejected" : "wechat_exchange_http_\(status)"
                finishWeChatSignInFailure(
                    source: source,
                    reason: reason,
                    message: "微信登录暂时没有完成，请稍后再试"
                )
            } catch {
                finishWeChatSignInFailure(
                    source: source,
                    reason: "wechat_exchange_network_or_server",
                    message: "微信登录暂时没有完成，请稍后再试"
                )
            }
        }
    }

    private func finishWeChatSignInFailure(source: String, reason: String, message: String) {
        clearPendingWeChatSignIn()
        track(AnalyticsAppEvent.signInFailed, properties: [
            "method": AuthMethod.wechat.rawValue,
            "source": source,
            "reason": reason
        ])
        lastFeedback = message
    }

    private func clearPendingWeChatSignIn() {
        pendingWeChatAuthState = nil
        pendingWeChatAuthSource = nil
        isWeChatSignInInProgress = false
    }

    func upgradeAccount(method: AuthMethod, source: String, phone: String? = nil) {
        upgradeAccount(method: method, source: source, phone: phone, verifiedProviderUserHash: nil)
    }

    func upgradePhoneAccount(source: String, verifiedProviderUserHash: String) {
        upgradeAccount(method: .phone, source: source, phone: nil, verifiedProviderUserHash: verifiedProviderUserHash)
    }

    private func upgradeAccount(
        method: AuthMethod,
        source: String,
        phone: String? = nil,
        verifiedProviderUserHash: String?
    ) {
        track(AnalyticsAppEvent.accountUpgradeStarted, properties: [
            "method": method.rawValue,
            "source": source
        ])
        track(AnalyticsAppEvent.signInStarted, properties: [
            "method": method.rawValue,
            "source": source
        ])

        guard let accountUpgradeClient else {
            applyAccountUpgrade(
                accountID: account.id,
                method: method,
                source: source,
                mergedWithExisting: false,
                mergedPostCount: 0
            )
            return
        }

        let payload = UpgradeAccountPayload(
            method: method.rawValue,
            providerUserHash: verifiedProviderUserHash ?? providerUserHash(method: method, phone: phone),
            wechatOpenIDHash: method == .wechat ? stableHash("wechat:dev-openid") : nil
        )

        Task {
            do {
                let result = try await accountUpgradeClient.upgrade(payload)
                let resolvedMethod = AuthMethod(rawValue: result.authMethod) ?? method
                applyAccountUpgrade(
                    accountID: result.accountID,
                    method: resolvedMethod,
                    source: source,
                    mergedWithExisting: result.mergedWithExisting,
                    mergedPostCount: result.mergedPostCount
                )
            } catch {
                track(AnalyticsAppEvent.signInFailed, properties: [
                    "method": method.rawValue,
                    "source": source,
                    "reason": "network_or_server"
                ])
                lastFeedback = "账号暂时没有保存成功，内容仍保存在本机"
            }
        }
    }

    private func applyAccountUpgrade(
        accountID: UUID,
        method: AuthMethod,
        source: String,
        mergedWithExisting: Bool,
        mergedPostCount: Int
    ) {
        account.id = accountID
        account.authMethod = method
        account.upgradedAt = Date()
        account.postCount = max(account.postCount, mergedPostCount)
        accountTokenProvider.update(accountID: accountID)
        persistAccount()
        track(AnalyticsAppEvent.signupCompleted, properties: [
            "user_id": account.id.uuidString,
            "utm_source": "direct",
            "utm_medium": "direct",
            "utm_campaign": "none",
            "referrer": "app",
            "signup_method": method.rawValue
        ])
        track(AnalyticsAppEvent.accountUpgradeCompleted, properties: [
            "method": method.rawValue,
            "source": source,
            "merged_with_existing": mergedWithExisting ? "true" : "false",
            "merged_post_count": "\(mergedPostCount)"
        ])
        track(AnalyticsAppEvent.signInSucceeded, properties: [
            "method": method.rawValue,
            "source": source
        ])
        lastFeedback = mergedWithExisting ? "找到你之前的账号，已合并飞行记录" : "保存好了，所有飞行已同步"
        accountUpgradePrompt = nil
    }

    private func providerUserHash(method: AuthMethod, phone: String?) -> String {
        switch method {
        case .guest:
            return stableHash("guest:\(account.id.uuidString)")
        case .wechat:
            return stableHash("wechat:dev-union")
        case .phone:
            let normalized = normalizedChinesePhone(phone ?? "")
            return stableHash("phone:\(normalized)")
        }
    }

    private func normalizedChinesePhone(_ rawPhone: String) -> String {
        let digits = rawPhone.filter(\.isNumber)
        if digits.hasPrefix("86") {
            return "+\(digits)"
        }
        return "+86\(digits)"
    }

    private func isValidChinesePhoneDigits(_ digits: String) -> Bool {
        digits.count == 11 && digits.first == "1"
    }

    func viewSettings() {
        track(AnalyticsAppEvent.accountSettingsViewed, properties: ["account_type": account.authMethod.rawValue])
    }

    func signOut() {
        guard account.authMethod != .guest else {
            lastFeedback = "当前已经是 Guest 状态，可以继续使用"
            return
        }
        track(AnalyticsAppEvent.signOutCompleted, properties: ["method": account.authMethod.rawValue])
        account = LocalAccount(
            id: UUID(),
            authMethod: .guest,
            createdAt: Date(),
            postCount: posts.count,
            hasCompletedOnboarding: true
        )
        accountTokenProvider.update(accountID: account.id)
        defaults.removeObject(forKey: Keys.lastUserReturnedDate)
        persistAccount()
        lastFeedback = "已退出，当前设备会继续以 Guest 使用"
    }

    func acceptAccountUpgradePrompt() {
        guard let prompt = accountUpgradePrompt else { return }
        markAccountUpgradePromptResolved(prompt, action: "accept")
        accountUpgradePrompt = nil
    }

    func dismissAccountUpgradePrompt() {
        guard let prompt = accountUpgradePrompt else { return }
        markAccountUpgradePromptResolved(prompt, action: "dismiss")
        accountUpgradePrompt = nil
    }

    func startAccountDeletionReauth() {
        track(AnalyticsAppEvent.accountDeletionRequested, properties: ["reauth_method": account.authMethod.rawValue])
        lastFeedback = "请先完成当前登录方式校验"
    }

    func confirmAccountDeletionAfterReauth() {
        track(AnalyticsAppEvent.accountDeletionConfirmed, properties: ["reauth_method": account.authMethod.rawValue])
        performAccountDeletion()
    }

    func requestAccountDeletion() {
        startAccountDeletionReauth()
        confirmAccountDeletionAfterReauth()
    }

    private func performAccountDeletion() {
        let method = account.authMethod
        guard let accountDeletionClient else {
            completeLocalAccountDeletion(reauthMethod: method)
            return
        }

        Task {
            do {
                _ = try await accountDeletionClient.delete(DeleteAccountPayload(reauthMethod: method.rawValue))
                completeLocalAccountDeletion(reauthMethod: method)
            } catch {
                lastFeedback = "账号删除暂时没有提交成功，请稍后重试"
            }
        }
    }

    func reportContent(reason: String) {
        guard let targetPostID = moderationPostID else {
            lastFeedback = "这条内容还没有可提交的服务端记录"
            return
        }
        track(AnalyticsAppEvent.reportSubmitted, properties: [
            "target_type": "post",
            "reason": reason
        ])
        if let reportClient {
            Task {
                do {
                    try await reportClient.report(
                        CreateReportPayload(
                            targetType: "post",
                            targetID: targetPostID,
                            reason: reason
                        )
                    )
                    lastFeedback = "举报已提交，我们会在 24 小时内处理"
                } catch {
                    lastFeedback = "举报暂时只保存在本机，请稍后重试"
                }
            }
            return
        }
        lastFeedback = "举报已提交，我们会在 24 小时内处理"
    }

    func blockUser(_ id: UUID? = nil) {
        let targetPostID = selectedFlightSpacePost?.id
        guard id != nil || targetPostID != nil else {
            lastFeedback = "这条内容还没有可屏蔽的服务端作者"
            return
        }
        track(AnalyticsAppEvent.blockUser, properties: [
            "target_type": "user",
            "reason": "user_blocked_from_post_detail"
        ])
        if let blockClient {
            Task {
                do {
                    if let id {
                        try await blockClient.block(CreateBlockPayload(blockedAccountID: id))
                        blockedUsers.insert(id.uuidString)
                    } else if let targetPostID {
                        try await blockClient.block(CreateBlockPayload(postID: targetPostID))
                        hiddenPostIDs.insert(targetPostID.uuidString)
                        flightSpacePosts.removeAll { $0.id == targetPostID }
                    }
                    defaults.set(Array(blockedUsers), forKey: Keys.blockedUsers)
                    defaults.set(Array(hiddenPostIDs), forKey: Keys.hiddenPostIDs)
                    lastFeedback = "已屏蔽该用户"
                } catch {
                    lastFeedback = "屏蔽暂时只保存在本机，请稍后重试"
                }
            }
            return
        }
        if let id {
            blockedUsers.insert(id.uuidString)
            defaults.set(Array(blockedUsers), forKey: Keys.blockedUsers)
        }
        if let targetPostID {
            hiddenPostIDs.insert(targetPostID.uuidString)
            defaults.set(Array(hiddenPostIDs), forKey: Keys.hiddenPostIDs)
            flightSpacePosts.removeAll { $0.id == targetPostID }
        }
        lastFeedback = "已屏蔽该用户"
    }

    func hideCurrentContent() {
        guard let targetPostID = moderationPostID else {
            lastFeedback = "这条内容还没有可隐藏的本地记录"
            return
        }
        hiddenPostIDs.insert(targetPostID.uuidString)
        defaults.set(Array(hiddenPostIDs), forKey: Keys.hiddenPostIDs)
        flightSpacePosts.removeAll { $0.id == targetPostID }
        lastFeedback = "已隐藏这条内容"
    }

    func submitComment(_ body: String) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lastFeedback = "先写一句回应"
            return
        }
        guard canCommentInSameFlight, let flightContextID = currentFlightContext?.id else {
            lastFeedback = "评论只在已验证的本航班开放"
            return
        }

        track(AnalyticsAppEvent.commentWritten, properties: [
            "is_same_flight": "true",
            "comment_length": "\(text.count)"
        ])

        guard let commentClient else {
            lastFeedback = "回应已保存在本机，联网后再同步"
            return
        }

        guard let targetPostID = selectedFlightSpacePost?.id ?? currentPost?.id else {
            lastFeedback = "这条内容还没有可回应的服务端记录"
            return
        }
        Task {
            do {
                try await commentClient.create(
                    CreateCommentPayload(
                        postID: targetPostID,
                        flightContextID: flightContextID,
                        body: text
                    )
                )
                lastFeedback = "回应已送到本航班"
                loadFlightSpacePosts(source: "comment")
            } catch {
                lastFeedback = "回应暂时只保存在本机，请稍后重试"
            }
        }
    }

    private var moderationPostID: UUID? {
        selectedFlightSpacePost?.id ?? currentPost?.id
    }

    func deleteCurrentPost() {
        guard let post = currentPost else {
            lastFeedback = "没有可删除的已发布卡片"
            return
        }
        guard let postDeletionClient else {
            completeLocalPostDeletion(postID: post.id)
            return
        }

        Task {
            do {
                try await postDeletionClient.delete(postID: post.id)
                completeLocalPostDeletion(postID: post.id)
            } catch {
                lastFeedback = "删除暂时没有提交成功，请稍后重试"
            }
        }
    }

    func openShareLanding(source: String = "qr") {
        track(AnalyticsAppEvent.shareLandingOpened, properties: [
            "source": source,
            "flight_number_hash": safeHash(currentFlightContext?.flightNumber ?? "unknown"),
            "route": currentFlightContext?.route ?? "pending"
        ])
    }

    func trackShareLandingSameFlightTapped() {
        track(AnalyticsAppEvent.shareLandingSameFlightTapped, properties: [
            "installed_app": "true",
            "flight_number_hash": safeHash(currentFlightContext?.flightNumber ?? "unknown"),
            "route": currentFlightContext?.route ?? "pending"
        ])
    }

    func trackShareLandingReminderStarted() {
        track(AnalyticsAppEvent.shareLandingReminderStarted, properties: [
            "installed_app": "true",
            "flight_number_hash": safeHash(currentFlightContext?.flightNumber ?? "unknown"),
            "route": currentFlightContext?.route ?? "pending"
        ])
    }

    func viewPaywall(sourcePage: String, planShown: String = "postcard_plus") {
        track(AnalyticsAppEvent.paywallViewed, properties: [
            "user_id": account.id.uuidString,
            "plan_shown": planShown,
            "source_page": sourcePage
        ])
    }

    func startCheckout(plan: String = "postcard_plus", priceCNY: Int = 12) {
        track(AnalyticsAppEvent.checkoutStarted, properties: [
            "user_id": account.id.uuidString,
            "plan": plan,
            "price_cny": "\(priceCNY)"
        ])

        guard let storeKitPurchaseCoordinator else {
            lastFeedback = "购买暂不可用：当前系统不支持 StoreKit 2"
            return
        }
        guard let purchaseClient else {
            lastFeedback = "购买暂不可用：服务端验证地址未配置"
            return
        }

        Task {
            do {
                lastFeedback = "正在连接 App Store..."
                let receipt = try await storeKitPurchaseCoordinator.purchase(
                    productID: productID(for: plan),
                    appAccountToken: account.id
                )
                let result = try await purchaseClient.verify(
                    VerifyIAPTransactionPayload(
                        transactionID: receipt.transactionID,
                        originalTransactionID: receipt.originalTransactionID,
                        productID: receipt.productID,
                        plan: plan,
                        amount: priceCNY,
                        currency: "CNY",
                        environment: receipt.environment,
                        signedTransactionJWS: receipt.signedTransactionJWS
                    )
                )
                lastFeedback = result.created ? "购买已由服务端记录" : "购买记录已存在"
            } catch let error as StoreKitPurchaseError {
                lastFeedback = error.userMessage
            } catch {
                lastFeedback = "购买验证暂时不可用，请稍后重试"
            }
        }
    }

    private func productID(for plan: String) -> String {
        switch plan {
        case "postcard_plus":
            return "hic.postcard.plus"
        default:
            return plan
        }
    }

    func postDetailViewed(source: String) {
        track(AnalyticsAppEvent.postDetailViewed, properties: [
            "source": source,
            "can_comment": canCommentInSameFlight ? "true" : "false"
        ])
    }

    func sameFlightNotificationOpened() {
        track(AnalyticsAppEvent.sameFlightNoteNotificationOpened, properties: [
            "flight_number_hash": safeHash(currentFlightContext?.flightNumber ?? "unknown")
        ])
    }

    func syncQueuedDrafts() {
        guard isOffline == false, isSyncingQueuedDraft == false, let post = nextQueuedPostForSync() else { return }
        isSyncingQueuedDraft = true

        if let postSyncClient {
            track(AnalyticsNames.offlineSyncStarted, properties: ["queue_id": post.id.uuidString])
            Task {
                do {
                    let synced = try await postSyncClient.sync(post: post)
                    currentPost = synced
                    upsertPostRecord(from: synced)
                    track(AnalyticsNames.offlineSyncCompleted, properties: ["queue_id": post.id.uuidString])
                    lastFeedback = "离线内容已同步"
                } catch {
                    var failed = post
                    failed.offlineStatus = .syncFailed
                    currentPost = failed
                    upsertPostRecord(from: failed)
                    track(AnalyticsNames.offlineSyncFailed, properties: [
                        "queue_id": post.id.uuidString,
                        "reason": String(describing: type(of: error))
                    ])
                    lastFeedback = "同步失败，内容仍保存在本机"
                }
                isSyncingQueuedDraft = false
            }
            return
        }

        let synced = queue.sync(post)
        currentPost = synced
        upsertPostRecord(from: synced)
        lastFeedback = "离线内容已同步"
        isSyncingQueuedDraft = false
    }

    private func nextQueuedPostForSync() -> CloudPost? {
        if let currentPost, currentPost.needsSync {
            return currentPost
        }

        guard let record = posts
            .sorted(by: { $0.createdAt < $1.createdAt })
            .first(where: { $0.offlineStatus.needsSync }) else {
            return nil
        }

        return record.asCloudPost(
            flightContextID: currentFlightContext?.id,
            flightProofID: currentFlightProof?.id
        )
    }

    private func upsertPostRecord(from post: CloudPost) {
        let context = currentFlightContext
        let record = LocalPostRecord(
            id: post.id,
            flightNumber: context?.flightNumber ?? "待确认",
            route: context?.route ?? "航班待确认",
            cityRoute: context?.route ?? "航班待确认",
            mood: "奔赴",
            headlineQuote: post.headlineQuote,
            text: post.text,
            templateID: post.cardTemplateID,
            scope: post.publishScope,
            offlineStatus: post.offlineStatus,
            createdAt: post.createdAt
        )

        posts.removeAll { $0.id == record.id }
        posts.append(record)
        account.postCount = posts.count
        persistPosts()
        persistAccount()
    }

    private func maybeShowAccountUpgradePromptAfterSameFlightPost() {
        guard account.authMethod == .guest else { return }
        let sameFlightPostCount = posts.filter { $0.scope == .sameFlight }.count
        guard [2, 3].contains(sameFlightPostCount),
              !shownAccountUpgradePromptThresholds.contains(sameFlightPostCount) else {
            return
        }

        let kind: AccountUpgradePrompt.Kind = sameFlightPostCount == 2 ? .soft : .hard
        accountUpgradePrompt = AccountUpgradePrompt(kind: kind, postCount: sameFlightPostCount)
        track(AnalyticsAppEvent.accountUpgradePromptViewed, properties: [
            "kind": kind.rawValue,
            "post_count": "\(sameFlightPostCount)"
        ])
        track(AnalyticsAppEvent.accountUpgradePromptShown, properties: [
            "variant": kind.rawValue,
            "trigger": "same_flight_post_count",
            "post_count": "\(sameFlightPostCount)"
        ])
    }

    private func markAccountUpgradePromptResolved(_ prompt: AccountUpgradePrompt, action: String) {
        shownAccountUpgradePromptThresholds.insert(prompt.postCount)
        defaults.set(Array(shownAccountUpgradePromptThresholds), forKey: Keys.accountUpgradePromptThresholds)
        track(AnalyticsAppEvent.accountUpgradePromptActioned, properties: [
            "kind": prompt.kind.rawValue,
            "post_count": "\(prompt.postCount)",
            "action": action
        ])
        if action == "dismiss" {
            track(AnalyticsAppEvent.accountUpgradePromptDismissed, properties: [
                "variant": prompt.kind.rawValue,
                "trigger": "same_flight_post_count",
                "post_count": "\(prompt.postCount)"
            ])
        }
    }

    private func trackUserReturnedIfNeeded(now: Date = Date()) {
        let calendar = Calendar(identifier: .gregorian)
        let signupDay = calendar.startOfDay(for: account.createdAt)
        let currentDay = calendar.startOfDay(for: now)
        guard currentDay > signupDay else { return }

        let currentDayKey = Self.analyticsDayFormatter.string(from: currentDay)
        guard defaults.string(forKey: Keys.lastUserReturnedDate) != currentDayKey else { return }

        let daysSinceSignup = calendar.dateComponents([.day], from: signupDay, to: currentDay).day ?? 0
        guard daysSinceSignup > 0 else { return }

        track(AnalyticsAppEvent.userReturned, properties: [
            "user_id": account.id.uuidString,
            "days_since_signup": "\(daysSinceSignup)"
        ])
        defaults.set(currentDayKey, forKey: Keys.lastUserReturnedDate)
    }

    private func completeLocalAccountDeletion(reauthMethod: AuthMethod) {
        track(AnalyticsAppEvent.accountDeletionCompleted, properties: [
            "account_type": reauthMethod.rawValue,
            "reauth_method": reauthMethod.rawValue,
            "recovery_days": "30"
        ])
        account = LocalAccount(id: UUID(), authMethod: .guest, createdAt: Date(), postCount: 0)
        accountTokenProvider.update(accountID: account.id)
        draftText = ""
        draftUpdatedAt = nil
        defaults.removeObject(forKey: Keys.draftUpdatedAt)
        defaults.removeObject(forKey: Keys.lastUserReturnedDate)
        currentFlightContext = nil
        currentFlightProof = nil
        generatedCard = nil
        currentPost = nil
        posts = []
        flightSpacePosts = []
        reminders = []
        persistAccount()
        persistPosts()
        persistReminders()
        lastFeedback = "账号已进入 30 天恢复期，本机会以 Guest 继续使用"
    }

    private func completeLocalPostDeletion(postID: UUID) {
        if currentPost?.id == postID {
            currentPost = nil
            generatedCard = nil
        }
        posts.removeAll { $0.id == postID }
        persistPosts()
        lastFeedback = "已删除这张卡片"
    }

    private func track(_ name: String, properties: [String: String] = [:]) {
        var eventProperties = sanitized(properties)
        if let smokeRunID = Self.configuredAnalyticsSmokeRunID() {
            eventProperties["smoke_run_id"] = smokeRunID
        }
        analyticsSink.track(AnalyticsEvent(name: name, properties: eventProperties))
    }

    private func trackDraftResumeIfNeeded() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let ageMS = max(0, Int(Date().timeIntervalSince(draftUpdatedAt ?? Date()) * 1000))
        track(AnalyticsAppEvent.draftResumed, properties: [
            "draft_age_ms": "\(ageMS)",
            "source": "app_launch"
        ])
        lastFeedback = "已恢复上次未写完的一句"
    }

    private func sanitized(_ properties: [String: String]) -> [String: String] {
        EventPropertySanitizer.sanitize(properties)
    }

    private func safeHash(_ value: String) -> String {
        stableHash(value)
    }

    private func stableHash(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !raw.isEmpty else { return "none" }
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func createFlightContextPayload(from context: FlightContext) -> CreateFlightContextPayload {
        CreateFlightContextPayload(
            id: context.id,
            flightNumberHash: safeHash(context.flightNumber ?? "unknown"),
            route: context.route ?? "pending",
            departureDate: context.departureDate.map { Self.flightDateFormatter.string(from: $0) },
            verificationStatus: context.verificationStatus
        )
    }

    private func persistAccount() {
        defaults.encode(account, forKey: Keys.account)
    }

    private static func defaultPostSyncClient(accountTokenProvider: LocalAccountTokenProvider) -> CloudPostSyncing? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteCloudPostSyncClient(api: api)
    }

    private static func defaultFlightContextSyncClient(accountTokenProvider: LocalAccountTokenProvider) -> FlightContextSyncing? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteFlightContextClient(api: api)
    }

    private static func defaultFlightProofSyncClient(accountTokenProvider: LocalAccountTokenProvider) -> FlightProofSyncing? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteFlightProofClient(api: api)
    }

    private static func defaultBoardingReminderClient(accountTokenProvider: LocalAccountTokenProvider) -> BoardingReminderScheduling? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteBoardingReminderClient(api: api)
    }

    private static func defaultFlightSpaceClient(accountTokenProvider: LocalAccountTokenProvider) -> FlightSpaceLoading? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteFlightSpaceClient(api: api)
    }

    private static func defaultPushTokenClient(accountTokenProvider: LocalAccountTokenProvider) -> PushTokenRegistering? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemotePushTokenClient(api: api)
    }

    private static func defaultAccountUpgradeClient(accountTokenProvider: LocalAccountTokenProvider) -> AccountUpgrading? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteAccountUpgradeClient(api: api)
    }

    private static func defaultWeChatAuthClient(accountTokenProvider: LocalAccountTokenProvider) -> WeChatAuthorizationExchanging? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteWeChatAuthClient(api: api)
    }

    private static func defaultAccountDeletionClient(accountTokenProvider: LocalAccountTokenProvider) -> AccountDeleting? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteAccountDeletionClient(api: api)
    }

    private static func defaultSMSChallengeClient(accountTokenProvider: LocalAccountTokenProvider) -> SMSChallengeHandling? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteSMSChallengeClient(api: api)
    }

    private static func defaultReportClient(accountTokenProvider: LocalAccountTokenProvider) -> ContentReporting? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteReportClient(api: api)
    }

    private static func defaultBlockClient(accountTokenProvider: LocalAccountTokenProvider) -> UserBlocking? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteBlockClient(api: api)
    }

    private static func defaultCommentClient(accountTokenProvider: LocalAccountTokenProvider) -> CommentCreating? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteCommentClient(api: api)
    }

    private static func defaultPostDeletionClient(accountTokenProvider: LocalAccountTokenProvider) -> OwnPostDeleting? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteOwnPostDeletionClient(api: api)
    }

    private static func defaultPurchaseClient(accountTokenProvider: LocalAccountTokenProvider) -> PurchaseVerifying? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemotePurchaseClient(api: api)
    }

    private static func defaultShareCardRenderClient(accountTokenProvider: LocalAccountTokenProvider) -> ShareCardRendering? {
        guard let api = defaultAPIRequestBuilder(accountTokenProvider: accountTokenProvider) else {
            return nil
        }
        return RemoteShareCardRenderClient(api: api)
    }

    private static func defaultAPIRequestBuilder(accountTokenProvider: LocalAccountTokenProvider) -> APIRequestBuilder? {
        guard let baseURL = configuredAPIBaseURL() else {
            return nil
        }
        return APIRequestBuilder(
            baseURL: baseURL,
            accountTokenProvider: {
                accountTokenProvider.currentToken()
            }
        )
    }

    private static func defaultAnalyticsSink(
        localAnalytics: InMemoryAnalyticsTracker,
        userIDHashProvider: @escaping () -> String?,
        deviceIDHashProvider: @escaping () -> String?,
        authorizationTokenProvider: @escaping () -> String?
    ) -> AnalyticsTracking {
        guard let endpointURL = configuredEventsEndpointURL() else {
            return localAnalytics
        }
        let eventPipeline = EventPipelineAnalyticsTracker(
            client: URLSessionEventIngestionClient(
                endpointURL: endpointURL,
                authorizationTokenProvider: authorizationTokenProvider
            ),
            appVersion: "dev",
            userIDHashProvider: userIDHashProvider,
            deviceIDHashProvider: deviceIDHashProvider
        )
        return FanoutAnalyticsTracker(trackers: [localAnalytics, eventPipeline])
    }

    private static func configuredEventsEndpointURL() -> URL? {
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: "HEAD_IN_CLOUDS_EVENTS_URL") as? String
        let environmentValue = ProcessInfo.processInfo.environment["HEAD_IN_CLOUDS_EVENTS_URL"]
        if let explicitURL = configuredURL(environmentValue ?? bundleValue) {
            return explicitURL
        }
        guard let baseURL = configuredAPIBaseURL() else {
            return nil
        }
        return baseURL.appendingPathComponent("events")
    }

    private static func configuredShareBaseURL() -> URL? {
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: "HEAD_IN_CLOUDS_SHARE_BASE_URL") as? String
        let environmentValue = ProcessInfo.processInfo.environment["HEAD_IN_CLOUDS_SHARE_BASE_URL"]
        return configuredURL(environmentValue ?? bundleValue)
    }

    private static func configuredAPIBaseURL() -> URL? {
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: "HEAD_IN_CLOUDS_API_BASE_URL") as? String
        let environmentValue = ProcessInfo.processInfo.environment["HEAD_IN_CLOUDS_API_BASE_URL"]
        return configuredURL(environmentValue ?? bundleValue)
    }

    private static func configuredAnalyticsSmokeRunID() -> String? {
        let environmentValue = ProcessInfo.processInfo.environment["HIC_ANALYTICS_SMOKE_RUN_ID"]
        let trimmed = environmentValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func configuredIAPEnvironment() -> String {
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: "HEAD_IN_CLOUDS_IAP_ENVIRONMENT") as? String
        let environmentValue = ProcessInfo.processInfo.environment["HEAD_IN_CLOUDS_IAP_ENVIRONMENT"]
        let rawValue = (environmentValue ?? bundleValue)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rawValue == "production" ? "production" : "sandbox"
    }

    private static func configuredURL(_ rawValue: String?) -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let url = URL(string: rawValue),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }
        return url
    }

    private func persistDraft() {
        defaults.set(draftText, forKey: Keys.draftText)
        if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftUpdatedAt = nil
            defaults.removeObject(forKey: Keys.draftUpdatedAt)
            return
        }
        let now = Date()
        draftUpdatedAt = now
        defaults.set(now, forKey: Keys.draftUpdatedAt)
    }

    private func persistFlightContext() {
        defaults.encode(currentFlightContext, forKey: Keys.flightContext)
    }

    private func persistFlightProof() {
        defaults.encode(currentFlightProof, forKey: Keys.flightProof)
    }

    private func persistPosts() {
        defaults.encode(posts, forKey: Keys.posts)
    }

    private func persistReminders() {
        defaults.encode(reminders, forKey: Keys.reminders)
    }

    private enum Keys {
        static let account = "hic.account"
        static let draftText = "hic.draftText"
        static let draftUpdatedAt = "hic.draftUpdatedAt"
        static let flightContext = "hic.flightContext"
        static let flightProof = "hic.flightProof"
        static let posts = "hic.posts"
        static let reminders = "hic.reminders"
        static let blockedUsers = "hic.blockedUsers"
        static let hiddenPostIDs = "hic.hiddenPostIDs"
        static let firstLaunchTracked = "hic.firstLaunchTracked"
        static let lastUserReturnedDate = "hic.lastUserReturnedDate"
        static let accountUpgradePromptThresholds = "hic.accountUpgradePromptThresholds"
    }

    private static let analyticsDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let flightDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct StoreKitPurchaseReceipt: Equatable {
    let transactionID: String
    let originalTransactionID: String?
    let productID: String
    let environment: String
    let signedTransactionJWS: String
}

@MainActor
protocol StoreKitPurchaseCoordinating: AnyObject {
    func purchase(productID: String, appAccountToken: UUID) async throws -> StoreKitPurchaseReceipt
}

enum StoreKitPurchaseError: Error {
    case productUnavailable
    case pending
    case userCancelled
    case unverified
    case unknown

    var userMessage: String {
        switch self {
        case .productUnavailable:
            return "购买暂不可用：App Store Connect 还没有配置这个商品"
        case .pending:
            return "购买正在等待 App Store 处理"
        case .userCancelled:
            return "已取消购买"
        case .unverified:
            return "购买验证失败，请稍后重试"
        case .unknown:
            return "购买暂时不可用，请稍后重试"
        }
    }
}

@MainActor
final class StoreKitPurchaseCoordinator: StoreKitPurchaseCoordinating {
    private let environment: String

    init(environment: String) {
        self.environment = environment
    }

    func purchase(productID: String, appAccountToken: UUID) async throws -> StoreKitPurchaseReceipt {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreKitPurchaseError.productUnavailable
        }

        let purchaseOptions: Set<Product.PurchaseOption> = [.appAccountToken(appAccountToken)]
        let result = try await product.purchase(options: purchaseOptions)
        switch result {
        case .success(let verificationResult):
            let transaction = try verifiedTransaction(from: verificationResult)
            await transaction.finish()
            return StoreKitPurchaseReceipt(
                transactionID: String(transaction.id),
                originalTransactionID: String(transaction.originalID),
                productID: transaction.productID,
                environment: environment,
                signedTransactionJWS: verificationResult.jwsRepresentation
            )
        case .pending:
            throw StoreKitPurchaseError.pending
        case .userCancelled:
            throw StoreKitPurchaseError.userCancelled
        @unknown default:
            throw StoreKitPurchaseError.unknown
        }
    }

    private func verifiedTransaction(from result: VerificationResult<StoreKit.Transaction>) throws -> StoreKit.Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreKitPurchaseError.unverified
        }
    }
}

private final class LocalAccountTokenProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var accountID: UUID

    init(accountID: UUID) {
        self.accountID = accountID
    }

    func update(accountID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        self.accountID = accountID
    }

    func currentToken() -> String {
        lock.lock()
        defer { lock.unlock() }
        return accountID.uuidString
    }
}

protocol NetworkMonitoring: AnyObject, Sendable {
    func start(_ handler: @escaping @Sendable (Bool) -> Void)
    func cancel()
}

final class NetworkPathMonitor: NetworkMonitoring, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "head-in-clouds.network")

    func start(_ handler: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            handler(path.status != .satisfied)
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}

struct LocalAccount: Codable, Equatable {
    var id: UUID
    var authMethod: AuthMethod
    var createdAt: Date
    var upgradedAt: Date?
    var postCount: Int
    var hasCompletedOnboarding: Bool

    init(
        id: UUID,
        authMethod: AuthMethod,
        createdAt: Date,
        upgradedAt: Date? = nil,
        postCount: Int,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.authMethod = authMethod
        self.createdAt = createdAt
        self.upgradedAt = upgradedAt
        self.postCount = postCount
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

enum AuthMethod: String, Codable, CaseIterable {
    case guest
    case wechat
    case phone

    var displayName: String {
        switch self {
        case .guest: return "未保存账号"
        case .wechat: return "已用微信保存"
        case .phone: return "已用手机号保存"
        }
    }
}

struct LocalPostRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var flightNumber: String
    var route: String
    var cityRoute: String
    var mood: String
    var headlineQuote: String
    var text: String
    var templateID: String
    var scope: PublishScope
    var offlineStatus: OfflineStatus
    var createdAt: Date

    var dateLabel: String {
        Self.dateFormatter.string(from: createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension LocalPostRecord {
    func asCloudPost(flightContextID: UUID?, flightProofID: UUID?) -> CloudPost {
        CloudPost(
            id: id,
            flightContextID: flightContextID,
            flightProofID: scope == .sameFlight ? flightProofID : nil,
            publishScope: scope,
            text: text,
            textMode: .oneLine,
            headlineQuote: headlineQuote,
            cardTemplateID: templateID,
            offlineStatus: offlineStatus,
            createdAt: createdAt
        )
    }
}

private extension CloudPost {
    var needsSync: Bool {
        offlineStatus.needsSync
    }
}

private extension OfflineStatus {
    var needsSync: Bool {
        self == .localOnly || self == .syncFailed
    }
}

struct LocalReminder: Identifiable, Codable, Equatable {
    let id: UUID
    var flightNumber: String
    var route: String
    var reminderAt: Date

    init(id: UUID = UUID(), flightNumber: String, route: String, reminderAt: Date) {
        self.id = id
        self.flightNumber = flightNumber
        self.route = route
        self.reminderAt = reminderAt
    }
}

struct FlightRecordViewModel: Identifiable, Equatable {
    let id = UUID()
    let flightNumber: String
    let date: String
    let route: String
    let cityRoute: String
    let mood: String
    let quote: String
}

struct FlightSpacePostViewModel: Identifiable, Equatable {
    let id: UUID
    let identity: String
    let quote: String
    let status: String

    init(id: UUID = UUID(), identity: String, quote: String, status: String) {
        self.id = id
        self.identity = identity
        self.quote = quote
        self.status = status
    }
}

struct AccountUpgradePrompt: Identifiable, Equatable {
    enum Kind: String {
        case soft
        case hard
    }

    let kind: Kind
    let postCount: Int

    var id: String {
        "\(kind.rawValue)-\(postCount)"
    }
}

enum ShareChannel: String, CaseIterable, Identifiable {
    case saveImage = "save_image"
    case wechat = "wechat_chat"
    case moments = "wechat_moments"
    case rednote = "xiaohongshu"
    case copyLink = "copy_link"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveImage: return "保存图片"
        case .wechat: return "微信"
        case .moments: return "朋友圈"
        case .rednote: return "小红书"
        case .copyLink: return "复制链接"
        }
    }

    var icon: String {
        switch self {
        case .saveImage: return "photo"
        case .wechat: return "message"
        case .moments: return "arrow.2.circlepath"
        case .rednote: return "book"
        case .copyLink: return "link"
        }
    }

    var feedback: String {
        switch self {
        case .saveImage: return "图片已保存到本机相册"
        case .wechat: return "已唤起微信，可选择好友发送"
        case .moments: return "已唤起朋友圈，可继续发布"
        case .rednote: return "已准备小红书分享图"
        case .copyLink: return "链接已复制"
        }
    }
}

enum AnalyticsAppEvent {
    static let appFirstLaunched = "app_first_launched"
    static let userReturned = "user_returned"
    static let onboardingStepViewed = "onboarding_step_viewed"
    static let onboardingCompleted = "onboarding_completed"
    static let guestModeChosen = "guest_mode_chosen"
    static let landingViewed = "landing_viewed"
    static let landingFirstViewed = "01a_landing_viewed"
    static let landingReturningViewed = "01b_landing_viewed"
    static let composeModeSelected = "compose_mode_selected"
    static let templatePromptSelected = "template_prompt_selected"
    static let voiceRecordingStarted = "voice_recording_started"
    static let voiceTranscribed = "voice_transcribed"
    static let cloudCardRendered = "cloud_card_rendered"
    static let headlineQuoteEdited = "headline_quote_edited"
    static let privateCardSaved = "private_card_saved"
    static let privateCardShared = "private_card_shared"
    static let cloudCardSaved = "cloud_card_saved"
    static let cardShared = "card_shared"
    static let flightIntentCreated = "flight_intent_created"
    static let flightVerificationStarted = "flight_verification_started"
    static let captureStarted = "capture_started"
    static let captureCompleted = "capture_completed"
    static let ocrFailed = "ocr_failed"
    static let flightConfirmed = "flight_confirmed"
    static let flightProofCreated = "flight_proof_created"
    static let flightVerificationCompleted = "flight_verification_completed"
    static let sameFlightPublishStarted = "same_flight_publish_started"
    static let flightSpaceViewed = "flight_space_viewed"
    static let boardingReminderScheduled = "boarding_reminder_scheduled"
    static let boardingReminderOpened = "boarding_reminder_opened"
    static let permissionGranted = "permission_granted"
    static let permissionDenied = "permission_denied"
    static let shareLandingOpened = "share_landing_opened"
    static let shareLandingSameFlightTapped = "share_landing_same_flight_tapped"
    static let shareLandingReminderStarted = "share_landing_reminder_started"
    static let sameFlightNoteNotificationOpened = "same_flight_note_notification_opened"
    static let sameFlightNotesViewed = "same_flight_notes_viewed"
    static let postDetailViewed = "post_detail_viewed"
    static let discoveryViewed = "discovery_viewed"
    static let accountUpgradeStarted = "account_upgrade_started"
    static let accountUpgradeCompleted = "account_upgrade_completed"
    static let accountUpgradePromptViewed = "account_upgrade_prompt_viewed"
    static let accountUpgradePromptActioned = "account_upgrade_prompt_actioned"
    static let accountUpgradePromptShown = "account_upgrade_prompt_shown"
    static let accountUpgradePromptDismissed = "account_upgrade_prompt_dismissed"
    static let signupCompleted = "signup_completed"
    static let signInStarted = "sign_in_started"
    static let signInSucceeded = "sign_in_succeeded"
    static let signInFailed = "sign_in_failed"
    static let smsCodeSent = "sms_code_sent"
    static let smsCodeVerified = "sms_code_verified"
    static let smsCodeResend = "sms_code_resend"
    static let wechatAuthInitiated = "wechat_auth_initiated"
    static let wechatAuthCallbackReceived = "wechat_auth_callback_received"
    static let accountSettingsViewed = "account_settings_viewed"
    static let signOutCompleted = "sign_out_completed"
    static let accountDeletionRequested = "account_deletion_requested"
    static let accountDeletionConfirmed = "account_deletion_confirmed"
    static let accountDeletionCompleted = "account_deletion_completed"
    static let reportSubmitted = "report_submitted"
    static let blockUser = "block_user"
    static let commentWritten = "comment_written"
    static let coreActionCompleted = "core_action_completed"
    static let draftResumed = "draft_resumed"
    static let paywallViewed = "paywall_viewed"
    static let checkoutStarted = "checkout_started"
}

private extension UserDefaults {
    func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key)
    }
}

private extension Optional where Wrapped == Bool {
    func map<T>(_ transform: (Bool) -> T, default defaultValue: T) -> T {
        guard let self else { return defaultValue }
        return transform(self)
    }
}

private extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
