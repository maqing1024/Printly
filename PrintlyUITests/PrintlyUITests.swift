import XCTest

final class PrintlyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsBatchPrintTitle() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Batch Print"].waitForExistence(timeout: 5))
    }
}
