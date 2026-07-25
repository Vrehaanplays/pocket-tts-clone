import SwiftUI

struct GenerateButton: View {
    @EnvironmentObject private var vm: TTSViewModel

    var body: some View {
        Button {
            vm.generate()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                Text("Generate Speech")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canGenerate ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
            )
            .opacity(canGenerate ? 1 : 0.6)
        }
        .disabled(!canGenerate || vm.state.isBusy)
        .animation(.easeInOut(duration: 0.2), value: canGenerate)
    }

    private var canGenerate: Bool {
        !vm.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && vm.referenceAudioURL != nil
        && vm.isModelReady
    }
}
