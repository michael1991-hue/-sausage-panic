import SwiftUI
import SceneKit

private struct KitchenView: UIViewRepresentable {
    let kitchen: KitchenScene
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = kitchen.scene
        view.pointOfView = kitchen.camera
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) { }
}

struct GameScreen: View {
    @StateObject private var game = GameStore()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    private let cream = Color(red: 1, green: 0.96, blue: 0.85)
    private let orange = Color(red: 1, green: 0.40, blue: 0.23)

    var body: some View {
        ZStack {
            KitchenView(kitchen: game.kitchen).ignoresSafeArea()
                .accessibilityHidden(true)
            LinearGradient(colors: [.black.opacity(0.4), .clear, .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
            if game.state == .playing {
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { game.aim($0.translation) }
                        .onEnded { _ in game.release() })
                    .accessibilityLabel("Jump control. Pull down and left, then release to jump.")
                playHUD
            }
            if game.state == .ready { home }
            if game.state == .finished { results }
            if game.paused && game.state == .playing { pauseMenu }
        }
        .foregroundStyle(cream)
        .preferredColorScheme(.dark)
        .onAppear { game.attach(); game.setReducedMotion(reducedMotion) }
        .onDisappear { game.detach() }
        .onChange(of: phase) { value in
            if value != .active && game.state == .playing { game.pause() }
        }
        .onChange(of: reducedMotion) { game.setReducedMotion($0) }
        .onChange(of: game.sound) { _ in game.saveSettings() }
        .onChange(of: game.haptics) { _ in game.saveSettings() }
    }

    private var home: some View {
        VStack(spacing: 12) {
            HStack {
                Text("FRESH OUT OF THE PAN").font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                Spacer()
                Label("\(game.bank)", systemImage: "circle.fill").font(.caption.bold()).foregroundStyle(.yellow)
            }.padding(.top, 12)
            VStack(spacing: -5) {
                Text("SAUSAGE").font(.system(size: 49, weight: .black, design: .rounded))
                Text("PANIC!").font(.system(size: 68, weight: .black, design: .rounded)).foregroundStyle(orange)
            }.rotationEffect(.degrees(-4)).padding(.top, 20)
            Text("Tiny sausage. Massive problems.").font(.subheadline.weight(.semibold))
            Spacer(minLength: 100)
            HStack(spacing: 8) {
                ForEach(0..<GameStore.names.count, id: \.self) { index in
                    Button { game.select(index) } label: {
                        VStack(spacing: 6) {
                            Capsule().fill(Color(uiColor: KitchenScene.colours[index]))
                                .frame(width: 34, height: 15).rotationEffect(.degrees(-20))
                            Text(GameStore.names[index]).font(.system(size: 11, weight: .bold))
                            if game.bank < GameStore.unlocks[index] {
                                Label("\(GameStore.unlocks[index])", systemImage: "lock.fill").font(.system(size: 10))
                            } else { Text(index == game.selected ? "PICKED" : "SELECT").font(.system(size: 9, weight: .bold)) }
                        }.frame(maxWidth: .infinity).frame(height: 75)
                            .background(game.selected == index ? orange.opacity(0.3) : .black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(game.selected == index ? orange : .clear, lineWidth: 2))
                    }.buttonStyle(.plain).disabled(game.bank < GameStore.unlocks[index])
                }
            }
            action("LET’S GET COOKING", icon: "play.fill") { game.start(daily: false) }
            Button { game.start(daily: true) } label: {
                HStack { Image(systemName: "calendar"); Text("Daily kitchen"); Spacer(); Text("SAME COURSE ALL DAY").font(.system(size: 9, weight: .black)) }
                    .font(.subheadline.bold()).padding(17)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain)
            Text("Pull back. Release. Try not to be breakfast.")
                .font(.caption).opacity(0.75).padding(.bottom, 8)
        }.padding(.horizontal, 24)
    }

    private var playHUD: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(game.daily ? "DAILY KITCHEN" : "BREAKFAST ESCAPE").font(.system(size: 10, weight: .black)).tracking(1.5)
                    Text("\(game.score)").font(.system(size: 54, weight: .black, design: .rounded)).monospacedDigit()
                    Text("BEST \(game.best)").font(.caption.bold()).opacity(0.65)
                }
                Spacer()
                Button { game.pause() } label: {
                    Image(systemName: "pause.fill").frame(width: 48, height: 48)
                        .background(.black.opacity(0.3), in: Circle())
                }.accessibilityLabel("Pause game")
            }
            HStack {
                Label("\(game.seconds)s", systemImage: "flame.fill").foregroundStyle(game.seconds < 10 ? orange : cream)
                Spacer()
                if game.combo > 1 { Text("\(game.combo)× PERFECT").foregroundStyle(.yellow) }
                Label("\(game.coins)", systemImage: "circle.fill").foregroundStyle(.yellow)
            }.font(.caption.bold())
            GeometryReader { geometry in
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(game.seconds < 10 ? orange : Color.yellow)
                    .frame(width: geometry.size.width * CGFloat(game.seconds) / 35)
            }.frame(height: 5)
            Text(game.toast).font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.yellow).padding(.top, 12).frame(height: 42)
            Spacer()
            VStack(spacing: 5) {
                Image(systemName: "hand.draw.fill").font(.title2)
                Text("PULL DOWN & LEFT · RELEASE TO FLING").font(.system(size: 10, weight: .black)).tracking(1)
                Text("Land on pans · Collect mustard · Avoid forks").font(.caption2).opacity(0.75)
            }.padding(16).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
                .allowsHitTesting(false)
        }.padding(24)
    }

    private var results: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("YOU’RE TOAST.").font(.system(size: 37, weight: .black, design: .rounded)).foregroundStyle(orange)
                Text(game.reason).font(.subheadline).multilineTextAlignment(.center)
                Text("\(game.score)").font(.system(size: 88, weight: .black, design: .rounded))
                HStack(spacing: 24) {
                    Label("BEST \(game.best)", systemImage: "trophy.fill")
                    Label("+\(game.coins) COINS", systemImage: "circle.fill")
                }.font(.caption.bold()).foregroundStyle(.yellow)
                action("ANOTHER GO", icon: "arrow.clockwise") { game.start(daily: game.daily) }
                ShareLink(item: "I scored \(game.score) in Sausage Panic\(game.daily ? "’s daily kitchen" : "")! Tiny sausage. Massive problems. 🌭") {
                    Label("Share score", systemImage: "square.and.arrow.up").font(.subheadline.bold()).padding(12)
                }
                Button("Back to the kitchen") { game.home() }.font(.subheadline)
            }.padding(28)
        }
    }

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("OFF THE HEAT").font(.system(size: 34, weight: .black, design: .rounded))
                Toggle("Sound effects", isOn: $game.sound)
                Toggle("Haptics", isOn: $game.haptics)
                action("KEEP COOKING", icon: "play.fill") { game.resume() }
                Button("End run & return home") { game.home() }.font(.subheadline)
                Text("Coins are banked when a run finishes.").font(.caption).opacity(0.6)
            }.tint(orange).padding(32)
        }
    }

    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack { Text(title); Spacer(); Image(systemName: icon) }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .padding(21).background(orange, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)
        }.buttonStyle(.plain)
    }
}
