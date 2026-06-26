import Foundation
import UIKit

enum WeChatShareScene {
    case session
    case timeline

    var wxScene: Int32 {
        switch self {
        case .session:
            return Int32(WXSceneSession.rawValue)
        case .timeline:
            return Int32(WXSceneTimeline.rawValue)
        }
    }
}

struct WeChatAuthResponse: Sendable {
    let code: String?
    let state: String?
    let errorCode: Int32
    let errorMessage: String?

    var hasAuthorizationCode: Bool {
        code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

enum WeChatSharing {
    static let appID = "wx8468c4582175e88e"
    static let universalLink = "https://headinclouds.cn/wechat/"

    static func register() {
        let registered = WXApi.registerApp(appID, universalLink: universalLink)
        diagnosticsLog(
            "registerApp success=\(registered) apiVersion=\(WXApi.getVersion()) universalLink=\(universalLink)"
        )
        runUniversalLinkSelfCheckIfRequested()
    }

    static var isAvailable: Bool {
        WXApi.isWXAppInstalled() && WXApi.isWXAppSupport()
    }

    static func handleOpenURL(_ url: URL, delegate: WXApiDelegate) -> Bool {
        WXApi.handleOpen(url, delegate: delegate)
    }

    static func handleUniversalLink(_ userActivity: NSUserActivity, delegate: WXApiDelegate) -> Bool {
        WXApi.handleOpenUniversalLink(userActivity, delegate: delegate)
    }

    static func requestAuthorization(
        state: String,
        completion: @escaping (Bool) -> Void
    ) {
        let installed = WXApi.isWXAppInstalled()
        let supported = WXApi.isWXAppSupport()
        diagnosticsLog("requestAuthorization installed=\(installed) supported=\(supported) state=\(state)")
        guard isAvailable else {
            completion(false)
            return
        }

        let request = SendAuthReq()
        request.scope = "snsapi_userinfo"
        request.state = state

        let completionBox = WeChatCallbackCompletion(completion)
        WXApi.send(request) { success in
            diagnosticsLog("auth send completion success=\(success)")
            completionBox.resolve(success)
        }
    }

    static func shareWebpage(
        title: String,
        description: String,
        webpageURL: URL,
        thumbnail: UIImage?,
        scene: WeChatShareScene,
        completion: @escaping (Bool) -> Void
    ) {
        let installed = WXApi.isWXAppInstalled()
        let supported = WXApi.isWXAppSupport()
        diagnosticsLog("shareWebpage installed=\(installed) supported=\(supported) scene=\(scene.wxScene) url=\(webpageURL.absoluteString)")
        guard isAvailable else {
            completion(false)
            return
        }

        let webpage = WXWebpageObject()
        webpage.webpageUrl = webpageURL.absoluteString

        let message = WXMediaMessage()
        message.title = title.clamped(to: 80)
        message.description = description.clamped(to: 180)
        message.mediaObject = webpage
        if let thumbnailData = thumbnail?.weChatThumbData(maxBytes: 32 * 1_024) {
            message.thumbData = thumbnailData
            diagnosticsLog("shareWebpage thumbBytes=\(thumbnailData.count)")
        }

        let request = SendMessageToWXReq()
        request.bText = false
        request.message = message
        request.scene = scene.wxScene

        let completionBox = WeChatCallbackCompletion(completion)
        WXApi.send(request) { success in
            diagnosticsLog("send completion success=\(success)")
            completionBox.resolve(success)
        }
    }

    private static var diagnosticsEnabled: Bool {
        ProcessInfo.processInfo.environment["HIC_WECHAT_DIAGNOSTICS"] == "1"
    }

    private static func diagnosticsLog(_ message: String) {
        guard diagnosticsEnabled else { return }
        print("HIC_WECHAT_DIAGNOSTIC \(message)")
    }

    private static func runUniversalLinkSelfCheckIfRequested() {
        guard ProcessInfo.processInfo.environment["HIC_WECHAT_UL_SELF_CHECK"] == "1" else { return }
        WXApi.startLog(by: .detail) { log in
            diagnosticsLog("sdkLog \(log)")
        }
        WXApi.checkUniversalLinkReady { step, result in
            diagnosticsLog(
                "ulCheck step=\(step.rawValue) success=\(result.success) error=\(result.errorInfo) suggestion=\(result.suggestion)"
            )
        }
    }
}

private final class WeChatCallbackCompletion: @unchecked Sendable {
    private let handler: (Bool) -> Void

    init(_ handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    func resolve(_ success: Bool) {
        DispatchQueue.main.async {
            self.handler(success)
        }
    }
}

private extension UIImage {
    func weChatThumbData(maxBytes: Int) -> Data? {
        let squareImage = resizedForWeChatThumbnail()
        var quality: CGFloat = 0.82
        while quality >= 0.35 {
            if let data = squareImage.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.12
        }
        return squareImage.jpegData(compressionQuality: 0.28)
    }

    func resizedForWeChatThumbnail() -> UIImage {
        let canvasSize = CGSize(width: 160, height: 160)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            UIColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

            let scale = min(canvasSize.width / size.width, canvasSize.height / size.height)
            let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(
                x: (canvasSize.width - drawSize.width) / 2,
                y: (canvasSize.height - drawSize.height) / 2
            )
            draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

private extension String {
    func clamped(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength))
    }
}
