import Foundation
import Testing
@testable import Rapporteur

/// Answers every request of a stubbed session from `answer`, and records the requests.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var answer: (URLRequest) throws -> (Int, String) = { _ in (200, "{}") }
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [String] = []

    static func client(answer: @escaping (URLRequest) throws -> (Int, String)) -> GitHubClient {
        self.answer = answer
        requests = []
        bodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return GitHubClient(session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.requests.append(request)
        Self.bodies.append(Self.bodyText(of: request))
        do {
            let (status, body) = try Self.answer(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// URLSession moves the body into a stream before the protocol sees the request.
    private static func bodyText(of request: URLRequest) -> String {
        guard let stream = request.httpBodyStream else {
            return String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// The suites that use StubURLProtocol share its static state, so they run one test at a time.
@Suite(.serialized) struct NetworkStubbed {}
