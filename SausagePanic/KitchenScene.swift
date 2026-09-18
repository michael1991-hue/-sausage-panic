import SceneKit
import UIKit

final class KitchenScene {
    let scene = SCNScene()
    let camera = SCNNode()
    let sausage = SCNNode()
    private let body = SCNNode()
    private let course = SCNNode()
    private let dots = SCNNode()
    private let floor = SCNNode()
    private let stripes = SCNNode()
    private var aimDots: [SCNNode] = []
    private var panNodes: [Int: SCNNode] = [:]
    private var forkNodes: [Int: SCNNode] = [:]
    private var toppingNodes: [Int: SCNNode] = [:]
    private var cameraX = 1.8
    private var cameraY = 2.9
    private var reducedMotion = false
    private let panColour = UIColor(red: 0.13, green: 0.21, blue: 0.25, alpha: 1)
    static let colours: [UIColor] = [
        UIColor(red: 0.92, green: 0.29, blue: 0.16, alpha: 1),
        UIColor(red: 0.72, green: 0.32, blue: 0.15, alpha: 1),
        UIColor(red: 0.86, green: 0.58, blue: 0.23, alpha: 1),
        UIColor(red: 0.31, green: 0.60, blue: 0.30, alpha: 1)
    ]

    init() {
        scene.background.contents = UIColor(red: 0.09, green: 0.16, blue: 0.18, alpha: 1)
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 5.9
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 100
        camera.position = SCNVector3(1.8, 2.9, 18)
        scene.rootNode.addChildNode(camera)
        scene.rootNode.addChildNode(course)
        scene.rootNode.addChildNode(sausage)
        scene.rootNode.addChildNode(dots)
        for index in 0..<16 {
            let dot = sphere(0.045, colour: .white)
            dot.opacity = 1 - Double(index) / 20
            dot.isHidden = true
            dots.addChildNode(dot)
            aimDots.append(dot)
        }

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.70, green: 0.81, blue: 0.86, alpha: 1)
        ambient.light?.intensity = 550
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1400
        key.light?.color = UIColor(red: 1, green: 0.85, blue: 0.68, alpha: 1)
        key.light?.castsShadow = true
        key.light?.shadowRadius = 5
        key.eulerAngles = SCNVector3(-0.6, -0.45, -0.3)
        scene.rootNode.addChildNode(key)

