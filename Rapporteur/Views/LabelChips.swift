import SwiftUI

/// The labels of a repository in their GitHub colours. A tap selects or deselects a label.
struct LabelChips: View {
    let labels: [Label]
    @Binding var selection: Set<String>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(labels) { label in
                    let isSelected = selection.contains(label.name)
                    Button {
                        if isSelected { selection.remove(label.name) } else { selection.insert(label.name) }
                    } label: {
                        Text(label.name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? (label.needsDarkText ? Color.black : Color.white) : Color.primary)
                            .background(label.fillColor.opacity(isSelected ? 1 : 0.15), in: .capsule)
                            .overlay(Capsule().strokeBorder(label.fillColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
