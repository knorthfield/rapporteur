import Foundation
import Testing
@testable import Rapporteur

extension NetworkStubbed {
    @MainActor @Suite struct StoreTests {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)/store.json")
        let keychain = Keychain(service: "com.krisnorthfield.rapporteur.tests")
        let issue = PendingIssue(repositoryFullName: "octo/app", title: "Crash", body: "", labels: [])
        let created = #"{"number":7,"html_url":"https://github.com/octo/app/issues/7"}"#

        init() {
            keychain.saveToken("t")
        }

        func store(answer: @escaping (URLRequest) throws -> (Int, String)) -> Store {
            Store(client: StubURLProtocol.client(answer: answer), keychain: keychain, fileURL: fileURL)
        }

        @Test func removesAnIssueThatGitHubAccepted() async {
            let store = store { _ in (201, created) }
            await store.send(issue)
            #expect(store.outbox.isEmpty)
            #expect(store.lastCreatedIssue?.number == 7)
        }

        @Test func keepsAnIssueWhenThereIsNoConnectionAndSendsItLater() async {
            let offline = store { _ in throw URLError(.notConnectedToInternet) }
            await offline.send(issue)
            #expect(offline.outbox == [issue])

            let online = store { _ in (201, created) }
            #expect(online.outbox == [issue])
            await online.sendOutbox()
            #expect(online.outbox.isEmpty)
        }

        @Test func keepsAnIssueWhenGitHubHasAProblem() async {
            let store = store { _ in (503, "{}") }
            await store.send(issue)
            #expect(store.outbox == [issue])
        }

        @Test func marksARefusedIssueAndSendsTheNextOne() async {
            let store = store { request in
                request.url!.path.contains("octo/app") ? (410, #"{"message":"Issues are disabled for this repo"}"#) : (201, created)
            }
            await store.send(issue)
            await store.send(PendingIssue(repositoryFullName: "octo/other", title: "Second", body: "", labels: []))
            #expect(store.outbox.map(\.refusal) == ["Issues are disabled for this repo"])
            #expect(StubURLProtocol.requests.count == 2)
        }

        @Test func sendsARefusedIssueAgainOnRetry() async {
            nonisolated(unsafe) var refuse = true
            let store = store { _ in refuse ? (422, #"{"message":"Validation Failed"}"#) : (201, created) }
            await store.send(issue)
            refuse = false
            await store.retry(store.outbox[0])
            #expect(store.outbox.isEmpty)
        }

        @Test func signsOutAndKeepsTheOutboxWhenTheTokenIsNotValid() async {
            let store = store { _ in (401, #"{"message":"Bad credentials"}"#) }
            await store.send(issue)
            #expect(!store.isSignedIn)
            #expect(store.outbox == [issue])
            #expect(keychain.readToken() == nil)
        }

        @Test func savesFavouritesAndTheCurrentRepository() {
            let app = Repository(fullName: "octo/app", isPrivate: false, canPush: false)
            let library = Repository(fullName: "octo/lib", isPrivate: true, canPush: false)
            let first = store { _ in (200, "[]") }
            first.addFavourite(app)
            first.addFavourite(library)
            first.selectNeighbour(1)

            let second = store { _ in (200, "[]") }
            #expect(second.favourites == [app, library])
            #expect(second.currentRepository == library)
        }

        @Test func goesRoundAtTheEndsOfTheFavourites() {
            let store = store { _ in (200, "[]") }
            let app = Repository(fullName: "octo/app", isPrivate: false, canPush: false)
            let library = Repository(fullName: "octo/lib", isPrivate: false, canPush: false)
            store.addFavourite(app)
            store.addFavourite(library)
            store.selectNeighbour(-1)
            #expect(store.currentRepository == library)
            store.selectNeighbour(1)
            #expect(store.currentRepository == app)
        }

        @Test func loadsTheLabelsOfARepositoryWithPushAccess() async {
            let store = store { _ in (200, #"[{"name":"bug","color":"d73a4a"}]"#) }
            let app = Repository(fullName: "octo/app", isPrivate: false, canPush: true)
            store.addFavourite(app)
            await store.refreshLabels(of: app)
            #expect(store.labels["octo/app"] == [Label(name: "bug", color: "d73a4a")])
        }
    }
}
