import Cocoa
import CoreAudio
import IOKit.pwr_mgt
import QuartzCore
import ServiceManagement
import UniformTypeIdentifiers

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class PillButton: NSButton {
    private var hovering = false { didSet { refreshBackground() } }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.target = target
        self.action = action
        self.title = title
        configure()
    }
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); configure() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        focusRingType = .none
        layer?.cornerRadius = 12
        refreshTitle()
        refreshBackground()
    }

    override var title: String { didSet { refreshTitle() } }

    private func refreshTitle() {
        let p = NSMutableParagraphStyle(); p.alignment = .center
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .paragraphStyle: p,
        ])
    }

    private func refreshBackground() {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(hovering ? 0.20 : 0.10).cgColor
    }

    override var intrinsicContentSize: NSSize {
        var s = super.intrinsicContentSize
        s.width += 48
        s.height = 42
        return s
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; NSCursor.pointingHand.set() }
    override func mouseExited(with event: NSEvent) { hovering = false; NSCursor.arrow.set() }
}

final class RingProgressView: NSView {
    private let track = CAShapeLayer()
    private let bar = CAShapeLayer()
    private let lineWidth: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(bar)
        for l in [track, bar] {
            l.fillColor = NSColor.clear.cgColor
            l.lineCap = .round
            l.lineWidth = lineWidth
        }
        track.strokeColor = NSColor.white.withAlphaComponent(0.14).cgColor
        bar.strokeColor = NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.55, alpha: 1).cgColor
        bar.strokeEnd = 1
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let inset = lineWidth / 2 + 1
        let path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
        track.frame = bounds; bar.frame = bounds
        track.path = path; bar.path = path
        bar.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
    }

    func setFraction(_ f: CGFloat, animated: Bool) {
        let clamped = max(0, min(1, f))
        let current = bar.presentation()?.strokeEnd ?? bar.strokeEnd
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.strokeEnd = clamped
        CATransaction.commit()
        guard animated else { return }
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = current
        anim.toValue = clamped
        anim.duration = 1.0
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        bar.add(anim, forKey: "strokeEnd")
    }
}

private enum MenuIcon {
    private static let heart = """
    M51 91.7703C27.0725 68.2295 4.25 48.008 4.25 30.5617C4.25 14.45 17.289 8.5 26.6943 8.5C32.2703 \
    8.5 44.336 10.6292 51 27.4422C57.7575 10.5782 69.972 8.5425 75.3355 8.5425C86.1305 8.5425 97.75 \
    15.4318 97.75 30.5617C97.75 47.855 75.922 67.218 51 91.7703ZM75.3355 4.2925C65.9727 4.2925 56.44 \
    8.721 51 18.054C45.5388 8.6785 36.0315 4.25 26.6943 4.25C13.1665 4.25 0 13.5447 0 30.5617C0 \
    50.371 23.6768 70.635 51 97.75C78.3275 70.635 102 50.371 102 30.5617C102 13.515 88.8462 4.2925 \
    75.3355 4.2925Z
    """

    private static let eyeTop: CGFloat = 41.18
    private static let eyeHalfWidth: CGFloat = 9.18
    private static let eyeCentres: [CGFloat] = [30.2401, 71.2401]

    private static let lashes: [(tip: CGPoint, root: CGPoint)] = [
        (CGPoint(x: -9.1800, y: 6.1200), CGPoint(x: -6.6300, y: 2.244)),
        (CGPoint(x:  9.1799, y: 6.0955), CGPoint(x:  6.6381, y: 2.244)),
        (CGPoint(x: -3.0600, y: 8.1600), CGPoint(x: -2.5500, y: 4.080)),
        (CGPoint(x:  3.0599, y: 8.1600), CGPoint(x:  2.5499, y: 4.080)),
    ]

    private static let viewBox: CGFloat = 102

    private static let heartStroke: CGFloat = 3.25
    private static let eyeStroke: CGFloat = 4

    static let frames: [NSImage] = (0...8).map { render(size: 17, squint: CGFloat($0) / 8) }
    static var statusItem: NSImage { frames[0] }

    private static let heartFillPath: CGPath = {
        let contours = heart.split(separator: "Z")
        let outer = contours.count > 1 ? String(contours[1]) : String(contours[0])
        return SVGPath.cgPath(outer + "Z")
    }()

    static func solidHeart(size: CGFloat) -> CGPath {
        let s = size / viewBox
        var flip = CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: 0, ty: size)
        return heartFillPath.copy(using: &flip) ?? heartFillPath
    }

    private static func eyePath(centre cx: CGFloat, squint: CGFloat) -> CGPath {
        let deepen = 1 + 0.85 * squint
        let reach = 1 + 0.30 * squint
        func y(_ offset: CGFloat) -> CGFloat { eyeTop + offset * deepen }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx + eyeHalfWidth, y: eyeTop))
        path.addCurve(to: CGPoint(x: cx, y: y(4.08)),
                      control1: CGPoint(x: cx + 6.732, y: y(2.7203)),
                      control2: CGPoint(x: cx + 3.672, y: y(4.08)))
        path.addCurve(to: CGPoint(x: cx - eyeHalfWidth, y: eyeTop),
                      control1: CGPoint(x: cx - 3.672, y: y(4.08)),
                      control2: CGPoint(x: cx - 6.732, y: y(2.7203)))

        for lash in lashes {
            let root = CGPoint(x: cx + lash.root.x, y: y(lash.root.y))
            let tip = CGPoint(x: root.x + (lash.tip.x - lash.root.x) * reach,
                              y: root.y + (lash.tip.y - lash.root.y) * deepen * reach)
            path.move(to: root)
            path.addLine(to: tip)
        }
        return path
    }

    private static func render(size: CGFloat, squint: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let scale = size / (viewBox + heartStroke)
            ctx.translateBy(x: 0, y: size)
            ctx.scaleBy(x: scale, y: -scale)
            ctx.translateBy(x: heartStroke / 2, y: heartStroke / 2)

            let centre = viewBox / 2
            ctx.translateBy(x: centre, y: centre)
            ctx.scaleBy(x: 1 + 0.04 * squint, y: 1 - 0.11 * squint)
            ctx.translateBy(x: -centre, y: -centre)

            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            ctx.addPath(SVGPath.cgPath(heart))
            ctx.setLineWidth(heartStroke)
            ctx.drawPath(using: .eoFillStroke)

            ctx.setLineWidth(eyeStroke)
            for cx in eyeCentres { ctx.addPath(eyePath(centre: cx, squint: squint)) }
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

private enum SVGPath {
    static func cgPath(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var numbers: [CGFloat] = []
        var digits = ""
        var command: Character = " "
        var start = CGPoint.zero

        func takeNumber() {
            if let value = Double(digits) { numbers.append(CGFloat(value)) }
            digits = ""
        }
        func point(_ i: Int) -> CGPoint { CGPoint(x: numbers[i], y: numbers[i + 1]) }
        func runCommand() {
            takeNumber()
            defer { numbers.removeAll() }
            switch command {
            case "M":
                guard numbers.count >= 2 else { return }
                start = point(0)
                path.move(to: start)
                for i in stride(from: 2, to: numbers.count - 1, by: 2) { path.addLine(to: point(i)) }
            case "L":
                for i in stride(from: 0, to: numbers.count - 1, by: 2) { path.addLine(to: point(i)) }
            case "C":
                for i in stride(from: 0, to: numbers.count - 5, by: 6) {
                    path.addCurve(to: point(i + 4), control1: point(i), control2: point(i + 2))
                }
            case "Z", "z":
                path.closeSubpath()
            default:
                return
            }
        }

        for ch in d {
            if ch.isNumber || ch == "." {
                digits.append(ch)
            } else if ch == "-" {
                takeNumber()
                digits.append(ch)
            } else if ch.isLetter {
                runCommand()
                command = ch
            } else {
                takeNumber()
            }
        }
        runCommand()
        return path
    }
}

private enum BlinkShape {
    static func sparkle(size: CGFloat) -> CGPath {
        let c = size / 2
        let k = c * 0.24
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c, y: 0))
        p.addQuadCurve(to: CGPoint(x: size, y: c), control: CGPoint(x: c + k, y: c - k))
        p.addQuadCurve(to: CGPoint(x: c, y: size), control: CGPoint(x: c + k, y: c + k))
        p.addQuadCurve(to: CGPoint(x: 0, y: c), control: CGPoint(x: c - k, y: c + k))
        p.addQuadCurve(to: CGPoint(x: c, y: 0), control: CGPoint(x: c - k, y: c - k))
        p.closeSubpath()
        return p
    }

    static func dewdrop(size: CGFloat) -> CGPath {
        let c = size / 2
        let r = size * 0.39
        let bulb = CGPoint(x: c, y: r)
        let tip = CGPoint(x: c, y: size)
        let p = CGMutablePath()
        p.move(to: tip)
        p.addCurve(to: CGPoint(x: c - r, y: bulb.y),
                   control1: CGPoint(x: c - r * 0.30, y: size * 0.72),
                   control2: CGPoint(x: c - r, y: bulb.y + r * 0.72))
        p.addArc(center: bulb, radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: tip,
                   control1: CGPoint(x: c + r, y: bulb.y + r * 0.72),
                   control2: CGPoint(x: c + r * 0.30, y: size * 0.72))
        p.closeSubpath()
        return p
    }
}

