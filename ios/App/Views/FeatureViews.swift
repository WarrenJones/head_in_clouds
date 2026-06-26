import Combine
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct AddFlightInfoView: View {
    @ObservedObject var appState: CloudAppState
    let onVerified: () -> Void

    @State private var flightNumber = ""
    @State private var route = ""
    @State private var showProofMessage = false
    @State private var proofMessage = "票证识别完成：姓名、票号、座位号不会进入公开内容。"
    @State private var showScanner = false
    @State private var ticketPhotoItem: PhotosPickerItem?
    @State private var itineraryPhotoItem: PhotosPickerItem?
    @FocusState private var focusedField: FlightFormField?

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
	                HStack {
	                    BackCircleButton()
	                    Spacer()
	                    Text("航班信息")
	                        .font(.system(size: 10, weight: .regular, design: .monospaced))
	                        .tracking(1.4)
	                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                Text("添加航班信息")
                    .font(.system(size: 31, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                Text("写作不需要验证；发布到同班机时，需要确认这趟航班。")
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(HICTheme.mist.opacity(0.66))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                VStack(spacing: 12) {
	                    FlightContextInputField(
	                        title: "航班号",
	                        text: $flightNumber,
	                        placeholder: "请输入真实航班号",
	                        accessibilityID: "add_flight.flight_number",
	                        focusedField: $focusedField,
	                        field: .flightNumber,
                        submitLabel: .next
                    ) {
                        focusedField = .route
                    }
	                    FlightContextInputField(
	                        title: "航线",
	                        text: $route,
	                        placeholder: "出发地 → 到达地（可稍后补）",
	                        accessibilityID: "add_flight.route",
	                        focusedField: $focusedField,
	                        field: .route,
                        submitLabel: .done
                    ) {
                        focusedField = nil
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                VStack(spacing: 12) {
                    ProofOptionRow(icon: "camera", title: "拍登机牌", subtitle: "相机权限在这里才会申请") {
                        if BoardingPassScannerView.isSupported {
                            appState.requestCameraScanPermission(
                                sourceScreen: "02",
                                onAllowed: {
                                    showScanner = true
                                },
                                onDenied: { _ in
                                    proofMessage = "相机权限未开启；可以选择票证截图，或先手动添加航班。"
                                    showProofMessage = true
                                }
	                            )
	                        } else {
	                            focusedField = nil
	                            proofMessage = "当前设备不支持相机扫描；请先手动填写航班号，发布同班机前再完成票证验证。"
	                            showProofMessage = true
	                        }
	                    }
                    if ProcessInfo.processInfo.arguments.contains("--ui-testing-enable-fixture-proof") {
                        ProofOptionRow(icon: "photo", title: "选择票证截图", subtitle: "原图默认不保存，只保留 hash / 脱敏图") {
                            applyFixtureProof(
                                method: .ticketScreenshot,
                                successMessage: "票证截图识别完成：原图不上传，只保留 hash 和可验证字段。"
                            )
                        }
                    } else {
                        PhotosPicker(selection: $ticketPhotoItem, matching: .images) {
                            ProofOptionRowContent(icon: "photo", title: "选择票证截图", subtitle: "原图默认不保存，只保留 hash / 脱敏图")
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                    }
                    if ProcessInfo.processInfo.arguments.contains("--ui-testing-enable-fixture-proof") {
                        ProofOptionRow(icon: "doc.text.viewfinder", title: "行程截图", subtitle: "识别失败时可手动修正字段") {
                            applyFixtureProof(
                                method: .itineraryScreenshot,
                                successMessage: "行程截图识别完成；识别不准时可以直接改上面的字段。"
                            )
                        }
                    } else {
                        PhotosPicker(selection: $itineraryPhotoItem, matching: .images) {
                            ProofOptionRowContent(icon: "doc.text.viewfinder", title: "行程截图", subtitle: "识别失败时可手动修正字段")
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                    }
                }
                .padding(.horizontal, 24)

                if showProofMessage {
                    Text(proofMessage)
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundStyle(HICTheme.gold.opacity(0.66))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HICTheme.gold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                VStack(spacing: 10) {
	                    PrimaryCloudButton(title: "确认并发布到同班机", systemImage: "checkmark") {
	                        focusedField = nil
	                        if !appState.canCommentInSameFlight {
	                            guard appState.createManualFlightContext(flightNumber: flightNumber, route: route) else {
	                                showProofMessage = true
	                                proofMessage = appState.lastFeedback ?? "请先填写航班号。"
	                                return
	                            }
	                            showProofMessage = true
	                            proofMessage = "航班信息已添加；发布到同班机前，还需要拍登机牌或上传票证完成验证。"
	                            HICFeedback.success()
	                            return
	                        }
	                        if appState.publishSameFlight() == nil {
	                            HICFeedback.success()
	                            onVerified()
	                        } else {
	                            showProofMessage = true
	                            proofMessage = appState.lastFeedback ?? "还没有完成同班机验证。"
	                        }
	                    }

                    SecondaryCloudButton(title: "只添加航班，稍后验证", systemImage: "airplane") {
                        focusedField = nil
                        if !appState.createManualFlightContext(flightNumber: flightNumber, route: route) {
                            showProofMessage = true
                            proofMessage = appState.lastFeedback ?? "请先填写航班号。"
                        } else {
                            showProofMessage = true
                            proofMessage = appState.lastFeedback ?? "航班信息已添加，发布同班机前再验证。"
                            HICFeedback.success()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                    HICKeyboard.dismiss()
                }
                .accessibilityIdentifier("keyboard.dismiss")
            }
        }
        .sheet(isPresented: $showScanner) {
            BoardingPassScannerView(
                onResult: { text in
                    showScanner = false
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        proofMessage = "没有识别到航班信息，请手动补充航班号和航线。"
                        showProofMessage = true
                        return
                    }
                    applyScannedText(
                        text,
                        method: .boardingPassPhoto,
                        message: "登机牌已扫描：公开内容不会出现姓名、票号、座位号。"
                    )
                },
                onCancel: {
                    showScanner = false
                    proofMessage = "已取消扫描；可以手动添加航班，发布同班机前再验证。"
                    showProofMessage = true
                }
                )
        }
        .onChange(of: ticketPhotoItem) { item in
            processSelectedProofImage(
                item,
                method: .ticketScreenshot,
                progressMessage: "正在识别票证截图...",
                successMessage: "票证截图识别完成：原图不上传，只保留 hash 和可验证字段。"
            )
        }
        .onChange(of: itineraryPhotoItem) { item in
            processSelectedProofImage(
                item,
                method: .itineraryScreenshot,
                progressMessage: "正在识别行程截图...",
                successMessage: "行程截图识别完成；识别不准时可以直接改上面的字段。"
            )
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: showProofMessage)
    }

    private func applyScannedText(_ text: String, method: VerificationMethod, message: String) {
        focusedField = nil
        appState.applyBoardingPassScan(
            text: text,
            method: method,
            fallbackFlightNumber: flightNumber,
            fallbackRoute: route
        )
        if let context = appState.currentFlightContext {
            flightNumber = context.flightNumber ?? flightNumber
            route = context.route ?? route
        }
        proofMessage = message
        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
            showProofMessage = true
        }
        HICFeedback.success()
    }

    private func applyFixtureProof(
        method: VerificationMethod,
        successMessage: String
    ) {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-enable-fixture-proof") {
            applyScannedText(Self.fixtureBoardingPassText, method: method, message: successMessage)
        }
    }

    private func processSelectedProofImage(
        _ item: PhotosPickerItem?,
        method: VerificationMethod,
        progressMessage: String,
        successMessage: String
    ) {
        guard let item else { return }
        focusedField = nil
        proofMessage = progressMessage
        showProofMessage = true

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let cgImage = image.cgImage else {
                    await MainActor.run {
                        proofMessage = "没有读取到图片；可以手动补充航班号和航线。"
                        showProofMessage = true
                        clearSelectedProofItems()
                    }
                    return
                }

                let recognizedText = Self.recognizeText(from: cgImage)
                await MainActor.run {
                    clearSelectedProofItems()
                    guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        proofMessage = "没有识别到航班信息，请手动补充航班号和航线。"
                        showProofMessage = true
                        return
                    }
                    applyScannedText(recognizedText, method: method, message: successMessage)
                }
            } catch {
                await MainActor.run {
                    proofMessage = "图片识别失败；可以手动补充航班号和航线。"
                    showProofMessage = true
                    clearSelectedProofItems()
                }
            }
        }
    }

    private func clearSelectedProofItems() {
        ticketPhotoItem = nil
        itineraryPhotoItem = nil
    }

    private static func recognizeText(from cgImage: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "zh-Hans"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n") ?? ""
    }

    private static let fixtureBoardingPassText = """
    MU5301
    SHA → CTU
    2026.05.19
    SEAT REDACTED
    """
}

struct FlightReminderView: View {
    @ObservedObject var appState: CloudAppState
    let onCompose: () -> Void

    @State private var flightNumber = ""
    @State private var route = ""
    @State private var showReminderMessage = false
    @State private var reminderMessage = ""
    @FocusState private var focusedField: FlightFormField?

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackCircleButton()
                    Spacer()
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)

                Spacer()

                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(HICTheme.gold)
                    .frame(width: 58, height: 58)
                    .background(HICTheme.gold.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.bottom, 24)

                Text("登机前 30 分钟，\n提醒我留下这一趟")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(8)
                    .padding(.bottom, 14)

                Text("不查询延误，不承诺登机口。这里只负责把写作意图提前到候机厅。")
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))
                    .padding(.bottom, 28)

                VStack(spacing: 12) {
	                    FlightContextInputField(
	                        title: "航班号",
	                        text: $flightNumber,
	                        placeholder: "请输入真实航班号",
	                        accessibilityID: "reminder.flight_number",
	                        focusedField: $focusedField,
	                        field: .flightNumber,
                        submitLabel: .next
                    ) {
                        focusedField = .route
                    }
	                    FlightContextInputField(
	                        title: "航线",
	                        text: $route,
	                        placeholder: "出发地 → 到达地（可稍后补）",
	                        accessibilityID: "reminder.route",
	                        focusedField: $focusedField,
	                        field: .route,
                        submitLabel: .done
                    ) {
                        focusedField = nil
                    }
                }

                if showReminderMessage {
                    Text(reminderMessage)
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundStyle(HICTheme.gold.opacity(0.66))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HICTheme.gold.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                PrimaryCloudButton(title: "保存登机提醒", systemImage: "bell") {
                    focusedField = nil
                    appState.scheduleBoardingReminder(flightNumber: flightNumber, route: route)
                    reminderMessage = appState.lastFeedback ?? "请先填写航班号。"
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        showReminderMessage = true
                    }
                    if let savedFlightNumber = appState.currentFlightContext?.flightNumber,
                       !savedFlightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HICFeedback.success()
                        onCompose()
                    }
                }
                .padding(.bottom, 10)

                Text("通知权限会在真实设置提醒时申请；拒绝后仍可继续写卡。")
                    .font(.system(size: 10))
                    .lineSpacing(5)
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                    HICKeyboard.dismiss()
                }
                .accessibilityIdentifier("keyboard.dismiss")
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: showReminderMessage)
    }
}

