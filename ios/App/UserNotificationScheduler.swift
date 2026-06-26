import Foundation
import UIKit
@preconcurrency import UserNotifications

final class UserNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func scheduleBoardingReminder(
        flightContext: FlightContext,
        minutesBeforeBoarding: Int,
        completion: @escaping @Sendable (NotificationScheduleResult) -> Void
    ) {
        let flight = flightContext.flightNumber ?? "这趟航班"
        let flightContextID = flightContext.id.uuidString
        let notificationCenter = center

        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard error == nil else {
                completion(.failed)
                return
            }
            guard granted else {
                completion(.denied)
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }

            let content = UNMutableNotificationContent()
            content.title = "准备登机了吗？"
            content.body = "\(flight) 登机前 \(minutesBeforeBoarding) 分钟，给这趟飞行留一句话"
            content.sound = .default
            content.userInfo = [
                "route": "compose",
                "flight_context_id": flightContextID
            ]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(60, TimeInterval(minutesBeforeBoarding * 60)),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "boarding-\(flightContextID)",
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request) { addError in
                completion(addError == nil ? .scheduled : .failed)
            }
        }
    }
}
