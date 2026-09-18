import Foundation

struct Vector: Equatable {
    var x: Double
    var y: Double
    static let zero = Vector(x: 0, y: 0)
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9007199254740992
    }
}

struct Pan {
    let id: Int
    let baseX: Double
    let y: Double
    let width: Double
    let movement: Double
    func x(at time: Double) -> Double { baseX + sin(time * 1.4 + Double(id)) * movement }
}

struct Fork {
    let x: Double
    let baseY: Double
    let phase: Double
    func y(at time: Double) -> Double { baseY + sin(time * 2 + phase) * 0.7 }
}

enum RunState: Equatable { case ready, playing, finished }
enum GameEvent: Equatable { case landing(perfect: Bool), topping, finished }

/// Renderer-independent fixed-step simulation. World units are metres, Y points up.
struct GameCore {
    private(set) var state: RunState = .ready
    private(set) var position = Vector(x: 0, y: 0.52)
    private(set) var velocity = Vector.zero
    private(set) var pans: [Pan] = []
    private(set) var forks: [Int: Fork] = [:]
    private(set) var toppings: Set<Int> = []
    private(set) var collected: Set<Int> = []
    private(set) var time = 0.0
    private(set) var remaining = 35.0
    private(set) var score = 0
    private(set) var coins = 0
    private(set) var combo = 0
    private(set) var grounded: Int? = 0
    private(set) var furthest = 0
    private(set) var reason = ""
    private var random: SeededRandom
    static let gravity = 13.5
    static let feet = 0.52

    init(seed: UInt64) {
        random = SeededRandom(seed: seed)
        pans = [Pan(id: 0, baseX: 0, y: 0, width: 2.6, movement: 0)]
        extendCourse()
    }

    mutating func start() { state = .playing }

    static func launchVelocity(drag: Vector) -> Vector {
        Vector(x: min(8.2, max(2.0, 4.7 - drag.x / 32)),
               y: min(10.0, max(5.0, 7.2 + drag.y / 40)))
    }

    mutating func launch(drag: Vector) {
        guard state == .playing, grounded != nil else { return }
        velocity = Self.launchVelocity(drag: drag)
        grounded = nil
    }

    func trajectory(drag: Vector) -> [Vector] {
        let v = Self.launchVelocity(drag: drag)
        return (1...16).map {
            let t = Double($0) * 0.065
            return Vector(x: position.x + v.x * t,
                          y: position.y + v.y * t - Self.gravity * t * t / 2)
        }
    }

    mutating func step(_ dt: Double) -> [GameEvent] {
        guard state == .playing, dt > 0 else { return [] }
        let previousTime = time
        time += dt
        remaining = max(0, remaining - dt)
        if remaining == 0 { return finish("Time’s up. Breakfast wins!") }
        if let id = grounded, let pan = pans.first(where: { $0.id == id }) {
            position.x += pan.x(at: time) - pan.x(at: previousTime)
            return []
        }
        let old = position
        position.x += velocity.x * dt
        position.y += velocity.y * dt - Self.gravity * dt * dt / 2
        velocity.y -= Self.gravity * dt
        var events: [GameEvent] = []

        // A swept plane crossing prevents fast falls from passing through a pan.
        if velocity.y <= 0 {
            for pan in pans {
                let surface = pan.y + Self.feet
                if old.y >= surface, position.y <= surface, old.y > position.y {
                    let fraction = (old.y - surface) / (old.y - position.y)
                    let crossX = old.x + (position.x - old.x) * fraction
                    let panX = pan.x(at: previousTime + dt * fraction)
                    if abs(crossX - panX) < pan.width / 2 + 0.2 {
                        position.y = surface
                        velocity = .zero
                        grounded = pan.id
                        if pan.id > furthest {
                            let perfect = abs(crossX - panX) < 0.36
                            combo = perfect ? combo + 1 : 0
                            score += 10 + (perfect ? 5 * min(combo, 5) : 0)
                            coins += 1
                            remaining = min(35, remaining + 1.5)
                            furthest = pan.id
                            events.append(.landing(perfect: perfect))
                            extendCourse()
                        }
                        break
                    }
                }
            }
        }
        for (id, fork) in forks where id > furthest - 2 {
            if abs(position.x - fork.x) < 0.65,
               abs(position.y - fork.y(at: time)) < 0.85 {
                return finish("Forked it!")
            }
        }
        for pan in pans where toppings.contains(pan.id) && !collected.contains(pan.id) {
            if abs(position.x - pan.x(at: time)) < 0.8,
               abs(position.y - (pan.y + 1.65)) < 0.85 {
                collected.insert(pan.id)
                coins += 3
                score += 5
                events.append(.topping)
            }
        }
        if position.y < -4 { return finish("Well done. A little too well done.") }
        return events
    }

    private mutating func finish(_ message: String) -> [GameEvent] {
        state = .finished
        reason = message
        return [.finished]
    }

    private mutating func extendCourse() {
        while pans.last!.id < furthest + 9 {
            let last = pans.last!
            let id = last.id + 1
            let gap = 3.5 + random.next() * 0.6
            let y = min(1.2, max(-0.5, last.y + (random.next() - 0.5) * 0.65))
            pans.append(Pan(id: id, baseX: last.baseX + gap, y: y,
                            width: id < 4 ? 2.5 : 2.15,
                            movement: id > 3 && id % 3 == 0 ? 0.3 : 0))
            if id % 2 == 0 { toppings.insert(id) }
            if id > 4 && id % 4 == 1 {
                forks[id] = Fork(x: last.baseX + gap * 0.5, baseY: y + 2.9,
                                 phase: random.next() * .pi * 2)
            }
        }
        pans.removeAll { $0.id < furthest - 3 }
        forks = forks.filter { $0.key >= furthest - 3 }
        toppings = Set(toppings.filter { $0 >= furthest - 3 })
        collected = Set(collected.filter { $0 >= furthest - 3 })
    }
}
