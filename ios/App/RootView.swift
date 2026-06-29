import SwiftUI
import UIKit

struct RootView: View {
    @State private var path: [Screen] = []
    @StateObject private var appState = CloudAppState()
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @State private var composeSource = "opening"
    @State private var shellSelection: AppShellSection = .today
    @State private var didNormalizeLaunchPath = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if appState.account.hasCompletedOnboarding {
                    appShell
                    .onAppear { appState.landingViewed(returning: !appState.posts.isEmpty) }
                } else {
                    WelcomeView(
                        onStartWriting: { path.append(.permissionPrimer) },
                        onAddFlight: { path.append(.addFlightInfo) }
                    )
                    .onAppear { appState.onboardingStepViewed("00a") }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .permissionPrimer:
                    PermissionPrimerView {
                        path.append(.privacyPromise)
                    }
                    .onAppear { appState.onboardingStepViewed("00b") }
                    .navigationBarBackButtonHidden(true)
                case .privacyPromise:
                    PrivacyPromiseView {
                        path.append(.getStarted)
                    }
                    .onAppear { appState.onboardingStepViewed("00c") }
                    .navigationBarBackButtonHidden(true)
                case .getStarted:
                    GetStartedView(
                        onStart: {
                            appState.completeOnboarding()
                            shellSelection = .today
                            path.removeAll()
                        },
                        onSignIn: { path.append(.signIn) }
                    )
                    .onAppear { appState.onboardingStepViewed("00d") }
                    .navigationBarBackButtonHidden(true)
                case .opening:
                    appShell
                    .onAppear { appState.landingViewed(returning: !appState.posts.isEmpty) }
                    .navigationBarBackButtonHidden(true)
                case .compose:
                    ComposeView(
                        text: draftBinding,
                        onGenerate: {
                            appState.generatePrivateCard()
                            path.append(.cardStudio)
                        },
                        onAddFlight: { path.append(.addFlightInfo) },
                        flightChipTitle: appState.flightChipTitle,
                        syncStatusTitle: appState.syncStatusTitle,
                        isOffline: appState.isOffline,
                        onModeSelected: appState.composeModeSelected,
                        onTemplateSelected: appState.templateSelected,
                        onVoiceTranscribed: appState.voiceTranscribed
                    )
                    .onAppear { appState.startCompose(source: composeSource) }
                    .navigationBarBackButtonHidden(true)
                case .cardStudio:
                    CardStudioView(
                        text: draftBinding,
                        onPublish: {
                            appState.finalizePrivateCardPublish()
                            path.append(.publish)
                        },
                        onOpenPaywall: { path.append(.paywall) },
                        onQuoteEdited: appState.editHeadlineQuote
                    )
                    .navigationBarBackButtonHidden(true)
                case .paywall:
                    PaywallView(appState: appState)
                        .navigationBarBackButtonHidden(true)
                case .publish:
                    PublishView(
                        text: appState.currentPublishText,
                        shareURL: appState.currentShareCardURL,
                        shareContext: appState.flightChipTitle,
                        feedback: appState.lastFeedback,
                        onShare: appState.sharePrivateCard,
                        onSaveImage: appState.savePrivateCardImage,
                        onOpenFlight: {
                            shellSelection = .flightBook
                            path.removeAll()
                        },
                        onVerifyFlight: {
                            if appState.publishSameFlight() == nil {
                                path.append(.flightSpace)
                            } else {
                                path.append(.addFlightInfo)
                            }
                        },
                        onOpenSharedLanding: { path.append(.sharedLanding) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .myFlights:
                    MyFlightsView(
                        records: appState.myFlightRecords,
                        onNewFlight: { path.append(.flightReminder) },
                        onSettings: { path.append(.accountSettings) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .addFlightInfo:
                    AddFlightInfoView(appState: appState) {
                        path.append(.flightSpace)
                    }
                    .navigationBarBackButtonHidden(true)
                case .flightReminder:
                    FlightReminderView(appState: appState) {
                        composeSource = "boarding_reminder"
                        path.append(.compose)
                    }
                    .navigationBarBackButtonHidden(true)
                case .flightSpace:
                    FlightSpaceView(
                        appState: appState,
                        onWrite: {
                            composeSource = "flight_space"
                            path.append(.compose)
                        },
                        onDiscovery: { path.append(.discovery) },
                        onDetail: { postID in
                            appState.selectFlightSpacePost(id: postID)
                            path.append(.postDetailSameFlight)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                case .discovery:
                    DiscoveryView(
                        onViewed: appState.discoveryViewed,
                        onDetail: {
                            appState.selectFlightSpacePost(id: nil)
                            path.append(.postDetailDiscovery)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                case .postDetailSameFlight:
                    PostDetailView(appState: appState, fromSameFlight: true) {
                        path.append(.report)
                    }
                    .onAppear { appState.postDetailViewed(source: "same_flight") }
                    .navigationBarBackButtonHidden(true)
                case .postDetailDiscovery:
                    PostDetailView(appState: appState, fromSameFlight: false) {
                        path.append(.report)
                    }
                    .onAppear { appState.postDetailViewed(source: "discovery") }
                    .navigationBarBackButtonHidden(true)
                case .report:
                    ReportView(appState: appState)
                        .navigationBarBackButtonHidden(true)
                case .accountSettings:
                    AccountSettingsView(
                        appState: appState,
                        onSignIn: { path.append(.signIn) },
                        onMyFlights: { path.append(.myFlights) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .signIn:
                    SignInView(appState: appState)
                        .navigationBarBackButtonHidden(true)
                case .sharedLanding:
                    SharedCardLandingView(
                        appState: appState,
                        onSameFlight: {
                            if appState.currentFlightContext?.hasPublicRouteContext == true {
                                path.append(.flightSpace)
                            } else {
                                path.append(.addFlightInfo)
                            }
                        },
                        onReminder: { path.append(.flightReminder) }
                    )
                        .navigationBarBackButtonHidden(true)
                }
            }
            .onAppear(perform: normalizeLaunchPathIfNeeded)
        }
        .tint(HICTheme.gold)
        .onChange(of: notificationRouter.pendingRoute) { route in
            guard let route else { return }
            handleNotificationRoute(route)
            notificationRouter.pendingRoute = nil
        }
        .sheet(item: accountUpgradePromptBinding) { prompt in
            AccountUpgradePromptView(
                prompt: prompt,
                onSaveAccount: {
                    appState.acceptAccountUpgradePrompt()
                    path.append(.signIn)
                },
                onLater: {
                    appState.dismissAccountUpgradePrompt()
                }
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled(prompt.kind == .hard)
        }
    }

    private var appShell: some View {
        AppShellView(
            appState: appState,
            selection: $shellSelection,
            onWrite: {
                composeSource = appState.posts.isEmpty ? "01a" : "01b"
                path.append(.compose)
            },
            onAddFlight: { path.append(.addFlightInfo) },
            onReminder: { path.append(.flightReminder) },
            onSettings: { path.append(.accountSettings) },
            onDiscoverViewed: appState.discoveryViewed,
            onDiscoveryDetail: { postID in
                appState.selectFlightSpacePost(id: postID)
                path.append(.postDetailDiscovery)
            }
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { appState.draftText },
            set: { appState.updateDraft($0) }
        )
    }

    private var accountUpgradePromptBinding: Binding<AccountUpgradePrompt?> {
        Binding(
            get: { appState.accountUpgradePrompt },
            set: { newValue in
                if newValue == nil {
                    appState.dismissAccountUpgradePrompt()
                }
            }
        )
    }

    private func normalizeLaunchPathIfNeeded() {
        guard !didNormalizeLaunchPath else { return }
        didNormalizeLaunchPath = true
        guard appState.account.hasCompletedOnboarding else { return }
        shellSelection = .today
        path.removeAll()
    }

    private func handleNotificationRoute(_ route: NotificationRoute) {
        switch route {
        case let .compose(source):
            composeSource = source
            appState.openBoardingReminder()
            path.append(.compose)
        case .flightSpace:
            appState.sameFlightNotificationOpened()
            path.append(.flightSpace)
        }
    }
}

enum Screen: Hashable {
    case permissionPrimer
    case privacyPromise
    case getStarted
    case opening
    case compose
    case cardStudio
    case paywall
    case publish
    case myFlights
    case addFlightInfo
    case flightReminder
    case flightSpace
    case discovery
    case postDetailSameFlight
    case postDetailDiscovery
    case report
    case accountSettings
    case signIn
    case sharedLanding
}

enum HICTheme {
    static let nightTop = Color(red: 0.02, green: 0.04, blue: 0.08)
    static let nightMid = Color(red: 0.04, green: 0.08, blue: 0.18)
    static let nightBottom = Color(red: 0.06, green: 0.12, blue: 0.22)
    static let gold = Color(red: 0.77, green: 0.64, blue: 0.42)
    static let brass = Color(red: 0.66, green: 0.52, blue: 0.28)
    static let cream = Color(red: 0.95, green: 0.91, blue: 0.82)
    static let paper = Color(red: 0.93, green: 0.87, blue: 0.75)
    static let ink = Color(red: 0.06, green: 0.12, blue: 0.22)
    static let mist = Color(red: 0.63, green: 0.72, blue: 0.84)
}

enum HICKeyboard {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension FlightContext {
    var hasPublicRouteContext: Bool {
        let flight = flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let publicRoute = route?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !flight.isEmpty || !publicRoute.isEmpty
    }
}

struct NightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HICTheme.nightTop, HICTheme.nightMid, HICTheme.nightBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [HICTheme.gold.opacity(0.12), .clear],
                center: .bottom,
                startRadius: 12,
                endRadius: 260
            )

            Canvas { context, size in
                let stars: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.10, 0.08, 1.0), (0.28, 0.05, 0.7), (0.52, 0.04, 1.2),
                    (0.74, 0.08, 0.8), (0.88, 0.13, 0.9), (0.16, 0.20, 0.6),
                    (0.63, 0.22, 0.6), (0.40, 0.28, 0.5), (0.80, 0.36, 0.45)
                ]

                for star in stars {
                    let rect = CGRect(
                        x: size.width * star.0,
                        y: size.height * star.1,
                        width: star.2,
                        height: star.2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.42)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct StepDots: View {
    let activeIndex: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == activeIndex ? HICTheme.gold : HICTheme.gold.opacity(index < activeIndex ? 0.45 : 0.16))
                    .frame(width: index == activeIndex ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: activeIndex)
    }
}

struct PrimaryCloudButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.medium)
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .tracking(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [HICTheme.gold, HICTheme.brass],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(Color(red: 0.03, green: 0.06, blue: 0.10))
            .clipShape(Capsule())
            .shadow(color: HICTheme.gold.opacity(0.28), radius: 20, y: 8)
        }
        .buttonStyle(CloudPressButtonStyle(kind: .primary))
    }
}

struct SecondaryCloudButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .regular))
            .tracking(0.35)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white.opacity(0.04))
            .foregroundStyle(HICTheme.mist.opacity(0.65))
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.09), lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

