#if canImport(UIKit)
import SwiftUI

/// Full-screen text editor for creating and styling text overlays.
public struct TextEditorView: View {
    @Binding var textClip: TextClip
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var tab: Tab = .style
    @FocusState private var isTextFocused: Bool

    enum Tab: String, CaseIterable {
        case style = "Style"
        case position = "Position"
        case animation = "Animation"
    }

    public init(
        textClip: Binding<TextClip>,
        onDone: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._textClip = textClip
        self.onDone = onDone
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Live preview
                textPreview
                    .frame(height: 200)
                    .onTapGesture { isTextFocused = true }

                Divider()

                // Text input
                TextField("Enter text", text: $textClip.text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()

                // Tab selector
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                // Tab content
                ScrollView {
                    switch tab {
                    case .style:    styleControls
                    case .position: positionGrid
                    case .animation: animationPicker
                    }
                }
            }
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone).fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Preview

    private var textPreview: some View {
        ZStack {
            Color.black
            Text(textClip.text.isEmpty ? "Your Text" : textClip.text)
                .font(.system(size: textClip.style.fontSize * 0.6, weight: uiFontWeight))
                .foregroundColor(Color(
                    red: textClip.style.textColor.r,
                    green: textClip.style.textColor.g,
                    blue: textClip.style.textColor.b,
                    opacity: textClip.style.textColor.a
                ))
                .multilineTextAlignment(uiAlignment)
                .shadow(radius: textClip.style.shadowEnabled ? textClip.style.shadowRadius : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: positionAlignment)
                .padding(16)
        }
        .cornerRadius(12)
        .padding(8)
    }

    // MARK: - Style controls

    private var styleControls: some View {
        VStack(spacing: 14) {
            // Font size
            HStack {
                Text("Size").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(textClip.style.fontSize))pt").font(.caption.monospacedDigit())
            }
            Slider(value: $textClip.style.fontSize, in: 12...120, step: 1)

            // Font weight
            HStack {
                Text("Weight").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Picker("Weight", selection: $textClip.style.fontWeight) {
                ForEach(TextStyle.FontWeight.allCases, id: \.self) { w in
                    Text(w.rawValue.capitalized).tag(w)
                }
            }
            .pickerStyle(.segmented)

            // Alignment
            Picker("Alignment", selection: $textClip.style.alignment) {
                Image(systemName: "text.alignleft").tag(TextStyle.TextAlignment.left)
                Image(systemName: "text.aligncenter").tag(TextStyle.TextAlignment.center)
                Image(systemName: "text.alignright").tag(TextStyle.TextAlignment.right)
            }
            .pickerStyle(.segmented)

            // Shadow
            Toggle("Shadow", isOn: $textClip.style.shadowEnabled)
                .font(.caption)

            // Presets
            Section {
                HStack {
                    Text("Presets").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TextStyle.presets, id: \.name) { preset in
                            Button {
                                textClip.style = preset.style
                            } label: {
                                Text(preset.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - Position grid

    private var positionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(TextPosition.allCases, id: \.self) { pos in
                Button {
                    textClip.position = pos
                } label: {
                    Text(pos.displayName)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(textClip.position == pos
                                      ? Color.accentColor.opacity(0.3)
                                      : Color.secondary.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(textClip.position == pos
                                              ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Animation picker

    private var animationPicker: some View {
        VStack(spacing: 6) {
            ForEach(TextStyle.TextAnimation.allCases, id: \.self) { anim in
                Button {
                    textClip.style.animation = anim
                } label: {
                    HStack {
                        Text(anim.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if textClip.style.animation == anim {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    private var uiFontWeight: Font.Weight {
        switch textClip.style.fontWeight {
        case .thin:     return .thin
        case .light:    return .light
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        case .heavy:    return .heavy
        case .black:    return .black
        }
    }

    private var uiAlignment: SwiftUI.TextAlignment {
        switch textClip.style.alignment {
        case .left:   return .leading
        case .center: return .center
        case .right:  return .trailing
        }
    }

    private var positionAlignment: Alignment {
        switch textClip.position {
        case .topLeft:      return .topLeading
        case .topCenter:    return .top
        case .topRight:     return .topTrailing
        case .centerLeft:   return .leading
        case .center:       return .center
        case .centerRight:  return .trailing
        case .bottomLeft:   return .bottomLeading
        case .bottomCenter: return .bottom
        case .bottomRight:  return .bottomTrailing
        }
    }
}
#endif
