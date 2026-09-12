import XCTest

final class CurtainCallUITests: XCTestCase {
    @MainActor
    func testLoginValidationAndSignupScreen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["authSubmit"].waitForExistence(timeout: 15))
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(app.staticTexts["올바른 이메일 주소를 입력해주세요."].exists)
        app.segmentedControls.buttons["회원가입"].tap()
        XCTAssertTrue(app.textFields["nickname"].exists)
        XCTAssertTrue(app.secureTextFields["confirmation"].exists)
        XCTAssertTrue(app.buttons["appleOAuth"].exists)
        XCTAssertTrue(app.buttons["googleOAuth"].exists)
        XCTAssertEqual(app.buttons["appleOAuth"].label, "Apple 로그인 준비 중")
        XCTAssertEqual(app.buttons["googleOAuth"].label, "Google 로그인 준비 중")
        XCTAssertFalse(app.buttons["appleOAuth"].isEnabled)
        XCTAssertFalse(app.buttons["googleOAuth"].isEnabled)
        app.textFields["nickname"].tap()
        app.textFields["nickname"].typeText("Tester")
        app.textFields["email"].tap()
        app.textFields["email"].typeText("test@example.com")
        app.secureTextFields["password"].tap()
        app.secureTextFields["password"].typeText("123")
        app.buttons["authSubmit"].tap()
        XCTAssertEqual(app.staticTexts["authError"].label, "비밀번호는 8자 이상으로 입력해주세요.")
        app.secureTextFields["confirmation"].tap()
        app.secureTextFields["confirmation"].typeText("123")
        app.segmentedControls.buttons["로그인"].tap()
        app.buttons["authSubmit"].tap()
        XCTAssertEqual(app.staticTexts["authError"].label, "비밀번호를 입력해주세요.")
        app.segmentedControls.buttons["회원가입"].tap()
        XCTAssertEqual(app.secureTextFields["confirmation"].value as? String, "비밀번호 확인")
    }
}