struct FlightSpaceView: View {
    @ObservedObject var appState: CloudAppState
    let onWrite: () -> Void
    let onDiscovery: () -> Void
    let onDetail: (UUID?) -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
	                HStack {
	                    BackCircleButton()
	                    Spacer()
	                    Text("同班机")
	                        .font(.system(size: 10, weight: .regular, design: .monospaced))
	                        .tracking(1.4)
	                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                VStack(spacing: 8) {
                    RouteArcView()
                        .frame(width: 64, height: 34)
                    Text(appState.currentFlightContext?.flightNumber ?? "航班待确认")
                        .font(.system(size: 42, weight: .semibold, design: .serif))
                        .foregroundStyle(HICTheme.cream)
                    Text(appState.currentFlightContext?.route ?? "路线待确认")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(HICTheme.gold.opacity(0.64))
                    Text("同一趟航班 · 只属于这段时空")
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.mist.opacity(0.50))
                }
                .padding(.bottom, 24)

	                ScrollView {
	                    VStack(spacing: 12) {
	                        if appState.isFlightSpaceLoading {
                            FlightSpacePostCard(
                                identity: "同步中",
                                quote: "正在取回这趟航班里别人留下的话。",
                                status: "更新中",
                                onTap: { onDetail(nil) }
	                            )
	                        }

	                        if appState.flightSpaceCards.isEmpty {
	                            EmptyStateCard(
	                                title: "这趟航班还没有公开笔记",
	                                message: "完成航班验证并发布后，同班机内容会出现在这里。"
	                            )
	                        } else {
	                            ForEach(appState.flightSpaceCards) { post in
	                                FlightSpacePostCard(
	                                    identity: post.identity,
	                                    quote: post.quote,
	                                    status: post.status,
	                                    onTap: { onDetail(post.id) }
	                                )
	                            }
	                        }
	                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 112)
                }

