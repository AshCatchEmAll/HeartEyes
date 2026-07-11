import Cocoa

final class ReflectionWindowController: NSWindowController {

    private static let ink = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.55, alpha: 1)
    private static let panelTop = NSColor(srgbRed: 0.12, green: 0.11, blue: 0.15, alpha: 1)
    private static let panelBottom = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.07, alpha: 1)

    convenience init(summary: WeekSummary, now: Date, calendar: Calendar = .current) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "This week"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Self.panelBottom
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentView = Self.buildContent(summary: summary, now: now, calendar: calendar)
        window.center()
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private static func buildContent(summary: WeekSummary, now: Date, calendar: Calendar) -> NSView {
        let root = GradientView(top: panelTop, bottom: panelBottom)
        root.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 46, left: 32, bottom: 26, right: 32)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])

        stack.addArrangedSubview(label("This week", size: 13, weight: .semibold,
                                       color: ink, tracking: 1.4, upper: true))
        stack.setCustomSpacing(3, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label(rangeText(now: now, calendar: calendar),
                                       size: 12, weight: .regular, color: faint))

        if summary.isEmpty {
            stack.setCustomSpacing(40, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(label("Nothing to reflect on yet.", size: 17, weight: .medium, color: primary))
            stack.setCustomSpacing(8, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(wrap(label(
                "Use your Mac for a while with HeartEyes running, and your week will start to take shape here.",
                size: 13, color: secondary), width: 396))
            return frame(root)
        }

        stack.setCustomSpacing(30, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label("LONGEST TIME WITHOUT A BREAK", size: 11, weight: .semibold,
                                       color: faint, tracking: 1.2))
        stack.setCustomSpacing(6, after: stack.arrangedSubviews.last!)
        let hero = label(durationLong(summary.longestStretchSeconds), size: 52, weight: .bold, color: primary)
        hero.font = .monospacedDigitSystemFont(ofSize: 52, weight: .bold)
        stack.addArrangedSubview(hero)
        stack.setCustomSpacing(3, after: hero)
        stack.addArrangedSubview(label(heroWhen(summary, calendar: calendar),
                                       size: 12.5, weight: .regular, color: secondary))
        stack.setCustomSpacing(9, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label("The shorter this is, the easier on your eyes.",
                                       size: 12.5, weight: .regular, color: secondary))

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label("DAY BY DAY", size: 11, weight: .semibold, color: faint, tracking: 1.2))
        stack.setCustomSpacing(3, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(label("point at a bar to see that day", size: 11, weight: .regular,
                                       color: NSColor.white.withAlphaComponent(0.32)))
        stack.setCustomSpacing(14, after: stack.arrangedSubviews.last!)
        let chart = WeekBarsView(days: summary.days, ink: ink, now: now, calendar: calendar)
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 132).isActive = true
        chart.widthAnchor.constraint(equalToConstant: 396).isActive = true
        stack.addArrangedSubview(chart)

        stack.setCustomSpacing(26, after: chart)
        stack.addArrangedSubview(statsRow(summary))

        if let note = clusterNote(summary) {
            stack.setCustomSpacing(22, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(noteRow(note))
        }

        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.widthAnchor.constraint(equalToConstant: 396).isActive = true
        stack.addArrangedSubview(rule)
        stack.setCustomSpacing(14, after: rule)
        stack.addArrangedSubview(wrap(label(
            "HeartEyes measures how your screen time was shaped — not your eyes. It stays on this Mac, and you can delete it any time.",
            size: 11.5, color: faint), width: 396))

        return frame(root)
    }

    private static func frame(_ root: NSView) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 600))
        container.wantsLayer = true
        container.layer?.backgroundColor = panelBottom.cgColor
        root.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private static func statsRow(_ s: WeekSummary) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 396).isActive = true

        let ratio = s.restRatio.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
        row.addArrangedSubview(statTile(value: ratio, caption: "of screen time\nspent resting"))
        row.addArrangedSubview(statTile(value: "\(s.breaksCompleted)",
                                        caption: s.breaksSkipped > 0 ? "breaks taken\n\(s.breaksSkipped) skipped"
                                                                     : "breaks taken\nnone skipped"))
        row.addArrangedSubview(statTile(value: s.totalHeldSeconds > 0 ? durationLong(s.totalHeldSeconds) : "none",
                                        caption: "withheld during\ncalls & video"))
        return row
    }

    private static func statTile(value: String, caption: String) -> NSView {
        let tile = NSView()
        tile.wantsLayer = true
        tile.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        tile.layer?.cornerRadius = 12
        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.heightAnchor.constraint(equalToConstant: 92).isActive = true

        let v = label(value, size: 22, weight: .semibold, color: primary)
        v.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        let c = label(caption, size: 11, weight: .regular, color: secondary)
        c.maximumNumberOfLines = 2

        let s = NSStackView(views: [v, c])
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 5
        s.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(s)
        NSLayoutConstraint.activate([
            s.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 13),
            s.trailingAnchor.constraint(lessThanOrEqualTo: tile.trailingAnchor, constant: -10),
            s.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
        ])
        return tile
    }

    private static func noteRow(_ text: String) -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = ink.withAlphaComponent(0.9).cgColor
        dot.layer?.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(dot)

        let text = wrap(label(text, size: 12.5, weight: .regular, color: secondary), width: 372)
        holder.addSubview(text)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            dot.topAnchor.constraint(equalTo: holder.topAnchor, constant: 6),
            text.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            text.topAnchor.constraint(equalTo: holder.topAnchor),
            text.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            text.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            holder.widthAnchor.constraint(equalToConstant: 396),
        ])
        return holder
    }

    private static func heroWhen(_ s: WeekSummary, calendar: Calendar) -> String {
        guard let start = s.longestStretchStart else { return "no long stretches yet this week" }
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEEE")
        let weekday = df.string(from: start)
        return "on \(weekday), starting \(timeOfDay(start, calendar: calendar))"
    }

    private static func timeOfDay(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0
        var twelve = h % 12
        if twelve == 0 { twelve = 12 }
        let period = h < 12 ? "am" : "pm"
        return m == 0 ? "\(twelve)\(period)" : String(format: "%d:%02d%@", twelve, m, period)
    }

    private static func clusterNote(_ s: WeekSummary) -> String? {
        guard let c = s.skipCluster else { return nil }
        let from = clock(c.startHour), to = clock(c.startHour + 3)
        return "Most of the breaks you skipped fell between \(from) and \(to). "
             + "A shorter work interval in that stretch might be easier to keep."
    }

    private static func rangeText(now: Date, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMMd")
        let start = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        return "\(df.string(from: start)) – \(df.string(from: now))"
    }

    private static func durationLong(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 1 { return "under a minute" }
        if m < 60 { return "\(m)m" }
        let h = m / 60, rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
    }

    private static func clock(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        let period = h < 12 ? "am" : "pm"
        var twelve = h % 12
        if twelve == 0 { twelve = 12 }
        return "\(twelve)\(period)"
    }

    private static let primary = NSColor.white.withAlphaComponent(0.95)
    private static let secondary = NSColor.white.withAlphaComponent(0.62)
    private static let faint = NSColor.white.withAlphaComponent(0.40)

    private static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                              color: NSColor, tracking: CGFloat = 0, upper: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: upper ? text.uppercased() : text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.translatesAutoresizingMaskIntoConstraints = false
        if tracking != 0 {
            field.attributedStringValue = NSAttributedString(
                string: upper ? text.uppercased() : text,
                attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                             .foregroundColor: color, .kern: tracking])
        }
        return field
    }

    private static func wrap(_ field: NSTextField, width: CGFloat) -> NSTextField {
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.preferredMaxLayoutWidth = width
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }
}

