import Foundation

struct Repository: Codable, Hashable, Identifiable, Sendable {
    let fullName: String
    let isPrivate: Bool
    /// GitHub silently drops labels from users without push access.
    let canPush: Bool

    var id: String { fullName }
}