                HStack(spacing: 10) {
                    SecondaryCloudButton(title: "发现同旅程", systemImage: "sparkles", action: onDiscovery)
                    PrimaryCloudButton(title: "再写一张", systemImage: "pencil", action: onWrite)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            appState.loadFlightSpacePosts()
        }
    }
}

struct DiscoveryView: View {
    var onViewed: (String) -> Void = { _ in }
    let onDetail: () -> Void
    @State private var selectedTab: DiscoveryTab = .sameJourney

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
	                HStack {
	                    BackCircleButton()
	                    Spacer()
	                    Text("发现")
	                        .font(.system(size: 10, weight: .regular, design: .monospaced))
	                        .tracking(1.4)
                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                Text("看看别人留下的")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                HStack(spacing: 8) {
                    ForEach(DiscoveryTab.allCases) { tab in
                        Button {
                            HICFeedback.impact(.light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                selectedTab = tab
                            }
                            onViewed(tab.eventSource)
                        } label: {
                            Text(tab.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? HICTheme.gold : HICTheme.mist.opacity(0.48))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? HICTheme.gold.opacity(0.10) : .white.opacity(0.03))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                        .accessibilityIdentifier("discovery.tab.\(tab.eventSource)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

	                ScrollView {
	                    VStack(spacing: 12) {
	                        EmptyStateCard(
                                title: selectedTab.emptyTitle,
                                message: selectedTab.emptyMessage
	                        )
	                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            onViewed(selectedTab.eventSource)
        }
    }
}

private enum DiscoveryTab: String, CaseIterable, Identifiable {
    case sameJourney
    case destination
    case trending
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sameJourney: return "同旅程"
        case .destination: return "同目的地"
        case .trending: return "热点"
        case .random: return "随机"
        }
    }

    var eventSource: String {
        switch self {
        case .sameJourney: return "same_journey"
        case .destination: return "destination"
        case .trending: return "trending"
        case .random: return "random"
        }
    }

    var emptyTitle: String {
        switch self {
        case .sameJourney: return "还没有真实同旅程内容"
        case .destination: return "还没有同目的地笔记"
        case .trending: return "热点还没开始"
        case .random: return "随机漫游还没有内容"
        }
    }

    var emptyMessage: String {
        switch self {
        case .sameJourney:
            return "当前版本只展示你已发布或服务端同步回来的内容，不用样例冒充真实用户。"
        case .destination:
            return "等有真实用户发布并同步后，这里才会按目的地聚合，不用假内容撑场。"
        case .trending:
            return "热点只来自真实互动和分享数据；没有数据时宁可空着。"
        case .random:
            return "随机内容会从真实可公开卡片里抽取；现在还没有可展示内容。"
        }
    }
}

struct PostDetailView: View {
    @ObservedObject var appState: CloudAppState
    let fromSameFlight: Bool
    let onReport: () -> Void

    @State private var comment = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
	                    HStack {
	                        BackCircleButton()
	                        Spacer()
	                        Text(fromSameFlight ? "同班机详情" : "笔记详情")
	                            .font(.system(size: 10, weight: .regular, design: .monospaced))
	                            .tracking(1.4)
                            .foregroundStyle(HICTheme.gold.opacity(0.56))
                        Spacer()
                        Button(action: onReport) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(HICTheme.mist.opacity(0.56))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .icon))
                        .accessibilityIdentifier("post_detail.report")
                    }
                    .padding(.top, 52)

                    CloudCardPreview(
                        template: .boardingPostcard,
                        quote: detailQuote
                    )
                    .frame(width: 260, height: 347)
                    .frame(maxWidth: .infinity)

                    Text(detailIdentity)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(HICTheme.gold.opacity(0.60))

                    Text(detailQuote)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .lineSpacing(10)
                        .foregroundStyle(HICTheme.cream)

