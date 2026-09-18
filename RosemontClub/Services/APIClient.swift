import Foundation

enum APIError: LocalizedError {
    case server(status: Int, message: String)
    case network
    case decoding

    var errorDescription: String? {
        switch self {
        case .server(_, let message): message
        case .network: "The neighborhood directory is unreachable right now. Check your connection and try again."
        case .decoding: "We received an unexpected response. Please try again."
        }
    }

    var isUnauthorized: Bool {
        if case .server(let status, _) = self { return status == 401 }
        return false
    }
}

/// Talks to the website's trusted API at `https://rosemont.club/api`. Every request
/// carries the Firebase ID token as a bearer token; the server enforces audience rules.
struct APIClient {
    var tokenProvider: () async throws -> String?
    var session: URLSession = .shared

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send("GET", path, query: query, body: nil)
    }

    func post<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        try await send("POST", path, query: [], body: try Self.encoder.encode(body))
    }

    func patch<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        try await send("PATCH", path, query: [], body: try Self.encoder.encode(body))
    }

    /// Raw download, used for the `.ics` calendar feed.
    func raw(_ path: String) async throws -> Data {
        let (data, response) = try await perform(try await request("GET", path, query: [], body: nil))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Calendar download failed.")
        }
        return data
    }

    private func send<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem], body: Data?) async throws -> T {
        let (data, response) = try await perform(try await request(method, path, query: query, body: body))
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        if !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "Please try again."
            throw APIError.server(status: http.statusCode, message: message)
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw APIError.decoding }
    }

    private func request(_ method: String, _ path: String, query: [URLQueryItem], body: Data?) async throws -> URLRequest {
        var url = AppConfig.apiURL.appending(path: path)
        if !query.isEmpty { url = url.appending(queryItems: query) }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 30
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = try await tokenProvider() {
            r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = body
        }
        return r
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: request) } catch { throw APIError.network }
    }

    private struct ErrorBody: Decodable { var error: String? }
}

/// Request bodies used by the app.
struct EmptyBody: Encodable {}
struct ProfileUpdate: Encodable { var displayName: String; var bio: String }
struct AddressBody: Encodable { var address: String }
struct FeedbackBody: Encodable { var message: String; var entityId: String; var type: String }
struct JoinBody: Encodable { var join: Bool }
struct RSVPBody: Encodable { var date: String; var attending: Bool }
struct VoteBody: Encodable { var option: Int }
struct MembershipBody: Encodable { var userId: String; var status: String }