enum BlinkStyle: String, CaseIterable {
    case hearts, sparkles, dew, subtle

    var label: String {
        switch self {
        case .hearts:   return "Hearts"
        case .sparkles: return "Sparkles"
        case .dew:      return "Dewdrops"
        case .subtle:   return "Just the blink"
        }
    }

    var count: Int {
        switch self {
        case .hearts:   return 5
        case .sparkles: return 7
        case .dew:      return 4
        case .subtle:   return 0
        }
    }

    var tints: [NSColor] {
        switch self {
        case .hearts:
            return [NSColor(srgbRed: 1.00, green: 0.30, blue: 0.55, alpha: 1.00),
                    NSColor(srgbRed: 1.00, green: 0.50, blue: 0.66, alpha: 1.00),
                    NSColor(srgbRed: 1.00, green: 0.70, blue: 0.79, alpha: 1.00)]
        case .sparkles:
            return [NSColor(srgbRed: 1.00, green: 0.83, blue: 0.43, alpha: 1.00),
                    NSColor(srgbRed: 1.00, green: 0.94, blue: 0.76, alpha: 1.00),
                    NSColor(srgbRed: 1.00, green: 0.99, blue: 0.94, alpha: 1.00)]
        case .dew:
            return [NSColor(srgbRed: 0.75, green: 0.88, blue: 1.00, alpha: 0.85),
                    NSColor(srgbRed: 0.86, green: 0.94, blue: 1.00, alpha: 0.80),
                    NSColor(srgbRed: 0.96, green: 0.99, blue: 1.00, alpha: 0.75)]
        case .subtle:
            return []
        }
    }

    func path(size: CGFloat) -> CGPath {
        switch self {
        case .hearts:   return MenuIcon.solidHeart(size: size)
        case .sparkles: return BlinkShape.sparkle(size: size)
        case .dew:      return BlinkShape.dewdrop(size: size)
        case .subtle:   return CGMutablePath()
        }
    }
}

enum BlinkScope: String, CaseIterable {
    case menuBar, wholeScreen

    var label: String {
        switch self {
        case .menuBar:     return "Menu bar"
        case .wholeScreen: return "Whole screen"
        }
    }
}

final class BlinkNudge {
    static let shared = BlinkNudge()
    private init() {}

    private var window: NSWindow?
    private var iconTimer: Timer?
    private var isPlaying = false

