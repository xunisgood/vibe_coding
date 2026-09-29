import XCTest
@testable import LifeCore
final class LifestyleTests: XCTestCase {
    func testNutritionCountsOnlyActualAndPreservesMissing() throws {
        var l=Library(); var a=Meal(day:"2026-09-29",slot:"早餐"); a.planned="燕麦"; a.calories=300; l.meals=[a]
        XCTAssertEqual(l.nutrition(on:a.day).calories,0)
        try l.eatAsPlanned(a.id); XCTAssertEqual(l.nutrition(on:a.day).calories,300); XCTAssertNil(l.meals[0].protein); XCTAssertTrue(l.nutrition(on:a.day).partial)
        l.meals[0].actual="面包"; XCTAssertEqual(l.meals[0].planned,"燕麦")
    }
    func testGameTotalsAfterEditAndDeleteAndInvalidInput() throws {
        var l=Library(); l.games=[Game(day:"2026-09-29",name:"a",minutes:try GameDuration.minutes(hours:1,minutes:30)),Game(day:"2026-09-29",name:"a",minutes:15),Game(day:"2026-09-28",name:"b",minutes:60)]
        XCTAssertEqual(l.gameMinutes(on:"2026-09-29"),105); l.games[0].minutes=30; XCTAssertEqual(l.gameMinutes(on:"2026-09-29"),45); l.games.removeFirst(); XCTAssertEqual(l.gameMinutes(on:"2026-09-29"),15)
        for (h,m) in [(-1,10),(0,0),(0,60),(1,-1)] { XCTAssertThrowsError(try GameDuration.minutes(hours:h,minutes:m)) }
    }
    func testProjectArchiveRetainsEntriesAndCanRestore() throws {
        var l=Library(); let p=Project("app"); l.projects=[p]; var e=DevEntry(); e.title="问题"; e.kind="问题"; try l.saveEntry(e,projectID:p.id); try l.archiveProject(p.id,archived:true)
        l=try LibraryStore.decode(LibraryStore.encode(l)); XCTAssertEqual(l.projects[0].entries[0].id,e.id); XCTAssertTrue(l.projects[0].archived)
        try l.archiveProject(p.id,archived:false); XCTAssertFalse(l.projects[0].archived); XCTAssertEqual(l.todos.count,0)
    }
    func testNegativeNutritionDuplicateMealsAndEmptyGameRejected() {
        var l=Library(); var m=Meal(day:"2026-09-29",slot:"午餐"); m.calories = -1; l.meals=[m]; XCTAssertThrowsError(try l.validate())
        m.calories=nil; var other=m; other.id=UUID(); l.meals=[m,other]; XCTAssertThrowsError(try l.validate())
        l.meals=[]; l.games=[Game(day:m.day,name:" ",minutes:3)]; XCTAssertThrowsError(try l.validate())
    }
}
