import MapKit
import SwiftUI

extension Endpoint {
    static let radarFrames = Endpoint(path: "/api/v1/radar/bilder", mock: "mock_radar")
}

/// Radar tab: the DWD radar of the last hour and the two-hour nowcast as an animated map, with the
/// server's summary of the surrounding 100 km.
struct RadarScreen: View {
    @StateObject private var loader = Loader<RadarResponse>()
    @State private var images: [CGImage?] = []
    @State private var index = 0
    @State private var playing = false
    @State private var summaryExpanded = false
    @State private var panelHeight: CGFloat = 260
    /// Map position the user tapped (shows the rain rate there).
    @State private var probe: CLLocationCoordinate2D?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isNight) private var night

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient(night: night).ignoresSafeArea()
                if let data = loader.value {
                    map(data)
                    VStack(spacing: 10) {
                        topCard(data)
                        Spacer(minLength: 0)
                        controls(data)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }
                        .padding(24)
                } else {
                    StateMessage(kind: .loading, text: "Radarbilder werden geladen …")
                }
            }
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loader.loadIfNeeded(.radarFrames, maxAge: 240)
            // new radar images every 5 minutes: refresh while the tab is visible
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                if Task.isCancelled { break }
                await loader.loadIfNeeded(.radarFrames, maxAge: 240)
            }
        }
        .onChange(of: loader.date) { _, _ in rebuildImages() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loader.loadIfNeeded(.radarFrames, maxAge: 240) } }
        }
        .task(id: playing) { await animate() }
    }

    // MARK: map

    private func map(_ data: RadarResponse) -> some View {
        let frame = data.frames.indices.contains(index) ? data.frames[index] : nil
        let label = RadarWords.frameLabel(frame, analysis: data.analysis)
        let image = images.indices.contains(index) ? images[index] : nil
        return RadarMapView(
            bounds: data.map.bounds,
            center: Self.center(data),
            placeName: Self.shortPlace(data.location?.label),
            image: image,
            bottomInset: panelHeight + 12,
            accessibilityText: "Radarkarte, \(label.kind) \(label.time). \(data.umkreis?.text ?? "")",
            onTap: { coordinate in
                probe = coordinate
                Haptics.selection()
            }
        )
        .ignoresSafeArea(edges: .top)
    }

    static func center(_ data: RadarResponse) -> CLLocationCoordinate2D? {
        guard let lat = data.location?.lat, let lon = data.location?.lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// "Gütersloh-Spexard" -> "Spexard" (the district the circle stands for).
    static func shortPlace(_ label: String?) -> String {
        guard let label, !label.isEmpty else { return "Standort" }
        return label.split(separator: "-").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? label
    }

    // MARK: summary on top

    private func topCard(_ data: RadarResponse) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Im Umkreis von \(Fmt.number(data.map.radiusKm ?? 100, decimals: 0)) km")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.8)
                Text(data.umkreis?.text ?? "Keine Zusammenfassung vom Server.")
                    .font(.footnote)
                    .lineLimit(summaryExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                if summaryExpanded, let later = data.umkreis?.in60Min {
                    Text(outlook(later, trend: data.umkreis?.trend))
                        .font(.footnote)
                        .opacity(0.9)
                }
                if loader.fromCache {
                    Label("Offline – Stand \(loader.date.map { Fmt.relativeDateTime($0, reference: Date()) } ?? "unbekannt")", systemImage: "icloud.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if let error = loader.error {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            Button {
                Task {
                    Haptics.armRefresh()
                    await loader.reload()
                }
            } label: {
                Group {
                    if loader.loading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Radar neu laden")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { summaryExpanded.toggle() } }
        .accessibilityElement(children: .contain)
        .accessibilityHint(summaryExpanded ? "Weniger anzeigen" : "Ganzen Text anzeigen")
    }

    private func outlook(_ later: RadarResponse.Stats, trend: String?) -> String {
        let time = Fmt.parse(later.time).map { Fmt.time($0) } ?? "–"
        let what = later.nearestKm != nil
            ? "nächster Niederschlag \(RadarWords.whereText(later.nearestKm, later.nearestDir))"
            : "kein Niederschlag im Umkreis"
        let tail = RadarWords.trend(trend).map { " – \($0)." } ?? "."
        return "In einer Stunde (\(time)): \(what)\(tail)"
    }

    // MARK: player and legend

    private func controls(_ data: RadarResponse) -> some View {
        let n = data.frames.count
        let frame = data.frames.indices.contains(index) ? data.frames[index] : nil
        let label = RadarWords.frameLabel(frame, analysis: data.analysis)
        let latest = data.latestRadarIndex
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(label.kind)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(frame?.isForecast == true ? Color.black : Color(red: 0.05, green: 0.2, blue: 0.45))
                    .background(Capsule().fill(frame?.isForecast == true ? Color(red: 1.0, green: 0.75, blue: 0.3) : .white))
                Text(label.time)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(label.offset)
                    .font(.footnote)
                    .opacity(0.8)
                Spacer(minLength: 0)
                Button("Jetzt") {
                    playing = false
                    index = latest
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(index == latest)
                .accessibilityLabel("Jüngstes Radarbild")
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .center, spacing: 12) {
                Button {
                    Haptics.selection()
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(.white.opacity(0.22)))
                }
                .disabled(n < 2)
                .accessibilityLabel(playing ? "Animation anhalten" : "Animation abspielen")

                VStack(spacing: 2) {
                    TimeTrack(frames: data.frames, split: latest)
                        .frame(height: 4)
                        .padding(.horizontal, 12)
                    Slider(
                        value: Binding(
                            get: { Double(index) },
                            set: { value in
                                playing = false
                                index = min(max(Int(value.rounded()), 0), max(n - 1, 0))
                            }
                        ),
                        in: 0...Double(max(n - 1, 1)),
                        step: 1
                    )
                    .tint(.white)
                    .disabled(n < 2)
                    .accessibilityLabel("Zeitpunkt des Radarbilds")
                    .accessibilityValue("\(label.kind) \(label.time), \(label.offset)")
                    HourTicks(frames: data.frames)
                        .frame(height: 14)
                        .padding(.horizontal, 12)
                }
            }

            if let probe, let text = probeText(data, frame: frame, at: probe) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                    Text(text).font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Button {
                        self.probe = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Stelle vergessen")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.14)))
            }
            if let frame {
                Text(factLine(frame))
                    .font(.caption)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RadarLegend(classes: data.classes)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { panelHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, height in panelHeight = height }
            }
        )
    }

    /// "Getippte Stelle: 1–2,5 mm/h (leicht), 12 km vom Standort" for the shown frame.
    private func probeText(_ data: RadarResponse, frame: RadarResponse.Frame?, at c: CLLocationCoordinate2D) -> String? {
        guard let pixel = RadarImages.pixel(data.map, latitude: c.latitude, longitude: c.longitude) else {
            return "Getippte Stelle liegt außerhalb des Radarbilds"
        }
        guard let value = RadarImages.rainClass(frame?.rle, at: pixel) else { return nil }
        var text: String
        if value == 0 {
            text = "Getippte Stelle: trocken"
        } else if let cls = data.classes.first(where: { $0.class == value }) {
            text = "Getippte Stelle: \(RadarWords.range(cls)) mm/h" + (cls.intensity.map { " (\($0))" } ?? "")
        } else {
            text = "Getippte Stelle: Niederschlag"
        }
        let center = Self.center(data) ?? RadarOverlay(bounds: data.map.bounds).coordinate
        let km = MKMapPoint(center).distance(to: MKMapPoint(c)) / 1000
        text += ", \(Fmt.number(km, decimals: 0)) km vom Standort"
        return text
    }

    private func factLine(_ f: RadarResponse.Frame) -> String {
        guard f.nearestKm != nil else { return "Kein Niederschlag im Umkreis auf diesem Bild." }
        var parts = ["Nächster Niederschlag \(RadarWords.whereText(f.nearestKm, f.nearestDir))"]
        if let max = f.maxMmH {
            parts.append("stärkste Stelle \(Fmt.value(max, 1, "mm/h")) (\(RadarWords.whereText(f.maxKm, f.maxDir)))")
        }
        parts.append("Fläche \(RadarWords.share(f.wetPct))")
        var text = parts.joined(separator: " · ")
        if f.scattered == true { text += ". Nur verstreute Einzelpixel, oft Störechos oder Niesel." }
        return text
    }

    // MARK: work

    private func rebuildImages() {
        guard let data = loader.value else { return }
        let start = data.latestRadarIndex
        if !playing { index = Self.initialIndex(data) ?? start }
        Task.detached(priority: .userInitiated) {
            let built = RadarImages.images(for: data)
            await MainActor.run { images = built }
        }
    }

    /// `-radarFrame N` (screenshots) or the newest radar image.
    private static func initialIndex(_ data: RadarResponse) -> Int? {
        guard let text = LaunchArgs.value("-radarFrame"), let i = Int(text) else { return nil }
        if i < 0 { return max(0, data.frames.count + i) }
        return min(i, max(data.frames.count - 1, 0))
    }

    private func animate() async {
        guard playing else { return }
        while !Task.isCancelled {
            let n = loader.value?.frames.count ?? 0
            guard n > 1 else { playing = false; return }
            let atEnd = index >= n - 1
            let pause: UInt64 = reduceMotion ? 1_000_000_000 : (atEnd ? 1_200_000_000 : 450_000_000)
            try? await Task.sleep(nanoseconds: pause)
            if Task.isCancelled { return }
            index = atEnd ? 0 : index + 1
        }
    }
}

/// Bar over the slider: measured part white, nowcast part amber.
struct TimeTrack: View {
    let frames: [RadarResponse.Frame]
    let split: Int

    var body: some View {
        GeometryReader { geo in
            let n = max(frames.count - 1, 1)
            let x = geo.size.width * CGFloat(min(max(split, 0), n)) / CGFloat(n)
            HStack(spacing: 0) {
                Capsule().fill(.white.opacity(0.85)).frame(width: x)
                Capsule().fill(Color(red: 1.0, green: 0.75, blue: 0.3))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Full hours under the slider ("18", "19", ...).
struct HourTicks: View {
    let frames: [RadarResponse.Frame]

    var body: some View {
        GeometryReader { geo in
            let n = max(frames.count - 1, 1)
            ForEach(Array(frames.enumerated()), id: \.offset) { i, frame in
                if let date = Fmt.parse(frame.time), Fmt.calendar.component(.minute, from: date) == 0 {
                    Text(Fmt.hour(date))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .opacity(0.75)
                        .fixedSize()
                        .position(x: geo.size.width * CGFloat(i) / CGFloat(n), y: 7)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Colour scale of the rain-rate classes (bounds from the server), grouped by the WMO word.
struct RadarLegend: View {
    let classes: [RadarResponse.RadarClass]

    private struct LegendGroup: Identifiable {
        let word: String
        var items: [RadarResponse.RadarClass]
        var id: String { word + "\(items.first?.class ?? 0)" }
    }

    private var groups: [LegendGroup] {
        var out: [LegendGroup] = []
        for c in classes {
            let word = c.intensity ?? ""
            if let last = out.indices.last, out[last].word == word {
                out[last].items.append(c)
            } else {
                out.append(LegendGroup(word: word, items: [c]))
            }
        }
        return out
    }

    var body: some View {
        if !classes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Regenrate in mm pro Stunde")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
                GeometryReader { geo in
                    let w = geo.size.width / CGFloat(max(classes.count, 1))
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 1) {
                                    ForEach(group.items) { c in
                                        Rectangle()
                                            .fill(RadarPalette.color(forClass: c.class))
                                            .frame(width: w - 1, height: 8)
                                    }
                                }
                                HStack(spacing: 0) {
                                    ForEach(group.items) { c in
                                        Text(lower(c))
                                            .font(.system(size: 9).monospacedDigit())
                                            .opacity(0.85)
                                            .frame(width: w, alignment: .leading)
                                    }
                                }
                                Text(group.word)
                                    .font(.system(size: 10, weight: .semibold))
                                    .opacity(0.8)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(width: w * CGFloat(group.items.count), alignment: .leading)
                        }
                    }
                }
                .frame(height: 40)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Legende Regenrate")
            .accessibilityValue(groups.map { g in
                "\(g.word): \(g.items.map(RadarWords.range).joined(separator: ", ")) Millimeter pro Stunde"
            }.joined(separator: "; "))
        }
    }

    private func lower(_ c: RadarResponse.RadarClass) -> String {
        let v = c.fromMmH
        let text = Fmt.number(v, decimals: v < 1 || v.rounded() != v ? 1 : 0)
        return c.toMmH == nil ? "≥\(text)" : text
    }
}