struct BackCircleButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            HICFeedback.impact(.light)
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HICTheme.mist.opacity(0.62))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(CloudPressButtonStyle(kind: .icon))
        .accessibilityIdentifier("nav.back")
    }
}

enum HICFeedback {
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    @MainActor
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

struct CloudPressButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case icon
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .brightness(configuration.isPressed ? pressedBrightness : 0)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .shadow(color: pressedGlow(configuration.isPressed), radius: configuration.isPressed ? 24 : 0, y: configuration.isPressed ? 10 : 0)
            .animation(.spring(response: 0.20, dampingFraction: 0.62), value: configuration.isPressed)
    }

    private var pressedScale: CGFloat {
        switch kind {
        case .primary: 0.955
        case .secondary: 0.970
        case .icon: 0.88
        }
    }

    private var pressedBrightness: Double {
        switch kind {
        case .primary: 0.060
        case .secondary: 0.035
        case .icon: 0.025
        }
    }

    private var pressedOpacity: Double {
        switch kind {
        case .primary: 0.92
        case .secondary: 0.90
        case .icon: 0.86
        }
    }

    private func pressedGlow(_ isPressed: Bool) -> Color {
        guard isPressed else { return .clear }
        switch kind {
        case .primary:
            return HICTheme.gold.opacity(0.30)
        case .secondary, .icon:
            return HICTheme.mist.opacity(0.10)
        }
    }
}

struct CloudRevealModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : offset)
            .blur(radius: isVisible ? 0 : 4)
            .onAppear {
                isVisible = false
                withAnimation(.spring(response: 0.56, dampingFraction: 0.84).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func cloudReveal(delay: Double = 0, offset: CGFloat = 14) -> some View {
        modifier(CloudRevealModifier(delay: delay, offset: offset))
    }
}

extension String {
    var cloudFallback: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "我把没有说出口的话，带过了云层。" : trimmed
    }

    var shouldUseFlightLogFallback: Bool {
        let ordinaryTerms = ["晚点", "延误", "累", "烦", "困", "吐槽"]
        return ordinaryTerms.contains { contains($0) }
    }
}
