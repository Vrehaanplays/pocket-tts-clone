import SwiftUI

struct CustomProgressView: View {
    let progress: Double
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(height: 12)

                // Animated progress
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: progress, y: 1, anchor: .leading)
                    .animation(.easeOut(duration: 0.3), value: progress)
            }

            HStack {
                Label(title, systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: progress)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
