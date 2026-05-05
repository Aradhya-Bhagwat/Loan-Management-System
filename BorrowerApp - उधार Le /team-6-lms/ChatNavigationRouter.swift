import Foundation
import Observation

@Observable
final class ChatNavigationRouter {
    static let shared = ChatNavigationRouter()

    var pendingChatApplicationId: UUID?

    private init() {}

    func navigateToChat(applicationId: UUID) {
        pendingChatApplicationId = applicationId
    }

    func clearPending() {
        pendingChatApplicationId = nil
    }
}
