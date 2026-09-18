import SwiftUI
import SceneKit
import AVFoundation

private final class FrameTarget: NSObject {
    weak var owner: GameStore?
    @objc func frame(_ link: CADisplayLink) { owner?.frame(link) }
}

final class GameStore: ObservableObject {
    @Published private(set) var state: RunState = .ready
    @Published private(set) var score = 0
    @Published private(set) var coins = 0
    @Published private(set) var seconds = 35
    @Published private(set) var best = 0
    @Published private(set) var bank = 0
    @Published private(set) var combo = 0
    @Published private(set) var reason = ""
    @Published private(set) var toast = ""
    @Published private(set) var daily = false
    @Published private(set) var selected = 0
    @Published var paused = false
    @Published var sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
    @Published var haptics = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    let kitchen = KitchenScene()
    private var core = GameCore(seed: 1)
    private var drag: Vector?
    private var link: CADisplayLink?
    private let frameTarget = FrameTarget()
    private var previousTimestamp = 0.0
    private var accumulator = 0.0
    private var toastUntil = 0.0
    private var runBestKey = "best"
    private var audio: [String: AVAudioPlayer] = [:]
    private let impact = UIImpactFeedbackGenerator(style: .light)
    static let names = ["Frank", "Big Brat", "Sir Chip", "Veggie"]
    static let unlocks = [0, 15, 40, 80]

    init() {
        best = UserDefaults.standard.integer(forKey: "best")
        bank = UserDefaults.standard.integer(forKey: "bank")
        selected = min(3, max(0, UserDefaults.standard.integer(forKey: "character")))
        if bank < Self.unlocks[selected] { selected = 0 }
        kitchen.setCharacter(selected)
        kitchen.reset(core)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        for name in ["boing", "ding", "sizzle"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.35
                player.prepareToPlay()
                audio[name] = player
            }
        }
        frameTarget.owner = self
    }

    func attach() {
        guard link == nil else { return }
        let newLink = CADisplayLink(target: frameTarget, selector: #selector(FrameTarget.frame(_:)))
        newLink.preferredFramesPerSecond = 60
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    func detach() { link?.invalidate(); link = nil; previousTimestamp = 0 }
    deinit { link?.invalidate() }

    func start(daily: Bool) {
        self.daily = daily
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = formatter.string(from: Date())
        let seed = daily ? (UInt64(date) ?? 1) : UInt64.random(in: 1...UInt64.max)
        runBestKey = daily ? "daily-\(date)" : "best"
        best = UserDefaults.standard.integer(forKey: runBestKey)
        core = GameCore(seed: seed)
        core.start()
        state = .playing; score = 0; coins = 0; combo = 0; seconds = 35
        toast = ""; reason = ""; drag = nil; paused = false
        previousTimestamp = 0; accumulator = 0
        kitchen.reset(core)
        impact.prepare()
    }

    func home() {
        state = .ready; paused = false; drag = nil
        core = GameCore(seed: 1)
        kitchen.reset(core)
        best = UserDefaults.standard.integer(forKey: "best")
    }

    func select(_ index: Int) {
        guard Self.names.indices.contains(index), bank >= Self.unlocks[index] else { return }
        selected = index
        kitchen.setCharacter(index)
        UserDefaults.standard.set(index, forKey: "character")
    }

    func aim(_ translation: CGSize) {
        guard state == .playing, !paused, core.grounded != nil else { return }
        drag = Vector(x: Double(translation.width), y: Double(translation.height))
    }

    func release() {
        guard let drag = drag, state == .playing, !paused else { self.drag = nil; return }
        core.launch(drag: drag)
        self.drag = nil
        play("boing")
        if haptics { impact.impactOccurred(intensity: 0.5) }
    }

    func pause() { paused = true; drag = nil; previousTimestamp = 0; accumulator = 0 }
    func resume() { previousTimestamp = 0; paused = false }
    func setReducedMotion(_ value: Bool) { kitchen.setReducedMotion(value) }
    func saveSettings() {
        UserDefaults.standard.set(sound, forKey: "sound")
        UserDefaults.standard.set(haptics, forKey: "haptics")
    }

    fileprivate func frame(_ link: CADisplayLink) {
        let dt = previousTimestamp == 0 ? 0 : min(0.1, link.timestamp - previousTimestamp)
        previousTimestamp = link.timestamp
        guard state == .playing, !paused else { return }
        accumulator += dt
        while accumulator >= 1.0 / 120 {
            let events = core.step(1.0 / 120)
            accumulator -= 1.0 / 120
            for event in events {
                switch event {
                case .landing(let perfect):
                    toast = perfect ? "PERFECT! +\(5 * min(core.combo, 5) + 10)" : "NICE LANDING +10"
                    toastUntil = core.time + 1.1
                    play("ding")
                    if haptics { impact.impactOccurred(intensity: perfect ? 1 : 0.5) }
                case .topping:
                    kitchen.addMustard()
                    toast = "EXTRA MUSTARD! +3 coins"
                    toastUntil = core.time + 1.1
                    play("ding")
                case .finished:
                    finish()
                }
            }
            if state == .finished { accumulator = 0; break }
        }
        if score != core.score { score = core.score }
        if coins != core.coins { coins = core.coins }
        if combo != core.combo { combo = core.combo }
        let remaining = Int(ceil(core.remaining))
        if seconds != remaining { seconds = remaining }
        if !toast.isEmpty, core.time > toastUntil { toast = "" }
        kitchen.update(core, drag: drag, dt: dt)
    }

    private func finish() {
        state = .finished; reason = core.reason; drag = nil
        bank += core.coins
        best = max(best, core.score)
        UserDefaults.standard.set(bank, forKey: "bank")
        UserDefaults.standard.set(best, forKey: runBestKey)
        play("sizzle")
        if haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }

    private func play(_ name: String) {
        guard sound, let player = audio[name] else { return }
        player.currentTime = 0; player.play()
    }
}