                    if let feedback = appState.lastFeedback,
                       !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(feedback, systemImage: "checkmark.seal")
                            .font(.system(size: 12))
                            .lineSpacing(5)
                            .foregroundStyle(HICTheme.gold.opacity(0.70))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HICTheme.gold.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if fromSameFlight && appState.canCommentInSameFlight {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("评论只在本航班开放")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(HICTheme.gold.opacity(0.56))
                            TextField("写一句回应", text: $comment)
                                .focused($isCommentFocused)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(.white.opacity(0.05))
                                .foregroundStyle(HICTheme.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            PrimaryCloudButton(title: "发送回应", systemImage: "paperplane") {
                                appState.submitComment(comment)
                                comment = ""
                                isCommentFocused = false
                                HICKeyboard.dismiss()
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "lock")
                            Text("评论只在本航班开放")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HICTheme.mist.opacity(0.60))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if appState.canDeleteCurrentPost {
                        SecondaryCloudButton(title: "删除我的这张卡片", systemImage: "trash") {
                            showDeleteConfirmation = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .confirmationDialog("删除这张卡片？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) {
                appState.deleteCurrentPost()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后会从你的飞行册和本机状态移除；如果已连接服务端，也会提交到一方 API。")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isCommentFocused = false
                    HICKeyboard.dismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .accessibilityIdentifier("keyboard.dismiss")
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: appState.lastFeedback)
    }

    private var detailQuote: String {
        if fromSameFlight, let selected = appState.selectedFlightSpacePost {
            return selected.headlineQuote
        }
        return appState.myFlightRecords.first?.quote ?? "我把没有说出口的话，带过了云层。"
    }

    private var detailIdentity: String {
        if fromSameFlight, let selected = appState.selectedFlightSpacePost {
            return selected.publicIdentityLabel
        }
        return "同机乘客"
    }
}

struct ReportView: View {
    @ObservedObject var appState: CloudAppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "骚扰"

    private let reasons = ["骚扰", "广告", "隐私泄露", "冒犯内容", "其他"]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BackCircleButton()
                    Spacer()
                }
                .padding(.top, 52)

                Text("举报内容")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)

                Text("请选择举报原因，我们会在 24 小时内处理。")
                    .font(.system(size: 13))
                    .foregroundStyle(HICTheme.mist.opacity(0.62))