    func play(from statusItem: NSStatusItem, style: BlinkStyle, scope: BlinkScope) {
        guard !isPlaying, let button = statusItem.button else { return }
        isPlaying = true

        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        blinkIcon(button, twice: !reduced)

        var settle = 0.9
        switch scope {
        case .menuBar:
            let effective: BlinkStyle = reduced ? .subtle : style
            if effective != .subtle, statusItem.isVisible, let host = button.window {
                let icon = host.convertToScreen(button.convert(button.bounds, to: nil))
                scatter(effective, from: CGPoint(x: icon.minX + 12.5, y: icon.minY))
                settle = 2.4
            }
        case .wholeScreen:
            if let screen = focusedScreen() {
                sweepEyelid(on: screen, style: style, sweep: !reduced)
                settle = (reduced || style == .subtle) ? 1.2 : 2.4
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.isPlaying = false
        }
    }

    private func focusedScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func sweepEyelid(on screen: NSScreen, style: BlinkStyle, sweep: Bool) {
        let frame = screen.frame
        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        win.contentView = root
        win.orderFrontRegardless()
        window = win

        let w = frame.width, h = frame.height

        guard sweep else {
            let dim = CALayer()
            dim.frame = CGRect(x: 0, y: 0, width: w, height: h)
            dim.backgroundColor = Self.lidInk
            dim.opacity = 0
            root.layer?.addSublayer(dim)
            let pulse = CAKeyframeAnimation(keyPath: "opacity")
            pulse.values = [0, 1, 1, 0]
            pulse.keyTimes = [0, 0.25, 0.6, 1]
            pulse.duration = 0.8
            dim.add(pulse, forKey: nil)
            return
        }

        let seam = h * 0.42
        let bow = min(w * 0.16, h * 0.40)
        let lidHeight = h + 2 * bow

        let lids = CALayer()
        lids.frame = CGRect(x: 0, y: 0, width: w, height: h)
        lids.allowsGroupOpacity = true
        lids.opacity = 0.33

        let lower = lid(width: w, height: lidHeight, bow: bow, top: false)
        let upper = lid(width: w, height: lidHeight, bow: bow, top: true)
        lids.addSublayer(lower)
        lids.addSublayer(upper)
        root.layer?.addSublayer(lids)

        let upperParked = h + lidHeight / 2
        let lowerParked = -lidHeight / 2
        let upperClosed = seam - bow + lidHeight / 2
        let lowerClosed = seam + bow + 2 - lidHeight / 2

        upper.position = CGPoint(x: w / 2, y: upperParked)
        lower.position = CGPoint(x: w / 2, y: lowerParked)
        shut(upper, from: upperParked, to: upperClosed)
        shut(lower, from: lowerParked, to: lowerClosed)

        guard style != .subtle else { return }
        let across = max(1, Int(w / 900)) * style.count
        for i in 0..<across {
            let source = CGPoint(x: CGFloat.random(in: 0...w), y: h - 4)
            root.layer?.addSublayer(particle(index: i % 5, from: source, style: style))
        }
    }

    private static let lidInk = NSColor(white: 0, alpha: 0.33).cgColor

    private func lid(width w: CGFloat, height lidHeight: CGFloat, bow: CGFloat, top: Bool) -> CAShapeLayer {
        let path = CGMutablePath()
        if top {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: 2 * bow))
            path.addLine(to: CGPoint(x: w, y: lidHeight))
            path.addLine(to: CGPoint(x: 0, y: lidHeight))
        } else {
            path.move(to: CGPoint(x: 0, y: lidHeight))
            path.addQuadCurve(to: CGPoint(x: w, y: lidHeight), control: CGPoint(x: w / 2, y: lidHeight - 2 * bow))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        path.closeSubpath()

        let layer = CAShapeLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: lidHeight)
        layer.path = path
        layer.fillColor = NSColor.black.cgColor
        layer.shadowPath = path
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: top ? -10 : 10)
        return layer
    }

    private func shut(_ lid: CALayer, from parked: CGFloat, to closed: CGFloat) {
        let fall = CAKeyframeAnimation(keyPath: "position.y")
        fall.values = [parked, closed, parked]
        fall.keyTimes = [0, 0.44, 1]
        fall.timingFunctions = [CAMediaTimingFunction(name: .easeIn),
                                CAMediaTimingFunction(name: .easeOut)]
        fall.duration = 0.42
        lid.add(fall, forKey: nil)
    }

    private func blinkIcon(_ button: NSStatusBarButton, twice: Bool) {
        iconTimer?.invalidate()
        let duration = twice ? 0.52 : 0.75
        let started = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            let t = Date().timeIntervalSince(started) / duration
            guard t < 1 else {
                timer.invalidate()
                self?.iconTimer = nil
                button.image = MenuIcon.frames[0]
                return
            }
            let squint = twice ? Self.doubleBlink(t) : Self.singleBlink(t)
            button.image = MenuIcon.frames[Int((squint * 8).rounded())]
        }
        RunLoop.main.add(timer, forMode: .common)
        iconTimer = timer
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func doubleBlink(_ t: Double) -> Double {
        switch t {
        case ..<0.20: return smoothstep(t / 0.20)
        case ..<0.42: return 1 - smoothstep((t - 0.20) / 0.22)
        case ..<0.60: return smoothstep((t - 0.42) / 0.18)
        default:      return 1 - smoothstep((t - 0.60) / 0.40)
        }
    }

    private static func singleBlink(_ t: Double) -> Double {
        t < 0.45 ? smoothstep(t / 0.45) : 1 - smoothstep((t - 0.45) / 0.55)
    }

    private func scatter(_ style: BlinkStyle, from spawn: CGPoint) {
        let size = NSSize(width: 190, height: 170)
        let win = NSWindow(contentRect: NSRect(x: spawn.x - size.width / 2,
                                               y: spawn.y - size.height,
                                               width: size.width, height: size.height),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .statusBar
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        win.contentView = root
        win.orderFrontRegardless()
        window = win

        let source = CGPoint(x: size.width / 2, y: size.height - 4)
        root.layer?.addSublayer(glow(at: source, tint: style.tints[0]))
        for i in 0..<style.count {
            root.layer?.addSublayer(particle(index: i, from: source, style: style))
        }
    }

    private func glow(at point: CGPoint, tint: NSColor) -> CALayer {
        let side: CGFloat = 64
        let layer = CAGradientLayer()
        layer.type = .radial
        layer.frame = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        layer.colors = [tint.withAlphaComponent(0.45).cgColor, tint.withAlphaComponent(0).cgColor]
        layer.locations = [0, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.opacity = 0

        let swell = CABasicAnimation(keyPath: "transform.scale")
        swell.fromValue = 0.35
        swell.toValue = 1.6
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 0]
        fade.keyTimes = [0, 0.25, 1]

        let group = CAAnimationGroup()
        group.animations = [swell, fade]
        group.duration = 0.6
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(group, forKey: nil)
        return layer
    }

    private struct Choreography {
        let side: CGFloat
        let travel: CGPath
        let duration: Double
        let delay: Double
        let curve: CAMediaTimingFunctionName
        let scale: [CGFloat]
        let scaleTimes: [Double]
        let opacity: [CGFloat]
        let opacityTimes: [Double]
        let spin: [Double]
        let spinTimes: [Double]
    }

    private func choreography(_ style: BlinkStyle, index: Int, source: CGPoint) -> Choreography {
        switch style {
        case .hearts:
            let drop = CGFloat.random(in: 96...132)
            let drift = CGFloat.random(in: -52...52)
            let sway = CGFloat.random(in: 22...40) * (Bool.random() ? 1 : -1)
            let end = CGPoint(x: source.x + drift, y: source.y - drop)
            let arc = CGMutablePath()
            arc.move(to: source)
            arc.addCurve(to: end,
                         control1: CGPoint(x: source.x + sway, y: source.y - drop * 0.35),
                         control2: CGPoint(x: end.x - sway, y: source.y - drop * 0.72))
            let tilt = Double.random(in: 0.18...0.34) * (sway > 0 ? 1 : -1)
            return Choreography(side: .random(in: 11...18), travel: arc,
                                duration: .random(in: 1.5...1.9),
                                delay: Double(index) * 0.075 + .random(in: 0...0.05),
                                curve: .easeOut,
                                scale: [0.2, 1.08, 0.96, 0.88], scaleTimes: [0, 0.22, 0.5, 1],
                                opacity: [0, 1, 1, 0], opacityTimes: [0, 0.14, 0.5, 1],
                                spin: [0, tilt, -tilt * 0.7, tilt * 0.4], spinTimes: [0, 0.3, 0.65, 1])

        case .sparkles:
            let theta = Double.random(in: -1.15...1.15)
            let distance = CGFloat.random(in: 42...80)
            let end = CGPoint(x: source.x + CGFloat(sin(theta)) * distance,
                              y: source.y - CGFloat(cos(theta)) * distance)
            let line = CGMutablePath()
            line.move(to: source)
            line.addLine(to: end)
            return Choreography(side: .random(in: 8...15), travel: line,
                                duration: .random(in: 0.9...1.25),
                                delay: Double(index) * 0.045 + .random(in: 0...0.04),
                                curve: .easeOut,
                                scale: [0.15, 1.3, 0.75, 1.05, 0], scaleTimes: [0, 0.18, 0.42, 0.66, 1],
                                opacity: [0, 1, 1, 0], opacityTimes: [0, 0.1, 0.5, 1],
                                spin: [0, Double.random(in: 0.5...1.1) * (theta > 0 ? 1 : -1)],
                                spinTimes: [0, 1])

        case .dew:
            let drop = CGFloat.random(in: 108...148)
            let drift = CGFloat.random(in: -18...18)
            let sway = CGFloat.random(in: 6...14) * (Bool.random() ? 1 : -1)
            let end = CGPoint(x: source.x + drift, y: source.y - drop)
            let arc = CGMutablePath()
            arc.move(to: source)
            arc.addCurve(to: end,
                         control1: CGPoint(x: source.x + sway, y: source.y - drop * 0.40),
                         control2: CGPoint(x: end.x - sway * 0.5, y: source.y - drop * 0.75))
            return Choreography(side: .random(in: 9...14), travel: arc,
                                duration: .random(in: 1.05...1.35),
                                delay: Double(index) * 0.09 + .random(in: 0...0.05),
                                curve: .easeIn,
                                scale: [0.35, 1.0, 1.0, 0.92], scaleTimes: [0, 0.18, 0.6, 1],
                                opacity: [0, 0.95, 0.95, 0], opacityTimes: [0, 0.12, 0.62, 1],
                                spin: [0, Double.random(in: -0.08...0.08)], spinTimes: [0, 1])

        case .subtle:
            return Choreography(side: 0, travel: CGMutablePath(), duration: 0, delay: 0,
                                curve: .linear, scale: [], scaleTimes: [], opacity: [],
                                opacityTimes: [], spin: [], spinTimes: [])
        }
    }

    private func particle(index: Int, from source: CGPoint, style: BlinkStyle) -> CALayer {
        let move = choreography(style, index: index, source: source)

        let shape = CAShapeLayer()
        shape.path = style.path(size: move.side)
        shape.fillColor = style.tints[index % style.tints.count].cgColor
        shape.frame = CGRect(x: 0, y: 0, width: move.side, height: move.side)
        shape.shadowColor = NSColor.black.cgColor
        shape.shadowOpacity = 0.18
        shape.shadowRadius = 3
        shape.shadowOffset = CGSize(width: 0, height: -1)
        if style == .dew {
            shape.strokeColor = NSColor.white.withAlphaComponent(0.55).cgColor
            shape.lineWidth = 0.6
        }

        let carrier = CALayer()
        carrier.bounds = shape.frame
        carrier.position = source
        carrier.opacity = 0
        carrier.addSublayer(shape)

        let begin = CACurrentMediaTime() + move.delay

        let travel = CAKeyframeAnimation(keyPath: "position")
        travel.path = move.travel
        travel.calculationMode = .cubicPaced

        let swell = CAKeyframeAnimation(keyPath: "transform.scale")
        swell.values = move.scale
        swell.keyTimes = move.scaleTimes.map(NSNumber.init)

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = move.opacity
        fade.keyTimes = move.opacityTimes.map(NSNumber.init)

        let group = CAAnimationGroup()
        group.animations = [travel, swell, fade]
        group.duration = move.duration
        group.beginTime = begin
        group.timingFunction = CAMediaTimingFunction(name: move.curve)
        group.fillMode = .backwards
        group.isRemovedOnCompletion = false
        carrier.add(group, forKey: nil)

        let spin = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        spin.values = move.spin
        spin.keyTimes = move.spinTimes.map(NSNumber.init)
        spin.duration = move.duration
        spin.beginTime = begin
        spin.fillMode = .backwards
        spin.isRemovedOnCompletion = false
        shape.add(spin, forKey: nil)

        return carrier
    }
}

enum Hold: Equatable {
    case call
    case watching(String)

    var explanation: String {
        switch self {
        case .call:              return "Held — you're on a call"
        case .watching(let app): return "Held — \(app) is playing"
        }
    }

    var forecast: String {
        switch self {
        case .call:              return "On a call — the next break will wait"
        case .watching(let app): return "\(app) is playing — the next break will wait"
        }
    }
}

enum Presence {
    static func hold() -> Hold? {
        if micIsLive() { return .call }
        if let app = keepingDisplayAwake() { return .watching(app) }
        return nil
    }

    static var idleSeconds: TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private static func micIsLive() -> Bool {
        let preferred = defaultInputDevice()
        if let preferred, isRunningSomewhere(preferred) { return true }
        return audioDevices().contains { device in
            device != preferred && inputChannelCount(device) > 0
                && isPhysical(device) && isRunningSomewhere(device)
        }
    }

