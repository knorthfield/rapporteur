import SwiftUI

struct Label: Codable, Hashable, Identifiable, Sendable {
    let name: String
    /// Six hex digits without "#", as GitHub sends them.
    let color: String

    var id: String { name }

    /// Red, green and blue from 0 to 1. Grey when the text is not a hex colour.
    var rgb: (red: Double, green: Double, blue: Double) {
        guard color.count == 6, let value = UInt32(color, radix: 16) else { return (0.5, 0.5, 0.5) }
        return (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    var needsDarkText: Bool {
        let (red, green, blue) = rgb
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    var fillColor: Color {
        let (red, green, blue) = rgb
        return Color(red: red, green: green, blue: blue)
    }
}