                VStack(spacing: 10) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            HICFeedback.impact(.light)
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                selectedReason = reason
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .stroke(selectedReason == reason ? HICTheme.gold : HICTheme.mist.opacity(0.3), lineWidth: 1.2)
                                    .frame(width: 17, height: 17)
                                    .overlay {
                                        if selectedReason == reason {
                                            Circle().fill(HICTheme.gold).frame(width: 8, height: 8)
                                        }
                                    }
                                Text(reason)
                                Spacer()
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(HICTheme.mist.opacity(0.74))
                            .padding(16)
                            .background(.white.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                    }
                }

                Spacer()

                PrimaryCloudButton(title: "提交举报", systemImage: "paperplane") {
                    appState.reportContent(reason: selectedReason)
                    dismiss()
                }

                SecondaryCloudButton(title: "屏蔽此用户", systemImage: "person.crop.circle.badge.xmark") {
                    appState.blockUser()
                    dismiss()
                }

                SecondaryCloudButton(title: "隐藏此内容", systemImage: "eye.slash") {
                    appState.hideCurrentContent()
                    dismiss()
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct AccountSettingsView: View {
    @ObservedObject var appState: CloudAppState
    let onSignIn: () -> Void
    let onMyFlights: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false
    @State private var showDeleteReauth = false

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
	                    HStack {
	                        BackCircleButton()
	                        Spacer()
	                        Text("账号设置")
	                            .font(.system(size: 10, weight: .regular, design: .monospaced))
	                            .tracking(1.4)
                            .foregroundStyle(HICTheme.gold.opacity(0.56))
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.top, 52)

                    AccountStatusCard(appState: appState, onSignIn: onSignIn)

                    SettingsGroup(title: "数据") {
                        SettingsRow(title: "我的飞行册（\(appState.myFlightRecords.count)）", subtitle: nil, icon: "book.closed", accessibilityID: "settings.my_flights", action: onMyFlights)
                        SettingsRow(title: "我发布的评论数：0", subtitle: "只读统计", icon: "bubble.left", accessibilityID: "settings.comments_count") {
                            appState.lastFeedback = "评论统计会在服务端账号同步后更新"
                        }
                        SettingsRow(title: "清除本机草稿", subtitle: "不会删除已发布卡片", icon: "trash", accessibilityID: "settings.clear_draft") {
                            appState.updateDraft("")
                            appState.lastFeedback = "本机草稿已清除"
                        }
                        SettingsRow(title: "我屏蔽的用户：\(appState.blockedUsers.count)", subtitle: "可在后续版本解除", icon: "person.crop.circle.badge.xmark", accessibilityID: "settings.blocked_users") {
                            appState.lastFeedback = appState.blockedUsers.isEmpty ? "当前没有屏蔽的用户" : "屏蔽列表已在本机生效"
                        }
                    }

                    SettingsGroup(title: "设置") {
                        SettingsRow(title: "相机 / 相册权限", subtitle: "在 iOS 系统设置里管理", icon: "camera", accessibilityID: "settings.system_photos", action: openSystemSettings)
                        SettingsRow(title: "通知", subtitle: "登机提醒 / 同班机新笔记", icon: "bell", accessibilityID: "settings.system_notifications", action: openSystemSettings)
                    }

                    SettingsGroup(title: "法务 & 账号") {
                        SettingsRow(title: "隐私政策", subtitle: appState.privacyPolicyURL == nil ? "配置 API 域名后可打开" : "打开网页", icon: "lock.doc", accessibilityID: "settings.privacy_policy") {
                            openLegalURL(
                                appState.privacyPolicyURL,
                                openedMessage: "已打开隐私政策",
                                missingMessage: "还没有配置隐私政策地址"
                            )
                        }
                        SettingsRow(title: "用户协议", subtitle: appState.termsOfServiceURL == nil ? "配置 API 域名后可打开" : "打开网页", icon: "doc.text", accessibilityID: "settings.terms") {
                            openLegalURL(
                                appState.termsOfServiceURL,
                                openedMessage: "已打开用户协议",
                                missingMessage: "还没有配置用户协议地址"
                            )
                        }
                        SettingsRow(title: "退出登录", subtitle: appState.account.authMethod == .guest ? "Guest 状态无需退出" : nil, icon: "rectangle.portrait.and.arrow.right", accessibilityID: "settings.sign_out", action: appState.signOut)
                        SettingsRow(title: "删除账号", subtitle: "二次确认 + 30 天恢复期", icon: "exclamationmark.triangle", accessibilityID: "settings.delete_account", action: { showDeleteConfirmation = true }, destructive: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }

            if let feedback = appState.lastFeedback, !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack {
                    Spacer()
                    Label(feedback, systemImage: "checkmark.seal")
                        .font(.system(size: 12))
                        .lineSpacing(5)
                        .foregroundStyle(HICTheme.gold.opacity(0.78))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HICTheme.nightMid.opacity(0.94))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(HICTheme.gold.opacity(0.18), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(feedback)
                        .accessibilityIdentifier("feedback.toast")
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .onAppear { appState.viewSettings() }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: appState.lastFeedback)
        .confirmationDialog(
            "删除账号后会进入 30 天恢复期，本机草稿和飞行册会清空。",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("确认删除账号", role: .destructive) {
                appState.startAccountDeletionReauth()
                showDeleteReauth = true
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showDeleteReauth) {
            AccountDeletionReauthView(appState: appState) {
                showDeleteReauth = false
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            appState.lastFeedback = "暂时无法打开系统设置"
            return
        }
        appState.lastFeedback = "已打开系统设置；回来后可继续使用"
        openURL(url)
    }

    private func openLegalURL(_ url: URL?, openedMessage: String, missingMessage: String) {
        guard let url else {
            appState.lastFeedback = missingMessage
            return
        }
        appState.lastFeedback = openedMessage
        openURL(url)
    }
}

struct AccountDeletionReauthView: View {
    @ObservedObject var appState: CloudAppState
    let onClose: () -> Void
    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var failedAttempts = 0
    @State private var isRateLimited = false
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    @State private var countdown = 0
    @State private var currentSMSChallenge: SMSChallengeResult?
    @State private var status = "删除前需要重新校验当前登录方式。"
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BackCircleButton()
                    Spacer()
                }
                .padding(.top, 52)

                Text("确认删除账号")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                Text("账号会进入 30 天恢复期，本机草稿、飞行册和登录状态会清空。")
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))

                switch appState.account.authMethod {
                case .phone:
                    phoneReauth
                case .wechat:
                    wechatReauth
                case .guest:
                    guestReauth
                }

                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(isRateLimited ? .orange : HICTheme.mist.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                SecondaryCloudButton(title: "取消", systemImage: "xmark") {
                    onClose()
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .onReceive(countdownTimer) { _ in
            guard countdown > 0 else { return }
            countdown -= 1
            if countdown == 0 && isRateLimited {
                isRateLimited = false
                failedAttempts = 0
                status = "可以重新获取验证码"
            }
        }
    }

    private var phoneReauth: some View {
        VStack(spacing: 10) {
            Text("为保护账号，请重新输入手机号接收验证码。手机号不会进入埋点。")
                .font(.system(size: 12))
                .lineSpacing(5)
                .foregroundStyle(HICTheme.mist.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .leading)

            FlightInputField(title: "+86 手机号", text: $phone, placeholder: "请输入手机号")

            HStack(spacing: 10) {
                FlightInputField(title: "短信验证码", text: $code, placeholder: "请输入验证码")
                Button {
                    guard !isSendingCode else { return }
                    let isResend = codeSent
                    isSendingCode = true
                    status = isResend ? "正在重新发送验证码..." : "正在发送验证码..."
                    Task {
                        let challenge = await appState.requestSMSCode(phone: phone, isResend: isResend)
                        isSendingCode = false
                        guard let challenge else {
                            status = appState.lastFeedback ?? "验证码暂时发送失败"
                            return
                        }
                        currentSMSChallenge = challenge
                        codeSent = true
                        failedAttempts = 0
                        isRateLimited = false
                        countdown = max(1, Int(challenge.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
                        status = isResend ? "验证码已重新发送，60 秒后可再次获取" : "验证码已发送，5 分钟内有效"
                    }
                } label: {
                    Text(isSendingCode ? "发送中" : (countdown > 0 ? "\(countdown)s" : (codeSent ? "重新发送" : "获取验证码")))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HICTheme.gold)
                        .frame(width: 82, height: 48)
                        .background(HICTheme.ink.opacity(0.74))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(HICTheme.gold.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                .disabled(countdown > 0 || isSendingCode)
                .opacity(countdown > 0 || isSendingCode ? 0.55 : 1)
            }

            PrimaryCloudButton(title: isVerifyingCode ? "校验中" : "校验并删除账号", systemImage: "trash") {
                guard codeSent else {
                    status = "先获取验证码，再删除账号"
                    return
                }
                guard let currentSMSChallenge else {
                    status = "验证码请求失效，请重新获取"
                    return
                }
                guard !isRateLimited else {
                    status = "验证码错误次数过多，请 60 秒后再试"
                    return
                }
                guard !isVerifyingCode else { return }
                isVerifyingCode = true
                status = "正在校验验证码..."
                Task {
                    let result = await appState.verifySMSCode(
                        challengeID: currentSMSChallenge.challengeID,
                        code: code
                    )
                    isVerifyingCode = false
                    guard result != nil else {
                        failedAttempts += 1
                        let remaining = max(0, currentSMSChallenge.maxAttempts - failedAttempts)
                        if remaining == 0 {
                            isRateLimited = true
                            countdown = 60
                            status = appState.lastFeedback ?? "验证码错误次数过多，请 60 秒后再试"
                        } else {
                            status = appState.lastFeedback ?? "验证码不正确，还剩 \(remaining) 次"
                        }
                        return
                    }
                    appState.confirmAccountDeletionAfterReauth()
                    onClose()
                }
            }
        }
    }

    private var wechatReauth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前账号通过微信保存。删除账号前需要再次确认身份。")
                .font(.system(size: 13))
                .lineSpacing(6)
                .foregroundStyle(HICTheme.mist.opacity(0.62))

            PrimaryCloudButton(title: "确认微信授权并删除", systemImage: "trash") {
                appState.confirmAccountDeletionAfterReauth()
                onClose()
            }
        }
    }

    private var guestReauth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前是 Guest 状态，只会清空本机数据，不会影响云端账号。")
                .font(.system(size: 13))
                .lineSpacing(6)
                .foregroundStyle(HICTheme.mist.opacity(0.62))

            PrimaryCloudButton(title: "清空本机数据", systemImage: "trash") {
                appState.confirmAccountDeletionAfterReauth()
                onClose()
            }
        }
    }
}

