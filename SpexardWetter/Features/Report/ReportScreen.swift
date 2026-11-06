import SwiftUI

struct ReportScreen: View {
    var body: some View {
        NavigationStack {
            ComingSoon(title: "Wetterbericht", systemImage: "newspaper", text: "Der Wetterbericht für heute, das Wochenende und die Woche folgt in einem der nächsten Builds.")
                .navigationTitle("Bericht")
        }
    }
}
