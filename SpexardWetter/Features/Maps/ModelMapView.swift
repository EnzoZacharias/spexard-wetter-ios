import MapKit
import SwiftUI
import UIKit

/// MapKit map with one model-map frame as image overlay (the server renders the PNGs in Web
/// Mercator onto `bounds`, so the image fills the bounding map rect exactly) and the location circle.
struct ModelMapView: UIViewRepresentable {
    let bounds: RadarResponse.Bounds
    /// Public (rounded) location of the server; nil = no circle.
    let center: CLLocationCoordinate2D?
    let placeName: String
    let image: CGImage?
    /// Heights covered by the controls on top and at the bottom.
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    let accessibilityText: String
    var onTap: ((CLLocationCoordinate2D) -> Void)?

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
        // below the labels: town names stay readable over the colours
        map.addOverlay(overlay, level: .aboveRoads)
        if let center {
            map.addOverlay(RadarMapView.PlaceCircle(center: center, radius: 2500), level: .aboveLabels)
            let kmPerDegLon = 111.2 * cos(center.latitude * .pi / 180)
            let labelPoint = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + 4.5 / kmPerDegLon)
            map.addAnnotation(TextAnnotation(coordinate: labelPoint, text: placeName, emphasized: true))
        }

        let rect = overlay.boundingMapRect
        let pad = rect.width * 0.25
        map.cameraBoundary = MKMapView.CameraBoundary(mapRect: rect.insetBy(dx: -pad, dy: -pad))
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 15_000, maxCenterCoordinateDistance: 2_500_000)
        map.layoutMargins = UIEdgeInsets(top: topInset, left: 8, bottom: bottomInset, right: 8)
        map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: topInset + 4, left: 2, bottom: bottomInset + 4, right: 2), animated: false)

        map.isAccessibilityElement = true
        map.accessibilityLabel = accessibilityText
        context.coordinator.image = image
        context.coordinator.onTap = onTap
        context.coordinator.rect = rect
        context.coordinator.insets = (topInset, bottomInset)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.image = image
        context.coordinator.onTap = onTap
        context.coordinator.renderer?.show(image)
        map.accessibilityValue = accessibilityText
        let insets = context.coordinator.insets
        if abs(insets.top - topInset) > 1 || abs(insets.bottom - bottomInset) > 1 {
            context.coordinator.insets = (topInset, bottomInset)
            map.layoutMargins = UIEdgeInsets(top: topInset, left: 8, bottom: bottomInset, right: 8)
            // the panels got their real height: fit the whole box between them once
            if !context.coordinator.userMoved, let rect = context.coordinator.rect {
                map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: topInset + 4, left: 2, bottom: bottomInset + 4, right: 2), animated: false)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var renderer: RadarRenderer?
        var image: CGImage?
        var onTap: ((CLLocationCoordinate2D) -> Void)?
        var rect: MKMapRect?
        var insets: (top: CGFloat, bottom: CGFloat) = (0, 0)
        var userMoved = false

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            onTap?(map.convert(point, toCoordinateFrom: map))
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // a region change started by a finger (not by setVisibleMapRect)
            if let gestures = mapView.subviews.first?.gestureRecognizers,
               gestures.contains(where: { $0.state == .began || $0.state == .changed }) {
                userMoved = true
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let frame = overlay as? RadarOverlay {
                let renderer = RadarRenderer(overlay: frame)
                renderer.show(image)
                self.renderer = renderer
                return renderer
            }
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.strokeColor = UIColor.white
                r.lineWidth = 2.5
                r.fillColor = UIColor.white.withAlphaComponent(0.12)
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let text = annotation as? TextAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place") ?? MKAnnotationView(annotation: text, reuseIdentifier: "place")
            view.annotation = text
            view.subviews.forEach { $0.removeFromSuperview() }
            let label = UILabel()
            label.text = text.text
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .white
            label.shadowColor = UIColor.black.withAlphaComponent(0.7)
            label.shadowOffset = CGSize(width: 0, height: 1)
            label.sizeToFit()
            view.addSubview(label)
            view.frame = label.frame
            view.centerOffset = CGPoint(x: label.frame.width / 2, y: 0)
            view.isEnabled = false
            view.canShowCallout = false
            view.isAccessibilityElement = false
            view.displayPriority = .required
            return view
        }
    }
}
