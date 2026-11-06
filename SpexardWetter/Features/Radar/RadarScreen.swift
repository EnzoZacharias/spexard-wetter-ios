import SwiftUI

struct RadarScreen: View {
    var body: some View {
        NavigationStack {
            ComingSoon(title: "Radar", systemImage: "map", text: "Die Radarkarte mit Animation folgt in einem der nächsten Builds.")
                .navigationTitle("Radar")
        }
    }
}
