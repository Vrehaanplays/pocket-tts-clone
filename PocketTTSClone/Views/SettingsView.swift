import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: TTSViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Generation Parameters
                Section("Generation") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Speech Speed")
                            Spacer()
                            Text(String(format: "%.1fx", vm.settings.speed))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $vm.settings.speed, in: 0.5...2.0, step: 0.1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Silence Scale")
                            Spacer()
                            Text(String(format: "%.1f", vm.settings.silenceScale))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $vm.settings.silenceScale, in: 0.0...1.0, step: 0.1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Flow Steps")
                            Spacer()
                            Text("\(vm.settings.numSteps)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(get: { Double(vm.settings.numSteps) },
                                              set: { vm.settings.numSteps = Int32($0) }),
                               in: 1...64, step: 1)
                    }
                }

                // MARK: Voice Cloning
                Section("Voice Cloning") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max Reference Audio (s)")
                            Spacer()
                            Text(String(format: "%.1f", vm.settings.maxReferenceAudioLen))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $vm.settings.maxReferenceAudioLen, in: 3.0...30.0, step: 1.0)
                    }

                    HStack {
                        Text("Random Seed")
                        Spacer()
                        Text(vm.settings.seed == -1 ? "Random" : "\(vm.settings.seed)")
                            .foregroundStyle(.secondary)
                        Button(vm.settings.seed == -1 ? "Set" : "Reset") {
                            if vm.settings.seed == -1 {
                                vm.settings.seed = 42
                            } else {
                                vm.settings.seed = -1
                            }
                        }
                        .font(.caption.weight(.medium))
                    }
                }

                // MARK: Model Management
                Section("Model") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(vm.isModelReady ? "Ready" : "Not Downloaded")
                            .foregroundStyle(vm.isModelReady ? .green : .orange)
                    }

                    if !vm.isModelReady {
                        Button("Download Pocket TTS Model (~800 MB)") {
                            Task { await vm.downloadModels() }
                        }
                        .disabled(vm.modelDownloader.isDownloading)
                    }

                    if vm.modelDownloader.isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: vm.modelDownloadProgress)
                            Text(vm.modelDownloadStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("sherpa-onnx + Pocket TTS")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
