import SwiftUI

struct AudioInputView: View {
    @EnvironmentObject private var vm: TTSViewModel
    @State private var showFilePicker = false
    @State private var showSaveDialog = false
    @State private var voiceName = ""

    var body: some View {
        VStack(spacing: 12) {
            Label("Voice Input", systemImage: "waveform.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Record Button
                Button {
                    if vm.recorder.isRecording {
                        vm.stopRecording()
                        showSaveDialog = true
                    } else {
                        vm.startRecording()
                    }
                } label: {
                    Label(
                        vm.recorder.isRecording ? "Stop" : "Record",
                        systemImage: vm.recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.recorder.isRecording ? Color.red : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.state.isBusy && !vm.recorder.isRecording)

                // Import Button
                Button {
                    showFilePicker = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.state.isBusy)
            }

            // Recording indicator
            if vm.recorder.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(vm.recorder.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: vm.recorder.isRecording)

                    Text(String(format: "Recording... %.1fs", vm.recorder.recordingDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Cancel") {
                        if let url = vm.recorder.recordedFileURL {
                            vm.recorder.deleteRecording(at: url)
                        }
                        vm.recorder.stopRecording()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 4)
            }

            // Reference audio indicator
            if let url = vm.referenceAudioURL, !vm.recorder.isRecording {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Reference: \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        vm.referenceAudioURL = nil
                        if let voice = vm.selectedVoice {
                            vm.deleteVoice(voice)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.wav, .audio, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    vm.importAudio(url: url)
                }
            case .failure(let error):
                vm.state = .error("Import failed: \(error.localizedDescription)")
            }
        }
        .alert("Save Voice", isPresented: $showSaveDialog) {
            TextField("Voice name", text: $voiceName)
            Button("Save") {
                if !voiceName.isEmpty {
                    vm.saveCurrentVoice(name: voiceName)
                }
                voiceName = ""
            }
            Button("Discard", role: .cancel) {
                voiceName = ""
            }
        } message: {
            Text("Name this voice profile for future use.")
        }
    }
}
