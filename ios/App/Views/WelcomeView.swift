import SwiftUI

struct WelcomeView: View {
    let onStartWriting: () -> Void
    let onAddFlight: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 52)

                brandBlock
                    .padding(.bottom, 28)

                PostcardAnchorView()
                    .frame(maxWidth: 308)
                    .padding(.bottom, 28)

                VStack(spacing: 8) {
                    Text("登机前 30 分钟，给这趟飞行留一句话")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(HICTheme.cream)
                        .tracking(0.5)

                    Text("落地后，生成一张只属于云上的明信片")
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.mist.opacity(0.56))
                        .tracking(0.3)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    PrimaryCloudButton(title: "写下这一趟", action: onStartWriting)
                        .accessibilityIdentifier("welcome.write")
                    SecondaryCloudButton(title: "添加航班信息", systemImage: "airplane.departure", action: onAddFlight)
                }
                .frame(maxWidth: 308)

                Spacer(minLength: 28)

                Text("票证原图默认不保存")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.5)
                    .foregroundStyle(HICTheme.mist.opacity(0.34))
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
    }

    private var brandBlock: some View {
        VStack(spacing: 8) {
            Text("Head in the Clouds")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(HICTheme.cream)
                .tracking(-0.2)

            Text("云·上·心·事")
                .font(.system(size: 13, weight: .light, design: .serif))
                .tracking(7)
                .foregroundStyle(HICTheme.gold.opacity(0.66))
        }
        .accessibilityElement(children: .combine)
    }
}

struct PostcardAnchorView: View {
    var quote = "我把没有说出口的话，带过了云层。"
    var route = "航线待补"
    var meta = "航班待确认"
    var detail = "时间待补 · 私人明信片"

    private var routeEndpoints: (String, String) {
        let parts = route
            .components(separatedBy: "→")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count == 2 else { return ("起点", "终点") }
        return (parts[0], parts[1])
    }

    private var routeDetail: String {
        route == "航线待补" ? "航线坐标稍后补齐" : "\(route) · 坐标待补"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meta)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Text(route)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                    Text(detail)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                }
                .foregroundStyle(HICTheme.ink.opacity(0.82))

                Spacer()

                PostmarkView(size: 42, ink: HICTheme.ink)
            }
            .padding(.bottom, 10)

            Divider()
                .overlay(HICTheme.ink.opacity(0.16))
                .padding(.bottom, 12)

            Text(quote)
                .font(.system(size: quote.count <= 16 ? 21 : 18, weight: .semibold, design: .serif))
                .foregroundStyle(HICTheme.ink)
                .lineSpacing(7)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)

            HStack(spacing: 6) {
                Text(routeEndpoints.0)
                DashedRouteLine()
                Text(routeEndpoints.1)
            }
            .font(.system(size: 7.5, weight: .regular, design: .monospaced))
            .foregroundStyle(HICTheme.ink.opacity(0.64))

            Text(routeDetail)
                .font(.system(size: 6.5, weight: .regular, design: .monospaced))
                .foregroundStyle(HICTheme.ink.opacity(0.36))
                .padding(.top, 5)
                .padding(.bottom, 12)

            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(HICTheme.ink.opacity(0.22), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Image(systemName: "cloud")
                            .font(.system(size: 6))
                            .foregroundStyle(HICTheme.ink.opacity(0.48))
                    }

                Text("Head in the Clouds / 云上心事")
                    .font(.system(size: 7, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(HICTheme.ink.opacity(0.42))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HICTheme.cream, HICTheme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperLines().opacity(0.55))
        }
        .padding(10)
        .background(HICTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.58), radius: 30, y: 16)
    }
}

struct PermissionPrimerView: View {
    let onContinue: () -> Void

