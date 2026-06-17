import SwiftUI
import UIKit

struct StaatsloterijFamilyTrackApp: View {
    @StateObject private var store = AppStore()

    init() {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let serif = descriptor.withDesign(.serif) ?? descriptor
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: UIFont(descriptor: serif, size: 20),
            .foregroundColor: UIColor.white
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont(descriptor: serif, size: 34),
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some View {
        ContentView()
            .environmentObject(store)
            .tint(AppTheme.goldColor)
            .preferredColorScheme(.dark)
    }
}
