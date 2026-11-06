import MapKit
import SwiftUI
import UIKit

/// The radar raster as one image on the map. The server already resampled it onto Web Mercator,
/// which is the projection of `MKMapPoint`, so the image fills the bounding map rect exactly.
final class RadarOverlay: NSObject, MKOverlay {
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D

    init(bounds: RadarResponse.Bounds) {
        let nw = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west))
        let se = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east))
        boundingMapRect = MKMapRect(x: nw.x, y: nw.y, width: se.x - nw.x, height: se.y - nw.y)
        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
        super.init()
    }
}

/// Draws the current frame; MapKit calls `draw` on background threads, hence the lock.
final class RadarRenderer: MKOverlayRenderer {
    private let lock = NSLock()
    private var frameImage: CGImage?

    func show(_ image: CGImage?) {
        lock.lock()
        let changed = frameImage !== image
        frameImage = image
        lock.unlock()
        if changed { setNeedsDisplay() }
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        lock.lock()
        let image = frameImage
        lock.unlock()
        guard let image else { return }
        let rect = self.rect(for: overlay.boundingMapRect)
        context.interpolationQuality = .none
        UIGraphicsPushContext(context)
        UIImage(cgImage: image).draw(in: rect)
        UIGraphicsPopContext()
    }
}

/// Text without a pin (ring distances, the place name next to the location circle).
final class TextAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let text: String
    let emphasized: Bool

    init(coordinate: CLLocationCoordinate2D, text: String, emphasized: Bool) {
        self.coordinate = coordinate
        self.text = text
        self.emphasized = emphasized
        super.init()
    }
}

struct RadarMapView: UIViewRepresentable {
    let bounds: RadarResponse.Bounds
    /// Public (rounded) location of the server; the circle marks about 1 km around it.
    let center: CLLocationCoordinate2D?
    let placeName: String
    let image: CGImage?
    /// Height covered by the controls at the bottom (keeps the Apple Maps logo and "Legal" visible).
    var bottomInset: CGFloat = 0
    let accessibilityText: String
    /// Tap on the map: the coordinate under the finger.
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    static let rings: [Double] = [25, 50, 100]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = false
        map.overrideUserInterfaceStyle = .dark

        let overlay = RadarOverlay(bounds: bounds)
        map.addOverlay(overlay, level: .aboveRoads)
        let mid = center ?? overlay.coordinate
        for km in Self.rings {
            map.addOverlay(RingCircle(center: mid, radius: km * 1000), level: .aboveLabels)
            let labelPoint = CLLocationCoordinate2D(latitude: mid.latitude + km / 111.2, longitude: mid.longitude)
            map.addAnnotation(TextAnnotation(coordinate: labelPoint, text: "\(Int(km)) km", emphasized: false))
        }
        map.addOverlay(PlaceCircle(center: mid, radius: 1000), level: .aboveLabels)
        let kmPerDegLon = 111.2 * cos(mid.latitude * .pi / 180)
        let labelPoint = CLLocationCoordinate2D(latitude: mid.latitude, longitude: mid.longitude + 3.2 / kmPerDegLon)
        map.addAnnotation(TextAnnotation(coordinate: labelPoint, text: placeName, emphasized: true))

        let rect = overlay.boundingMapRect
        let pad = rect.width * 0.4
        map.cameraBoundary = MKMapView.CameraBoundary(mapRect: rect.insetBy(dx: -pad, dy: -pad))
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 8_000, maxCenterCoordinateDistance: 1_200_000)
        let inner = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
        map.setVisibleMapRect(inner, edgePadding: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8), animated: false)

        map.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: bottomInset, right: 8)
        map.isAccessibilityElement = true
        map.accessibilityLabel = accessibilityText
        context.coordinator.overlay = overlay
        context.coordinator.image = image
        context.coordinator.onTap = onTap
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.image = image
        context.coordinator.onTap = onTap
        context.coordinator.renderer?.show(image)
        map.accessibilityValue = accessibilityText
        if abs(map.layoutMargins.bottom - bottomInset) > 1 {
            map.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: bottomInset, right: 8)
        }
    }

    final class RingCircle: MKCircle {}
    final class PlaceCircle: MKCircle {}

    final class Coordinator: NSObject, MKMapViewDelegate {
        var overlay: RadarOverlay?
        var renderer: RadarRenderer?
        var image: CGImage?
        var onTap: ((CLLocationCoordinate2D) -> Void)?

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            onTap?(map.convert(point, toCoordinateFrom: map))
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let radar = overlay as? RadarOverlay {
                let renderer = RadarRenderer(overlay: radar)
                renderer.alpha = 0.85
                renderer.show(image)
                self.renderer = renderer
                return renderer
            }
            if let circle = overlay as? PlaceCircle {
                let r = MKCircleRenderer(circle: circle)
                r.strokeColor = UIColor.white
                r.lineWidth = 2.5
                r.fillColor = UIColor.white.withAlphaComponent(0.25)
                return r
            }
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.strokeColor = UIColor.white.withAlphaComponent(0.45)
                r.lineWidth = 1
                r.lineDashPattern = [3, 5]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let text = annotation as? TextAnnotation else { return nil }
            let id = text.emphasized ? "place" : "ring"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: text, reuseIdentifier: id)
            view.annotation = text
            view.subviews.forEach { $0.removeFromSuperview() }
            let label = UILabel()
            label.text = text.text
            label.font = text.emphasized ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 11, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(text.emphasized ? 1 : 0.75)
            label.shadowColor = UIColor.black.withAlphaComponent(0.6)
            label.shadowOffset = CGSize(width: 0, height: 1)
            label.sizeToFit()
            view.addSubview(label)
            view.frame = label.frame
            view.centerOffset = text.emphasized ? CGPoint(x: label.frame.width / 2, y: 0) : .zero
            view.isEnabled = false
            view.canShowCallout = false
            view.isAccessibilityElement = false
            view.displayPriority = .required
            return view
        }
    }
}
