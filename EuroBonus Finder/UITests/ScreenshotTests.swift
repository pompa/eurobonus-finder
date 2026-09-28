import XCTest

/// App Store screenshots, driven by `fastlane snapshot` (see fastlane/Snapfile).
/// snapshot re-runs this across every device and language in the Snapfile, so
/// nothing here may depend on a specific language: the Setup CTA is found
/// by its accessibility identifier, never by its (localized) title.
///
/// The Safari banner screenshot is NOT here and cannot be — it needs the
/// extension enabled in Settings and a real partner site in Safari, neither of
/// which a UI test can drive. See fastlane/README.md.
@MainActor
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The app under test, named explicitly.
    ///
    /// A bare `XCUIApplication()` resolves the target application from the
    /// scheme, and when that resolution fails it silently falls back to
    /// launching the *test bundle* — "FBSApplicationLibrary returned nil for
    /// com.…​.uitests". The bundle id is `$(APP_BUNDLE_ID)` and so is not a
    /// literal we can hard-code, but this target's own id is always that plus
    /// ".uitests" (project.yml), so derive it and leave nothing implicit.
    private var appUnderTest: XCUIApplication {
        let testBundleID = Bundle(for: ScreenshotTests.self).bundleIdentifier ?? ""
        return XCUIApplication(bundleIdentifier: testBundleID.replacingOccurrences(of: ".uitests", with: ""))
    }

    private func launch(setupCompleted: Bool) -> XCUIApplication {
        let app = appUnderTest
        // @AppStorage reads UserDefaults, and `-key value` launch arguments set
        // it — so we can start either before Setup or after it without a
        // test-only code path in the app.
        app.launchArguments += ["-setup", #"{"state":"\#(setupCompleted ? "completed" : "active")"}"#]
        setupSnapshot(app)
        app.launch()
        return app
    }

    func testSetupScreens() {
        let app = launch(setupCompleted: false)

        let cta = app.buttons["setup.next"]
        XCTAssertTrue(cta.waitForExistence(timeout: 20), "setup welcome did not appear")
        snapshot("1_welcome")

        cta.tap()
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "region step did not appear")
        snapshot("2_region")
    }

    func testSettings() {
        let app = launch(setupCompleted: true)
        // Settings is the root once Setup is done; wait for any of its rows.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 20), "settings did not appear")
        snapshot("3_settings")
    }
}
