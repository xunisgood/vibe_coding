import XCTest
@testable import LifeCore
final class EnvironmentTests: XCTestCase {
    func testDayRoundTripAndInvalidDate() {
        XCTAssertEqual(Day.key(Day.date("2026-09-29")!), "2026-09-29")
        XCTAssertNil(Day.date("2026-02-30"))
        XCTAssertEqual(Day.adding(1, to: "2026-12-31"), "2027-01-01")
    }
    func testCalendarBoundaryUsesLocalDay() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 8*3600)!
        let date = ISO8601DateFormatter().date(from: "2026-09-29T17:00:00Z")!
        XCTAssertEqual(Day.key(date, calendar: c), "2026-09-30")
    }
}
