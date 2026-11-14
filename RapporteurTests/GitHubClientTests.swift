import Foundation
import Testing
@testable import Rapporteur

extension NetworkStubbed {
    @Suite struct GitHubClientTests {
        @Test func requestsADeviceCodeWithTheRepoScope() async throws {
            let client = StubURLProtocol.client { _ in
                (200, #"{"device_code":"dc","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#)
            }
            let code = try await client.requestDeviceCode()
            #expect(code.userCode == "WDJB-MJHT")
            #expect(code.deviceCode == "dc")
            #expect(code.interval == 5)
            #expect(StubURLProtocol.requests[0].url?.absoluteString == "https://github.com/login/device/code")
            #expect(StubURLProtocol.bodies[0].contains("scope=repo"))
        }

        @Test(arguments: [
            (#"{"access_token":"gho_abc","token_type":"bearer","scope":"repo"}"#, TokenPoll.token("gho_abc")),
            (#"{"error":"authorization_pending"}"#, TokenPoll.pending),
            (#"{"error":"slow_down","interval":10}"#, TokenPoll.slowDown),
        ])
        func readsThePollAnswer(body: String, expected: TokenPoll) async throws {
            let client = StubURLProtocol.client { _ in (200, body) }
            #expect(try await client.pollForToken(deviceCode: "dc") == expected)
        }

        @Test(arguments: ["access_denied", "expired_token"])
        func failsTheSignInWhenTheUserDeniesOrTheCodeExpires(error: String) async {
            let client = StubURLProtocol.client { _ in (200, #"{"error":"\#(error)","error_description":"Reason."}"#) }
            await #expect(throws: GitHubError.signInFailed("Reason.")) {
                try await client.pollForToken(deviceCode: "dc")
            }
        }

        @Test func readsRepositoriesWithPushPermission() async throws {
            let client = StubURLProtocol.client { _ in
                (200, #"[{"full_name":"octo/app","private":true,"permissions":{"push":true}},{"full_name":"other/lib","private":false,"permissions":{"push":false}}]"#)
            }
            let repositories = try await client.repositories(token: "t")
            #expect(repositories == [
                Repository(fullName: "octo/app", isPrivate: true, canPush: true),
                Repository(fullName: "other/lib", isPrivate: false, canPush: false),
            ])
            #expect(StubURLProtocol.requests.count == 1)
            #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer t")
        }

        @Test func readsLabels() async throws {
            let client = StubURLProtocol.client { _ in (200, #"[{"name":"bug","color":"d73a4a","description":null}]"#) }
            #expect(try await client.labels(repositoryFullName: "octo/app", token: "t") == [Label(name: "bug", color: "d73a4a")])
        }

        @Test func createsAnIssueWithTitleBodyAndLabels() async throws {
            let client = StubURLProtocol.client { _ in (201, #"{"number":7,"html_url":"https://github.com/octo/app/issues/7"}"#) }
            let issue = PendingIssue(repositoryFullName: "octo/app", title: "Crash", body: "On launch", labels: ["bug"])
            let created = try await client.createIssue(issue, token: "t")
            #expect(created.number == 7)
            let request = StubURLProtocol.requests[0]
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.github.com/repos/octo/app/issues")
            let sent = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.bodies[0].utf8)) as? [String: Any]
            #expect(sent?["title"] as? String == "Crash")
            #expect(sent?["body"] as? String == "On launch")
            #expect(sent?["labels"] as? [String] == ["bug"])
        }

        @Test(arguments: [
            (401, GitHubError.unauthorized),
            (410, GitHubError.refused("Issues are disabled for this repo")),
            (503, GitHubError.serverProblem),
        ])
        func mapsTheStatusToAnError(status: Int, expected: GitHubError) async {
            let client = StubURLProtocol.client { _ in (status, #"{"message":"Issues are disabled for this repo"}"#) }
            await #expect(throws: expected) {
                try await client.createIssue(PendingIssue(repositoryFullName: "octo/app", title: "T", body: "", labels: []), token: "t")
            }
        }
    }
}
