import SwiftUI

struct ExportButton: View {
    @EnvironmentObject private var vm: TTSViewModel
    @State private var showExportSuccess = false
    @State private var exportedURL: URL?

    var body: some View {
        Button {
            if let url = vm.exportToDocuments() {
                exportedURL = url
                showExportSuccess = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.title3)
                Text("Export WAV")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.green)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(vm.generatedAudioURL == nil)
        .opacity(vm.generatedAudioURL == nil ? 0.4 : 1)
        .alert("Exported Successfully", isPresented: $showExportSuccess) {
            Button("OK") { showExportSuccess = false }
        } message: {
            Text("Saved to app Documents/exports/")
        }
    }
}
