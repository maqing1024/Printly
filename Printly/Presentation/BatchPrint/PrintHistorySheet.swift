import SwiftUI

/// Lists recent print attempts.
struct PrintHistorySheet: View {
    let records: [PrintHistoryRecord]
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "history.title"))
                    .font(.title2.bold())
                Spacer()
                Button(String(localized: "button.clearHistory")) {
                    onClear()
                }
                .disabled(records.isEmpty)
                Button(String(localized: "button.close")) {
                    dismiss()
                }
            }

            if records.isEmpty {
                Text(String(localized: "history.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { record in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: record.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(record.succeeded ? Color.green : Color.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.fileName)
                                .lineLimit(1)
                            Text(detail(for: record))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
    }

    private func detail(for record: PrintHistoryRecord) -> String {
        let stamp = record.date.formatted(date: .abbreviated, time: .shortened)
        if let message = record.message, !record.succeeded {
            return "\(stamp) · \(record.printerName) · \(message)"
        }
        return "\(stamp) · \(record.printerName)"
    }
}