struct SignInView: View {
    @ObservedObject var appState: CloudAppState
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var code = ""
    @State private var showPhone = false
    @State private var codeSent = false
    @State private var failedCodeAttempts = 0
    @State private var isPhoneRateLimited = false
    @State private var resendRemainingSeconds = 0
    @State private var currentSMSChallenge: SMSChallengeResult?
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    @State private var isWeChatAvailable = false
    @State private var phoneStatus = "先获取验证码；真实短信商未配置时会明确失败。"
    private let smsCountdown = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @MainActor
    private static func detectWeChatAvailability() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let url = URL(string: "weixin://") else { return false }
        return UIApplication.shared.canOpenURL(url)
        #endif
    }

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BackCircleButton()
                    Spacer()
                }
                .padding(.top, 52)

                Text("保存你的飞行")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                Text("绑定微信或手机号，换设备也能找回这些云上心事。")
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))

                Button {
                    guard isWeChatAvailable, !appState.isWeChatSignInInProgress else { return }
                    appState.beginWeChatSignIn(source: "sign_in_sheet")
                } label: {
                    HStack {
                        Image(systemName: appState.isWeChatSignInInProgress ? "hourglass" : "message.fill")
                        Text(appState.isWeChatSignInInProgress ? "等待微信授权" : "微信登录")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isWeChatAvailable ? Color(red: 0.03, green: 0.76, blue: 0.38) : HICTheme.mist.opacity(0.16))
                    .foregroundStyle(isWeChatAvailable ? .white : HICTheme.mist.opacity(0.48))
                    .clipShape(Capsule())
                }
                .buttonStyle(CloudPressButtonStyle(kind: .primary))
                .accessibilityIdentifier("sign_in.wechat")
                .disabled(!isWeChatAvailable || appState.isWeChatSignInInProgress)

                if appState.isWeChatSignInInProgress {
                    Text("请在微信完成授权，返回后会自动保存账号")
                        .font(.system(size: 11))
                        .foregroundStyle(HICTheme.mist.opacity(0.52))
                } else if !isWeChatAvailable {
                    Text("未检测到微信，请用手机号登录")
                        .font(.system(size: 11))
                        .foregroundStyle(HICTheme.mist.opacity(0.52))
                }

                SecondaryCloudButton(title: showPhone ? "收起手机号登录" : "手机号验证码登录", systemImage: "phone") {
                    showPhone.toggle()
                }

                if showPhone {
                    VStack(spacing: 10) {
                        FlightInputField(title: "+86 手机号", text: $phone, placeholder: "请输入手机号")
                        HStack(spacing: 10) {
                            FlightInputField(title: "验证码", text: $code, placeholder: "请输入验证码")
                            Button {
                                guard !isSendingCode else { return }
                                let isResend = codeSent
                                isSendingCode = true
                                phoneStatus = isResend ? "正在重新发送验证码..." : "正在发送验证码..."
                                Task {
                                    let challenge = await appState.requestSMSCode(phone: phone, isResend: isResend)
                                    isSendingCode = false
                                    guard let challenge else {
                                        phoneStatus = appState.lastFeedback ?? "验证码暂时发送失败"
                                        return
                                    }
                                    currentSMSChallenge = challenge
                                    codeSent = true
                                    failedCodeAttempts = 0
                                    isPhoneRateLimited = false
                                    resendRemainingSeconds = max(
                                        1,
                                        Int(challenge.resendAvailableAt.timeIntervalSinceNow.rounded(.up))
                                    )
                                    phoneStatus = isResend ? "验证码已重新发送，60 秒后可再次获取" : "验证码已发送，5 分钟内有效"
                                }
                            } label: {
                                Text(isSendingCode ? "发送中" : (resendRemainingSeconds > 0 ? "\(resendRemainingSeconds)s" : (codeSent ? "重新发送" : "获取验证码")))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(HICTheme.gold)
                                    .frame(width: 82, height: 48)
                                    .background(HICTheme.ink.opacity(0.74))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(HICTheme.gold.opacity(0.22), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                            .disabled(resendRemainingSeconds > 0 || isSendingCode)
                            .opacity(resendRemainingSeconds > 0 || isSendingCode ? 0.55 : 1)
                        }
                        Text(phoneStatus)
                            .font(.system(size: 11))
                            .foregroundStyle(isPhoneRateLimited ? .orange : HICTheme.mist.opacity(0.52))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        PrimaryCloudButton(title: isVerifyingCode ? "校验中" : "验证并保存", systemImage: "checkmark") {
                            guard codeSent else {
                                phoneStatus = "先获取验证码，再验证手机号"
                                appState.phoneSignInFailed(reason: "code_not_requested")
                                return
                            }
                            guard let currentSMSChallenge else {
                                phoneStatus = "验证码请求失效，请重新获取"
                                appState.phoneSignInFailed(reason: "challenge_missing")
                                return
                            }
                            guard !isPhoneRateLimited else {
                                phoneStatus = "验证码错误次数过多，请 60 秒后再试"
                                appState.phoneSignInFailed(reason: "rate_limited")
                                return
                            }
                            guard !isVerifyingCode else { return }
                            isVerifyingCode = true
                            phoneStatus = "正在校验验证码..."
                            Task {
                                let result = await appState.verifySMSCode(
                                    challengeID: currentSMSChallenge.challengeID,
                                    code: code
                                )
                                isVerifyingCode = false
                                guard let result else {
                                    failedCodeAttempts += 1
                                    let remaining = max(0, currentSMSChallenge.maxAttempts - failedCodeAttempts)
                                    if remaining == 0 {
                                        isPhoneRateLimited = true
                                        resendRemainingSeconds = 60
                                        phoneStatus = appState.lastFeedback ?? "验证码错误次数过多，请 60 秒后再试"
                                    } else {
                                        phoneStatus = appState.lastFeedback ?? "验证码不正确，还剩 \(remaining) 次"
                                    }
                                    return
                                }
                                appState.upgradePhoneAccount(
                                    source: "sign_in_sheet",
                                    verifiedProviderUserHash: result.providerUserHash
                                )
                                dismiss()
                            }
                        }
                    }
                }

                Spacer()

                Text("验证码错误 3 次后会限流；手机号只发给一方服务端和短信商，不进入埋点。")
                    .font(.system(size: 10))
                    .lineSpacing(5)
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .onReceive(smsCountdown) { _ in
            guard resendRemainingSeconds > 0 else { return }
            resendRemainingSeconds -= 1
            if resendRemainingSeconds == 0 && isPhoneRateLimited {
                isPhoneRateLimited = false
                failedCodeAttempts = 0
                phoneStatus = "可以重新获取验证码"
            }
        }
        .onAppear {
            isWeChatAvailable = Self.detectWeChatAvailability()
        }
        .onChange(of: appState.account.authMethod) { method in
            if method == .wechat {
                dismiss()
            }
        }
    }
}

