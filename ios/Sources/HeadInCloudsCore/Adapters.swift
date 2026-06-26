import Foundation

public protocol CloudPostRepository {
    func saveDraft(_ post: CloudPost)
    func publishSameFlight(_ post: CloudPost)
    func post(id: UUID) -> CloudPost?
}

public final class InMemoryCloudPostRepository: CloudPostRepository {
    private var posts: [UUID: CloudPost] = [:]

    public init() {}

    public func saveDraft(_ post: CloudPost) {
        posts[post.id] = post
    }

    public func publishSameFlight(_ post: CloudPost) {
        var published = post
        published.publishScope = .sameFlight
        published.offlineStatus = .synced
        posts[post.id] = published
    }

    public func post(id: UUID) -> CloudPost? {
        posts[id]
    }
}

public enum NotificationScheduleResult: Equatable, Sendable {
    case scheduled
    case denied
    case failed
}

public protocol NotificationScheduling {
    func scheduleBoardingReminder(
        flightContext: FlightContext,
        minutesBeforeBoarding: Int,
        completion: @escaping @Sendable (NotificationScheduleResult) -> Void
    )
}

public final class InMemoryNotificationScheduler: NotificationScheduling {
    public private(set) var scheduledReminderCount = 0
    private let result: NotificationScheduleResult

    public init(result: NotificationScheduleResult = .scheduled) {
        self.result = result
    }

    public func scheduleBoardingReminder(
        flightContext: FlightContext,
        minutesBeforeBoarding: Int,
        completion: @escaping @Sendable (NotificationScheduleResult) -> Void
    ) {
        if result == .scheduled {
            scheduledReminderCount += 1
        }
        completion(result)
    }
}

public protocol AuthProviding {
    func createGuestAccount() -> UUID
}

public final class GuestAuthProviderMock: AuthProviding {
    public init() {}

    public func createGuestAccount() -> UUID {
        UUID()
    }
}
