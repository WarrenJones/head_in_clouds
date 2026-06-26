import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class NotificationRouter: ObservableObject {
    @Published var pendingRoute: NotificationRoute?

    func route(from userInfo: [AnyHashable: Any]) {
        guard let route = userInfo["route"] as? String else { return }
        switch route {
        case "compose":
            pendingRoute = .compose(source: "boarding_reminder")
        case "flight_space":
            pendingRoute = .flightSpace
        default:
            break
        }
    }
}

enum NotificationRoute: Equatable {
    case compose(source: String)
    case flightSpace
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate, WXApiDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationRouteBus.shared.route(from: userInfo)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationCenter.default.post(
            name: .didReceiveRemotePushToken,
            object: deviceToken.apnsHexString
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: .didFailToRegisterRemotePush,
            object: String(describing: type(of: error))
        )
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        WeChatSharing.handleOpenURL(url, delegate: self)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        WeChatSharing.handleUniversalLink(userActivity, delegate: self)
    }

    nonisolated func onResp(_ resp: BaseResp) {
        if let authResp = resp as? SendAuthResp {
            if ProcessInfo.processInfo.environment["HIC_WECHAT_DIAGNOSTICS"] == "1" {
                print("HIC_WECHAT_DIAGNOSTIC onAuthResp type=\(resp.type) errCode=\(resp.errCode) errStr=\(resp.errStr) state=\(authResp.state ?? "nil") hasCode=\((authResp.code?.isEmpty == false) ? "true" : "false")")
            }
            NotificationCenter.default.post(
                name: .didReceiveWeChatAuthResponse,
                object: WeChatAuthResponse(
                    code: authResp.code,
                    state: authResp.state,
                    errorCode: resp.errCode,
                    errorMessage: resp.errStr
                )
            )
            return
        }

        guard resp is SendMessageToWXResp else { return }
        if ProcessInfo.processInfo.environment["HIC_WECHAT_DIAGNOSTICS"] == "1" {
            print("HIC_WECHAT_DIAGNOSTIC onResp type=\(resp.type) errCode=\(resp.errCode) errStr=\(resp.errStr)")
        }
        let message: String
        switch resp.errCode {
        case WXSuccess.rawValue:
            message = "微信分享已完成"
        case WXErrCodeUserCancel.rawValue:
            message = "微信分享已取消"
        default:
            message = "微信分享没有完成；可以复制链接"
        }
        NotificationCenter.default.post(name: .didReceiveWeChatShareResponse, object: message)
    }
}

@MainActor
final class NotificationRouteBus {
    static let shared = NotificationRouter()
}

extension Notification.Name {
    static let didReceiveRemotePushToken = Notification.Name("HeadInClouds.didReceiveRemotePushToken")
    static let didFailToRegisterRemotePush = Notification.Name("HeadInClouds.didFailToRegisterRemotePush")
    static let didReceiveWeChatShareResponse = Notification.Name("HeadInClouds.didReceiveWeChatShareResponse")
    static let didReceiveWeChatAuthResponse = Notification.Name("HeadInClouds.didReceiveWeChatAuthResponse")
}

private extension Data {
    var apnsHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
