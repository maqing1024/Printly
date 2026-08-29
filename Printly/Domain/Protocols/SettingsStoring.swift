import Foundation

/// Loads and saves app settings (presets, history, sort/filter, folders).
nonisolated protocol SettingsStoring: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