    private let items: [PermissionItem] = [
        .init(icon: "camera", title: "相机", desc: "识别登机牌上的航班信息", trigger: "拍登机牌时申请", tint: Color(red: 0.48, green: 0.56, blue: 0.72)),
        .init(icon: "photo", title: "相册", desc: "从相册选截图，或把 Cloud Card 存到本机", trigger: "保存 Cloud Card 时申请", tint: Color(red: 0.49, green: 0.63, blue: 0.54)),
        .init(icon: "bell", title: "通知", desc: "登机前提醒你留下这一趟的心事", trigger: "添加登机提醒时申请", tint: HICTheme.gold)
    ]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 1, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)
                    .padding(.bottom, 40)

                Text("为了你的飞行心事，\n我们需要：")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(8)
                    .padding(.bottom, 30)

                VStack(spacing: 12) {
                    ForEach(items) { item in
                        PermissionRow(item: item)
                    }
                }

                Spacer()

                Text("以上权限均在你实际用到时才申请，不提前索权")
                    .font(.system(size: 11))
                    .foregroundStyle(HICTheme.mist.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                SecondaryCloudButton(title: "继续，不现在授权", action: onContinue)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct PrivacyPromiseView: View {
    let onContinue: () -> Void

    private let items: [PermissionItem] = [
        .init(icon: "lock.shield", title: "票证原图默认不保存到云", desc: "OCR 完成后立即销毁，永远不上传原图", trigger: "", tint: Color(red: 0.48, green: 0.61, blue: 0.61)),
        .init(icon: "eye.slash", title: "卡片不显示任何敏感字段", desc: "只显示航班号、起降地、时间；不显示姓名、座位号、票号", trigger: "", tint: Color(red: 0.61, green: 0.56, blue: 0.63)),
        .init(icon: "bubble.left.and.bubble.right", title: "评论只在你那趟航班内可见", desc: "同机乘客才能看到评论，陌生人看不到你的任何细节", trigger: "", tint: Color(red: 0.49, green: 0.63, blue: 0.54))
    ]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 2, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)
                    .padding(.bottom, 40)

                Image(systemName: "lock")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(HICTheme.gold.opacity(0.74))
                    .frame(width: 52, height: 52)
                    .background(HICTheme.gold.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(HICTheme.gold.opacity(0.18), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 20)

                Text("你的票，\n只在你手里")
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(8)
                    .padding(.bottom, 30)

                VStack(spacing: 14) {
                    ForEach(items) { item in
                        PromiseRow(item: item)
                    }
                }

                Spacer()

                PrimaryCloudButton(title: "我知道了，继续", action: onContinue)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct GetStartedView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 3, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)

                Spacer()

                RouteArcView()
                    .frame(width: 52, height: 32)
                    .padding(.bottom, 26)

                Text("准备好了吗？")
                    .font(.system(size: 38, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .padding(.bottom, 16)

                Text("不需要注册，\n直接开始你的第一次")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HICTheme.mist.opacity(0.72))
                    .lineSpacing(9)
                    .padding(.bottom, 52)

                PrimaryCloudButton(title: "开始我的第一次飞行", action: onStart)
                    .padding(.bottom, 14)

                HStack(spacing: 4) {
                    Spacer()
                    Text("已有账号？")
                        .foregroundStyle(HICTheme.mist.opacity(0.45))
                    Button("登录", action: onSignIn)
                        .foregroundStyle(HICTheme.gold.opacity(0.72))
                        .underline(true, color: HICTheme.gold.opacity(0.72))
                    Spacer()
                }
                .font(.system(size: 12))
                .padding(.bottom, 12)

                Text("之后可以选择绑定微信或手机号\n换设备也能找回你的飞行记录")
                    .font(.system(size: 10))
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Spacer()

                Text("Head in the Clouds")
                    .font(.system(size: 9, weight: .regular, design: .serif))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(HICTheme.gold.opacity(0.22))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
    }
}

