import Foundation

/// Public configuration. The Firebase values are the public client identifiers the
/// website itself serves from `/api/config`; the app refreshes them from there at launch.
struct AppConfig: Codable, Equatable {
    var apiKey: String
    var authDomain: String
    var projectId: String
    var appId: String
    var tenantId: String

    static let baseURL = URL(string: "https://rosemont.club")!
    static var apiURL: URL { baseURL.appending(path: "api") }

    static let fallback = AppConfig(
        apiKey: "AIzaSyDO7YTX1BF7joEJvTeZsbI0c4kAaINFhC0",
        authDomain: "permitting-ai-helper.firebaseapp.com",
        projectId: "permitting-ai-helper",
        appId: "1:650621702399:web:c76c7781c435ef2e273cca",
        tenantId: "alex311-qfnem"
    )

    private static let cacheKey = "club.rosemont.config"

    static func cached() -> AppConfig {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let c = try? JSONDecoder().decode(AppConfig.self, from: data) {
            return c
        }
        return fallback
    }

    static func fetch() async -> AppConfig {
        var request = URLRequest(url: apiURL.appending(path: "config"))
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let c = try? JSONDecoder().decode(AppConfig.self, from: data),
              !c.apiKey.isEmpty else { return cached() }
        UserDefaults.standard.set(data, forKey: cacheKey)
        return c
    }
}

enum ExternalLinks {
    static let neighborVote = URL(string: "https://neighborvote.online")!
    static let rcaHistory = URL(string: "https://www.rosemontcitizens.org/history")!
    static let coloredRosemont = URL(string: "https://www.alexandriava.gov/cultural-history/the-colored-rosemont-community-history-initiative")!
    static let historicNomination = URL(string: "https://www.dhr.virginia.gov/VLR_to_transfer/PDFNoms/100-0137_Rosemont_HD_1992_Final_Nomination.pdf")!
    static let website = AppConfig.baseURL
}
