import Foundation

/// Where the weather server lives: the address saved in the app's settings, else the one built into
/// the app (Info.plist `SpexardAPIBaseURL`, set by CI), else none (the app asks for it).
enum ServerSettings {
    static let storageKey = "serverURL"

    static var builtIn: String {
        (Bundle.main.object(forInfoDictionaryKey: "SpexardAPIBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var current: String {
        let saved = UserDefaults.standard.string(forKey: storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? builtIn : saved
    }

    /// "192.168.178.106:8080" -> "http://192.168.178.106:8080"; trailing slashes removed.
    static func normalized(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if !text.isEmpty, !text.lowercased().hasPrefix("http://"), !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        return text
    }
}

enum APIError: LocalizedError {
    case noServer
    case badURL(String)
    case http(Int)
    case decoding(String)
    case missingMock(String)

    var errorDescription: String? {
        switch self {
        case .noServer: return "Keine Server-Adresse eingetragen."
        case .badURL(let url): return "Ungültige Adresse: \(url)"
        case .http(let code): return "Der Server antwortet mit Fehler \(code)."
        case .decoding(let what): return "Antwort nicht lesbar (\(what))."
        case .missingMock(let name): return "Beispieldaten \(name) fehlen."
        }
    }
}

/// JSON API of the weather server (`/api/v1`). With the launch argument `-mock` the answers come
/// from bundled example files (used for the simulator screenshots in CI).
struct APIClient {
    static var isMock: Bool { ProcessInfo.processInfo.arguments.contains("-mock") }

    var baseURL: String = ServerSettings.current

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func now() async throws -> WeatherNow {
        try await get("/api/v1/tools/weather_now", mock: "mock_now")
    }

    func hours() async throws -> HoursResponse {
        try await get("/api/v1/vorhersage/stunden", mock: "mock_hours")
    }

    func forecast() async throws -> ForecastResponse {
        try await get("/api/v1/tools/weather_forecast?days=16", mock: "mock_forecast")
    }

    private func get<T: Decodable>(_ path: String, mock: String) async throws -> T {
        let data: Data
        if Self.isMock {
            guard let url = Bundle.main.url(forResource: mock, withExtension: "json") else {
                throw APIError.missingMock(mock)
            }
            data = try Data(contentsOf: url)
        } else {
            let base = ServerSettings.normalized(baseURL)
            guard !base.isEmpty else { throw APIError.noServer }
            guard let url = URL(string: base + path) else { throw APIError.badURL(base) }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (body, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.http(http.statusCode)
            }
            data = body
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: T.self))
        }
    }
}