struct OpeningView: View {
    let onWrite: () -> Void
    let onAddFlight: () -> Void
    let onReminder: () -> Void
	let onMyFlights: () -> Void
	let onExplore: () -> Void
	let onSettings: () -> Void
	var flightRecordCount = 0

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Head in the Clouds")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(HICTheme.cream)
                        Text("今天这趟，先留一句话")
                            .font(.system(size: 12))
                            .tracking(0.4)
                            .foregroundStyle(HICTheme.gold.opacity(0.56))
                    }

                    Spacer()

                    Button {
                        HICFeedback.impact(.light)
                        onSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(HICTheme.mist.opacity(0.50))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(CloudPressButtonStyle(kind: .icon))
                    .accessibilityLabel("账号设置")
                    .accessibilityIdentifier("opening.settings")
                }
                .padding(.top, 54)
                .padding(.bottom, 28)

                PostcardAnchorView(
                    quote: "我在起飞前最后一次看见这座城市的灯。",
                    route: "航线待补",
                    meta: "航班待确认"
                )
                .padding(.bottom, 22)

                Divider()
                    .overlay(.white.opacity(0.06))
                    .padding(.bottom, 22)

                Text("准备好下一次\n飞行了吗？")
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(7)
                    .padding(.bottom, 8)

                Text("一句话就够，航班信息可以稍后补")
                    .font(.system(size: 14))
                    .foregroundStyle(HICTheme.mist.opacity(0.62))

                Spacer()

                VStack(spacing: 10) {
                    PrimaryCloudButton(title: "写下这一趟", action: onWrite)
                        .accessibilityIdentifier("opening.write")
                    SecondaryCloudButton(title: "添加航班号 / 扫登机牌", systemImage: "airplane.departure", action: onAddFlight)
                    SecondaryCloudButton(title: "添加登机提醒", systemImage: "bell", action: onReminder)
	                    SecondaryCloudButton(title: "我的飞行册 \(flightRecordCount)", systemImage: "book.closed", action: onMyFlights)
                    SecondaryCloudButton(title: "看看别人留下的", systemImage: "sparkles", action: onExplore)
                }
                .padding(.bottom, 10)

                Text("票证原图默认不保存")
                    .font(.system(size: 10))
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}

enum AppShellSection: String, CaseIterable, Identifiable {
    case today
    case flightBook
    case discover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .flightBook: return "飞行册"
        case .discover: return "发现"
        }
    }

    var icon: String {
        switch self {
        case .today: return "moon.stars"
        case .flightBook: return "book.closed"
        case .discover: return "sparkles"
        }
    }

    var accessibilityID: String {
        switch self {
        case .today: return "shell.today"
        case .flightBook: return "shell.flight_book"
        case .discover: return "shell.discover"
        }
    }
}

struct AppShellView: View {
    @ObservedObject var appState: CloudAppState
    @Binding var selection: AppShellSection

    let onWrite: () -> Void
    let onAddFlight: () -> Void
    let onReminder: () -> Void
    let onSettings: () -> Void
    let onDiscoverViewed: (String) -> Void
    let onDiscoveryDetail: (UUID?) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            NightBackground()

            Group {
                switch selection {
                case .today:
                    TodayShellContent(
                        appState: appState,
                        onWrite: onWrite,
                        onAddFlight: onAddFlight,
                        onReminder: onReminder,
                        onSettings: onSettings
                    )
                case .flightBook:
                    FlightBookShellContent(
                        records: appState.myFlightRecords,
                        onWrite: onWrite,
                        onSettings: onSettings
                    )
                case .discover:
                    DiscoverShellContent(
                        cards: appState.publicDiscoveryCards,
                        onViewed: onDiscoverViewed,
                        onDetail: onDiscoveryDetail,
                        onAddFlight: onAddFlight,
                        onSettings: onSettings
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CabinShellBar(selection: $selection, onWrite: onWrite)
        }
    }
}

private struct TodayShellContent: View {
    @ObservedObject var appState: CloudAppState
    let onWrite: () -> Void
    let onAddFlight: () -> Void
    let onReminder: () -> Void
    let onSettings: () -> Void

