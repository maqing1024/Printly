import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Drop target (and click target) for selecting files or a folder to scan.
struct FolderDropZone: View {
    let isEnabled: Bool
    let onURLsDropped: ([URL]) -> Void
    let onClick: () -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text(String(localized: "dropZone.prompt"))
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard isEnabled else { return false }
            return handleDrop(providers: providers)
        }
        .accessibilityLabel(String(localized: "dropZone.accessibility"))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await Self.loadFileURL(from: provider) {
                    urls.append(url)
                }
            }
            let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !existing.isEmpty else { return }
            await MainActor.run {
                onURLsDropped(existing)
            }
        }
        return true
    }

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let value = item as? URL {
                    continuation.resume(returning: value)
                } else if let data = item as? Data {
                    continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
