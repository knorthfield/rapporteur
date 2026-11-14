import Foundation

/// An issue that waits in the outbox until GitHub accepts it.
struct PendingIssue: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var repositoryFullName: String
    var title: String
    var body: String
    var labels: [String]
    /// GitHub's message when it refused the issue. The outbox does not retry a refused issue by itself.
    var refusal: String?
}
