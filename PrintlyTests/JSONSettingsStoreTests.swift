import Foundation
import Testing
@testable import Printly

struct JSONSettingsStoreTests {
    @Test func save_roundTripsPresetsAndTrimsHistory() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrintlySettings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = JSONSettingsStore(fileURL: url, historyLimit: 2)
        var settings = AppSettings.default
        settings.presets = [
            PrintPreset(name: "Office", printerName: "HP", settings: .default)
        ]
        settings.history = [
            PrintHistoryRecord(fileName: "c.pdf", kind: .pdf, printerName: "HP", succeeded: true),
            PrintHistoryRecord(fileName: "b.pdf", kind: .pdf, printerName: "HP", succeeded: true),
            PrintHistoryRecord(fileName: "a.pdf", kind: .pdf, printerName: "HP", succeeded: true),
        ]
        store.save(settings)

        let loaded = store.load()
        #expect(loaded.presets.map(\.name) == ["Office"])
        #expect(loaded.history.map(\.fileName) == ["c.pdf", "b.pdf"])
    }
}
