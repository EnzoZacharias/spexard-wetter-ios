import Foundation
import SwiftUI
import UIKit

/// Loads one endpoint for a screen and keeps the last answer while it reloads. Switching the
/// endpoint (e.g. another model) keeps the old answer visible until the new one arrives.
@MainActor
final class Loader<T: Decodable>: ObservableObject {
    @Published private(set) var value: T?
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    /// When the server gave the shown answer.
    @Published private(set) var date: Date?
    /// The request failed; the shown answer is the stored one from `date`.
    @Published private(set) var fromCache = false
    @Published private(set) var endpoint: Endpoint?

    init() {}

    func load(_ endpoint: Endpoint) async {
        if endpoint != self.endpoint {
            self.endpoint = endpoint
            error = nil
        }
        loading = true
        defer { loading = false }
        do {
            let result: Fetched<T> = try await APIClient().fetch(endpoint)
            guard endpoint == self.endpoint else { return }
            value = result.value
            date = result.date
            fromCache = result.fromCache
            error = nil
            if !result.fromCache { Haptics.refreshed() }
        } catch {
            guard endpoint == self.endpoint, !APIClient.isCancellation(error) else { return }
            self.error = error.localizedDescription
        }
    }

    /// Load only when nothing is shown yet or the answer is older than `maxAge` seconds.
    func loadIfNeeded(_ endpoint: Endpoint, maxAge: TimeInterval = 300) async {
        if endpoint == self.endpoint, value != nil, let date, Date().timeIntervalSince(date) < maxAge, !fromCache { return }
        await load(endpoint)
    }

    func reload() async {
        guard let endpoint else { return }
        await load(endpoint)
    }
}

/// Light feedback when fresh data arrived after a pull to refresh.
enum Haptics {
    @MainActor private static var lastRefresh = Date.distantPast
    @MainActor private static var armed = false

    /// Call when the user starts a refresh; the next successful load gives a short tick.
    @MainActor static func armRefresh() {
        armed = true
    }

    @MainActor static func refreshed() {
        guard armed else { return }
        armed = false
        guard Date().timeIntervalSince(lastRefresh) > 1 else { return }
        lastRefresh = Date()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    @MainActor static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
