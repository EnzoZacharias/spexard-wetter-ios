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
    case http(Int, String?)
    case decoding(String)
    case missingMock(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .noServer: return "Keine Server-Adresse eingetragen."
        case .badURL(let url): return "Ungültige Adresse: \(url)"
        case .http(let code, let message):
            if let message, !message.isEmpty { return message }
            if code == 429 { return "Zu viele Anfragen in kurzer Zeit. Bitte gleich noch einmal versuchen." }
            if code == 404 { return "Diese Daten gibt es auf dem Server nicht." }
            if code >= 500 { return "Der Wetterserver hat einen Fehler gemeldet (\(code))." }
            return "Der Server antwortet mit Fehler \(code)."
        case .decoding(let what): return "Antwort nicht lesbar (\(what))."
        case .missingMock(let name): return "Beispieldaten \(name) fehlen."
        case .offline: return "Keine Verbindung zum Wetterserver."
        }
    }
}

/// One answer of the server: path below the base address plus the bundled example file that
/// stands in for it with the launch argument `-mock`.
struct Endpoint: Hashable {
    let path: String
    let mock: String?
}

extension Endpoint {
    static let now = Endpoint(path: "/api/v1/tools/weather_now", mock: "mock_now")
    static let hours = Endpoint(path: "/api/v1/vorhersage/stunden", mock: "mock_hours")
    static let forecast16 = Endpoint(path: "/api/v1/tools/weather_forecast?days=16", mock: "mock_forecast")
    static let alerts = Endpoint(path: "/api/v1/tools/weather_alerts?include_reports=false", mock: "mock_alerts")
    static let nowcast = Endpoint(path: "/api/v1/tools/rain_nowcast", mock: "mock_nowcast")
    static let radarSummary = Endpoint(path: "/api/v1/radar/umkreis", mock: "mock_radar_umkreis")
}

/// A decoded answer plus when the server gave it. `fromCache` = the request failed and the last
/// stored answer is shown instead.
struct Fetched<T> {
    let value: T
    let date: Date
    let fromCache: Bool
}

/// The last good answer of every path, kept in the caches folder so the app can show it offline.
enum ResponseCache {
    private static var folder: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = base.appendingPathComponent("api", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func file(_ path: String) -> URL? {
        let name = String(path.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        return folder?.appendingPathComponent(name + ".json")
    }

    static func store(_ data: Data, for path: String) {
        guard let url = file(path) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Size of all stored answers in bytes.
    static var size: Int {
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    static func clear() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    static func load(_ path: String) -> (data: Data, date: Date)? {
        guard let url = file(path), let data = try? Data(contentsOf: url) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let date = attributes?[.modificationDate] as? Date ?? Date.distantPast
        return (data, date)
    }
}

/// JSON API of the weather server (`/api/v1`). With the launch argument `-mock` the answers come
/// from bundled example files (used for the simulator screenshots in CI).
struct APIClient {
    static var isMock: Bool { ProcessInfo.processInfo.arguments.contains("-mock") }

    var baseURL: String = ServerSettings.current

    /// snake_case keys of the server -> camelCase properties ("radar_5min" -> "radar5min",
    /// "t_c" -> "tC"). Own rule instead of `.convertFromSnakeCase`, so digits stay predictable.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { keys in
            let last = keys.last?.stringValue ?? ""
            return AnyKey(stringValue: APIClient.camelCase(last))
        }
        return decoder
    }()

    static func camelCase(_ key: String) -> String {
        let parts = key.split(separator: "_", omittingEmptySubsequences: true)
        guard parts.count > 1 else { return key }
        var out = String(parts[0])
        for part in parts.dropFirst() {
            out += part.prefix(1).uppercased() + part.dropFirst()
        }
        return out
    }

    static func decode<T: Decodable>(_ data: Data, as type: T.Type = T.self) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding("\(T.self): \(Self.describe(error))")
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context): return "\(path(context)).\(key.stringValue) fehlt"
        case .typeMismatch(_, let context), .valueNotFound(_, let context): return path(context)
        case .dataCorrupted(let context): return path(context).isEmpty ? "kein JSON" : path(context)
        @unknown default: return "unbekannt"
        }
    }

    /// The answer of `endpoint`; on failure the last stored answer (marked `fromCache`).
    func fetch<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self, timeout: TimeInterval = 20) async throws -> Fetched<T> {
        if Self.isMock {
            guard let name = endpoint.mock, let url = Bundle.main.url(forResource: name, withExtension: "json") else {
                throw APIError.missingMock(endpoint.mock ?? endpoint.path)
            }
            let data = try Data(contentsOf: url)
            return Fetched(value: try Self.decode(data), date: Date(), fromCache: false)
        }
        let base = ServerSettings.normalized(baseURL)
        guard !base.isEmpty else { throw APIError.noServer }
        do {
            let data = try await download(base: base, path: endpoint.path, timeout: timeout)
            let value: T = try Self.decode(data)
            ResponseCache.store(data, for: endpoint.path)
            return Fetched(value: value, date: Date(), fromCache: false)
        } catch {
            if Self.isCancellation(error) { throw error }
            if let cached = ResponseCache.load(endpoint.path), let value = try? Self.decode(cached.data, as: T.self) {
                return Fetched(value: value, date: cached.date, fromCache: true)
            }
            throw error
        }
    }

    /// The stored answer of `endpoint` (instantly, without asking the server), nil in mock mode
    /// or when nothing is stored yet.
    static func cached<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) -> Fetched<T>? {
        guard !isMock, let stored = ResponseCache.load(endpoint.path),
              let value = try? decode(stored.data, as: T.self) else { return nil }
        return Fetched(value: value, date: stored.date, fromCache: true)
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        return false
    }

    private func download(base: String, path: String, timeout: TimeInterval) async throws -> Data {
        guard let url = URL(string: base + path) else { throw APIError.badURL(base) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw APIError.offline
        }
        let (body, response) = result
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? String
            throw APIError.http(http.statusCode, message)
        }
        return body
    }

    // MARK: home

    func now() async throws -> WeatherNow { try await fetch(.now).value }
    func hours() async throws -> HoursResponse { try await fetch(.hours).value }
    func forecast() async throws -> ForecastResponse { try await fetch(.forecast16).value }
}

/// Coding key with any name (for the key decoding strategy).
struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
