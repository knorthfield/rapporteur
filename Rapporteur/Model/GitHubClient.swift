import Foundation

enum GitHubError: Error, Equatable {
    /// The token is not valid any more.
    case unauthorized
    /// GitHub refused the request. A retry will not help.
    case refused(String)
    /// GitHub had a problem. A retry can help.
    case serverProblem
    /// The user denied the sign-in or the code expired.
    case signInFailed(String)
}

struct DeviceCode: Decodable, Equatable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: URL
    let interval: Int
}

enum TokenPoll: Equatable, Sendable {
    case token(String)
    case pending
    case slowDown
}

struct CreatedIssue: Decodable, Equatable, Sendable {
    let number: Int
    let htmlUrl: URL
}

struct GitHubClient: Sendable {
    /// The client ID of the Rapporteur OAuth App. It is a public value. The device flow needs no secret.
    static let clientID = "REPLACE_WITH_CLIENT_ID"

    var session: URLSession = .shared

    // MARK: Sign-in (device flow)

    func requestDeviceCode() async throws -> DeviceCode {
        let data = try await post("https://github.com/login/device/code",
                                  form: ["client_id": Self.clientID, "scope": "repo"])
        return try decode(DeviceCode.self, from: data)
    }

    func pollForToken(deviceCode: String) async throws -> TokenPoll {
        let data = try await post("https://github.com/login/oauth/access_token", form: [
            "client_id": Self.clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
        struct Answer: Decodable {
            let accessToken: String?
            let error: String?
            let errorDescription: String?
        }
        let answer = try decode(Answer.self, from: data)
        if let token = answer.accessToken { return .token(token) }
        switch answer.error {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown
        default: throw GitHubError.signInFailed(answer.errorDescription ?? answer.error ?? "Sign-in failed.")
        }
    }

    // MARK: API

    /// The repositories the user can reach, most recently pushed first.
    func repositories(token: String) async throws -> [Repository] {
        var repositories: [Repository] = []
        for page in 1...5 {
            let data = try await api("GET", "/user/repos?per_page=100&sort=pushed&page=\(page)", token: token)
            let batch = try decode([RepositoryAnswer].self, from: data)
            repositories += batch.map(\.repository)
            if batch.count < 100 { break }
        }
        return repositories
    }

    func repository(fullName: String, token: String) async throws -> Repository {
        let data = try await api("GET", "/repos/\(fullName)", token: token)
        return try decode(RepositoryAnswer.self, from: data).repository
    }

    func labels(repositoryFullName: String, token: String) async throws -> [Label] {
        let data = try await api("GET", "/repos/\(repositoryFullName)/labels?per_page=100", token: token)
        return try decode([Label].self, from: data)
    }

    func createIssue(_ issue: PendingIssue, token: String) async throws -> CreatedIssue {
        var fields: [String: Any] = ["title": issue.title]
        if !issue.body.isEmpty { fields["body"] = issue.body }
        if !issue.labels.isEmpty { fields["labels"] = issue.labels }
        let body = try JSONSerialization.data(withJSONObject: fields)
        let data = try await api("POST", "/repos/\(issue.repositoryFullName)/issues", token: token, body: body)
        return try decode(CreatedIssue.self, from: data)
    }

    // MARK: Requests

    private struct RepositoryAnswer: Decodable {
        struct Permissions: Decodable { let push: Bool }
        let fullName: String
        let `private`: Bool
        let permissions: Permissions?

        var repository: Repository {
            Repository(fullName: fullName, isPrivate: `private`, canPush: permissions?.push ?? false)
        }
    }

    private func decode<Answer: Decodable>(_ type: Answer.Type, from data: Data) throws -> Answer {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    private func post(_ url: String, form: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return try await session.data(for: request).0
    }

    private func api(_ method: String, _ path: String, token: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.github.com" + path)!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            return data
        case 401:
            throw GitHubError.unauthorized
        case 500...:
            throw GitHubError.serverProblem
        default:
            struct Refusal: Decodable { let message: String }
            let message = (try? JSONDecoder().decode(Refusal.self, from: data))?.message
            throw GitHubError.refused(message ?? "GitHub refused the request (\(status)).")
        }
    }
}
