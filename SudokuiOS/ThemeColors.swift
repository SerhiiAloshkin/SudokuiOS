import SwiftUI

extension Color {
    static var oddEvenFrame: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor.cyan : UIColor(named: "ThemeBlue") ?? UIColor.systemBlue
        })
    }
}
