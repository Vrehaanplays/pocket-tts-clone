import SwiftUI

struct TextEditorView: View {
    @EnvironmentObject private var vm: TTSViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Text to Speak", systemImage: "textformat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if vm.textInput.isEmpty {
                    Text("Type or paste text here...\n\nTip: For best voice cloning results, use 1-2 paragraphs of natural speech.")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }

                TextEditor(text: $vm.textInput)
                    .font(.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minHeight: 120, maxHeight: 200)
            }
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            if !vm.textInput.isEmpty {
                HStack {
                    Text("\(vm.textInput.count) characters")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Clear") {
                        vm.textInput = ""
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}
