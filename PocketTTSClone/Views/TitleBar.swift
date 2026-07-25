import SwiftUI

struct TitleBar: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, options: .speed(0.5), value: true)

                Text("PocketTTS")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("Clone")
                    .font(.system(.title2, design: .rounded, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Text("Offline Voice Cloning")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
