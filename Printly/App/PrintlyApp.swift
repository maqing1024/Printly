import SwiftUI

@main
struct PrintlyApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            BatchPrintView(viewModel: container.makeBatchPrintViewModel())
                // `.defaultSize` requires macOS 13+; set an initial frame for 12.4+.
                .frame(minWidth: 560, idealWidth: 640, minHeight: 720, idealHeight: 820)
        }
    }
}
