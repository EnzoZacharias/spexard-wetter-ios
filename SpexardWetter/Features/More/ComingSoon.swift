import SwiftUI

/// Screen that is not built yet.
struct ComingSoon: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage).font(.system(size: 44)).opacity(0.85)
            Text(title).font(.title2.weight(.semibold))
            Text(text).font(.callout).multilineTextAlignment(.center).opacity(0.85)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}