    private var trimmedDraft: String {
        appState.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var latestRecord: FlightRecordViewModel? {
        appState.myFlightRecords.first
    }

    private var nextReminder: LocalReminder? {
        appState.reminders
            .filter { $0.reminderAt >= Date() }
            .sorted { $0.reminderAt < $1.reminderAt }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ShellHeader(
                    eyebrow: "云上心事",
                    title: "Head in the Clouds",
                    subtitle: "今天这趟，先留一句话。",
                    showsSettings: true,
                    onSettings: onSettings
                )
                .padding(.bottom, 24)

                todayPriorityModule
                    .padding(.bottom, 22)

                PrimaryCloudButton(title: "写下这一句", systemImage: "pencil", action: onWrite)
                    .accessibilityIdentifier("today.write_primary")
                    .padding(.bottom, 16)

                TodayContextActions(
                    onAddFlight: onAddFlight,
                    onReminder: onReminder
                )
                .padding(.bottom, 14)

                Text("添加航班和登机提醒只是辅助；写一句话永远可以先开始。")
                    .font(.system(size: 10))
                    .lineSpacing(5)
                    .foregroundStyle(HICTheme.mist.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 124)
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var todayPriorityModule: some View {
        if !trimmedDraft.isEmpty {
            TodayPaperNote(
                label: "未完成草稿",
                title: "这句话还在云层里",
                message: trimmedDraft,
                footer: appState.syncStatusTitle,
                icon: "pencil.line",
                actionTitle: "继续写",
                action: onWrite
            )
        } else if let latestRecord {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("最近留下")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    Spacer()
                    Text(latestRecord.date)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(HICTheme.mist.opacity(0.38))
                }

                PostcardAnchorView(
                    quote: latestRecord.quote,
                    route: latestRecord.route,
                    meta: latestRecord.flightNumber,
                    detail: "\(latestRecord.mood) · 私人明信片"
                )
            }
        } else if let nextReminder {
            TodayPaperNote(
                label: "下一趟提醒",
                title: nextReminder.flightNumber,
                message: "\(nextReminder.route)\n登机前再留一句，不用现在想完。",
                footer: Self.reminderFormatter.string(from: nextReminder.reminderAt),
                icon: "bell",
                actionTitle: "现在先写",
                action: onWrite
            )
        } else {
            TodayPaperNote(
                label: "今天的纸条",
                title: "此刻的你，想对未来的自己说什么？",
                message: "比如：我把没有说出口的话，带过了云层。",
                footer: "草稿会自动保存在本机",
                icon: "cloud",
                actionTitle: "写下这一句",
                action: onWrite
            )
        }
    }

    private static let reminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct FlightBookShellContent: View {
    let records: [FlightRecordViewModel]
    let onWrite: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ShellHeader(
                    eyebrow: "\(records.count) 趟飞行",
                    title: "我的飞行册",
                    subtitle: "把每次离开和抵达，收成一册私人明信片。",
                    showsSettings: true,
                    onSettings: onSettings
                )
                .padding(.bottom, 22)

                if records.isEmpty {
                    FlightBookEmptyCard(onWrite: onWrite)
                        .padding(.bottom, 18)
                } else {
                    VStack(spacing: 14) {
                        ForEach(records) { record in
                            FlightRecordCard(record: record)
                        }
                    }
                    .padding(.bottom, 18)
                }

                Text("这里只展示你真实生成过的 Cloud Card，不用样例航班填充。")
                    .font(.system(size: 10))
                    .lineSpacing(5)
                    .foregroundStyle(HICTheme.mist.opacity(0.42))
                    .padding(.bottom, 124)
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
        }
        .scrollIndicators(.hidden)
    }
}

private struct DiscoverShellContent: View {
    let cards: [FlightSpacePostViewModel]
    let onViewed: (String) -> Void
    let onDetail: (UUID?) -> Void
    let onAddFlight: () -> Void
    let onSettings: () -> Void

    @State private var segment: DiscoverShellSegment = .route

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ShellHeader(
                    eyebrow: "READING CABIN",
                    title: "别人留下的",
                    subtitle: "同一段云层里，有人也写下了心事。",
                    showsSettings: true,
                    onSettings: onSettings
                )
                .padding(.bottom, 20)

                HStack(spacing: 8) {
                    ForEach(DiscoverShellSegment.allCases) { item in
                        Button {
                            HICFeedback.impact(.light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                segment = item
                            }
                            onViewed(item.eventSource)
                        } label: {
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(segment == item ? HICTheme.gold : HICTheme.mist.opacity(0.48))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(segment == item ? HICTheme.gold.opacity(0.10) : .white.opacity(0.035))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(segment == item ? HICTheme.gold.opacity(0.24) : .white.opacity(0.06), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                        .accessibilityIdentifier("discover.segment.\(item.eventSource)")
                    }
                }
                .padding(.bottom, 18)

                VStack(spacing: 12) {
                    if cards.isEmpty {
                        ForEach(DiscoverPlaceholderRow.rows) { row in
                            DiscoverQuietRow(identity: row.identity, quote: row.quote, status: row.status)
                        }
                    } else {
                        ForEach(Array(cards.prefix(6))) { card in
                            DiscoverQuietRow(
                                identity: card.identity,
                                quote: card.quote,
                                status: card.status,
                                action: { onDetail(card.id) }
                            )
                        }
                    }
                }
                .padding(.bottom, 18)

                DiscoverBoundaryCard(onAddFlight: onAddFlight)
                    .padding(.bottom, 124)
            }
            .padding(.horizontal, 24)
            .padding(.top, 52)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            onViewed(segment.eventSource)
        }
    }
}

