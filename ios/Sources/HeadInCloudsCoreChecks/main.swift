import Foundation
import HeadInCloudsCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError("Check failed: \(message)")
    }
}

func checkPrivateCardDoesNotRequireFlightVerification() {
    let analytics = InMemoryAnalyticsTracker()
    let core = HeadInCloudsCore(
        analytics: analytics,
        repository: InMemoryCloudPostRepository()
    )

    let card = core.generatePrivateCard(text: "这次飞行，我只想说一句。")

    expect(card.templateID == "boarding_postcard", "private card uses default postcard template")
    expect(card.metadata == "航班待确认", "private card can be generated without flight metadata")
    expect(
        analytics.events.contains { $0.name == AnalyticsNames.privateCardGenerated },
        "private_card_generated is tracked"
    )
}

func checkOrdinaryUGCUsesFlightLogTemplate() {
    let renderer = CloudCardRenderer()
    let post = CloudPost(text: "飞机晚点了，累死。")

    let card = renderer.render(post: post, flightContext: nil)

    expect(card.templateID == "flight_log", "ordinary UGC should use flight_log fallback")
}

func checkUnverifiedSameFlightPublishIsBlocked() {
    let analytics = InMemoryAnalyticsTracker()
    let core = HeadInCloudsCore(
        analytics: analytics,
        repository: InMemoryCloudPostRepository()
    )
    let context = FlightContext(flightNumber: "MU5301", route: "SHA -> CTU")
    let post = CloudPost(flightContextID: context.id, text: "落地以后，我希望能睡一觉。")

    let reason = core.publishSameFlight(
        post: post,
        flightContext: context,
        flightProof: nil,
        isOnline: true
    )

    expect(reason == .unverified, "unverified user cannot publish to same flight")
    expect(
        analytics.events.contains {
            $0.name == AnalyticsNames.sameFlightPublishBlocked &&
                $0.properties["reason"] == SameFlightBlockReason.unverified.rawValue
        },
        "same_flight_publish_blocked is tracked"
    )
}

func checkVerifiedSameFlightPublishPasses() {
    let analytics = InMemoryAnalyticsTracker()
    let repository = InMemoryCloudPostRepository()
    let core = HeadInCloudsCore(analytics: analytics, repository: repository)
    let context = FlightContext(
        flightNumber: "MU5301",
        route: "SHA -> CTU",
        verificationStatus: .verified
    )
    let proof = FlightProof(flightContextID: context.id, method: .manual)
    let post = CloudPost(
        flightContextID: context.id,
        flightProofID: proof.id,
        text: "这次终于不是出差。"
    )

    let reason = core.publishSameFlight(
        post: post,
        flightContext: context,
        flightProof: proof,
        isOnline: true
    )

    expect(reason == nil, "verified user can publish to same flight")
    expect(repository.post(id: post.id)?.publishScope == .sameFlight, "post scope changes to sameFlight")
    expect(
        analytics.events.contains {
            $0.name == AnalyticsNames.sameFlightPublishCompleted &&
                $0.properties["flight_space_id"] == context.id.uuidString &&
                $0.properties["template_id"] == post.cardTemplateID
        },
        "same_flight_publish_completed is tracked with flight space and template"
    )
}

func checkOfflineDraftCanBeSavedAndSynced() {
    let analytics = InMemoryAnalyticsTracker()
    let repository = InMemoryCloudPostRepository()
    let queue = OfflineSyncQueue(analytics: analytics, repository: repository)
    let post = CloudPost(text: "如果只能带一样东西上飞机，是一本没读完的书。")

    queue.saveOfflineDraft(post)
    let synced = queue.sync(post)

    expect(repository.post(id: post.id)?.offlineStatus == .synced, "offline draft sync persists")
    expect(synced.offlineStatus == .synced, "sync returns synced post")
    expect(
        analytics.events.contains {
            $0.name == AnalyticsNames.offlineDraftSaved &&
                $0.properties["content_length"] == "\(post.text.count)" &&
                $0.properties["has_flight_context"] == "false"
        },
        "offline draft save tracked with content length and flight context state"
    )
    expect(
        analytics.events.contains {
            $0.name == AnalyticsNames.offlineSyncStarted &&
                $0.properties["queue_id"] == post.id.uuidString
        },
        "offline sync start tracked with queue id"
    )
    expect(
        analytics.events.contains {
            $0.name == AnalyticsNames.offlineSyncCompleted &&
                $0.properties["queue_id"] == post.id.uuidString
        },
        "offline sync completion tracked with queue id"
    )
}

func checkNotificationSchedulerReportsPermissionResult() {
    let context = FlightContext(flightNumber: "MU5301", route: "SHA -> CTU")
    let deniedScheduler = InMemoryNotificationScheduler(result: .denied)
    let resultBox = ScheduleResultBox()

    deniedScheduler.scheduleBoardingReminder(flightContext: context, minutesBeforeBoarding: 30) { result in
        resultBox.value = result
    }

    expect(resultBox.value == .denied, "notification scheduler returns denied result")
    expect(deniedScheduler.scheduledReminderCount == 0, "denied notification is not counted as scheduled")
}

final class ScheduleResultBox: @unchecked Sendable {
    var value: NotificationScheduleResult?
}

func checkPublicIdentityDoesNotExposeExactSeat() {
    let card = CloudCardRenderer().render(
        post: CloudPost(text: "我把没说的话带过云层。"),
        flightContext: FlightContext(
            flightNumber: "MU5301",
            route: "SHA -> CTU",
            verificationStatus: .verified
        )
    )

    expect(card.publicIdentityLabel == "同机乘客", "public identity uses fuzzy label")
    expect(!card.publicIdentityLabel.contains("14A"), "public identity does not expose exact seat")
}

