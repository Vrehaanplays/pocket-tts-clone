import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: TTSViewModel
    @State private var showSettings = false
    @Namespace private var animation

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // MARK: Title
                TitleBar()

                // MARK: Model Download Prompt (shown when models missing)
                if !vm.isModelReady {
                    modelDownloadPrompt
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: Voice Selector
                VoiceSelectorView()

                // MARK: Audio Input
                AudioInputView()

                // MARK: Text Editor
                TextEditorView()

                // MARK: Generate Button
                GenerateButton()

                // MARK: Progress (shown during generation)
                if case .generating(let progress) = vm.state {
                    CustomProgressView(progress: progress, title: "Generating speech...")
                        .transition(.scale.combined(with: .opacity))
                        .matchedGeometryEffect(id: "progress", in: animation)
                }

                // MARK: Error State
                if case .error(let message) = vm.state {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { vm.reset() }
                            .font(.caption.weight(.medium))
                    }
                    .padding()
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // MARK: Audio Player (shown after generation)
                if case .completed = vm.state {
                    VStack(spacing: 12) {
                        AudioPlayerView()
                        ExportButton()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // MARK: Settings Button
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.state)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isModelReady)
    }

    // MARK: - Model Download Prompt

    private var modelDownloadPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .repeating, value: true)

            Text("Pocket TTS Model Required")
                .font(.headline)

            Text("Download the pre-trained voice cloning model (~800 MB).\nYour voice data stays on-device and offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if vm.modelDownloader.isDownloading {
                ProgressView(value: vm.modelDownloadProgress) {
                    Text(vm.modelDownloadStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                .padding(.horizontal)
            } else {
                Button {
                    Task { await vm.downloadModels() }
                } label: {
                    Label("Download Model", systemImage: "icloud.and.arrow.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