private struct ShellHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var showsSettings = false
    var onSettings: () -> Void = {}

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(HICTheme.gold.opacity(0.52))
                titleView
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            if showsSettings {
                Button {
                    HICFeedback.impact(.light)
                    onSettings()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HICTheme.mist.opacity(0.54))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.055))
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(CloudPressButtonStyle(kind: .icon))
                .accessibilityLabel("账号设置")
                .accessibilityIdentifier("shell.settings")
            }
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if title == "Head in the Clouds" {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(HICTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(title)
                .font(.system(size: title.count <= 8 ? 32 : 24, weight: .medium, design: .serif))
                .foregroundStyle(HICTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TodayPaperNote: View {
    let label: String
    let title: String
    let message: String
    let footer: String
    let icon: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .tracking(1)
                    Text(title)
                        .font(.system(size: title.count > 14 ? 19 : 22, weight: .semibold, design: .serif))
                        .lineSpacing(7)
                }
                .foregroundStyle(HICTheme.ink.opacity(0.82))

                Spacer(minLength: 10)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HICTheme.ink.opacity(0.42))
                    .frame(width: 36, height: 36)
                    .background(HICTheme.ink.opacity(0.05))
                    .clipShape(Circle())
            }
            .padding(.bottom, 18)

            Text(message)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .lineSpacing(9)
                .foregroundStyle(HICTheme.ink.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

            HStack {
                Text(footer)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(HICTheme.ink.opacity(0.40))
                Spacer()
                Button {
                    HICFeedback.impact(.light)
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HICTheme.ink.opacity(0.76))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(HICTheme.gold.opacity(0.20))
                        .clipShape(Capsule())
                }
                .buttonStyle(CloudPressButtonStyle(kind: .secondary))
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HICTheme.cream, HICTheme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperLines().opacity(0.42))
        }
        .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
    }
}

private struct TodayContextActions: View {
    let onAddFlight: () -> Void
    let onReminder: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ContextActionCard(
                title: "添加航班号",
                subtitle: "解锁同班机",
                icon: "airplane.departure",
                action: onAddFlight
            )
            .accessibilityIdentifier("today.add_flight")
            ContextActionCard(
                title: "登机前提醒",
                subtitle: "候机时再写",
                icon: "bell",
                action: onReminder
            )
            .accessibilityIdentifier("today.reminder")
        }
    }
}

private struct ContextActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HICTheme.gold.opacity(0.70))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HICTheme.mist.opacity(0.80))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(HICTheme.mist.opacity(0.42))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

