import MapKit
import SwiftUI

extension Endpoint {
    static let maps = Endpoint(path: "/api/v1/karten", mock: "mock_karten")
}

/// Own maps of the server from ICON-D2 for NRW: layer picker, time slider with play/pause, run and
/// valid time, legend, value at the location and the largest value in the map box.
struct MapsScreen: View {
    @StateObject private var loader = Loader<MapsResponse>()
    /// Last shown layer, and the last variant of the precipitation group.
    @AppStorage("kartenEbene") private var storedLayer = ""
    @AppStorage("kartenVariante") private var storedVariant = ""
    @State private var layerId = ""
    @State private var index = 0
    @State private var playing = false
    @State private var image: CGImage?
    @State private var imageMissing = false
    @State private var probe: CLLocationCoordinate2D?
    @State private var showInfo = false
    @State private var sentenceExpanded = false
    /// Lower edge of the layer picker on the screen (the map runs under the navigation bar).
    @State private var topEdge: CGFloat = 160
    /// Run whose frame was chosen at the start (a reload of the same run keeps the slider).
    @State private var setUpRun: String?
    @State private var panelHeight: CGFloat = 250
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if let data = loader.value, let mapInfo = data.map, data.run != nil, let layer = currentLayer(data) {
                map(data, mapInfo, layer)
                VStack(spacing: 8) {
                    picker(data)
                        .background(GeometryReader { g in
                            Color.clear
                                .onAppear { topEdge = g.frame(in: .global).maxY }
                                .onChange(of: g.frame(in: .global).maxY) { _, y in topEdge = y }
                        })
                    Spacer(minLength: 0)
                    panel(data, layer)
                        .background(HeightReader { panelHeight = $0 })
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 10)
            } else if let data = loader.value {
                ScrollView {
                    VStack(spacing: 12) {
                        StateMessage(kind: .empty, text: data.sourceErrors?.first?.message ?? "Der Server hat noch keine Karten berechnet.")
                            .card()
                        StandFooter(date: loader.date, fromCache: loader.fromCache, sources: data.attribution?.joined(separator: " · "))
                    }
                    .padding(16)
                }
                .refreshable { await loader.reload() }
            } else if let error = loader.error {
                StateMessage(kind: .error, text: error) { await loader.reload() }
                    .padding(24)
            } else {
                StateMessage(kind: .loading, text: "Karten werden geladen …")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .navigationTitle("Karten")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loader.loadIfNeeded(.maps, maxAge: 600) }
        .onChange(of: loader.date) { _, _ in setUp() }
        .task(id: frameKey) { await showFrame() }
        .task(id: prefetchKey) { await prefetchLayer() }
        .task(id: playing) { await animate() }
        .sheet(isPresented: $showInfo) {
            if let data = loader.value, let layer = currentLayer(data) {
                MapLayerInfoSheet(layer: layer, run: data.run)
            }
        }
    }

    // MARK: state

    private func currentLayer(_ data: MapsResponse) -> MapsResponse.Layer? {
        data.layers.first { $0.id == layerId } ?? data.layers.first
    }

    private func currentFrame(_ layer: MapsResponse.Layer) -> MapsResponse.Frame? {
        layer.frames.indices.contains(index) ? layer.frames[index] : layer.frames.last
    }

    /// Changes whenever another image must be shown.
    private var frameKey: String {
        guard let data = loader.value, let layer = currentLayer(data), let frame = currentFrame(layer) else { return "" }
        return "\(data.run?.id ?? "")/\(layer.id)/\(frame.zeit)"
    }

    private var prefetchKey: String {
        guard let data = loader.value, let layer = currentLayer(data) else { return "" }
        return "\(data.run?.id ?? "")/\(layer.id)"
    }

    private static func mockName(_ layer: String, _ frame: MapsResponse.Frame) -> String {
        "mock_karte_\(layer)_" + String(format: "%03d", frame.stunde)
    }

    /// First answer (or a new run): pick the stored or launch-argument layer and the frame closest to now.
    private func setUp() {
        guard let data = loader.value else { return }
        let choices = MapChoice.choices(data.layers)
        let wanted = LaunchArgs.option ?? (layerId.isEmpty ? storedLayer : layerId)
        if choices.contains(where: { $0.layerIds.contains(wanted) }) {
            layerId = wanted
        } else {
            layerId = choices.first?.layerIds.first ?? ""
        }
        guard let layer = currentLayer(data), setUpRun != data.run?.id || !layer.frames.indices.contains(index) else { return }
        setUpRun = data.run?.id
        if let text = LaunchArgs.value("-mapFrame"), let i = Int(text) {
            index = min(max(i, 0), max(layer.frames.count - 1, 0))
            return
        }
        let reference = (APIClient.isMock ? Fmt.parse(data.generatedAt) : nil) ?? Date()
        index = layer.frames.firstIndex { (Fmt.parse($0.time) ?? .distantPast) >= reference.addingTimeInterval(-1800) } ?? 0
    }

    /// Switch the layer and keep the shown valid time (or the nearest one).
    private func select(layer id: String, in data: MapsResponse) {
        guard id != layerId, let new = data.layers.first(where: { $0.id == id }) else { return }
        let oldTime = currentLayer(data).flatMap(currentFrame).flatMap { Fmt.parse($0.time) }
        layerId = id
        storedLayer = id
        if choiceOf(id, in: data)?.layerIds.count ?? 0 > 1 { storedVariant = id }
        if let oldTime {
            let distances = new.frames.map { abs((Fmt.parse($0.time) ?? .distantPast).timeIntervalSince(oldTime)) }
            index = distances.indices.min { distances[$0] < distances[$1] } ?? 0
        } else {
            index = 0
        }
        probe = nil
        Haptics.selection()
    }

    private func choiceOf(_ id: String, in data: MapsResponse) -> MapChoice? {
        MapChoice.choices(data.layers).first { $0.layerIds.contains(id) }
    }

    private func showFrame() async {
        guard let data = loader.value, let layer = currentLayer(data), let frame = currentFrame(layer),
              let path = data.imagePath(layer: layer.id, frame: frame) else { return }
        let loaded = await MapFrames.shared.image(path: path, mock: Self.mockName(layer.id, frame))
        guard !Task.isCancelled else { return }
        image = loaded
        imageMissing = loaded == nil
    }

    private func prefetchLayer() async {
        guard let data = loader.value, let layer = currentLayer(data) else { return }
        // from the shown frame onwards, the way the player runs
        let start = min(index, max(layer.frames.count - 1, 0))
        let ordered = Array(layer.frames[start...]) + Array(layer.frames[..<start])
        for frame in ordered {
            if Task.isCancelled { return }
            guard let path = data.imagePath(layer: layer.id, frame: frame) else { continue }
            await MapFrames.shared.prefetch(path: path, mock: Self.mockName(layer.id, frame))
        }
    }

    private func animate() async {
        guard playing else { return }
        while !Task.isCancelled {
            guard let data = loader.value, let layer = currentLayer(data), layer.frames.count > 1 else {
                playing = false
                return
            }
            let n = layer.frames.count
            let atEnd = index >= n - 1
            let pause: UInt64 = reduceMotion ? 1_200_000_000 : (atEnd ? 1_400_000_000 : 700_000_000)
            try? await Task.sleep(nanoseconds: pause)
            if Task.isCancelled { return }
            let next = atEnd ? 0 : index + 1
            // decode the next image before switching, so the map never flashes empty
            if let path = data.imagePath(layer: layer.id, frame: layer.frames[next]) {
                _ = await MapFrames.shared.image(path: path, mock: Self.mockName(layer.id, layer.frames[next]))
            }
            if Task.isCancelled { return }
            index = next
        }
    }

    // MARK: map

    private func map(_ data: MapsResponse, _ info: MapsResponse.MapInfo, _ layer: MapsResponse.Layer) -> some View {
        let frame = currentFrame(layer)
        let center: CLLocationCoordinate2D? = {
            guard let lat = data.location?.lat, let lon = data.location?.lon else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()
        return ModelMapView(
            bounds: info.bounds,
            center: center,
            placeName: RadarScreen.shortPlace(data.location?.label),
            image: image,
            extremes: extremes(layer, frame),
            topInset: topEdge + 6,
            bottomInset: panelHeight + 14,
            accessibilityText: accessibilityText(data, layer, frame),
            onTap: { coordinate in
                probe = coordinate
                Haptics.selection()
            }
        )
        .ignoresSafeArea(edges: .top)
    }

    /// Markers at the places of the largest and smallest value of the shown frame.
    private func extremes(_ layer: MapsResponse.Layer, _ frame: MapsResponse.Frame?) -> [ModelMapView.Extreme] {
        guard let frame else { return [] }
        var out: [ModelMapView.Extreme] = []
        if let p = frame.maxBei, p.count == 2, let v = MapWords.value(frame.max, layer) {
            out.append(.init(id: "max", coordinate: CLLocationCoordinate2D(latitude: p[0], longitude: p[1]), text: "▲ \(v)"))
        }
        if let p = frame.minBei, p.count == 2, let v = MapWords.value(frame.min, layer) {
            out.append(.init(id: "min", coordinate: CLLocationCoordinate2D(latitude: p[0], longitude: p[1]), text: "▼ \(v)"))
        }
        return out
    }

    private func accessibilityText(_ data: MapsResponse, _ layer: MapsResponse.Layer, _ frame: MapsResponse.Frame?) -> String {
        guard let frame else { return "Karte \(layer.title)" }
        var parts = ["Karte \(layer.title), gültig \(MapWords.validLabel(frame))"]
        parts.append(placeText(data, layer, frame))
        parts.append(maxText(layer, frame))
        return parts.joined(separator: ". ")
    }

    // MARK: layer picker

    private func picker(_ data: MapsResponse) -> some View {
        let choices = MapChoice.choices(data.layers)
        let active = choices.first { $0.layerIds.contains(layerId) } ?? choices.first
        return VStack(alignment: .leading, spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(choices) { choice in
                            let selected = choice.id == active?.id
                            Button {
                                guard !selected else { return }
                                let target = choice.layerIds.contains(storedVariant) ? storedVariant : (choice.layerIds.first ?? "")
                                select(layer: target, in: data)
                            } label: {
                                Text(choice.title)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(selected ? Color(red: 0.05, green: 0.2, blue: 0.45) : .white)
                                    .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.18)))
                            }
                            .buttonStyle(.plain)
                            .id(choice.id)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(4)
                }
                .onAppear { if let id = active?.id { proxy.scrollTo(id, anchor: .center) } }
            }
            .background(.ultraThinMaterial, in: Capsule())

            if let active, active.layerIds.count > 1 {
                Picker("Zeitraum", selection: Binding(get: { layerId }, set: { select(layer: $0, in: data) })) {
                    ForEach(active.layerIds, id: \.self) { id in
                        if let layer = data.layers.first(where: { $0.id == id }) {
                            Text(MapWords.variantTitle(layer)).tag(id)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    // MARK: panel

    private func panel(_ data: MapsResponse, _ layer: MapsResponse.Layer) -> some View {
        let frame = currentFrame(layer)
        let n = layer.frames.count
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(layer.title).font(.subheadline.weight(.semibold))
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .frame(width: 30, height: 24)
                }
                .accessibilityLabel("Was zeigt die Karte \(layer.title)?")
                Spacer(minLength: 0)
                if let run = data.run {
                    Text(MapWords.runLabel(run))
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            if let satz = layer.satz, !satz.isEmpty {
                Text(satz)
                    .font(.footnote)
                    .lineLimit(sentenceExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.95)
                    .onTapGesture { withAnimation(.snappy) { sentenceExpanded.toggle() } }
                    .accessibilityHint(sentenceExpanded ? "" : "Tippen zeigt den ganzen Satz")
            }
            GlossaryNotesView(MapLayerInfoSheet.glossaryIds(layer))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(frame.map(MapWords.validLabel) ?? "–")
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(timeNote(layer, frame))
                    .font(.footnote)
                    .opacity(0.8)
                Spacer(minLength: 0)
                if image == nil && !imageMissing {
                    ProgressView().tint(.white).controlSize(.small)
                }
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
                    .accessibilityLabel("Gültigkeitszeit der Karte")
                    .accessibilityValue(frame.map { "\(MapWords.validLabel($0)), \(timeNote(layer, $0))" } ?? "")
                    DayTicks(frames: layer.frames)
                        .frame(height: 14)
                        .padding(.horizontal, 12)
                }
            }

            if let frame {
                Text("\(placeText(data, layer, frame)) · \(maxText(layer, frame))")
                    .font(.caption)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if imageMissing {
                Text("Für diese Zeit liefert der Server kein Kartenbild.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let probe, let text = probeText(data, layer, at: probe) {
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

            MapLegendBar(layer: layer)

            if data.run?.stale == true || loader.fromCache {
                Label(staleText(data), systemImage: loader.fromCache ? "icloud.slash" : "clock.badge.exclamationmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if let error = loader.error {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// "Stunde davor · +15 h" (what the time means for this layer and the hours after the run start).
    private func timeNote(_ layer: MapsResponse.Layer, _ frame: MapsResponse.Frame?) -> String {
        var parts: [String] = []
        if let period = layer.period, !period.isEmpty { parts.append(period) }
        if let frame { parts.append("+\(frame.stunde) h") }
        return parts.joined(separator: " · ")
    }

    private func placeText(_ data: MapsResponse, _ layer: MapsResponse.Layer, _ frame: MapsResponse.Frame) -> String {
        let place = RadarScreen.shortPlace(data.location?.label)
        if let value = MapWords.value(frame.standort, layer) {
            return "\(place): \(value)"
        }
        return layer.id == "radar" ? "\(place): kein Echo" : "\(place): kein Wert"
    }

    private func maxText(_ layer: MapsResponse.Layer, _ frame: MapsResponse.Frame) -> String {
        if let top = MapWords.value(frame.max, layer) {
            var text = "höchster Wert \(top)" + (frame.maxOrt.map { " \($0)" } ?? " im Ausschnitt")
            if let low = MapWords.value(frame.min, layer) {
                text += ", tiefster \(low)" + (frame.minOrt.map { " \($0)" } ?? "")
            }
            return text
        }
        if let threshold = MapWords.threshold(layer) {
            return "im Ausschnitt nirgends ab \(threshold)"
        }
        return "kein Wert im Ausschnitt"
    }

    private func staleText(_ data: MapsResponse) -> String {
        if loader.fromCache {
            return "Offline – Stand \(loader.date.map { Fmt.relativeDateTime($0, reference: Date()) } ?? "unbekannt")"
        }
        return data.sourceErrors?.first?.message ?? "Die Karten sind älter als zwölf Stunden."
    }

    /// "Getippte Stelle: 2–5 mm" from the colour of the shown image.
    private func probeText(_ data: MapsResponse, _ layer: MapsResponse.Layer, at c: CLLocationCoordinate2D) -> String? {
        guard let info = data.map, let image else { return nil }
        guard let pixel = MapProbe.pixel(info.bounds, width: image.width, height: image.height, at: c) else {
            return "Getippte Stelle liegt außerhalb der Karte"
        }
        guard let i = MapProbe.classIndex(image, x: pixel.x, y: pixel.y, classes: layer.legend.classes) else { return nil }
        if i < 0 {
            if let threshold = MapWords.threshold(layer) { return "Getippte Stelle: unter \(threshold)" }
            return layer.id == "radar" ? "Getippte Stelle: kein Echo" : "Getippte Stelle: kein Wert"
        }
        let cls = layer.legend.classes[i]
        var text = "Getippte Stelle: \(MapWords.range(cls, layer))"
        if layer.legend.below == "clamp", i == 0 { text = "Getippte Stelle: unter \(MapWords.value(layer.legend.classes.dropFirst().first?.from, layer) ?? "–")" }
        if let lat = data.location?.lat, let lon = data.location?.lon {
            let km = MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon)).distance(to: MKMapPoint(c)) / 1000
            text += ", \(Fmt.number(km, decimals: 0)) km vom Standort"
        }
        return text
    }
}

/// Reports the height of the view it is the background of.
struct HeightReader: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { onChange(geo.size.height) }
                .onChange(of: geo.size.height) { _, height in onChange(height) }
        }
    }
}

/// Day names under the slider where a new local day starts.
struct DayTicks: View {
    let frames: [MapsResponse.Frame]

    var body: some View {
        GeometryReader { geo in
            let n = max(frames.count - 1, 1)
            let cal = Fmt.calendar
            ForEach(Array(frames.enumerated()), id: \.offset) { i, frame in
                if let date = Fmt.parse(frame.time) {
                    let previous = i > 0 ? Fmt.parse(frames[i - 1].time) : nil
                    if previous.map({ !cal.isDate($0, inSameDayAs: date) }) ?? true {
                        Text(i == 0 ? "\(Fmt.weekdayShort(date)) \(Fmt.hour(date))" : Fmt.weekdayShort(date))
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .opacity(0.8)
                            .fixedSize()
                            .position(x: min(max(geo.size.width * CGFloat(i) / CGFloat(n), 14), geo.size.width - 10), y: 7)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Colour classes of a layer with the server's tick values.
struct MapLegendBar: View {
    let layer: MapsResponse.Layer

    private var classes: [MapsResponse.LegendClass] { layer.legend.classes }

    /// Position 0...1 of a value along the bar of equally wide classes.
    private func position(_ v: Double) -> CGFloat? {
        guard !classes.isEmpty else { return nil }
        for (i, c) in classes.enumerated() {
            if let to = c.to, v >= c.from, v < to {
                return (CGFloat(i) + CGFloat((v - c.from) / (to - c.from))) / CGFloat(classes.count)
            }
            if c.to == nil, v >= c.from {
                return CGFloat(i) / CGFloat(classes.count)
            }
        }
        return nil
    }

    private func tick(_ v: Double) -> String {
        Fmt.number(v, decimals: v.rounded() == v ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text("Legende in \(layer.legend.unit ?? layer.unit ?? "")")
                    .font(.caption2.weight(.semibold))
                if let threshold = MapWords.threshold(layer) {
                    Text("· unter \(threshold) ohne Farbe")
                        .font(.caption2)
                }
            }
            .opacity(0.8)
            GeometryReader { geo in
                let w = geo.size.width
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(classes) { c in
                            Rectangle().fill(MapProbe.color(c.color))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    ZStack(alignment: .topLeading) {
                        ForEach(layer.legend.ticks ?? classes.map(\.from), id: \.self) { v in
                            if let p = position(v) {
                                Text(tick(v))
                                    .font(.system(size: 9).monospacedDigit())
                                    .opacity(0.85)
                                    .fixedSize()
                                    .position(x: min(max(p * w, 8), w - 8), y: 6)
                            }
                        }
                    }
                    .frame(height: 12)
                }
            }
            .frame(height: 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legende \(layer.title)")
        .accessibilityValue(classes.map { MapWords.range($0, layer) }.joined(separator: ", "))
    }
}

/// What a layer shows: the server's description and note, how the time is meant, the colour classes.
struct MapLayerInfoSheet: View {
    let layer: MapsResponse.Layer
    let run: MapsResponse.Run?
    @Environment(\.dismiss) private var dismiss

    /// Glossary entries behind a map layer: the server's list in the catalog (`glossar`), for an
    /// older server the matching entry of the glossary.
    static func glossaryIds(_ layer: MapsResponse.Layer) -> [String] {
        if let ids = layer.glossar, !ids.isEmpty { return ids }
        let fallback: [String: String] = [
            "cape": "cape",
            "nullgradgrenze": "nullgradgrenze",
            "boeen": "boee",
            "neuschnee": "schneefallgrenze",
            "schneehoehe": "schneefallgrenze",
        ]
        return fallback[layer.id].map { [$0] } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let text = layer.description, !text.isEmpty {
                        Text(text).font(.body)
                    }
                    if let note = layer.note, !note.isEmpty {
                        Text(note).font(.callout).opacity(0.9)
                    }
                    if let period = layer.period, !period.isEmpty {
                        Fact(label: "Zeitangabe", value: "Der Wert gilt für den Zeitraum \(period) bis zur angezeigten Zeit.")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Farbstufen").font(.footnote.weight(.semibold)).opacity(0.8)
                        ForEach(layer.legend.classes) { c in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3).fill(MapProbe.color(c.color)).frame(width: 22, height: 12)
                                Text(MapWords.range(c, layer)).font(.caption.monospacedDigit())
                            }
                        }
                    }
                    ForEach(Self.glossaryIds(layer).compactMap { Glossary.shared.entry($0) }) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Im Lexikon: \(entry.begriff)").font(.footnote.weight(.semibold)).opacity(0.8)
                            GlossaryEntryView(entry: entry)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
                    }
                    if let run {
                        Text(runText(run)).font(.caption).opacity(0.75)
                    }
                    Text("Datenbasis: Deutscher Wetterdienst (ICON-D2). Die Karten rechnet der eigene Server aus den DWD-Modelldaten.")
                        .font(.caption)
                        .opacity(0.75)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(layer.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func runText(_ run: MapsResponse.Run) -> String {
        var parts = ["Modell \(run.model ?? "ICON-D2")"]
        if let km = run.resolutionKm { parts.append("\(Fmt.number(km, decimals: 1)) km Gitter") }
        if let start = Fmt.parse(run.init_) { parts.append("Lauf vom \(Fmt.relativeDateTime(start, reference: Date()))") }
        if let done = Fmt.parse(run.processed) { parts.append("berechnet \(Fmt.relativeDateTime(done, reference: Date()))") }
        return parts.joined(separator: " · ")
    }
}