final class WeekBarsView: NSView {
    private let days: [DayRecord]
    private let ink: NSColor
    private let todayKey: String
    private let weekdayInitials: [String]
    private let weekdayFull: [String]

    private var hoveredIndex: Int? {
        didSet { if oldValue != hoveredIndex { needsDisplay = true } }
    }
    var forcedHoverIndex: Int? {
        didSet { if oldValue != forcedHoverIndex { needsDisplay = true } }
    }
    private var activeHover: Int? { forcedHoverIndex ?? hoveredIndex }

    init(days: [DayRecord], ink: NSColor, now: Date, calendar: Calendar) {
        self.days = days
        self.ink = ink
        let key: (Date) -> String = { date in
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        self.todayKey = key(now)
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        let fulls: [String] = days.map { rec in
            guard let d = ReflectionWindowController.parseDay(rec.day, calendar: calendar) else { return "" }
            return df.weekdaySymbols[calendar.component(.weekday, from: d) - 1]
        }
        self.weekdayFull = fulls
        self.weekdayInitials = fulls.map { String($0.prefix(1)) }
        super.init(frame: .zero)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }

    private struct Geometry { let plot: NSRect; let barW: CGFloat; let gap: CGFloat; let scaleTop: Double }

    private func geometry() -> Geometry {
        let labelH: CGFloat = 18
        let plot = NSRect(x: 0, y: labelH, width: bounds.width, height: bounds.height - labelH)
        let peak = days.map { $0.longestStretchSeconds }.max() ?? 0
        let step = 1800.0
        let scaleTop = max(3600.0, (Double(max(peak, 1)) / step).rounded(.up) * step)
        let gap: CGFloat = 14
        let barW = (plot.width - gap * CGFloat(days.count - 1)) / CGFloat(days.count)
        return Geometry(plot: plot, barW: barW, gap: gap, scaleTop: scaleTop)
    }

    private func barHeight(_ rec: DayRecord, _ g: Geometry) -> CGFloat {
        guard rec.longestStretchSeconds > 0 else { return 2 }
        return max(g.plot.height * CGFloat(min(Double(rec.longestStretchSeconds) / g.scaleTop, 1)), 3)
    }

    private func columnX(_ i: Int, _ g: Geometry) -> CGFloat { g.plot.minX + CGFloat(i) * (g.barW + g.gap) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        hoveredIndex = columnIndex(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseExited(with event: NSEvent) { hoveredIndex = nil }

    private func columnIndex(at p: CGPoint) -> Int? {
        let g = geometry()
        for i in 0..<days.count {
            let x0 = columnX(i, g) - g.gap / 2
            if p.x >= x0 && p.x < x0 + g.barW + g.gap { return i }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let g = geometry()
        let plot = g.plot

        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: plot.minX, y: plot.minY + 0.5))
        ctx.addLine(to: CGPoint(x: plot.maxX, y: plot.minY + 0.5))
        ctx.strokePath()

        let refY = plot.minY + plot.height * CGFloat(min(3600 / g.scaleTop, 1))
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.11).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [2, 3])
        ctx.move(to: CGPoint(x: plot.minX, y: refY.rounded() + 0.5))
        ctx.addLine(to: CGPoint(x: plot.maxX, y: refY.rounded() + 0.5))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        let refLabel = NSAttributedString(string: "1 hour", attributes: [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.34)])
        let labelY = min(refY + 3, plot.maxY - refLabel.size().height)
        refLabel.draw(at: CGPoint(x: plot.maxX - refLabel.size().width, y: labelY))

