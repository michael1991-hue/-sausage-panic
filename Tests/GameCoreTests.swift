import XCTest
@testable import SausagePanicCore

final class GameCoreTests: XCTestCase {
    func testDailyCourseIsDeterministic() {
        let a = GameCore(seed: 20260918)
        let b = GameCore(seed: 20260918)
        XCTAssertEqual(a.pans.map(\.baseX), b.pans.map(\.baseX))
        XCTAssertEqual(a.pans.map(\.y), b.pans.map(\.y))
        XCTAssertNotEqual(a.pans.map(\.baseX), GameCore(seed: 20260919).pans.map(\.baseX))
    }

    func testCannotJumpBeforeStartingOrJumpAgainInFlight() {
        var game = GameCore(seed: 42)
        game.launch(drag: .zero)
        XCTAssertEqual(game.velocity, .zero)
        game.start()
        game.launch(drag: .zero)
        let first = game.velocity
        game.launch(drag: Vector(x: -100, y: 100))
        XCTAssertEqual(game.velocity, first)
    }

    func testVelocityIsBounded() {
        XCTAssertEqual(GameCore.launchVelocity(drag: Vector(x: -1e9, y: 1e9)), Vector(x: 8.2, y: 10))
        XCTAssertEqual(GameCore.launchVelocity(drag: Vector(x: 1e9, y: -1e9)), Vector(x: 2, y: 5))
    }

    func testFirstPanIsReachableAcrossSeeds() {
        for seed in 1...100 {
            var game = GameCore(seed: UInt64(seed))
            let pan = game.pans[1]
            // Pick a velocity whose ballistic arc reaches the pan centre on descent.
            let vy = 7.2
            let flight = (vy + sqrt(vy * vy - 2 * GameCore.gravity * pan.y)) / GameCore.gravity
            let vx = pan.baseX / flight
            let drag = Vector(x: (4.7 - vx) * 32, y: 0)
            game.start(); game.launch(drag: drag)
            for _ in 0..<240 {
                _ = game.step(1.0 / 120)
                if game.grounded != nil { break }
            }
            XCTAssertEqual(game.grounded, 1, "seed \(seed)")
            XCTAssertEqual(game.score, 15, "seed \(seed)")
            XCTAssertEqual(game.coins, 1)
            let score = game.score
            for _ in 0..<60 { _ = game.step(1.0 / 120) }
            XCTAssertEqual(game.score, score, "A resting sausage must not score repeatedly")
        }
    }

    func testFailureFiresOnceAndFreezesState() {
        var game = GameCore(seed: 1)
        game.start()
        var endings = 0
        for _ in 0..<4300 {
            endings += game.step(1.0 / 120).filter { $0 == .finished }.count
        }
        XCTAssertEqual(game.state, .finished)
        XCTAssertEqual(endings, 1)
        let time = game.time
        XCTAssertTrue(game.step(1).isEmpty)
        XCTAssertEqual(game.time, time)
    }

    func testFirstJumpIsFrameRateIndependent() {
        var fast = GameCore(seed: 42)
        var slow = GameCore(seed: 42)
        fast.start(); slow.start()
        fast.launch(drag: .zero); slow.launch(drag: .zero)
        for _ in 0..<60 { _ = fast.step(1.0 / 120) }
        for _ in 0..<15 { _ = slow.step(1.0 / 30) }
        XCTAssertEqual(fast.position.x, slow.position.x, accuracy: 0.00001)
        XCTAssertEqual(fast.position.y, slow.position.y, accuracy: 0.00001)
    }
}