    private static func defaultInputDevice() -> AudioDeviceID? {
        guard let id = property(AudioObjectID(kAudioObjectSystemObject),
                                kAudioHardwarePropertyDefaultInputDevice,
                                scope: kAudioObjectPropertyScopeGlobal, as: AudioDeviceID.self),
              id != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        return id
    }

    private static func isPhysical(_ device: AudioDeviceID) -> Bool {
        let transport = property(device, kAudioDevicePropertyTransportType,
                                 scope: kAudioObjectPropertyScopeGlobal, as: UInt32.self) ?? 0
        return transport != kAudioDeviceTransportTypeVirtual
            && transport != kAudioDeviceTransportTypeAggregate
    }

    private static func isRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        (property(device, kAudioDevicePropertyDeviceIsRunningSomewhere,
                  scope: kAudioObjectPropertyScopeGlobal, as: UInt32.self) ?? 0) != 0
    }

    private static func property<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope, as: T.Type) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                                 mElement: kAudioObjectPropertyElementMain)
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, value) == noErr else { return nil }
        return value.pointee
    }

    private static func audioDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func inputChannelCount(_ device: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioDevicePropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func keepingDisplayAwake() -> String? {
        var copy: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&copy) == kIOReturnSuccess,
              let byProcess = copy?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return nil }

        let ours = ProcessInfo.processInfo.processIdentifier
        for (owner, assertions) in byProcess {
            let pid = pid_t(truncating: owner)
            guard pid != ours else { continue }
            for assertion in assertions {
                let kind = (assertion["AssertionTrueType"] as? String)
                    ?? (assertion["AssertionType"] as? String) ?? ""
                guard kind.contains("PreventUserIdleDisplaySleep") || kind.contains("NoDisplaySleep")
                else { continue }
                let who = NSRunningApplication(processIdentifier: pid)?.localizedName
                    ?? (assertion["Process Name"] as? String)
                    ?? "Something"
                guard !isKeepAwakeTool(who) else { continue }
                return who
            }
        }
        return nil
    }

    private static let keepAwakeTools = [
        "amphetamine", "caffeinate", "caffeine", "keepingyouawake", "lungo",
        "theine", "owly", "jiggler", "nosleep", "wimoweh", "sleepless",
    ]

    private static func isKeepAwakeTool(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return keepAwakeTools.contains { lowered.contains($0) }
    }
}

private enum Keys {
    static let gifPath = "gifPath"
    static let gifLabel = "gifLabel"
    static let workMinutes = "workMinutes"
    static let breakSeconds = "breakSeconds"
    static let blinkMinutes = "blinkMinutes"
    static let blinkStyle = "blinkStyle"
    static let blinkScope = "blinkScope"
    static let blinkExplained = "blinkExplained"
    static let autoPause = "autoPause"
    static let naturalBreaks = "naturalBreaks"
    static let auditDay = "auditDay"
    static let heldToday = "heldToday"
    static let naturalToday = "naturalToday"
}

enum GifSource {
    case file(URL)
    case link(URL)
}

enum GifLoader {
    enum Failure: Error {
        case badLink
        case notAnImage
        case tooLarge
        case network(String)
        case save

        var message: String {
            switch self {
            case .badLink:        return "That doesn't look like a link."
            case .notAnImage:     return "That link doesn't point to an image."
            case .tooLarge:       return "That image is over 40 MB — try a smaller one."
            case .network(let why): return why
            case .save:           return "Couldn't save the image."
            }
        }
    }

    static let maxBytes = 40 * 1024 * 1024

    static func normalized(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if !text.lowercased().hasPrefix("http") { text = "https://" + text }
        guard let comps = URLComponents(string: text),
              let host = comps.host, host.contains(".") else { return nil }
        if host.contains("giphy.com"), !comps.path.lowercased().hasSuffix(".gif"),
           let id = giphyID(in: comps.path) {
            return URL(string: "https://i.giphy.com/\(id).gif")
        }
        return comps.url
    }

    private static func giphyID(in path: String) -> String? {
        let segs = path.split(separator: "/").map(String.init)
        if let i = segs.firstIndex(of: "media"), i + 1 < segs.count { return segs[i + 1] }
        if let last = segs.last, let id = last.split(separator: "-").last { return String(id) }
        return nil
    }

    static func fetch(_ url: URL, followHTML: Bool = true,
                      completion: @escaping (Result<Data, Failure>) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("HeartEyes (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                completion(.failure(.network("The server returned \(http.statusCode).")))
                return
            }
            guard let data = data, !data.isEmpty else { completion(.failure(.notAnImage)); return }
            guard data.count <= maxBytes else { completion(.failure(.tooLarge)); return }
            if NSBitmapImageRep(data: data) != nil { completion(.success(data)); return }
            if followHTML, let html = String(data: data.prefix(300_000), encoding: .utf8),
               let preview = ogImage(in: html, base: url) {
                fetch(preview, followHTML: false, completion: completion)
                return
            }
            completion(.failure(.notAnImage))
        }.resume()
    }

    private static func ogImage(in html: String, base: URL) -> URL? {
        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else { continue }
            let raw = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
            if let url = URL(string: raw, relativeTo: base) { return url.absoluteURL }
        }
        return nil
    }

    static func save(_ data: Data, in dir: URL) throws -> URL {
        let ext: String
        if data.starts(with: Data("GIF".utf8)) { ext = "gif" }
        else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { ext = "png" }
        else if data.starts(with: [0xFF, 0xD8]) { ext = "jpg" }
        else { ext = "img" }
        let dest = dir.appendingPathComponent("break-\(UUID().uuidString).\(ext)")
        try data.write(to: dest, options: .atomic)
        prune(in: dir, keeping: dest)
        return dest
    }

    private static func prune(in dir: URL, keeping keep: URL) {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent != keep.lastPathComponent {
            let name = url.lastPathComponent
            if name.hasPrefix("break-") || name == "remote.gif" { try? fm.removeItem(at: url) }
        }
    }
}

fileprivate func pickerLabel(_ text: String, size: CGFloat,
                             weight: NSFont.Weight = .regular,
                             color: NSColor = .labelColor) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = color
    return l
}

final class GifDropView: NSView {
    private let imageView = NSImageView()
    private let empty = NSStackView()
    private var targeted = false { didSet { needsDisplay = true } }

    var onSource: ((GifSource) -> Void)?

    var image: NSImage? {
        didSet {
            imageView.image = image
            imageView.isHidden = (image == nil)
            empty.isHidden = (image != nil)
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.unregisterDraggedTypes()
        addSubview(imageView)

        let glyph = pickerLabel("😍", size: 40)
        let hint = pickerLabel("Drop a GIF here", size: 12, color: .secondaryLabelColor)
        empty.orientation = .vertical
        empty.alignment = .centerX
        empty.spacing = 6
        empty.addArrangedSubview(glyph)
        empty.addArrangedSubview(hint)
        empty.translatesAutoresizingMaskIntoConstraints = false
        addSubview(empty)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            empty.centerXAnchor.constraint(equalTo: centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        registerForDraggedTypes([.fileURL, .URL, .string])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        (targeted ? NSColor.controlAccentColor.withAlphaComponent(0.10)
                  : NSColor.controlBackgroundColor).setFill()
        path.fill()
        path.lineWidth = targeted ? 2 : 1
        if image == nil && !targeted { path.setLineDash([4, 3], count: 2, phase: 0) }
        (targeted ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()
    }

    private func source(from info: NSDraggingInfo) -> GifSource? {
        let pb = info.draggingPasteboard
        if let files = pb.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let file = files.first {
            return .file(file)
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let web = urls.first, web.scheme?.hasPrefix("http") == true {
            return .link(web)
        }
        if let text = pb.string(forType: .string), let link = GifLoader.normalized(text) {
            return .link(link)
        }
        return nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        targeted = source(from: sender) != nil
        return targeted ? .copy : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { targeted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { targeted = false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        targeted = false
        guard let source = source(from: sender) else { return false }
        onSource?(source)
        return true
    }
}

final class SuggestionChip: NSView {
    private var hovering = false { didSet { needsDisplay = true } }

    var onUse: (() -> Void)?
    var onDismiss: (() -> Void)?

    init(title: String, detail: String, symbol: String) {
        super.init(frame: .zero)
        wantsLayer = true

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = pickerLabel(title, size: 12, weight: .medium)
        let detailLabel = pickerLabel(detail, size: 11, color: .secondaryLabelColor)
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.lineBreakMode = .byTruncatingMiddle
        for l in [titleLabel, detailLabel] {
            l.maximumNumberOfLines = 1
            l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        let text = NSStackView(views: [titleLabel, detailLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1
        text.translatesAutoresizingMaskIntoConstraints = false
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss") ?? NSImage(),
                             target: self, action: #selector(dismiss))
        close.isBordered = false
        close.bezelStyle = .regularSquare
        close.symbolConfiguration = .init(pointSize: 10, weight: .semibold)
        close.contentTintColor = .secondaryLabelColor
        close.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon); addSubview(text); addSubview(close)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 18),
            close.heightAnchor.constraint(equalToConstant: 18),
        ])

        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        NSColor.controlAccentColor.withAlphaComponent(hovering ? 0.18 : 0.10).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) { onUse?() }
    @objc private func dismiss() { onDismiss?() }
    override func accessibilityPerformPress() -> Bool { onUse?(); return true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; NSCursor.pointingHand.set() }
    override func mouseExited(with event: NSEvent) { hovering = false; NSCursor.arrow.set() }
}

final class GifPickerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { performClose(nil) }
}

final class GifPicker: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let window = GifPickerWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
                                         styleMask: [.titled, .closable],
                                         backing: .buffered,
                                         defer: false)
    private let drop = GifDropView()
    private let field = NSTextField()
    private let loadButton = NSButton()
    private let resetButton = NSButton()
    private let spinner = NSProgressIndicator()
    private let status = pickerLabel(" ", size: 11, color: .secondaryLabelColor)
    private var chip: SuggestionChip?

    private let storeDir: URL
    private var path: String?
    private var busy = false { didSet { refreshControls() } }

    var onChange: ((String?, String?) -> Void)?
    var onClose: (() -> Void)?

    init(currentPath: String?, storeDir: URL) {
        self.storeDir = storeDir
        self.path = currentPath
        super.init()

        window.title = "Break GIF"
        window.delegate = self
        window.isReleasedWhenClosed = false
        let content = buildContent()
        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.center()

        refreshPreview()
        refreshControls()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    private func buildContent() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 480))

        let heading = pickerLabel("Pick what you'll look at", size: 15, weight: .semibold)
        let sub = pickerLabel("It fills the screen while your eyes rest.", size: 12, color: .secondaryLabelColor)

        drop.translatesAutoresizingMaskIntoConstraints = false
        drop.onSource = { [weak self] in self?.load($0) }

        field.placeholderString = "Paste a Giphy, Tenor, or .gif link"
        field.font = .systemFont(ofSize: 12)
        field.delegate = self
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)