        let hover = activeHover
        for (i, rec) in days.enumerated() {
            let x = columnX(i, g)
            let isToday = rec.day == todayKey
            let hasData = rec.longestStretchSeconds > 0

            var alpha: CGFloat = !hasData ? 0.14 : (isToday ? 0.95 : 0.58)
            if let h = hover { alpha = (h == i) ? (hasData ? 1.0 : 0.32) : alpha * 0.6 }
            drawBar(ctx, x: x, y: plot.minY, w: g.barW, h: barHeight(rec, g), color: ink.withAlphaComponent(alpha))

            let initial = i < weekdayInitials.count ? weekdayInitials[i] : ""
            let emphasised = isToday || hover == i
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: emphasised ? .semibold : .regular),
                .foregroundColor: isToday ? ink.withAlphaComponent(0.9)
                                          : NSColor.white.withAlphaComponent(hover == i ? 0.7 : 0.38)]
            let s = NSAttributedString(string: initial, attributes: attrs)
            s.draw(at: CGPoint(x: x + (g.barW - s.size().width) / 2, y: 0))
        }

        if let h = hover { drawTooltip(ctx, index: h, g: g) }
    }

    private func drawBar(_ ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor) {
        let r = min(5, w / 2)
        let path = CGPath(roundedRect: NSRect(x: x, y: y, width: w, height: h),
                          cornerWidth: r, cornerHeight: r, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    private func tooltipContent(_ i: Int) -> (title: String, lines: [String]) {
        let rec = days[i]
        let title = rec.day == todayKey ? "Today" : (i < weekdayFull.count ? weekdayFull[i] : "")
        guard rec.activeSeconds > 0 || rec.breaksCompleted > 0 || rec.breaksSkipped > 0 else {
            return (title, ["No screen time"])
        }
        var lines = ["\(durationShort(rec.longestStretchSeconds)) longest run"]
        if rec.breaksCompleted == 0 && rec.breaksSkipped == 0 {
            lines.append("no breaks")
        } else {
            var b = "\(rec.breaksCompleted) break\(rec.breaksCompleted == 1 ? "" : "s") taken"
            if rec.breaksSkipped > 0 { b += ", \(rec.breaksSkipped) skipped" }
            lines.append(b)
        }
        return (title, lines)
    }

    private func drawTooltip(_ ctx: CGContext, index: Int, g: Geometry) {
        let content = tooltipContent(index)
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)]
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.60)]
        let title = NSAttributedString(string: content.title, attributes: titleAttr)
        let bodies = content.lines.map { NSAttributedString(string: $0, attributes: bodyAttr) }

        let padH: CGFloat = 11, padV: CGFloat = 9, titleGap: CGFloat = 5, lineGap: CGFloat = 3
        let contentW = max(title.size().width, bodies.map { $0.size().width }.max() ?? 0)
        var textH = title.size().height + titleGap
        for (j, b) in bodies.enumerated() { textH += b.size().height; if j < bodies.count - 1 { textH += lineGap } }
        let boxW = (contentW + padH * 2).rounded()
        let boxH = (textH + padV * 2).rounded()

        let barTop = g.plot.minY + barHeight(days[index], g)
        var boxX = columnX(index, g) + g.barW / 2 - boxW / 2
        boxX = max(0, min(boxX, bounds.width - boxW))
        var boxY = barTop + 8
        if boxY + boxH > bounds.height { boxY = bounds.height - boxH }
        boxY = max(g.plot.minY, boxY)
        let box = NSRect(x: boxX, y: boxY, width: boxW, height: boxH)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 14,
                      color: NSColor.black.withAlphaComponent(0.55).cgColor)
        let path = CGPath(roundedRect: box, cornerWidth: 9, cornerHeight: 9, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(srgbRed: 0.11, green: 0.11, blue: 0.14, alpha: 0.98).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        var y = box.maxY - padV - title.size().height
        title.draw(at: CGPoint(x: box.minX + padH, y: y))
        y -= titleGap
        for b in bodies {
            y -= b.size().height
            b.draw(at: CGPoint(x: box.minX + padH, y: y))
            y -= lineGap
        }
    }

    private func durationShort(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 1 { return "under a minute" }
        if m < 60 { return "\(m)m" }
        let h = m / 60, rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
    }
}

extension ReflectionWindowController {
    func debugSetHoveredBar(_ index: Int?) {
        func find(_ v: NSView) -> WeekBarsView? {
            if let w = v as? WeekBarsView { return w }
            for s in v.subviews { if let f = find(s) { return f } }
            return nil
        }
        if let content = window?.contentView { find(content)?.forcedHoverIndex = index }
    }

    static func parseDay(_ day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c)
    }
}

final class GradientView: NSView {
    private let top: NSColor
    private let bottom: NSColor
    init(top: NSColor, bottom: NSColor) {
        self.top = top; self.bottom = bottom
        super.init(frame: .zero)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateLayer() {
        let g = CAGradientLayer()
        g.frame = bounds
        g.colors = [top.cgColor, bottom.cgColor]
        g.locations = [0, 1]
        layer?.sublayers?.removeAll { $0 is CAGradientLayer }
        layer?.insertSublayer(g, at: 0)
    }
    override func layout() { super.layout(); layer?.sublayers?.forEach { if $0 is CAGradientLayer { $0.frame = bounds } } }
}