struct AccountUpgradePromptView: View {
    let prompt: AccountUpgradePrompt
    let onSaveAccount: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(HICTheme.mist.opacity(0.22))
                    .frame(width: 42, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text(prompt.kind == .soft ? "把这几趟飞行存起来" : "先保存账号，再继续带走这些飞行")
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)

                Text(prompt.kind == .soft ? "你已经在同班机留下第 \(prompt.postCount) 张心事。现在保存账号，换手机也能找回这些航班。" : "这是第 \(prompt.postCount) 张同班机心事。为了避免换设备后丢失，先选一个可找回的身份。")
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundStyle(HICTheme.mist.opacity(0.68))

                VStack(alignment: .leading, spacing: 10) {
                    Label("微信优先，也可以用手机号验证码", systemImage: "checkmark.seal")
                    Label("不会公开手机号、座位号或票证信息", systemImage: "lock")
                    Label("Guest 内容会合并到已存在账号", systemImage: "arrow.triangle.merge")
                }
                .font(.system(size: 12))
                .foregroundStyle(HICTheme.mist.opacity(0.62))
                .padding(16)
                .background(.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                PrimaryCloudButton(title: "保存我的账号", systemImage: "person.crop.circle.badge.checkmark", action: onSaveAccount)

                if prompt.kind == .soft {
                    SecondaryCloudButton(title: "稍后再说", systemImage: "clock", action: onLater)
                } else {
                    SecondaryCloudButton(title: "先留在本机", systemImage: "iphone", action: onLater)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SharedCardLandingView: View {
    @ObservedObject var appState: CloudAppState
    let onSameFlight: () -> Void
    let onReminder: () -> Void
    @State private var feedback: String?

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 18) {
                HStack {
                    BackCircleButton()
                    Spacer()
                    Text("分享预览")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)

                Spacer()

                Text("一张来自云上的明信片")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)

                CloudCardPreview(template: .boardingPostcard, quote: "我把没有说出口的话，带过了云层。")
                    .frame(width: 260, height: 347)

                Text("这里不是下载墙。你可以先看看同航线的人写了什么，或者为自己的下一趟飞行设置提醒。")
                    .font(.system(size: 13))
                    .lineSpacing(6)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    SecondaryCloudButton(title: "复制转发链接", systemImage: "link") {
                        copyShareLink()
                    }
                    PrimaryCloudButton(title: sameFlightButtonTitle, systemImage: "person.2") {
                        appState.trackShareLandingSameFlightTapped()
                        onSameFlight()
                    }
                    SecondaryCloudButton(title: "添加我的登机提醒", systemImage: "bell") {
                        appState.trackShareLandingReminderStarted()
                        onReminder()
                    }
                }
                .padding(.horizontal, 24)

                if let feedback {
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.gold.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
        }
        .onAppear { appState.openShareLanding() }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: feedback)
    }

    private func copyShareLink() {
        guard let url = appState.currentShareCardURL else {
            feedback = "还没有可复制的明信片链接，请先生成私人明信片。"
            return
        }
        UIPasteboard.general.string = url.absoluteString
        feedback = "转发链接已复制，可以粘贴到微信或备忘录。"
    }

    private var sameFlightButtonTitle: String {
        appState.currentFlightContext?.hasPublicRouteContext == true ? "看同班机笔记" : "添加航班，看同航线"
    }
}

