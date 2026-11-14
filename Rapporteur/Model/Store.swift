import Foundation
import Observation

/// The app's state: the account, the favourite repositories, their labels and the outbox.
@MainActor @Observable
final class Store {
    private struct Saved: Codable {
        var favourites: [Repository] = []
        var currentRepositoryName: String?
        var labels: [String: [Label]] = [:]
        var outbox: [PendingIssue] = []
    }

    private(set) var isSignedIn: Bool
    private(set) var favourites: [Repository]
    private(set) var currentRepository: Repository?
    /// The labels of each favourite, by the repository's full name.
    private(set) var labels: [String: [Label]]
    private(set) var outbox: [PendingIssue]
    /// The newest issue that GitHub accepted, for the confirmation on the entry screen.
    private(set) var lastCreatedIssue: CreatedIssue?

    private let client: GitHubClient
    private let keychain: Keychain
    private let fileURL: URL
    private var isSending = false

    init(client: GitHubClient = GitHubClient(),
         keychain: Keychain = Keychain(),
         fileURL: URL = URL.applicationSupportDirectory.appending(path: "store.json")) {
        self.client = client
        self.keychain = keychain
        self.fileURL = fileURL
        let saved = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        favourites = saved.favourites
        currentRepository = saved.favourites.first { $0.fullName == saved.currentRepositoryName } ?? saved.favourites.first
        labels = saved.labels
        outbox = saved.outbox
        isSignedIn = keychain.readToken() != nil
    }

    private func save() {
        let saved = Saved(favourites: favourites, currentRepositoryName: currentRepository?.fullName,
                          labels: labels, outbox: outbox)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: fileURL, options: .atomic)
    }

    // MARK: Account

    func signIn(token: String) {
        keychain.saveToken(token)
        isSignedIn = true
        Task { await sendOutbox() }
    }

    func signOut() {
        keychain.deleteToken()
        isSignedIn = false
    }

    /// Runs a request with the token. Signs out when GitHub says the token is not valid any more.
    private func withToken<Answer>(_ request: (String) async throws -> Answer) async throws -> Answer {
        guard let token = keychain.readToken() else {
            isSignedIn = false
            throw GitHubError.unauthorized
        }
        do {
            return try await request(token)
        } catch GitHubError.unauthorized {
            signOut()
            throw GitHubError.unauthorized
        }
    }

    // MARK: Repositories

    func repositories() async throws -> [Repository] {
        try await withToken { try await client.repositories(token: $0) }
    }

    /// Adds a repository by its "owner/name", for repositories that are not the user's.
    func addFavourite(fullName: String) async throws {
        let repository = try await withToken { try await client.repository(fullName: fullName, token: $0) }
        addFavourite(repository)
    }

    func addFavourite(_ repository: Repository) {
        guard !favourites.contains(where: { $0.fullName == repository.fullName }) else { return }
        favourites.append(repository)
        if currentRepository == nil { currentRepository = repository }
        save()
        Task { await refreshLabels(of: repository) }
    }

    func removeFavourites(at offsets: IndexSet) {
        for index in offsets { labels[favourites[index].fullName] = nil }
        favourites.remove(atOffsets: offsets)
        if let current = currentRepository, !favourites.contains(current) { currentRepository = favourites.first }
        save()
    }

    func moveFavourites(from offsets: IndexSet, to destination: Int) {
        favourites.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func select(_ repository: Repository) {
        currentRepository = repository
        save()
        Task { await refreshLabels(of: repository) }
    }

    /// Moves to the next (+1) or the previous (-1) favourite, and goes round at the ends.
    func selectNeighbour(_ step: Int) {
        guard let current = currentRepository, let index = favourites.firstIndex(of: current), favourites.count > 1 else { return }
        select(favourites[(index + step + favourites.count) % favourites.count])
    }

    func refreshLabels(of repository: Repository) async {
        guard repository.canPush,
              let fresh = try? await withToken({ try await client.labels(repositoryFullName: repository.fullName, token: $0) }),
              favourites.contains(repository) else { return }
        labels[repository.fullName] = fresh
        save()
    }

    // MARK: Outbox

    func send(_ issue: PendingIssue) async {
        outbox.append(issue)
        save()
        await sendOutbox()
    }

    func retry(_ issue: PendingIssue) async {
        guard let index = outbox.firstIndex(where: { $0.id == issue.id }) else { return }
        outbox[index].refusal = nil
        save()
        await sendOutbox()
    }

    func removeFromOutbox(_ issue: PendingIssue) {
        outbox.removeAll { $0.id == issue.id }
        save()
    }

    /// Sends the issues that wait, oldest first. Stops at a network problem and keeps the remaining issues.
    func sendOutbox() async {
        guard !isSending, isSignedIn else { return }
        isSending = true
        defer { isSending = false }
        while let issue = outbox.first(where: { $0.refusal == nil }) {
            do {
                lastCreatedIssue = try await withToken { try await client.createIssue(issue, token: $0) }
                outbox.removeAll { $0.id == issue.id }
            } catch GitHubError.refused(let message) {
                if let index = outbox.firstIndex(where: { $0.id == issue.id }) { outbox[index].refusal = message }
            } catch {
                return
            }
            save()
        }
    }
}