        loadButton.title = "Load"
        loadButton.bezelStyle = .rounded
        loadButton.target = self
        loadButton.action = #selector(loadFromField)
        loadButton.keyEquivalent = "\r"

        let urlRow = NSStackView(views: [field, loadButton])
        urlRow.orientation = .horizontal
        urlRow.spacing = 8
        urlRow.translatesAutoresizingMaskIntoConstraints = false

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        status.lineBreakMode = .byTruncatingTail
        status.maximumNumberOfLines = 1
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let statusRow = NSStackView(views: [spinner, status])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        let column = NSStackView(views: [heading, sub, drop, urlRow, statusRow])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.setCustomSpacing(16, after: sub)
        column.setCustomSpacing(14, after: drop)
        column.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(column)

        if let suggestion = GifPicker.clipboardSuggestion() {
            let chip = makeChip(for: suggestion.source, label: suggestion.label)
            chip.translatesAutoresizingMaskIntoConstraints = false
            column.insertArrangedSubview(chip, at: 3)
            column.setCustomSpacing(10, after: chip)
            chip.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            self.chip = chip
        }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let browse = NSButton(title: "Browse Files…", target: self, action: #selector(browseFiles))
        browse.bezelStyle = .rounded
        resetButton.title = "Use Default"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(useDefault)
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let bar = NSStackView(views: [browse, spacer, resetButton, done])
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)
        root.addSubview(bar)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            column.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            column.widthAnchor.constraint(equalToConstant: 380),

