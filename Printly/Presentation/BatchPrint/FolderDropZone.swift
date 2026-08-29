import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Drop target (and click target) for selecting a folder to scan.
struct FolderDropZone: View {
    let isEnabled: Bool
    let onFolderDropped: (URL) -> Void
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
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let value = item as? URL {
                url = value
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }

            guard let url else { return }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return }

            Task { @MainActor in
                onFolderDropped(url)
            }
        }
        return true
    }
}
