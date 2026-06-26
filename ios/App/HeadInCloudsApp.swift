import Foundation
import SwiftUI

@main
struct HeadInCloudsApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate

    init() {
        WeChatSharing.register()

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-reset"),
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        if arguments.contains("--ui-testing-seed-legacy-fixture-flight") {
            Self.seedLegacyFixtureFlightState()
        }
        if arguments.contains("--ui-testing-seed-current-flight") {
            Self.seedCurrentFlightState()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(NotificationRouteBus.shared)
                .onOpenURL { url in
                    _ = WeChatSharing.handleOpenURL(url, delegate: notificationDelegate)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    _ = WeChatSharing.handleUniversalLink(userActivity, delegate: notificationDelegate)
                }
        }
    }

    private static func seedLegacyFixtureFlightState() {
        let legacyContext = FlightContext(
            flightNumber: "MU5301",
            route: "SHA → CTU",
            departureDate: Date(timeIntervalSince1970: 1_777_968_000),
            verificationStatus: .unverified
        )
        let legacyProof = FlightProof(
            flightContextID: legacyContext.id,
            method: .manual,
            sourceImageHash: "local-fixture-hash"
        )
        let encoder = JSONEncoder()
        if let contextData = try? encoder.encode(legacyContext) {
            UserDefaults.standard.set(contextData, forKey: "hic.flightContext")
        }
        if let proofData = try? encoder.encode(legacyProof) {
            UserDefaults.standard.set(proofData, forKey: "hic.flightProof")
        }
        UserDefaults.standard.synchronize()
    }

    private static func seedCurrentFlightState() {
        let context = FlightContext(
            flightNumber: "CA9999",
            route: "PVG → HAK",
            departureDate: Date(timeIntervalSince1970: 1_777_968_000),
            verificationStatus: .unverified
        )
        let encoder = JSONEncoder()
        if let contextData = try? encoder.encode(context) {
            UserDefaults.standard.set(contextData, forKey: "hic.flightContext")
        }
        UserDefaults.standard.synchronize()
    }
}
