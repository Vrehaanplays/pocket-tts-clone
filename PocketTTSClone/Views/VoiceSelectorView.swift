import SwiftUI

struct VoiceSelectorView: View {
    @EnvironmentObject private var vm: TTSViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reference Voice", systemImage: "person.waveform")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                if vm.savedVoices.isEmpty {
                    Text("No saved voices yet")
                        .foregroundStyle(.secondary)
                }

                ForEach(vm.savedVoices) { voice in
                    Button {
                        vm.selectVoice(voice)
                    } label: {
                        HStack {
                            Text(voice.name)
                            Spacer()
                            if vm.selectedVoice?.id == voice.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    if let voice = vm.selectedVoice {
                        vm.deleteVoice(voice)
                    }
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .disabled(vm.selectedVoice == nil)
            } label: {
                HStack {
                    Image(systemName: vm.referenceAudioURL != nil ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(vm.referenceAudioURL != nil ? .green : .secondary)
                    Text(vm.selectedVoice?.name ?? (vm.referenceAudioURL != nil ? "Recorded Voice" : "None selected"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if vm.referenceAudioURL != nil && vm.selectedVoice == nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Recording ready — not saved as a voice profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