func checkPublicTextSanitizerRedactsCardQuote() {
    let card = CloudCardRenderer().render(
        post: CloudPost(
            text: "我坐在14A，想把邮箱 user@example.com 留给同机乘客。",
            headlineQuote: "14A窗边的人，邮箱 user@example.com"
        ),
        flightContext: nil
    )

    expect(card.headlineQuote.contains("某个座位"), "public card quote redacts exact seat")
    expect(card.headlineQuote.contains("已隐藏联系方式"), "public card quote redacts email")
    expect(!card.headlineQuote.contains("14A"), "public card quote removes raw seat")
    expect(!card.headlineQuote.contains("user@example.com"), "public card quote removes raw email")
}

func checkBoardingPassParserExtractsSafeFlightFields() {
    let parsed = BoardingPassTextParser().parse("""
    Passenger REDACTED
    MU 5301
    SHA → CTU
    2026.05.19
    Seat 14A
    """)

    expect(parsed.flightNumber == "MU5301", "boarding pass parser extracts normalized flight number")
    expect(parsed.route == "SHA → CTU", "boarding pass parser extracts route")
    expect(parsed.departureDate == Date(timeIntervalSince1970: 1_779_148_800), "boarding pass parser extracts UTC date")
    expect(parsed.confidence == 1.0, "boarding pass parser confidence reflects filled fields")
}

func checkAnalyticsSanitizerRemovesSensitiveFields() {
    let sanitized = EventPropertySanitizer.sanitize([
        "email": "user@example.com",
        "seat_number": "14A",
        "flight_number_hash": "123456",
        "source": "compose",
        "note": "I sat in 14A"
    ])

    expect(sanitized["email"] == nil, "email key is removed")
    expect(sanitized["seat_number"] == nil, "seat number key is removed")
    expect(sanitized["note"] == nil, "seat number value is removed")
    expect(sanitized["flight_number_hash"] == "123456", "safe hash is preserved")
    expect(sanitized["source"] == "compose", "safe source is preserved")
}

func checkEventPipelineBuildsFirstPartyEnvelope() {
    let client = InMemoryEventIngestionClient()
    let tracker = EventPipelineAnalyticsTracker(
        client: client,
        appVersion: "dev",
        userIDHashProvider: { "user-hash" },
        deviceIDHashProvider: { "device-hash" }
    )

    tracker.track(
        AnalyticsEvent(
            name: "compose_started",
            properties: [
                "source": "opening",
                "email": "user@example.com"
            ]
        )
    )

    expect(client.envelopes.count == 1, "event pipeline sends one envelope")
    expect(client.envelopes[0].eventName == "compose_started", "envelope keeps event name")
    expect(client.envelopes[0].properties["source"] == "opening", "envelope keeps safe property")
    expect(client.envelopes[0].properties["email"] == nil, "envelope removes raw email")
    expect(client.envelopes[0].appVersion == "dev", "envelope includes app version")
    expect(client.envelopes[0].platform == "ios", "envelope includes platform")
    expect(client.envelopes[0].userIDHash == "user-hash", "envelope uses user hash")
    expect(client.envelopes[0].deviceIDHash == "device-hash", "envelope uses device hash")
}

func checkFanoutAnalyticsKeepsLocalAndFirstPartyEvents() {
    let local = InMemoryAnalyticsTracker()
    let client = InMemoryEventIngestionClient()
    let eventPipeline = EventPipelineAnalyticsTracker(client: client, appVersion: "dev")
    let fanout = FanoutAnalyticsTracker(trackers: [local, eventPipeline])

    fanout.track(AnalyticsEvent(name: "boarding_reminder_scheduled", properties: ["flight_number_hash": "safe"]))

    expect(local.events.count == 1, "fanout keeps local analytics event")
    expect(client.envelopes.count == 1, "fanout sends first-party event envelope")
    expect(client.envelopes[0].eventName == "boarding_reminder_scheduled", "fanout keeps event name")
}