struct PaywallView: View {
    @ObservedObject var appState: CloudAppState

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BackCircleButton()
                    Spacer()
                }
                .padding(.top, 52)

                Text("让明信片更像一件作品")
                    .font(.system(size: 30, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)

                Text("高级模板包只增强私人卡片的视觉表达，不改变同班机权限，也不会把票证信息公开。")
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundStyle(HICTheme.mist.opacity(0.64))

                VStack(alignment: .leading, spacing: 12) {
                    Label("3 套额外票根 / 航线 / 夜航模板", systemImage: "rectangle.on.rectangle")
                    Label("分享图高清导出", systemImage: "photo")
                    Label("后续模板包优先试用", systemImage: "sparkles")
                }
                .font(.system(size: 13))
                .foregroundStyle(HICTheme.mist.opacity(0.68))
                .padding(16)
                .background(.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("¥12")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(HICTheme.gold)
                    Text("使用 StoreKit 2 发起购买；成功后再由服务端记录订阅事件。未配置 IAP 商品时不会伪造成功。")
                        .font(.system(size: 11))
                        .lineSpacing(5)
                        .foregroundStyle(HICTheme.mist.opacity(0.46))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HICTheme.gold.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(HICTheme.gold.opacity(0.20), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let feedback = appState.lastFeedback {
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.gold.opacity(0.68))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HICTheme.gold.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                PrimaryCloudButton(title: "开始购买", systemImage: "creditcard") {
                    appState.startCheckout(plan: "postcard_plus", priceCNY: 12)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            appState.viewPaywall(sourcePage: "card_studio", planShown: "postcard_plus")
        }
    }
}

private enum FlightFormField: Hashable {
    case flightNumber
    case route
}

private struct FlightContextInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let accessibilityID: String
    let focusedField: FocusState<FlightFormField?>.Binding
    let field: FlightFormField
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(1)
                .foregroundStyle(HICTheme.gold.opacity(0.54))
            TextField(placeholder, text: $text)
                .accessibilityIdentifier(accessibilityID)
                .focused(focusedField, equals: field)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(HICTheme.cream)
                .padding(14)
                .background(.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct FlightInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(1)
                .foregroundStyle(HICTheme.gold.opacity(0.54))
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(HICTheme.cream)
                .padding(14)
                .background(.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct ProofOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            action()
        } label: {
            ProofOptionRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

private struct ProofOptionRowContent: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(HICTheme.gold.opacity(0.72))
                .frame(width: 42, height: 42)
                .background(HICTheme.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HICTheme.mist.opacity(0.84))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(HICTheme.mist.opacity(0.48))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HICTheme.mist.opacity(0.32))
        }
        .padding(14)
        .background(.white.opacity(0.03))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FlightSpacePostCard: View {
    let identity: String
    let quote: String
    let status: String
    let onTap: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(identity)
                    Spacer()
                    Text(status)
                }
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(HICTheme.gold.opacity(0.56))

                Text(quote)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .lineSpacing(7)
                    .foregroundStyle(HICTheme.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.white.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(HICTheme.gold.opacity(0.64))
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(HICTheme.cream)
            Text(message)
                .font(.system(size: 12))
                .lineSpacing(5)
                .foregroundStyle(HICTheme.mist.opacity(0.56))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DiscoveryCard: View {
    let route: String
    let quote: String
    let onTap: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(route)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "lock")
                        .font(.system(size: 10))
                }
                .foregroundStyle(HICTheme.gold.opacity(0.58))

                Text(quote)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .lineSpacing(7)
                    .foregroundStyle(HICTheme.cream)
            }
            .padding(16)
            .background(.white.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

private struct AccountStatusCard: View {
    @ObservedObject var appState: CloudAppState
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: appState.account.authMethod == .guest ? "cloud" : "checkmark.seal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(HICTheme.gold.opacity(0.72))
                    .frame(width: 52, height: 52)
                    .background(HICTheme.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.account.authMethod.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HICTheme.cream)
                    Text(appState.account.authMethod == .guest ? "\(appState.myFlightRecords.count) 趟飞行存在本机，换设备会丢" : "\(appState.myFlightRecords.count) 趟飞行已同步")
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.mist.opacity(0.56))
                }
            }

            if appState.account.authMethod == .guest {
                PrimaryCloudButton(title: "保存我的账号", action: onSignIn)
            }
        }
        .padding(18)
        .background(.white.opacity(0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(HICTheme.gold.opacity(0.48))
            VStack(spacing: 0) {
                content
            }
            .background(.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    var accessibilityID: String? = nil
    let action: () -> Void
    var destructive = false

    var body: some View {
        Button {
            HICFeedback.impact(destructive ? .medium : .light)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(destructive ? Color(red: 0.90, green: 0.34, blue: 0.30) : HICTheme.mist.opacity(0.58))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(destructive ? Color(red: 0.90, green: 0.34, blue: 0.30) : HICTheme.mist.opacity(0.76))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(HICTheme.mist.opacity(0.40))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HICTheme.mist.opacity(0.30))
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
        .accessibilityIdentifier(accessibilityID ?? title)
    }
}