private struct FlightBookEmptyCard: View {
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(HICTheme.gold.opacity(0.70))
            Text("还没有飞行卡片")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(HICTheme.cream)
            Text("先写下一句话，生成第一张属于这趟飞行的私人明信片。")
                .font(.system(size: 13))
                .lineSpacing(6)
                .foregroundStyle(HICTheme.mist.opacity(0.58))
            Button {
                HICFeedback.impact(.light)
                onWrite()
            } label: {
                Text("写第一张")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HICTheme.gold.opacity(0.86))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(HICTheme.gold.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(CloudPressButtonStyle(kind: .secondary))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum DiscoverShellSegment: String, CaseIterable, Identifiable {
    case route
    case destination
    case now

    var id: String { rawValue }

    var title: String {
        switch self {
        case .route: return "同航线"
        case .destination: return "目的地"
        case .now: return "此刻"
        }
    }

    var eventSource: String {
        switch self {
        case .route: return "same_route"
        case .destination: return "destination"
        case .now: return "moment"
        }
    }
}

private struct DiscoverPlaceholderRow: Identifiable {
    let id = UUID()
    let identity: String
    let quote: String
    let status: String

    static let rows = [
        DiscoverPlaceholderRow(identity: "靠窗的人", quote: "等待第一张真实公开的云上心事。", status: "尚未开放留言"),
        DiscoverPlaceholderRow(identity: "同机乘客", quote: "有真实公开卡片后，这里会按航线出现。", status: "只读"),
        DiscoverPlaceholderRow(identity: "通道旁的人", quote: "没有数据时宁可安静，不用假热闹撑场。", status: "真实内容")
    ]
}

private struct DiscoverQuietRow: View {
    let identity: String
    let quote: String
    let status: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            guard let action else { return }
            HICFeedback.impact(.light)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 11) {
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
                    .lineSpacing(8)
                    .foregroundStyle(HICTheme.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.white.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
        .disabled(action == nil)
    }
}

private struct DiscoverBoundaryCard: View {
    let onAddFlight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock")
                Text("未验证同班机时，只能阅读，不能留言。")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(HICTheme.mist.opacity(0.70))

            Button {
                HICFeedback.impact(.light)
                onAddFlight()
            } label: {
                Text("添加航班，解锁同班机留言")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HICTheme.gold.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(HICTheme.gold.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(CloudPressButtonStyle(kind: .secondary))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HICTheme.gold.opacity(0.055))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HICTheme.gold.opacity(0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CabinShellBar: View {
    @Binding var selection: AppShellSection
    let onWrite: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ShellTabButton(section: .today, selection: $selection)
            ShellTabButton(section: .flightBook, selection: $selection)

            Button {
                HICFeedback.impact(.medium)
                onWrite()
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [HICTheme.gold, HICTheme.brass],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: HICTheme.gold.opacity(0.34), radius: 18, y: 8)
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HICTheme.ink)
                    }
                    Text("写")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HICTheme.gold.opacity(0.90))
                }
                .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(CloudPressButtonStyle(kind: .primary))
            .accessibilityIdentifier("shell.write")

            ShellTabButton(section: .discover, selection: $selection)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.03, green: 0.07, blue: 0.13).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.42), radius: 24, y: 14)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

private struct ShellTabButton: View {
    let section: AppShellSection
    @Binding var selection: AppShellSection

    private var isSelected: Bool {
        selection == section
    }

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = section
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(section.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? HICTheme.gold.opacity(0.92) : HICTheme.mist.opacity(0.48))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(isSelected ? HICTheme.gold.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
        .accessibilityIdentifier(section.accessibilityID)
    }
}

private struct PermissionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let desc: String
    let trigger: String
    let tint: Color
}

private struct PermissionRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(item.tint)
                .frame(width: 48, height: 48)
                .background(item.tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(item.tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HICTheme.mist.opacity(0.92))
                Text(item.desc)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))
                Text(item.trigger)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(HICTheme.mist.opacity(0.48))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.white.opacity(0.03))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PromiseRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(item.tint)
                .frame(width: 40, height: 40)
                .background(item.tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HICTheme.mist.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.desc)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(HICTheme.mist.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.025))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PostmarkView: View {
    let size: CGFloat
    let ink: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(ink.opacity(0.30), lineWidth: 1.4)
            Circle()
                .stroke(ink.opacity(0.16), lineWidth: 1)
                .padding(5)
            VStack(spacing: -1) {
                Text("Head")
                Text("in the")
                Text("Clouds")
            }
            .font(.system(size: 6, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(ink.opacity(0.50))
        }
        .frame(width: size, height: size)
    }
}

private struct DashedRouteLine: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(HICTheme.ink.opacity(0.22))
                .frame(height: 1)
            Image(systemName: "airplane")
                .font(.system(size: 8))
                .foregroundStyle(HICTheme.ink.opacity(0.56))
                .background(HICTheme.paper)
        }
    }
}

struct PaperLines: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                stride(from: CGFloat(18), through: height, by: 18).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.025), lineWidth: 1)
        }
    }
}

struct RouteArcView: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: size.width - 4, y: size.height - 8),
                control: CGPoint(x: size.width / 2, y: 4)
            )
            context.stroke(path, with: .color(HICTheme.gold.opacity(0.36)), lineWidth: 1)

            for point in [CGPoint(x: 4, y: size.height - 8), CGPoint(x: size.width / 2, y: 9), CGPoint(x: size.width - 4, y: size.height - 8)] {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(HICTheme.gold.opacity(0.58)))
            }
        }
    }
}
