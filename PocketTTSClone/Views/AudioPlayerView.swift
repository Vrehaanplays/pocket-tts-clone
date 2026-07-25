import SwiftUI

struct AudioPlayerView: View {
    @EnvironmentObject private var vm: TTSViewModel
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(currentProgress), height: 8)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = min(max(0, value.location.x / geo.size.width), 1)
                        }
                        .onEnded { _ in
                            vm.player.seek(to: dragProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 8)

            // Controls
            HStack {
                Text(timeString(from: vm.player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        vm.player.seek(to: max(0, currentProgress - 0.05))
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if vm.player.isPlaying {
                            vm.player.pause()
                        } else if vm.player.isPaused {
                            vm.player.resume()
                        } else {
                            vm.playGenerated()
                        }
                    } label: {
                        Image(systemName: vm.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, value: vm.player.isPlaying)
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.player.seek(to: min(1, currentProgress + 0.05))
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(timeString(from: vm.player.currentDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var currentProgress: Double {
        isDragging ? dragProgress : vm.player.playbackProgress
    }

    private func timeString(from time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
