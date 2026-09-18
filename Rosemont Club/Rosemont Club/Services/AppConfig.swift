import Foundation

/// Public configuration. The Firebase values are the public client identifiers the
/// website itself serves from `/api/config`; the app refreshes them from there at launch.
struct AppConfig: Codable, Equatable {
    var apiKey: String
    var authDomain: String
    var projectId: String
    var appId: String
    var tenantId: String
    /// Lowest app version the API still supports; the app prompts for an update below it.
    var iosMinimumVersion: String?
    var platform: String?

    /// Identifies the native client to the API (`X-Rosemont-Client: ios/<version>`).
    static let clientHeader = "ios/" + appVersion
    static var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    /// Firebase project's iOS OAuth client, registered by the web side on September 18, 2026.
    static let googleClientID = "650621702399-71b77nam1lq620biotmitnr9u6ncs63p.apps.googleusercontent.com"
    static let googleReversedClientID = "com.googleusercontent.apps.650621702399-71b77nam1lq620biotmitnr9u6ncs63p"

    static let baseURL = URL(string: "https://rosemont.club")!
    static var apiURL: URL { baseURL.appending(path: "api") }

    /// The Firebase iOS app's public values (bundle `club.rosemont.ios`).
    static let fallback = AppConfig(
        apiKey: "AIzaSyATF0AOZCgT6VcQsxJFV5vs7dyCSINZmSc",
        authDomain: "permitting-ai-helper.firebaseapp.com",
        projectId: "permitting-ai-helper",
        appId: "1:650621702399:ios:30fbf444d819cbf8273cca",
        tenantId: "alex311-qfnem",
        iosMinimumVersion: nil,
        platform: "ios"
    )

    /// True when the API says this build is too old to keep using.
    var updateRequired: Bool {
        guard let minimum = iosMinimumVersion else { return false }
        return Self.compare(Self.appVersion, minimum) < 0
    }

    static func compare(_ a: String, _ b: String) -> Int {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }

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
        request.setValue(clientHeader, forHTTPHeaderField: "X-Rosemont-Client")
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