            drop.widthAnchor.constraint(equalTo: column.widthAnchor),
            drop.heightAnchor.constraint(equalToConstant: 186),
            urlRow.widthAnchor.constraint(equalTo: column.widthAnchor),
            statusRow.widthAnchor.constraint(equalTo: column.widthAnchor),
            statusRow.heightAnchor.constraint(equalToConstant: 16),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.topAnchor.constraint(equalTo: column.bottomAnchor, constant: 14),
            separator.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -14),

            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            bar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        return root
    }

    private func commit(_ newPath: String?, label: String?) {
        path = newPath
        refreshPreview()
        refreshControls()
        onChange?(newPath, label)
    }

    private func refreshPreview() {
        drop.image = path.flatMap { NSImage(contentsOfFile: $0) }
    }

    private func refreshControls() {
        let typed = !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty
        loadButton.isEnabled = typed && !busy
        resetButton.isEnabled = (path != nil) && !busy
        field.isEnabled = !busy
        busy ? spinner.startAnimation(nil) : spinner.stopAnimation(nil)
    }

    func controlTextDidChange(_ obj: Notification) { refreshControls() }

    private func note(_ text: String) {
        status.stringValue = text
        status.textColor = .secondaryLabelColor
    }
    private func succeed(_ text: String) {
        status.stringValue = "✓ " + text
        status.textColor = .secondaryLabelColor
    }
    private func fail(_ why: GifLoader.Failure) {
        NSSound.beep()
        status.stringValue = "⚠︎ " + why.message
        status.textColor = .systemRed
    }

    @objc private func loadFromField() {
        guard let url = GifLoader.normalized(field.stringValue) else { fail(.badLink); return }
        load(.link(url))
    }

    @objc private func browseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Pick a GIF (or image) to show during your eye breaks"
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.load(.file(url))
        }
    }

    @objc private func useDefault() {
        commit(nil, label: nil)
        succeed("Back to the default 😍")
    }

    @objc private func closeWindow() { window.performClose(nil) }

    private func load(_ source: GifSource) {
        dismissChip()
        switch source {
        case .file(let url):
            guard NSImage(contentsOf: url) != nil else { fail(.notAnImage); return }
            commit(url.path, label: url.lastPathComponent)
            succeed("Using \(url.lastPathComponent)")

        case .link(let url):
            field.stringValue = url.absoluteString
            busy = true
            note("Fetching…")
            GifLoader.fetch(url) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.busy = false
                    switch result {
                    case .failure(let why):
                        self.fail(why)
                    case .success(let data):
                        do {
                            let saved = try GifLoader.save(data, in: self.storeDir)
                            self.commit(saved.path, label: url.host ?? "Downloaded GIF")
                            self.succeed("Ready for your next break")
                        } catch {
                            self.fail(.save)
                        }
                    }
                }
            }
        }
    }

    private static func clipboardSuggestion() -> (source: GifSource, label: String)? {
        let pb = NSPasteboard.general
        let imageTypes = ["gif", "png", "jpg", "jpeg", "heic", "webp"]
        if let files = pb.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let file = files.first, imageTypes.contains(file.pathExtension.lowercased()) {
            return (.file(file), file.lastPathComponent)
        }
        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           text.count < 2000, text.lowercased().hasPrefix("http"),
           let link = GifLoader.normalized(text) {
            return (.link(link), text)
        }
        return nil
    }

    private func makeChip(for source: GifSource, label: String) -> SuggestionChip {
        let chip: SuggestionChip
        switch source {
        case .file:
            chip = SuggestionChip(title: "Use the file you copied", detail: label, symbol: "doc.on.clipboard")
        case .link:
            chip = SuggestionChip(title: "Use the link you copied", detail: label, symbol: "link")
        }
        chip.onUse = { [weak self] in self?.load(source) }
        chip.onDismiss = { [weak self] in self?.dismissChip() }
        return chip
    }

    private func dismissChip() {
        guard let chip = chip else { return }
        self.chip = nil
        DispatchQueue.main.async { [weak self] in
            chip.removeFromSuperview()
            self?.resizeToFit()
        }
    }

    private func resizeToFit() {
        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: content.fittingSize))
        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size = target.size
        window.setFrame(frame, display: true, animate: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var workMinutes: Int {
        get { let v = UserDefaults.standard.integer(forKey: Keys.workMinutes); return v == 0 ? 20 : v }
        set { UserDefaults.standard.set(newValue, forKey: Keys.workMinutes) }
    }
    var breakSeconds: Int {
        get { let v = UserDefaults.standard.integer(forKey: Keys.breakSeconds); return v == 0 ? 20 : v }
        set { UserDefaults.standard.set(newValue, forKey: Keys.breakSeconds) }
    }
    var gifPath: String? {
        get { UserDefaults.standard.string(forKey: Keys.gifPath) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.gifPath) }
    }
    var gifLabel: String? {
        get { UserDefaults.standard.string(forKey: Keys.gifLabel) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.gifLabel) }
    }
    var blinkMinutes: Int {
        get { UserDefaults.standard.integer(forKey: Keys.blinkMinutes) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.blinkMinutes) }
    }
    var blinkStyle: BlinkStyle {
        get { BlinkStyle(rawValue: UserDefaults.standard.string(forKey: Keys.blinkStyle) ?? "") ?? .hearts }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.blinkStyle) }
    }
    var blinkScope: BlinkScope {
        get { BlinkScope(rawValue: UserDefaults.standard.string(forKey: Keys.blinkScope) ?? "") ?? .menuBar }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.blinkScope) }
    }
    var autoPause: Bool {
        get { UserDefaults.standard.object(forKey: Keys.autoPause) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoPause) }
    }
    var naturalBreaks: Bool {
        get { UserDefaults.standard.object(forKey: Keys.naturalBreaks) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.naturalBreaks) }
    }

    private var statusItem: NSStatusItem!
    private var infoItem: NSMenuItem?
    private var forecastItem: NSMenuItem?
    private var gifPicker: GifPicker?
    private var thumbnailCache: (path: String, image: NSImage)?
    private var tickTimer: Timer?
    private var breakTimer: Timer?
    private var secondsUntilBreak = 20 * 60
    private var secondsUntilBlink = 0
    private var breakRemaining = 20
    private var isPaused = false
    private var onBreak = false
    private var blinkPopover: NSPopover?

    private var currentHold: Hold?
    private var heldSince: Date?
    private var clearedAt: Date?
    private static let graceSeconds: TimeInterval = 30
    private static let watchCap: TimeInterval = 2 * 60 * 60

    private var overlayWindows: [NSWindow] = []
    private var countdownLabels: [NSTextField] = []
    private var ringViews: [RingProgressView] = []

    private let ledger = RestLedger()
    private let history = RestHistory(url: RestHistory.defaultURL())
    private var lastHistorySave = Date.distantPast
    private var reflection: ReflectionWindowController?

    private var watchProbe: (at: Date, watching: Bool)?
    private static let watchProbeIdle: TimeInterval = 15
    private static let watchProbeInterval: TimeInterval = 5
    private static let historySaveInterval: TimeInterval = 300

    private var settledAt = Date.distantPast
    private static let overlaySettle: TimeInterval = 3

    func applicationDidFinishLaunching(_ note: Notification) {
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        secondsUntilBreak = workMinutes * 60
        resetBlinkCountdown()

        ledger.setRestThreshold(naturalRestThreshold)
        ledger.load(history.load())
        ledger.resync(now: Date())
        observeSleepAndWake()

        buildMenu()
        updateStatusTitle()
        startTicking()
    }

    private func observeSleepAndWake() {
        let centre = NSWorkspace.shared.notificationCenter
        centre.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            self.ledger.stoppedWatching(now: now)
            self.saveHistory(now: now)
        }
        centre.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ledger.resync(now: Date())
        }
    }

    func applicationWillTerminate(_ note: Notification) {
        let now = Date()
        ledger.stoppedWatching(now: now)
        saveHistory(now: now)
    }

    private var naturalRestThreshold: TimeInterval { Double(max(60, breakSeconds * 3)) }

    private func saveHistory(now: Date = Date()) {
        lastHistorySave = now
        history.save(ledger.allDays(asOf: now), asOf: now)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit HeartEyes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func startTicking() {
        tickTimer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused, !self.onBreak else { return }
            self.recordExposure()
            if self.secondsUntilBreak > 0 { self.secondsUntilBreak -= 1 }
            self.tickBlinkReminder()
            if self.secondsUntilBreak <= 0 {
                self.attemptBreak()
            } else {
                self.updateStatusTitle()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func recordExposure() {
        let now = Date()
        guard now >= settledAt else { ledger.resync(now: now); return }
        let idle = Presence.idleSeconds
        ledger.observe(now: now,
                       idleSeconds: idle,
                       watching: isWatching(idle: idle),
                       suppressing: currentHold != nil)
        if now.timeIntervalSince(lastHistorySave) >= Self.historySaveInterval { saveHistory(now: now) }
    }

    private func isWatching(idle: TimeInterval) -> Bool {
        if currentHold != nil { return true }
        guard idle >= Self.watchProbeIdle else { watchProbe = nil; return false }
        if let p = watchProbe, Date().timeIntervalSince(p.at) < Self.watchProbeInterval { return p.watching }
        let watching = Presence.hold() != nil
        watchProbe = (Date(), watching)
        return watching
    }

    private func resetCountdown() {
        secondsUntilBreak = workMinutes * 60
        resetBlinkCountdown()
        clearHold()
        updateStatusTitle()
    }

    private func attemptBreak() {
        if autoPause, let hold = Presence.hold() {
            if heldSince == nil {
                heldSince = Date()
                bumpAudit(Keys.heldToday)
            }
            clearedAt = nil
            currentHold = hold
            if case .watching = hold, Date().timeIntervalSince(heldSince!) > Self.watchCap {
                startBreak()
            } else {
                updateStatusTitle()
            }
            return
        }

        if currentHold != nil {
            if clearedAt == nil { clearedAt = Date() }
            if Date().timeIntervalSince(clearedAt!) < Self.graceSeconds {
                updateStatusTitle()
                return
            }
        }

        if naturalBreaks, Presence.idleSeconds >= Double(max(60, breakSeconds * 3)) {
            bumpAudit(Keys.naturalToday)
            resetCountdown()
            return
        }

        startBreak()
    }

    private func clearHold() {
        currentHold = nil
        heldSince = nil
        clearedAt = nil
    }

    private func tickBlinkReminder() {
        guard blinkMinutes > 0 else { return }
        secondsUntilBlink -= 1
        guard secondsUntilBlink <= 0 else { return }
        defer { resetBlinkCountdown() }
        guard secondsUntilBreak > 25 else { return }
        if autoPause, Presence.hold() != nil { return }
        BlinkNudge.shared.play(from: statusItem, style: blinkStyle, scope: blinkScope)
    }

    private func resetBlinkCountdown() {
        secondsUntilBlink = max(blinkMinutes, 1) * 60
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func bumpAudit(_ key: String) {
        let today = Self.dayFormatter.string(from: Date())
        if UserDefaults.standard.string(forKey: Keys.auditDay) != today {
            UserDefaults.standard.set(today, forKey: Keys.auditDay)
            UserDefaults.standard.set(0, forKey: Keys.heldToday)
            UserDefaults.standard.set(0, forKey: Keys.naturalToday)
        }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
        buildMenu()
    }

    private func auditText() -> String? {
        guard UserDefaults.standard.string(forKey: Keys.auditDay) == Self.dayFormatter.string(from: Date())
        else { return nil }
        let held = UserDefaults.standard.integer(forKey: Keys.heldToday)
        let natural = UserDefaults.standard.integer(forKey: Keys.naturalToday)
        var parts: [String] = []
        if held > 0 { parts.append("held \(held)") }
        if natural > 0 { parts.append("\(natural) natural") }
        guard !parts.isEmpty else { return nil }
        return "Today: " + parts.joined(separator: " · ")
    }

    private func startBreak() {
        guard !onBreak else { return }
        onBreak = true
        clearHold()
        breakRemaining = breakSeconds
        ledger.breakBegan(now: Date())
        showOverlays()
        updateBreakLabels()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.breakRemaining -= 1
            if self.breakRemaining <= 0 {
                self.finishBreak(completed: true)
            } else {
                self.updateBreakLabels()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        breakTimer = t
        NSApp.activate(ignoringOtherApps: true)
        updateStatusTitle()
    }

    @objc private func skipBreak() { finishBreak(completed: false) }

    private func finishBreak(completed: Bool) {
        guard onBreak || !overlayWindows.isEmpty else { return }
        breakTimer?.invalidate(); breakTimer = nil
        onBreak = false

        let now = Date()
        ledger.breakEnded(now: now,
                          restedSeconds: max(0, breakSeconds - max(0, breakRemaining)),
                          completed: completed)
        settledAt = now.addingTimeInterval(Self.overlaySettle)
        saveHistory(now: now)

        let windows = overlayWindows
        overlayWindows.removeAll()
        countdownLabels.removeAll()
        ringViews.removeAll()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for w in windows { w.animator().alphaValue = 0 }
        } completionHandler: {
            for w in windows { w.orderOut(nil) }
        }

        secondsUntilBreak = workMinutes * 60
        resetBlinkCountdown()
        updateStatusTitle()
    }

    private func showOverlays() {
        for (idx, screen) in NSScreen.screens.enumerated() {
            let win = OverlayWindow(contentRect: screen.frame,
                                    styleMask: .borderless,
                                    backing: .buffered,
                                    defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .screenSaver
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            win.ignoresMouseEvents = false
            win.hasShadow = false
            win.contentView = makeBreakView(size: screen.frame.size, primary: idx == 0)
            win.setFrame(screen.frame, display: true)
            win.alphaValue = 0
            if idx == 0 { win.makeKeyAndOrderFront(nil) } else { win.orderFrontRegardless() }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                win.animator().alphaValue = 1
            }
            overlayWindows.append(win)
        }
    }

    private func makeBreakView(size: NSSize, primary: Bool) -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true

        let vignette = CAGradientLayer()
        vignette.type = .radial
        vignette.frame = root.bounds
        vignette.colors = [
            NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.14, alpha: 0.98).cgColor,
            NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 0.98).cgColor,
        ]
        vignette.locations = [0, 1]
        vignette.startPoint = CGPoint(x: 0.5, y: 0.5)
        vignette.endPoint = CGPoint(x: 1.0, y: 1.0)
        root.layer?.addSublayer(vignette)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let path = gifPath, let img = NSImage(contentsOfFile: path) {
            let maxW = size.width * 0.42
            let maxH = size.height * 0.46
            var w = img.size.width, h = img.size.height
            if w <= 0 || h <= 0 { w = maxW; h = maxH }
            let scale = min(min(maxW / w, maxH / h), 2.5)
            let gw = (w * scale).rounded(), gh = (h * scale).rounded()

            let card = NSView()
            card.wantsLayer = true
            card.translatesAutoresizingMaskIntoConstraints = false
            card.layer?.cornerRadius = 18
            card.layer?.backgroundColor = NSColor.black.cgColor
            card.layer?.masksToBounds = false
            card.layer?.shadowColor = NSColor.black.cgColor
            card.layer?.shadowOpacity = 0.55
            card.layer?.shadowRadius = 44
            card.layer?.shadowOffset = CGSize(width: 0, height: -12)

            let iv = NSImageView()
            iv.image = img
            iv.animates = true
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.wantsLayer = true
            iv.layer?.cornerRadius = 18
            iv.layer?.masksToBounds = true
            iv.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(iv)
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: gw),
                card.heightAnchor.constraint(equalToConstant: gh),
                iv.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                iv.topAnchor.constraint(equalTo: card.topAnchor),
                iv.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            ])
            stack.addArrangedSubview(card)
            stack.setCustomSpacing(36, after: card)
        } else {
            let emoji = makeLabel("😍", size: 108)
            stack.addArrangedSubview(emoji)
            stack.setCustomSpacing(32, after: emoji)
        }

        stack.addArrangedSubview(makeLabel("Look 20 feet away", size: 36, weight: .semibold))
        let subtitle = makeLabel("Rest your eyes until the timer ends",
                                 size: 15, color: NSColor.white.withAlphaComponent(0.55))
        stack.addArrangedSubview(subtitle)
        stack.setCustomSpacing(34, after: subtitle)

        let ring = RingProgressView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.setFraction(CGFloat(breakRemaining) / CGFloat(max(breakSeconds, 1)), animated: false)
        ringViews.append(ring)

        let number = makeLabel("\(breakRemaining)", size: 46, weight: .bold)
        number.font = NSFont.monospacedDigitSystemFont(ofSize: 46, weight: .bold)
        number.translatesAutoresizingMaskIntoConstraints = false
        countdownLabels.append(number)

        let ringHost = NSView()
        ringHost.translatesAutoresizingMaskIntoConstraints = false
        ringHost.addSubview(ring)
        ringHost.addSubview(number)
        NSLayoutConstraint.activate([
            ring.widthAnchor.constraint(equalToConstant: 128),
            ring.heightAnchor.constraint(equalToConstant: 128),
            ring.leadingAnchor.constraint(equalTo: ringHost.leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: ringHost.trailingAnchor),
            ring.topAnchor.constraint(equalTo: ringHost.topAnchor),
            ring.bottomAnchor.constraint(equalTo: ringHost.bottomAnchor),
            number.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            number.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
        ])
        stack.addArrangedSubview(ringHost)

        if primary {
            stack.setCustomSpacing(40, after: ringHost)
            let skip = PillButton(title: "Skip  ·  Esc", target: self, action: #selector(skipBreak))
            skip.keyEquivalent = "\u{1b}"
            stack.addArrangedSubview(skip)
        }

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        return root
    }

    private func makeLabel(_ text: String, size: CGFloat,
                           weight: NSFont.Weight = .regular,
                           color: NSColor = .white) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func updateBreakLabels() {
        let fraction = CGFloat(breakRemaining) / CGFloat(max(breakSeconds, 1))
        for l in countdownLabels { l.stringValue = "\(breakRemaining)" }
        for r in ringViews { r.setFraction(fraction, animated: true) }
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        if button.image == nil {
            button.image = MenuIcon.statusItem
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
        }
        let txt: String
        if onBreak { txt = "break" }
        else if isPaused { txt = "paused" }
        else if currentHold != nil { txt = "held" }
        else { txt = String(format: "%02d:%02d", secondsUntilBreak / 60, secondsUntilBreak % 60) }
        button.appearsDisabled = isPaused || currentHold != nil
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: " " + txt, attributes: [.font: font])
    }

    private func statusInfoText() -> String {
        if onBreak { return "On a break…" }
        if isPaused { return "Paused" }
        if let hold = currentHold { return hold.explanation }
        return String(format: "Next break in %d:%02d", secondsUntilBreak / 60, secondsUntilBreak % 60)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let info = NSMenuItem(title: statusInfoText(), action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        infoItem = info

        let forecast = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        forecast.isEnabled = false
        forecast.isHidden = true
        menu.addItem(forecast)
        forecastItem = forecast

        if let audit = auditText() {
            let line = NSMenuItem(title: audit, action: nil, keyEquivalent: "")
            line.isEnabled = false
            line.attributedTitle = secondaryTitle(audit)
            menu.addItem(line)
        }
        addItem(to: menu, "This week…", #selector(openReflection))
        menu.addItem(.separator())

        addItem(to: menu, "Take a break now", #selector(takeBreakNow), key: "b")
        addItem(to: menu, isPaused ? "Resume" : "Pause", #selector(togglePause), key: "p")
        menu.addItem(.separator())

        let gif = NSMenuItem(title: "Choose Break GIF…", action: #selector(openGifPicker), keyEquivalent: "")
        gif.target = self
        if let p = gifPath {
            gif.attributedTitle = menuTitle("Break GIF…", subtitle: gifLabel ?? (p as NSString).lastPathComponent)
            gif.image = menuThumbnail(for: p)
        }
        menu.addItem(gif)

        let intervalItem = NSMenuItem(title: "Work interval", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for m in [1, 10, 20, 30, 45, 60] {
            let it = NSMenuItem(title: m == 1 ? "1 min (test)" : "\(m) min",
                                action: #selector(setInterval(_:)), keyEquivalent: "")
            it.target = self; it.tag = m; it.state = (m == workMinutes) ? .on : .off
            intervalMenu.addItem(it)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let breakItem = NSMenuItem(title: "Break length", action: nil, keyEquivalent: "")
        let breakMenu = NSMenu()
        for s in [10, 20, 30, 60] {
            let it = NSMenuItem(title: "\(s) sec", action: #selector(setBreakLen(_:)), keyEquivalent: "")
            it.target = self; it.tag = s; it.state = (s == breakSeconds) ? .on : .off
            breakMenu.addItem(it)
        }
        breakItem.submenu = breakMenu
        menu.addItem(breakItem)

        let blinkItem = NSMenuItem(title: "Blink reminders", action: nil, keyEquivalent: "")
        let blinkMenu = NSMenu()
        for m in [0, 3, 5, 10] {
            let it = NSMenuItem(title: m == 0 ? "Off" : "Every \(m) min",
                                action: #selector(setBlinkInterval(_:)), keyEquivalent: "")
            it.target = self; it.tag = m; it.state = (m == blinkMinutes) ? .on : .off
            blinkMenu.addItem(it)
        }
        blinkMenu.addItem(.separator())
        let nudgeHeader = NSMenuItem(title: "Nudge", action: nil, keyEquivalent: "")
        nudgeHeader.isEnabled = false
        blinkMenu.addItem(nudgeHeader)
        for (i, scope) in BlinkScope.allCases.enumerated() {
            let it = NSMenuItem(title: scope.label, action: #selector(setBlinkScope(_:)), keyEquivalent: "")
            it.target = self; it.tag = i; it.state = (scope == blinkScope) ? .on : .off
            blinkMenu.addItem(it)
        }

        blinkMenu.addItem(.separator())
        let styleHeader = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        styleHeader.isEnabled = false
        blinkMenu.addItem(styleHeader)
        for (i, style) in BlinkStyle.allCases.enumerated() {
            let it = NSMenuItem(title: style.label, action: #selector(setBlinkStyle(_:)), keyEquivalent: "")
            it.target = self; it.tag = i; it.state = (style == blinkStyle) ? .on : .off
            blinkMenu.addItem(it)
        }
        blinkItem.submenu = blinkMenu
        menu.addItem(blinkItem)

        menu.addItem(.separator())

        let guardItem = NSMenuItem(title: "Hold breaks during calls & video",
                                   action: #selector(toggleAutoPause), keyEquivalent: "")
        guardItem.target = self
        guardItem.state = autoPause ? .on : .off
        menu.addItem(guardItem)

        let naturalItem = NSMenuItem(title: "Count time away as a break",
                                     action: #selector(toggleNaturalBreaks), keyEquivalent: "")
        naturalItem.target = self
        naturalItem.state = naturalBreaks ? .on : .off
        menu.addItem(naturalItem)

        menu.addItem(.separator())

        addItem(to: menu, "Delete rest history…", #selector(eraseHistory))
        if ProcessInfo.processInfo.environment["HEARTEYES_DIAGNOSTICS"] == "1" {
            addItem(to: menu, "Copy today's ledger (JSON)", #selector(copyLedgerJSON))
        }

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        switch SMAppService.mainApp.status {
        case .enabled:
            login.state = .on
        case .requiresApproval:
            login.state = .mixed
            login.attributedTitle = menuTitle("Launch at login", subtitle: "approve in System Settings")
        default:
            login.state = .off
        }
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit HeartEyes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        menu.addItem(it)
    }

    private func secondaryTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.menuFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        infoItem?.title = statusInfoText()

        let looming: Hold? = (autoPause && !onBreak && !isPaused && currentHold == nil)
            ? Presence.hold() : nil
        if let looming {
            forecastItem?.attributedTitle = secondaryTitle(looming.forecast)
            forecastItem?.isHidden = false
        } else {
            forecastItem?.isHidden = true
        }
    }

    @objc private func takeBreakNow() { startBreak() }

    @objc private func openReflection() {
        let now = Date()
        let summary = WeekSummary(records: ledger.allDays(asOf: now), asOf: now)
        reflection = ReflectionWindowController(summary: summary, now: now)
        reflection?.present()
    }

    @objc private func eraseHistory() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete your rest history?"
        alert.informativeText = """
            HeartEyes keeps a local record of your screen time and breaks, coarse to the hour and \
            ninety days deep. It has never left this Mac. Deleting it cannot be undone.
            """
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ledger.forget()
        history.erase()
        ledger.resync(now: Date())
        buildMenu()
    }

    @objc private func copyLedgerJSON() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(ledger.allDays(asOf: Date())),
              let text = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if !isPaused { resetCountdown(); ledger.resync(now: Date()) }
        updateStatusTitle()
        buildMenu()
    }

    @objc private func openGifPicker() {
        if let picker = gifPicker { picker.show(); return }
        let picker = GifPicker(currentPath: gifPath, storeDir: appSupportDir())
        picker.onChange = { [weak self] path, label in
            guard let self = self else { return }
            self.gifPath = path
            self.gifLabel = label
            self.buildMenu()
        }
        picker.onClose = { [weak self] in self?.gifPicker = nil }
        gifPicker = picker
        picker.show()
    }

    private func appSupportDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HeartEyes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func menuTitle(_ title: String, subtitle: String) -> NSAttributedString {
        let trimmed = subtitle.count > 30 ? subtitle.prefix(29) + "…" : subtitle[...]
        let s = NSMutableAttributedString(string: title + "\n", attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor,
        ])
        s.append(NSAttributedString(string: String(trimmed), attributes: [
            .font: NSFont.menuFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return s
    }

    private func menuThumbnail(for path: String) -> NSImage? {
        if let cached = thumbnailCache, cached.path == path { return cached.image }
        guard let source = NSImage(contentsOfFile: path),
              source.size.width > 0, source.size.height > 0 else { return nil }
        let side: CGFloat = 22
        let thumb = NSImage(size: NSSize(width: side, height: side))
        thumb.lockFocus()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side), xRadius: 5, yRadius: 5).addClip()
        let scale = max(side / source.size.width, side / source.size.height)
        let w = source.size.width * scale, h = source.size.height * scale
        source.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        thumb.unlockFocus()
        thumbnailCache = (path, thumb)
        return thumb
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        workMinutes = sender.tag
        if !onBreak { resetCountdown() }
        buildMenu()
    }

    @objc private func setBreakLen(_ sender: NSMenuItem) {
        breakSeconds = sender.tag
        ledger.setRestThreshold(naturalRestThreshold)
        buildMenu()
    }

    @objc private func setBlinkInterval(_ sender: NSMenuItem) {
        let changed = sender.tag != blinkMinutes
        blinkMinutes = sender.tag
        resetBlinkCountdown()
        buildMenu()
        guard changed, blinkMinutes > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            BlinkNudge.shared.play(from: self.statusItem, style: self.blinkStyle, scope: self.blinkScope)
            guard !UserDefaults.standard.bool(forKey: Keys.blinkExplained) else { return }
            UserDefaults.standard.set(true, forKey: Keys.blinkExplained)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { self.explainBlink() }
        }
    }

    @objc private func setBlinkStyle(_ sender: NSMenuItem) {
        let styles = BlinkStyle.allCases
        guard styles.indices.contains(sender.tag) else { return }
        blinkStyle = styles[sender.tag]
        buildMenu()
        previewBlink()
    }

    @objc private func setBlinkScope(_ sender: NSMenuItem) {
        let scopes = BlinkScope.allCases
        guard scopes.indices.contains(sender.tag) else { return }
        blinkScope = scopes[sender.tag]
        if blinkScope == .wholeScreen, (1..<10).contains(blinkMinutes) {
            blinkMinutes = 10
            resetBlinkCountdown()
        }
        buildMenu()
        previewBlink()
    }

    private func previewBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            BlinkNudge.shared.play(from: self.statusItem, style: self.blinkStyle, scope: self.blinkScope)
        }
    }

    private func explainBlink() {
        guard let button = statusItem.button else { return }
        let width: CGFloat = 214

        let label = NSTextField(wrappingLabelWithString:
            "That flutter is your cue to blink.\nA few slow ones — your eyes will thank you.")
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        label.textColor = .labelColor
        label.preferredMaxLayoutWidth = width
        let height = label.sizeThatFits(NSSize(width: width, height: .greatestFiniteMagnitude)).height
        label.frame = NSRect(x: 16, y: 14, width: width, height: height)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width + 32, height: height + 28))
        content.addSubview(label)
        let controller = NSViewController()
        controller.view = content

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.contentSize = content.frame.size
        popover.behavior = .applicationDefined
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        blinkPopover = popover

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.blinkPopover?.performClose(nil)
            self?.blinkPopover = nil
        }
    }

    @objc private func toggleAutoPause() {
        autoPause.toggle()
        if !autoPause { clearHold() }
        buildMenu()
        updateStatusTitle()
    }

    @objc private func toggleNaturalBreaks() {
        naturalBreaks.toggle()
        buildMenu()
    }

    private var runningTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        if service.status != .enabled, runningTranslocated {
            let alert = NSAlert()
            alert.messageText = "Move HeartEyes to Applications first"
            alert.informativeText = "HeartEyes is running from a temporary copy that macOS makes "
                + "for apps opened from a download. A login item set up now would stop working after "
                + "you restart. Drag HeartEyes into your Applications folder, reopen it, then turn "
                + "this on."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval { promptLoginApproval() }
            }
        } catch {
            presentLoginError(error)
        }
        buildMenu()
    }

    private func promptLoginApproval() {
        let alert = NSAlert()
        alert.messageText = "One more step to launch at login"
        alert.informativeText = "macOS needs you to allow HeartEyes under System Settings › "
            + "General › Login Items. It'll then open quietly each time you sign in."
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func presentLoginError(_ error: Error) {
        NSSound.beep()
        let alert = NSAlert()
        alert.messageText = "Couldn't change launch at login"
        alert.informativeText = (error as NSError).localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