func checkEventRequestBuilderTargetsFirstPartyEndpoint() throws {
    let builder = EventIngestionRequestBuilder(endpointURL: URL(string: "http://127.0.0.1:8787/events")!)
    let request = try builder.build(
        envelope: EventEnvelope(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            eventName: "compose_started",
            properties: ["source": "opening"],
            clientTime: Date(timeIntervalSince1970: 1_779_321_600),
            appVersion: "dev",
            platform: "ios",
            userIDHash: "user-hash",
            deviceIDHash: "device-hash"
        ),
        authorizationToken: "account-token"
    )
    let body = String(data: request.body, encoding: .utf8) ?? ""

    expect(request.url.absoluteString == "http://127.0.0.1:8787/events", "request targets first-party endpoint")
    expect(request.method == "POST", "request uses POST")
    expect(request.headers["content-type"] == "application/json", "request uses JSON content type")
    expect(request.headers["authorization"] == "Bearer account-token", "request includes account bearer token")
    expect(body.contains(#""event_name":"compose_started""#), "request uses snake_case event name")
    expect(body.contains(#""client_time":"2026-05-21T00:00:00Z""#), "request uses ISO client time")
    expect(body.contains(#""device_id_hash":"device-hash""#), "request uses hashed device identifier")
}

func checkAPIRequestBuilderUsesFirstPartyAuthenticatedAPI() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.createBoardingReminder(
        CreateBoardingReminderPayload(
            flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            scheduledFor: Date(timeIntervalSince1970: 1_779_323_400),
            reminderOffsetMinutes: 30
        )
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/notification-jobs/boarding-reminder/create", "request targets first-party boarding reminder API")
    expect(request.httpMethod == "POST", "request uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "request includes bearer token")
    expect(body.contains(#""flight_context_id":"00000000-0000-0000-0000-000000000002""#), "request includes flight context id")
    expect(body.contains(#""reminder_offset_minutes":30"#), "request includes reminder offset")
}

func checkPostAPIRequestUsesClientGeneratedID() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.createPost(
        CreatePostPayload(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            publishScope: .privateCard,
            text: "离线写下的一句话。",
            headlineQuote: "离线写下的一句话。",
            offlineStatus: .syncing
        )
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/posts/create", "request targets first-party post API")
    expect(body.contains(#""id":"00000000-0000-0000-0000-000000000003""#), "request includes client-generated post id")
    expect(body.contains(#""publish_scope":"private_card""#), "request includes publish scope")
    expect(body.contains(#""offline_status":"syncing""#), "request includes offline status")
}

func checkCreatePostResponseDecodesServerContract() throws {
    let data = """
    {
      "ok": true,
      "post": {
        "id": "00000000-0000-0000-0000-000000000003",
        "flight_context_id": null,
        "flight_proof_id": null,
        "publish_scope": "private_card",
        "text": "离线写下的一句话。",
        "headline_quote": "离线写下的一句话。",
        "text_mode": "one_line",
        "card_template_id": "boarding_postcard",
        "offline_status": "synced",
        "created_at": "2026-05-21T00:00:01.000Z"
      }
    }
    """.data(using: .utf8)!

    let post = try APIResponseDecoder.decodeCreatePostResponse(data)

    expect(post.id == UUID(uuidString: "00000000-0000-0000-0000-000000000003"), "decoded post keeps server id")
    expect(post.publishScope == .privateCard, "decoded post uses private_card contract")
    expect(post.textMode == .oneLine, "decoded post uses one_line contract")
    expect(post.offlineStatus == .synced, "decoded post is synced")
    expect(post.createdAt == Date(timeIntervalSince1970: 1_779_321_601), "decoded post parses fractional ISO date")
}

func checkFlightSpacePostsAPIUsesVerifiedContextEndpoint() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = builder.flightSpacePosts(
        flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    )

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/flight-spaces/00000000-0000-0000-0000-000000000009/posts", "flight space posts request targets first-party API")
    expect(request.httpMethod == "GET", "flight space posts request uses GET")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "flight space posts request includes bearer token")
}

func checkFlightSpacePostsResponseDecodesSafeFields() throws {
    let data = """
    {
      "ok": true,
      "posts": [
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "flight_context_id": "00000000-0000-0000-0000-000000000009",
          "publish_scope": "same_flight",
          "text": "我把没有说出口的话，带过了云层。",
          "headline_quote": "我把没有说出口的话，带过了云层。",
          "text_mode": "one_line",
          "card_template_id": "boarding_postcard",
          "public_identity_label": "同机乘客",
          "comment_count": 2,
          "created_at": "2026-05-21T00:00:01.000Z",
          "published_at": "2026-05-21T00:00:01.000Z"
        }
      ]
    }
    """.data(using: .utf8)!

    let posts = try APIResponseDecoder.decodeFlightSpacePostsResponse(data)

    expect(posts.count == 1, "decoded one flight space post")
    expect(posts[0].publishScope == .sameFlight, "decoded post uses same_flight contract")
    expect(posts[0].publicIdentityLabel == "同机乘客", "decoded post keeps fuzzy identity label")
    expect(posts[0].commentCount == 2, "decoded post keeps comment count")
    expect(posts[0].createdAt == Date(timeIntervalSince1970: 1_779_321_601), "decoded post parses created date")
}

func checkRemoteCloudPostSyncClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "post": {
        "id": "00000000-0000-0000-0000-000000000004",
        "flight_context_id": null,
        "flight_proof_id": null,
        "publish_scope": "private_card",
        "text": "本地离线稿。",
        "headline_quote": "本地离线稿。",
        "text_mode": "one_line",
        "card_template_id": "boarding_postcard",
        "offline_status": "synced",
        "created_at": "2026-05-21T00:00:01.000Z"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemoteCloudPostSyncClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )
    let synced = try await client.sync(
        post: CloudPost(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            publishScope: .privateCard,
            text: "本地离线稿。",
            offlineStatus: .localOnly
        )
    )

    let lastRequest = await loader.lastRequest
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/posts/create", "remote sync hits post create endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote sync includes account token")
    expect(synced.id == UUID(uuidString: "00000000-0000-0000-0000-000000000004"), "remote sync keeps client id")
    expect(synced.offlineStatus == .synced, "remote sync returns synced post")
}

func checkRemoteFlightContextClientSyncsBeforePost() async throws {
    let data = """
    {
      "ok": true,
      "flight_context": {
        "id": "00000000-0000-0000-0000-000000000011"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemoteFlightContextClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    try await client.sync(
        CreateFlightContextPayload(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            flightNumberHash: "flight-hash",
            route: "SHA -> CTU",
            departureDate: "2026-05-21",
            verificationStatus: .unverified
        )
    )

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/flight-contexts/create", "remote flight context hits create endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote flight context includes bearer token")
    expect(body.contains(#""id":"00000000-0000-0000-0000-000000000011""#), "remote flight context uses client-generated id")
    expect(body.contains(#""departure_date":"2026-05-21""#), "remote flight context includes departure date")
}

func checkRemoteFlightProofClientSyncsVerification() async throws {
    let data = """
    {
      "ok": true,
      "flight_proof": {
        "id": "00000000-0000-0000-0000-000000000012"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemoteFlightProofClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    try await client.sync(
        CreateFlightProofPayload(
            flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            method: .ticketScreenshot,
            sourceImageHash: "local-fixture-hash"
        )
    )

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/flight-proof/create", "remote flight proof hits create endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote flight proof includes bearer token")
    expect(body.contains(#""flight_context_id":"00000000-0000-0000-0000-000000000011""#), "remote flight proof includes context id")
    expect(body.contains(#""method":"ticket_screenshot""#), "remote flight proof uses server method enum")
    expect(body.contains(#""source_image_hash":"local-fixture-hash""#), "remote flight proof includes safe image hash")
}

func checkRemoteBoardingReminderClientSchedulesServerJob() async throws {
    let data = """
    {
      "ok": true,
      "job": {
        "id": "00000000-0000-0000-0000-000000000013"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemoteBoardingReminderClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    try await client.schedule(
        CreateBoardingReminderPayload(
            flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            scheduledFor: Date(timeIntervalSince1970: 1_779_323_400),
            reminderOffsetMinutes: 30
        )
    )

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/notification-jobs/boarding-reminder/create", "remote boarding reminder hits create endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote boarding reminder includes bearer token")
    expect(body.contains(#""flight_context_id":"00000000-0000-0000-0000-000000000011""#), "remote boarding reminder includes context id")
    expect(body.contains(#""reminder_offset_minutes":30"#), "remote boarding reminder includes offset")
}

func checkRemoteFlightSpaceClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "posts": [
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "flight_context_id": "00000000-0000-0000-0000-000000000009",
          "publish_scope": "same_flight",
          "text": "我把没有说出口的话，带过了云层。",
          "headline_quote": "我把没有说出口的话，带过了云层。",
          "text_mode": "one_line",
          "card_template_id": "boarding_postcard",
          "public_identity_label": "同机乘客",
          "comment_count": 0,
          "created_at": "2026-05-21T00:00:01.000Z",
          "published_at": "2026-05-21T00:00:01.000Z"
        }
      ]
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 200)
    let client = RemoteFlightSpaceClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let posts = try await client.posts(
        flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    )

    let lastRequest = await loader.lastRequest
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/flight-spaces/00000000-0000-0000-0000-000000000009/posts", "remote flight space hits posts endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote flight space includes account token")
    expect(posts.count == 1, "remote flight space returns decoded posts")
}

func checkRemotePushTokenClientRegistersToken() async throws {
    let data = """
    {
      "ok": true,
      "push_token": {
        "id": "token-a"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemotePushTokenClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    try await client.register(RegisterPushTokenPayload(token: "apns-token-a"))

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/push-tokens/register", "remote push token hits register endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote push token includes bearer token")
    expect(body.contains(#""platform":"ios""#), "remote push token includes platform")
    expect(body.contains(#""token":"apns-token-a""#), "remote push token includes token")
}

func checkSafetyAPIRequestsUseFirstPartyEndpoints() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let report = try builder.createReport(
        CreateReportPayload(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            targetType: "post",
            targetID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            reason: "harassment"
        )
    )
    let block = try builder.createBlock(
        CreateBlockPayload(blockedAccountID: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
    )
    let blockByPost = try builder.createBlock(
        CreateBlockPayload(postID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)
    )
    let comment = try builder.createComment(
        CreateCommentPayload(
            postID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            body: "我也在这趟航班上。"
        )
    )
    let deletePost = builder.deletePost(postID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)
    let reportBody = String(data: report.httpBody ?? Data(), encoding: .utf8) ?? ""
    let blockBody = String(data: block.httpBody ?? Data(), encoding: .utf8) ?? ""
    let blockByPostBody = String(data: blockByPost.httpBody ?? Data(), encoding: .utf8) ?? ""
    let commentBody = String(data: comment.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(report.url?.absoluteString == "https://api.headintheclouds.test/api/reports/create", "report uses first-party API")
    expect(reportBody.contains(#""target_type":"post""#), "report includes target type")
    expect(block.url?.absoluteString == "https://api.headintheclouds.test/api/blocks/create", "block uses first-party API")
    expect(blockBody.contains(#""blocked_account_id":"00000000-0000-0000-0000-000000000007""#), "block includes blocked account id")
    expect(blockByPost.url?.absoluteString == "https://api.headintheclouds.test/api/blocks/create", "block by post uses first-party API")
    expect(blockByPostBody.contains(#""post_id":"00000000-0000-0000-0000-000000000006""#), "block by post includes post id")
    expect(comment.url?.absoluteString == "https://api.headintheclouds.test/api/comments/create", "comment uses first-party API")
    expect(commentBody.contains(#""flight_context_id":"00000000-0000-0000-0000-000000000009""#), "comment includes verified flight context id")
    expect(deletePost.url?.absoluteString == "https://api.headintheclouds.test/api/posts/00000000-0000-0000-0000-000000000006", "delete own post uses first-party API")
    expect(deletePost.httpMethod == "DELETE", "delete own post uses DELETE")
}

func checkRemoteSafetyClientsUseFirstPartyEndpoints() async throws {
    let data = """
    {
      "ok": true
    }
    """.data(using: .utf8)!
    let reportLoader = StubDataLoader(data: data, statusCode: 201)
    let blockLoader = StubDataLoader(data: data, statusCode: 201)
    let commentLoader = StubDataLoader(data: data, statusCode: 201)
    let deleteLoader = StubDataLoader(data: data, statusCode: 200)
    let api = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let reportClient = RemoteReportClient(api: api, session: reportLoader)
    let blockClient = RemoteBlockClient(api: api, session: blockLoader)
    let commentClient = RemoteCommentClient(api: api, session: commentLoader)
    let deleteClient = RemoteOwnPostDeletionClient(api: api, session: deleteLoader)

    try await reportClient.report(
        CreateReportPayload(
            targetType: "post",
            targetID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            reason: "harassment"
        )
    )
    try await blockClient.block(
        CreateBlockPayload(blockedAccountID: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
    )
    try await commentClient.create(
        CreateCommentPayload(
            postID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            flightContextID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            body: "我也在这趟航班上。"
        )
    )
    try await deleteClient.delete(postID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)

    let reportRequest = await reportLoader.lastRequest
    let blockRequest = await blockLoader.lastRequest
    let commentRequest = await commentLoader.lastRequest
    let deleteRequest = await deleteLoader.lastRequest
    expect(reportRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/reports/create", "remote report hits first-party endpoint")
    expect(reportRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote report includes bearer token")
    expect(blockRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/blocks/create", "remote block hits first-party endpoint")
    expect(blockRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote block includes bearer token")
    expect(commentRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/comments/create", "remote comment hits first-party endpoint")
    expect(commentRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote comment includes bearer token")
    expect(deleteRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/posts/00000000-0000-0000-0000-000000000006", "remote delete own post hits first-party endpoint")
    expect(deleteRequest?.httpMethod == "DELETE", "remote delete own post uses DELETE")
    expect(deleteRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote delete own post includes bearer token")
}

func checkShareCardURLUsesPublicShareEndpoint() {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let url = builder.shareCardURL(postID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!)

    expect(url.absoluteString == "https://api.headintheclouds.test/share/cards/00000000-0000-0000-0000-000000000008", "share card URL uses public share endpoint")
}

func checkShareCardRenderAPIUsesFirstPartyServer() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.renderShareCard(
        RenderShareCardPayload(
            postID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            channel: "wechat_moments"
        )
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/share-cards/render", "share card render uses first-party API")
    expect(request.httpMethod == "POST", "share card render uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "share card render includes bearer token")
    expect(body.contains(#""post_id":"00000000-0000-0000-0000-000000000008""#), "share card render includes post id")
    expect(body.contains(#""channel":"wechat_moments""#), "share card render includes channel")
}

func checkShareCardRenderResponseDecodesServerContract() throws {
    let data = """
    {
      "ok": true,
      "share_card": {
        "post_id": "00000000-0000-0000-0000-000000000008",
        "template_id": "boarding_postcard",
        "object_key": "cloud-cards/00000000-0000-0000-0000-000000000008.svg",
        "share_image_url": "https://cdn.example/cloud-cards/00000000-0000-0000-0000-000000000008.svg",
        "content_type": "image/svg+xml",
        "channel": "wechat_moments"
      }
    }
    """.data(using: .utf8)!

    let result = try APIResponseDecoder.decodeShareCardRenderResponse(data)

    expect(result.postID == UUID(uuidString: "00000000-0000-0000-0000-000000000008"), "share card render decodes post id")
    expect(result.shareImageURL.absoluteString == "https://cdn.example/cloud-cards/00000000-0000-0000-0000-000000000008.svg", "share card render decodes public URL")
    expect(result.objectKey == "cloud-cards/00000000-0000-0000-0000-000000000008.svg", "share card render decodes object key")
    expect(result.contentType == "image/svg+xml", "share card render decodes content type")
    expect(result.channel == "wechat_moments", "share card render decodes channel")
}

func checkRemoteShareCardRenderClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "share_card": {
        "post_id": "00000000-0000-0000-0000-000000000008",
        "template_id": "boarding_postcard",
        "object_key": "cloud-cards/00000000-0000-0000-0000-000000000008.svg",
        "share_image_url": "https://cdn.example/cloud-cards/00000000-0000-0000-0000-000000000008.svg",
        "content_type": "image/svg+xml",
        "channel": "wechat_moments"
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 201)
    let client = RemoteShareCardRenderClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let result = try await client.render(
        RenderShareCardPayload(
            postID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            channel: "wechat_moments"
        )
    )

    let lastRequest = await loader.lastRequest
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/share-cards/render", "remote share render hits first-party endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote share render includes account token")
    expect(result.shareImageURL.host == "cdn.example", "remote share render returns public image URL")
}

func checkPushTokenRegistrationUsesFirstPartyAPI() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.registerPushToken(
        RegisterPushTokenPayload(token: "apns-token-a")
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/push-tokens/register", "push token registration uses first-party API")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "push token registration includes bearer token")
    expect(body.contains(#""platform":"ios""#), "push token registration includes platform")
    expect(body.contains(#""token":"apns-token-a""#), "push token registration includes APNs token")
}

func checkAccountUpgradeAPIUsesFirstPartyAPI() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.upgradeAccount(
        UpgradeAccountPayload(
            method: "phone",
            providerUserHash: "phone-hash-a"
        )
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/accounts/upgrade", "account upgrade uses first-party API")
    expect(request.httpMethod == "POST", "account upgrade uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "account upgrade includes bearer token")
    expect(body.contains(#""method":"phone""#), "account upgrade includes auth method")
    expect(body.contains(#""provider_user_hash":"phone-hash-a""#), "account upgrade sends provider hash")
    expect(!body.contains("13800138000"), "account upgrade does not send raw phone")
}

func checkAccountUpgradeResponseDecodesMerge() throws {
    let data = """
    {
      "ok": true,
      "account": {
        "id": "11111111-1111-4111-8111-111111111111",
        "auth_method": "phone",
        "created_at": "2026-05-21T00:00:00.000Z",
        "upgraded_at": "2026-05-21T00:00:02.000Z",
        "deleted_at": null
      },
      "merge": {
        "merged_with_existing": true,
        "previous_account_id": "22222222-2222-4222-8222-222222222222",
        "target_account_id": "11111111-1111-4111-8111-111111111111",
        "merged_post_count": 2
      }
    }
    """.data(using: .utf8)!

    let result = try APIResponseDecoder.decodeAccountUpgradeResponse(data)

    expect(result.accountID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"), "account upgrade decodes target account id")
    expect(result.authMethod == "phone", "account upgrade decodes auth method")
    expect(result.mergedWithExisting, "account upgrade decodes merge flag")
    expect(result.previousAccountID == UUID(uuidString: "22222222-2222-4222-8222-222222222222"), "account upgrade decodes previous account id")
    expect(result.mergedPostCount == 2, "account upgrade decodes migrated post count")
}

func checkRemoteAccountUpgradeClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "account": {
        "id": "11111111-1111-4111-8111-111111111111",
        "auth_method": "wechat",
        "created_at": "2026-05-21T00:00:00.000Z",
        "upgraded_at": "2026-05-21T00:00:02.000Z",
        "deleted_at": null
      },
      "merge": {
        "merged_with_existing": false,
        "previous_account_id": null,
        "target_account_id": "11111111-1111-4111-8111-111111111111",
        "merged_post_count": 0
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 200)
    let client = RemoteAccountUpgradeClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let result = try await client.upgrade(
        UpgradeAccountPayload(
            method: "wechat",
            providerUserHash: "wechat-union-hash",
            wechatOpenIDHash: "wechat-openid-hash"
        )
    )

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/accounts/upgrade", "remote account upgrade hits upgrade endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote account upgrade includes bearer token")
    expect(body.contains(#""wechat_open_id_hash":"wechat-openid-hash""#), "remote account upgrade includes WeChat openid hash")
    expect(result.accountID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"), "remote account upgrade returns account id")
    expect(result.authMethod == "wechat", "remote account upgrade returns auth method")
    expect(!result.mergedWithExisting, "remote account upgrade returns merge flag")
}

func checkAccountDeletionAPIUsesFirstPartyAPI() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.deleteAccount(DeleteAccountPayload(reauthMethod: "phone"))
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/accounts/delete", "account deletion uses first-party API")
    expect(request.httpMethod == "POST", "account deletion uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "account deletion includes bearer token")
    expect(body.contains(#""reauth_method":"phone""#), "account deletion sends reauth method")
}

func checkAccountDeletionResponseDecodesRecoveryDeadline() throws {
    let data = """
    {
      "ok": true,
      "account": {
        "id": "11111111-1111-4111-8111-111111111111",
        "auth_method": "phone",
        "created_at": "2026-05-21T00:00:00.000Z",
        "upgraded_at": "2026-05-21T00:00:02.000Z",
        "deleted_at": "2026-05-21T00:00:03.000Z"
      },
      "recovery_deadline": "2026-06-20T00:00:03.000Z"
    }
    """.data(using: .utf8)!

    let result = try APIResponseDecoder.decodeAccountDeletionResponse(data)

    expect(result.accountID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"), "account deletion decodes account id")
    expect(result.deletedAt == Date(timeIntervalSince1970: 1_779_321_603), "account deletion decodes deleted timestamp")
    expect(result.recoveryDeadline == Date(timeIntervalSince1970: 1_781_913_603), "account deletion decodes 30-day recovery timestamp")
}

func checkRemoteAccountDeletionClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "account": {
        "id": "11111111-1111-4111-8111-111111111111",
        "auth_method": "phone",
        "created_at": "2026-05-21T00:00:00.000Z",
        "upgraded_at": "2026-05-21T00:00:02.000Z",
        "deleted_at": "2026-05-21T00:00:03.000Z"
      },
      "recovery_deadline": "2026-06-20T00:00:03.000Z"
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 200)
    let client = RemoteAccountDeletionClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let result = try await client.delete(DeleteAccountPayload(reauthMethod: "phone"))

    let lastRequest = await loader.lastRequest
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/accounts/delete", "remote account deletion hits delete endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote account deletion includes bearer token")
    expect(result.accountID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"), "remote account deletion returns account id")
    expect(result.deletedAt != nil, "remote account deletion returns deleted timestamp")
}

func checkSMSChallengeAPIUsesFirstPartyServer() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let sendRequest = try builder.sendSMSCode(SendSMSCodePayload(phone: "13800138000"))
    let sendBody = String(data: sendRequest.httpBody ?? Data(), encoding: .utf8) ?? ""
    let challengeID = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
    let verifyRequest = try builder.verifySMSCode(VerifySMSCodePayload(challengeID: challengeID, code: "123456"))
    let verifyBody = String(data: verifyRequest.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(sendRequest.url?.absoluteString == "https://api.headintheclouds.test/api/auth/sms/send", "SMS send uses first-party endpoint")
    expect(sendRequest.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "SMS send includes bearer token")
    expect(sendBody.contains(#""phone_country_code":"+86""#), "SMS send includes country code")
    expect(sendBody.contains(#""phone":"13800138000""#), "SMS send includes phone for provider delivery")
    expect(verifyRequest.url?.absoluteString == "https://api.headintheclouds.test/api/auth/sms/verify", "SMS verify uses first-party endpoint")
    expect(verifyRequest.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "SMS verify includes bearer token")
    expect(verifyBody.contains(#""challenge_id":"00000000-0000-4000-8000-000000000401""#), "SMS verify includes challenge id")
    expect(verifyBody.contains(#""code":"123456""#), "SMS verify includes code")
}

func checkSMSChallengeResponsesDecodeServerContract() throws {
    let sendData = """
    {
      "ok": true,
      "sms_challenge": {
        "id": "00000000-0000-4000-8000-000000000401",
        "status": "pending",
        "phone_country_code": "+86",
        "expires_at": "2026-05-21T00:05:01.000Z",
        "resend_available_at": "2026-05-21T00:01:01.000Z",
        "max_attempts": 3
      },
      "delivery": {
        "provider": "mock",
        "status": "mocked"
      }
    }
    """.data(using: .utf8)!
    let verifyData = """
    {
      "ok": true,
      "sms_challenge": {
        "id": "00000000-0000-4000-8000-000000000401",
        "status": "verified",
        "phone_country_code": "+86",
        "expires_at": "2026-05-21T00:05:01.000Z",
        "resend_available_at": "2026-05-21T00:01:01.000Z",
        "max_attempts": 3,
        "verified_at": "2026-05-21T00:00:21.000Z",
        "provider_user_hash": "phone-provider-hash"
      }
    }
    """.data(using: .utf8)!

    let sent = try APIResponseDecoder.decodeSMSChallengeResponse(sendData)
    let verified = try APIResponseDecoder.decodeSMSVerificationResponse(verifyData)

    expect(sent.challengeID == UUID(uuidString: "00000000-0000-4000-8000-000000000401"), "SMS challenge decodes id")
    expect(sent.deliveryProvider == "mock", "SMS challenge decodes delivery provider")
    expect(sent.deliveryStatus == "mocked", "SMS challenge decodes delivery status")
    expect(sent.maxAttempts == 3, "SMS challenge decodes max attempts")
    expect(verified.status == "verified", "SMS verification decodes status")
    expect(verified.providerUserHash == "phone-provider-hash", "SMS verification returns provider hash for account upgrade")
}

func checkRemoteSMSChallengeClientUsesServerResponse() async throws {
    let sendData = """
    {
      "ok": true,
      "sms_challenge": {
        "id": "00000000-0000-4000-8000-000000000401",
        "status": "pending",
        "phone_country_code": "+86",
        "expires_at": "2026-05-21T00:05:01.000Z",
        "resend_available_at": "2026-05-21T00:01:01.000Z",
        "max_attempts": 3
      },
      "delivery": {
        "provider": "mock",
        "status": "mocked"
      }
    }
    """.data(using: .utf8)!
    let verifyData = """
    {
      "ok": true,
      "sms_challenge": {
        "id": "00000000-0000-4000-8000-000000000401",
        "status": "verified",
        "phone_country_code": "+86",
        "expires_at": "2026-05-21T00:05:01.000Z",
        "resend_available_at": "2026-05-21T00:01:01.000Z",
        "max_attempts": 3,
        "verified_at": "2026-05-21T00:00:21.000Z",
        "provider_user_hash": "phone-provider-hash"
      }
    }
    """.data(using: .utf8)!
    let api = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let sendLoader = StubDataLoader(data: sendData, statusCode: 201)
    let verifyLoader = StubDataLoader(data: verifyData, statusCode: 200)
    let sendClient = RemoteSMSChallengeClient(api: api, session: sendLoader)
    let verifyClient = RemoteSMSChallengeClient(api: api, session: verifyLoader)

    let sent = try await sendClient.send(SendSMSCodePayload(phone: "13800138000"))
    let verified = try await verifyClient.verify(VerifySMSCodePayload(challengeID: sent.challengeID, code: "123456"))

    let sendRequest = await sendLoader.lastRequest
    let verifyRequest = await verifyLoader.lastRequest
    expect(sendRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/auth/sms/send", "remote SMS send hits first-party endpoint")
    expect(verifyRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/auth/sms/verify", "remote SMS verify hits first-party endpoint")
    expect(sent.deliveryProvider == "mock", "remote SMS send returns delivery provider")
    expect(verified.providerUserHash == "phone-provider-hash", "remote SMS verify returns provider hash")
}

func checkWeChatExchangeAPIUsesFirstPartyServer() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.exchangeWeChatCode(ExchangeWeChatCodePayload(code: "wechat-auth-code"))
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/auth/wechat/exchange", "wechat exchange uses first-party API")
    expect(request.httpMethod == "POST", "wechat exchange uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "wechat exchange includes bearer token")
    expect(body.contains(#""code":"wechat-auth-code""#), "wechat exchange sends authorization code")
    expect(!body.contains("AppSecret"), "wechat exchange does not send AppSecret from client")
}

func checkRemoteWeChatAuthClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "provider": "wechat",
      "scope": "snsapi_userinfo",
      "account": {
        "id": "11111111-1111-4111-8111-111111111111",
        "auth_method": "wechat",
        "created_at": "2026-05-21T00:00:00.000Z",
        "upgraded_at": "2026-05-21T00:00:02.000Z",
        "deleted_at": null
      },
      "merge": {
        "merged_with_existing": false,
        "previous_account_id": null,
        "target_account_id": "11111111-1111-4111-8111-111111111111",
        "merged_post_count": 0
      }
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 200)
    let client = RemoteWeChatAuthClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let result = try await client.exchange(code: "wechat-auth-code")

    let lastRequest = await loader.lastRequest
    let body = String(data: lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/auth/wechat/exchange", "remote wechat auth hits exchange endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote wechat auth includes bearer token")
    expect(body.contains(#""code":"wechat-auth-code""#), "remote wechat auth sends code only")
    expect(result.accountID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"), "remote wechat auth returns account id")
    expect(result.authMethod == "wechat", "remote wechat auth returns auth method")
}

func checkPurchaseVerificationAPIUsesFirstPartyServer() throws {
    let builder = APIRequestBuilder(
        baseURL: URL(string: "https://api.headintheclouds.test")!,
        accountTokenProvider: { "account-token" }
    )
    let request = try builder.verifyIAPTransaction(
        VerifyIAPTransactionPayload(
            transactionID: "local-tx-001",
            originalTransactionID: "local-original-001",
            productID: "hic.postcard.plus",
            plan: "postcard_plus",
            amount: 12,
            environment: "sandbox",
            signedTransactionJWS: "header.payload.signature"
        )
    )
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

    expect(request.url?.absoluteString == "https://api.headintheclouds.test/api/iap/transactions/verify", "IAP verification uses first-party API")
    expect(request.httpMethod == "POST", "IAP verification uses POST")
    expect(request.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "IAP verification includes bearer token")
    expect(body.contains(#""transaction_id":"local-tx-001""#), "IAP verification includes transaction id")
    expect(body.contains(#""product_id":"hic.postcard.plus""#), "IAP verification includes product id")
    expect(body.contains(#""amount":12"#), "IAP verification includes CNY amount")
    expect(body.contains(#""environment":"sandbox""#), "IAP verification includes StoreKit environment")
    expect(body.contains(#""signed_transaction_jws":"header.payload.signature""#), "IAP verification includes signed transaction JWS")
}

func checkPurchaseVerificationResponseDecodesServerContract() throws {
    let data = """
    {
      "ok": true,
      "subscription": {
        "id": "00000000-0000-4000-8000-000000000301",
        "transaction_id": "local-tx-001",
        "original_transaction_id": "local-original-001",
        "product_id": "hic.postcard.plus",
        "plan": "postcard_plus",
        "amount": 12,
        "currency": "CNY",
        "environment": "local_mock",
        "status": "active",
        "created_at": "2026-05-21T00:00:01.000Z"
      },
      "created": true
    }
    """.data(using: .utf8)!

    let result = try APIResponseDecoder.decodePurchaseVerificationResponse(data)

    expect(result.transactionID == "local-tx-001", "purchase verification decodes transaction id")
    expect(result.productID == "hic.postcard.plus", "purchase verification decodes product id")
    expect(result.plan == "postcard_plus", "purchase verification decodes plan")
    expect(result.amount == 12, "purchase verification decodes amount")
    expect(result.currency == "CNY", "purchase verification decodes currency")
    expect(result.environment == "local_mock", "purchase verification decodes environment")
    expect(result.created, "purchase verification decodes created flag")
}

func checkRemotePurchaseClientUsesServerResponse() async throws {
    let data = """
    {
      "ok": true,
      "subscription": {
        "id": "00000000-0000-4000-8000-000000000301",
        "transaction_id": "local-tx-001",
        "original_transaction_id": "local-original-001",
        "product_id": "hic.postcard.plus",
        "plan": "postcard_plus",
        "amount": 12,
        "currency": "CNY",
        "environment": "local_mock",
        "status": "active",
        "created_at": "2026-05-21T00:00:01.000Z"
      },
      "created": true
    }
    """.data(using: .utf8)!
    let loader = StubDataLoader(data: data, statusCode: 200)
    let client = RemotePurchaseClient(
        api: APIRequestBuilder(
            baseURL: URL(string: "https://api.headintheclouds.test")!,
            accountTokenProvider: { "account-token" }
        ),
        session: loader
    )

    let result = try await client.verify(
        VerifyIAPTransactionPayload(
            transactionID: "local-tx-001",
            productID: "hic.postcard.plus",
            plan: "postcard_plus",
            amount: 12,
            signedTransactionJWS: "header.payload.signature"
        )
    )

    let lastRequest = await loader.lastRequest
    expect(lastRequest?.url?.absoluteString == "https://api.headintheclouds.test/api/iap/transactions/verify", "remote purchase verification hits first-party endpoint")
    expect(lastRequest?.value(forHTTPHeaderField: "authorization") == "Bearer account-token", "remote purchase verification includes bearer token")
    expect(result.transactionID == "local-tx-001", "remote purchase verification returns transaction id")
    expect(result.created, "remote purchase verification returns created flag")
}

private actor StubDataLoader: URLRequestDataLoading {
    private let data: Data
    private let statusCode: Int
    private var request: URLRequest?

    var lastRequest: URLRequest? {
        request
    }

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["content-type": "application/json"]
        )!
        return (data, response)
    }
}

checkPrivateCardDoesNotRequireFlightVerification()
checkOrdinaryUGCUsesFlightLogTemplate()
checkUnverifiedSameFlightPublishIsBlocked()
checkVerifiedSameFlightPublishPasses()
checkOfflineDraftCanBeSavedAndSynced()
checkNotificationSchedulerReportsPermissionResult()
checkPublicIdentityDoesNotExposeExactSeat()
checkPublicTextSanitizerRedactsCardQuote()
checkBoardingPassParserExtractsSafeFlightFields()
checkAnalyticsSanitizerRemovesSensitiveFields()
checkEventPipelineBuildsFirstPartyEnvelope()
checkFanoutAnalyticsKeepsLocalAndFirstPartyEvents()
try checkEventRequestBuilderTargetsFirstPartyEndpoint()
try checkAPIRequestBuilderUsesFirstPartyAuthenticatedAPI()
try checkPostAPIRequestUsesClientGeneratedID()
try checkCreatePostResponseDecodesServerContract()
try checkFlightSpacePostsAPIUsesVerifiedContextEndpoint()
try checkFlightSpacePostsResponseDecodesSafeFields()
try await checkRemoteCloudPostSyncClientUsesServerResponse()
try await checkRemoteFlightContextClientSyncsBeforePost()
try await checkRemoteFlightProofClientSyncsVerification()
try await checkRemoteBoardingReminderClientSchedulesServerJob()
try await checkRemoteFlightSpaceClientUsesServerResponse()
try await checkRemotePushTokenClientRegistersToken()
try checkSafetyAPIRequestsUseFirstPartyEndpoints()
checkShareCardURLUsesPublicShareEndpoint()
try checkShareCardRenderAPIUsesFirstPartyServer()
try checkShareCardRenderResponseDecodesServerContract()
try checkPushTokenRegistrationUsesFirstPartyAPI()
try checkAccountUpgradeAPIUsesFirstPartyAPI()
try checkAccountUpgradeResponseDecodesMerge()
try await checkRemoteAccountUpgradeClientUsesServerResponse()
try checkAccountDeletionAPIUsesFirstPartyAPI()
try checkAccountDeletionResponseDecodesRecoveryDeadline()
try await checkRemoteAccountDeletionClientUsesServerResponse()
try checkSMSChallengeAPIUsesFirstPartyServer()
try checkSMSChallengeResponsesDecodeServerContract()
try await checkRemoteSMSChallengeClientUsesServerResponse()
try checkWeChatExchangeAPIUsesFirstPartyServer()
try await checkRemoteWeChatAuthClientUsesServerResponse()
try checkPurchaseVerificationAPIUsesFirstPartyServer()
try checkPurchaseVerificationResponseDecodesServerContract()
try await checkRemotePurchaseClientUsesServerResponse()
try await checkRemoteSafetyClientsUseFirstPartyEndpoints()
try await checkRemoteShareCardRenderClientUsesServerResponse()

print("HeadInCloudsCoreChecks passed")