        let backdrop = box(300, 50, 0.3, colour: UIColor(red: 0.15, green: 0.25, blue: 0.27, alpha: 1))
        backdrop.position = SCNVector3(120, 10, -3)
        scene.rootNode.addChildNode(backdrop)
        // Subtle tile seams add depth without raster textures.
        for index in -5...100 {
            let seam = box(0.025, 40, 0.02, colour: UIColor(white: 1, alpha: 0.08))
            seam.position = SCNVector3(Float(index) * 2.5, 10, -2.8)
            scene.rootNode.addChildNode(seam)
        }
        for index in -2...7 {
            let seam = box(300, 0.025, 0.02, colour: UIColor(white: 1, alpha: 0.08))
            seam.position = SCNVector3(120, Float(index) * 2.5, -2.8)
            scene.rootNode.addChildNode(seam)
        }
        floor.geometry = SCNBox(width: 35, height: 0.45, length: 5, chamferRadius: 0.1)
        floor.geometry?.firstMaterial = material(UIColor(red: 0.90, green: 0.32, blue: 0.13, alpha: 1))
        floor.position = SCNVector3(0, -3.7, 0)
        scene.rootNode.addChildNode(floor)
        for i in -10...10 {
            let bar = box(0.28, 0.1, 4, colour: panColour)
            bar.position = SCNVector3(Float(i) * 1.4, 0.28, 0)
            floor.addChildNode(bar)
        }
        buildSausage()
    }

    private func material(_ colour: UIColor, metal: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = colour
        m.lightingModel = .physicallyBased
        m.metalness.contents = metal
        m.roughness.contents = 0.3
        return m
    }

    private func box(_ width: CGFloat, _ height: CGFloat, _ depth: CGFloat,
                     colour: UIColor, radius: CGFloat = 0) -> SCNNode {
        let n = SCNNode(geometry: SCNBox(width: width, height: height, length: depth, chamferRadius: radius))
        n.geometry?.firstMaterial = material(colour)
        return n
    }

    private func sphere(_ radius: CGFloat, colour: UIColor) -> SCNNode {
        let shape = SCNSphere(radius: radius)
        shape.segmentCount = 32
        shape.firstMaterial = material(colour)
        return SCNNode(geometry: shape)
    }

    private func buildSausage() {
        let capsule = SCNCapsule(capRadius: 0.34, height: 1.55)
        capsule.radialSegmentCount = 48
        capsule.capSegmentCount = 20
        body.geometry = capsule
        body.geometry?.firstMaterial = material(Self.colours[0])
        body.eulerAngles.z = .pi / 2
        sausage.addChildNode(body)
        for x in [Float(-0.23), Float(0.23)] {
            let eye = sphere(0.14, colour: .white)
            eye.position = SCNVector3(x, 0.09, 0.31)
            sausage.addChildNode(eye)
            let pupil = sphere(0.065, colour: UIColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1))
            pupil.position = SCNVector3(x + 0.025, 0.095, 0.43)
            sausage.addChildNode(pupil)
            let glint = sphere(0.019, colour: .white)
            glint.position = SCNVector3(x + 0.015, 0.115, 0.49)
            sausage.addChildNode(glint)
        }
        let mouth = sphere(0.09, colour: UIColor(red: 0.3, green: 0.07, blue: 0.05, alpha: 1))
        mouth.scale = SCNVector3(1, 0.5, 0.4)
        mouth.position = SCNVector3(0, -0.15, 0.33)
        sausage.addChildNode(mouth)
        sausage.addChildNode(stripes)
    }

    func setCharacter(_ index: Int) {
        body.geometry?.firstMaterial?.diffuse.contents = Self.colours[index]
    }

    func reset(_ core: GameCore) {
        course.childNodes.forEach { $0.removeFromParentNode() }
        panNodes.removeAll(); forkNodes.removeAll(); toppingNodes.removeAll()
        stripes.childNodes.forEach { $0.removeFromParentNode() }
        cameraX = 1.8; cameraY = 2.9
        update(core, drag: nil, dt: 1)
    }

    func addMustard() {
        guard stripes.childNodes.count < 7 else { return }
        let stripe = box(0.065, 0.4, 0.07, colour: .systemYellow, radius: 0.025)
        stripe.position = SCNVector3(-0.6 + Float(stripes.childNodes.count) * 0.19, 0, 0.34)
        stripe.eulerAngles.z = 0.3
        stripes.addChildNode(stripe)
    }

    func setReducedMotion(_ value: Bool) { reducedMotion = value }

    func update(_ core: GameCore, drag: Vector?, dt: Double) {
        let panIDs = Set(core.pans.map(\.id))
        for id in Array(panNodes.keys) where !panIDs.contains(id) {
            panNodes.removeValue(forKey: id)?.removeFromParentNode()
        }
        for pan in core.pans {
            if panNodes[pan.id] == nil {
                let n = box(CGFloat(pan.width), 0.28, 1.6, colour: panColour, radius: 0.12)
                let lip = box(CGFloat(pan.width - 0.1), 0.04, 1.45,
                              colour: UIColor(red: 0.29, green: 0.36, blue: 0.39, alpha: 1), radius: 0.02)
                lip.position.y = 0.16
                n.addChildNode(lip)
                let handle = box(0.85, 0.14, 0.26, colour: .darkGray, radius: 0.06)
                handle.position.x = Float(pan.width / 2 + 0.32)
                n.addChildNode(handle)
                course.addChildNode(n)
                panNodes[pan.id] = n
            }
            panNodes[pan.id]?.position = SCNVector3(Float(pan.x(at: core.time)), Float(pan.y - 0.17), 0)
        }
        for id in Array(forkNodes.keys) where core.forks[id] == nil {
            forkNodes.removeValue(forKey: id)?.removeFromParentNode()
        }
        for (id, fork) in core.forks {
            if forkNodes[id] == nil {
                let node = SCNNode()
                let silver = UIColor(red: 0.72, green: 0.82, blue: 0.86, alpha: 1)
                let shaft = box(0.14, 1.2, 0.12, colour: silver, radius: 0.04)
                shaft.position.y = 0.7
                node.addChildNode(shaft)
                let base = box(0.58, 0.15, 0.14, colour: silver)
                node.addChildNode(base)
                for i in 0...3 {
                    let prong = box(0.075, 0.48, 0.10, colour: silver, radius: 0.035)
                    prong.position = SCNVector3(-0.225 + Float(i) * 0.15, -0.25, 0)
                    node.addChildNode(prong)
                }
                course.addChildNode(node); forkNodes[id] = node
            }
            forkNodes[id]?.position = SCNVector3(Float(fork.x), Float(fork.y(at: core.time)), 0)
        }
        let visibleToppings = core.toppings.subtracting(core.collected)
        for id in Array(toppingNodes.keys) where !visibleToppings.contains(id) {
            toppingNodes.removeValue(forKey: id)?.removeFromParentNode()
        }
        for pan in core.pans where visibleToppings.contains(pan.id) {
            if toppingNodes[pan.id] == nil {
                let torus = SCNTorus(ringRadius: 0.22, pipeRadius: 0.07)
                torus.firstMaterial = material(.systemYellow, metal: 0.5)
                let n = SCNNode(geometry: torus)
                n.eulerAngles.x = .pi / 2
                course.addChildNode(n); toppingNodes[pan.id] = n
            }
            toppingNodes[pan.id]?.position = SCNVector3(Float(pan.x(at: core.time)), Float(pan.y + 1.65), 0)
            toppingNodes[pan.id]?.eulerAngles.y = reducedMotion ? 0 : Float(core.time * 2)
        }
        sausage.position = SCNVector3(Float(core.position.x), Float(core.position.y), 0)
        let aiming = drag != nil
        let squash: Float = aiming ? 0.8 : 1
        sausage.scale = SCNVector3(aiming ? 1.13 : 1, squash, 1)
        sausage.eulerAngles.z = reducedMotion ? 0 : (core.grounded != nil ? Float(sin(core.time * 3) * 0.04) : Float(core.velocity.y * 0.035))
        let ease = reducedMotion ? 1 : min(1, dt * 7)
        cameraX += (core.position.x + 1.8 - cameraX) * ease
        cameraY += (max(2.9, core.position.y + 0.7) - cameraY) * ease
        camera.position = SCNVector3(Float(cameraX), Float(cameraY), 18)
        floor.position.x = Float(cameraX)
        aimDots.forEach { $0.isHidden = true }
        if let drag = drag, core.grounded != nil {
            for (index, point) in core.trajectory(drag: drag).enumerated() {
                let dot = aimDots[index]
                dot.isHidden = false
                dot.position = SCNVector3(Float(point.x), Float(point.y), 0.6)
            }
        }
    }
}
