import Cocoa

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class RoutineStrip: NSView {
    enum Kind { case rest, turns, placed }
    struct Item { let number: Int; let name: String; let kind: Kind }

    static let width: CGFloat = 440

    var items: [Item] = [] { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }

    private let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let pillH: CGFloat = 22, padX: CGFloat = 9, gap: CGFloat = 6, rowGap: CGFloat = 6

    override var isFlipped: Bool { true }

    private func textColor(_ kind: Kind) -> NSColor {
        switch kind {
        case .placed: return .controlAccentColor
        case .turns:  return .labelColor
        case .rest:   return .tertiaryLabelColor
        }
    }

    private func pills() -> [(NSRect, Item, NSAttributedString)] {
        var out: [(NSRect, Item, NSAttributedString)] = []
        var x: CGFloat = 0, y: CGFloat = 0
        for item in items {
            let text = NSAttributedString(string: "\(item.number) · \(item.name)",
                                          attributes: [.font: font, .foregroundColor: textColor(item.kind)])
            let w = ceil(text.size().width) + padX * 2
            if x > 0, x + w > Self.width { x = 0; y += pillH + rowGap }
            out.append((NSRect(x: x, y: y, width: w, height: pillH), item, text))
            x += w + gap
        }
        return out
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: pills().last.map { $0.0.maxY } ?? 0)
    }

    override func draw(_ dirtyRect: NSRect) {
        for (rect, item, text) in pills() {
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: pillH / 2, yRadius: pillH / 2)
            switch item.kind {
            case .placed:
                NSColor.controlAccentColor.withAlphaComponent(0.16).setFill(); path.fill()
            case .turns:
                NSColor.labelColor.withAlphaComponent(0.08).setFill(); path.fill()
            case .rest:
                NSColor.separatorColor.setStroke(); path.lineWidth = 1; path.stroke()
            }
            let size = text.size()
            text.draw(at: NSPoint(x: rect.minX + padX, y: rect.minY + (pillH - size.height) / 2))
        }
    }
}

final class TaskCard: NSView, NSTextFieldDelegate {
    private static let durations = [20, 30, 45, 60, 90, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600]

    private(set) var task: Activity
    private var length: Int

    var onChange: (() -> Void)?
    var onRemove: (() -> Void)?
    var onChooseFile: ((@escaping (String?) -> Void) -> Void)?
    var onPasteLink: ((@escaping (String?) -> Void) -> Void)?

    let nameField = NSTextField()
    private let durationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let kindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let everyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let onField = NSTextField()
    private let lineField = NSTextField()
    private let gifPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    init(task: Activity, length: Int) {
        self.task = task
        self.length = length
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.05).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        nameField.stringValue = task.name
        nameField.placeholderString = "What to do — e.g. 10 push-ups"
        nameField.font = .systemFont(ofSize: 13)
        nameField.delegate = self
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var options = Self.durations
        if !options.contains(task.seconds) { options.append(task.seconds); options.sort() }
        for s in options {
            durationPopup.addItem(withTitle: Routine.duration(s))
            durationPopup.lastItem?.tag = s
        }
        durationPopup.selectItem(withTag: task.seconds)
        durationPopup.target = self
        durationPopup.action = #selector(durationChanged)
        durationPopup.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let remove = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove")!,
                              target: self, action: #selector(removeTapped))
        remove.isBordered = false
        remove.contentTintColor = .secondaryLabelColor
        remove.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let top = NSStackView(views: [nameField, durationPopup, remove])
        top.orientation = .horizontal
        top.spacing = 8

        for title in ["Takes turns", "Every Nth break", "On breaks…"] { kindPopup.addItem(withTitle: title) }
        kindPopup.target = self
        kindPopup.action = #selector(kindChanged)
        kindPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true

        everyPopup.target = self
        everyPopup.action = #selector(everyChanged)
        everyPopup.widthAnchor.constraint(equalToConstant: 84).isActive = true

        onField.placeholderString = "e.g. 3, 7, 12"
        onField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        onField.delegate = self
        onField.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let when = NSStackView(views: [kindPopup, everyPopup, onField])
        when.orientation = .horizontal
        when.spacing = 8

        lineField.stringValue = task.line ?? ""
        lineField.placeholderString = "A line to show with it (optional)"
        lineField.font = .systemFont(ofSize: 13)
        lineField.delegate = self
        lineField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        lineField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        gifPopup.target = self
        gifPopup.action = #selector(gifChanged)
        gifPopup.widthAnchor.constraint(equalToConstant: 170).isActive = true

        let extras = NSStackView(views: [lineField, gifPopup])
        extras.orientation = .horizontal
        extras.spacing = 8

        let column = NSStackView(views: [top, when, extras])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            top.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -24),
            extras.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -24),
        ])

        refreshPlacement()
        refreshGif()
    }

    func setLength(_ n: Int) {
        length = n
        if let every = task.placement.every, every > length { task.placement = .every(length) }
        refreshPlacement()
    }

    private func refreshPlacement() {
        everyPopup.removeAllItems()
        for n in 2...max(2, length) {
            everyPopup.addItem(withTitle: Routine.ordinal(n))
            everyPopup.lastItem?.tag = n
        }
        switch task.placement {
        case .turns:
            kindPopup.selectItem(at: 0)
            everyPopup.isHidden = true
            onField.isHidden = true
        case .every(let n):
            kindPopup.selectItem(at: 1)
            everyPopup.selectItem(withTag: n)
            everyPopup.isHidden = false
            onField.isHidden = true
        case .on(let breaks):
            kindPopup.selectItem(at: 2)
            onField.stringValue = breaks.map(String.init).joined(separator: ", ")
            everyPopup.isHidden = true
            onField.isHidden = false
        }
    }

    private func refreshGif() {
        gifPopup.removeAllItems()
        if let gif = task.gif {
            gifPopup.addItem(withTitle: (gif as NSString).lastPathComponent)
            gifPopup.lastItem?.tag = 3
            gifPopup.menu?.addItem(.separator())
        }
        gifPopup.addItem(withTitle: "Same GIF as usual")
        gifPopup.lastItem?.tag = 0
        gifPopup.addItem(withTitle: "Choose a GIF…")
        gifPopup.lastItem?.tag = 1
        gifPopup.addItem(withTitle: "Paste a GIF link…")
        gifPopup.lastItem?.tag = 2
        gifPopup.selectItem(withTag: task.gif == nil ? 0 : 3)
        gifPopup.isEnabled = true
    }

    @objc private func durationChanged() {
        task.seconds = durationPopup.selectedTag()
        onChange?()
    }

    @objc private func removeTapped() { onRemove?() }

    @objc private func kindChanged() {
        switch kindPopup.indexOfSelectedItem {
        case 1:  task.placement = .every(min(3, length))
        case 2:  task.placement = .on([])
        default: task.placement = .turns
        }
        refreshPlacement()
        if case .on = task.placement { window?.makeFirstResponder(onField) }
        onChange?()
    }

    @objc private func everyChanged() {
        task.placement = .every(everyPopup.selectedTag())
        onChange?()
    }

    @objc private func gifChanged() {
        let finish: (String?) -> Void = { [weak self] path in
            guard let self = self else { return }
            if let path { self.task.gif = path }
            self.refreshGif()
            self.onChange?()
        }
        switch gifPopup.selectedTag() {
        case 0:
            task.gif = nil
            refreshGif()
            onChange?()
        case 1:
            onChooseFile?(finish)
        case 2:
            gifPopup.isEnabled = false
            gifPopup.selectItem(withTag: task.gif == nil ? 0 : 3)
            gifPopup.selectedItem?.title = "Fetching…"
            onPasteLink?(finish)
        default:
            break
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        if field === nameField {
            task.name = text
        } else if field === lineField {
            task.line = text.isEmpty ? nil : text
        } else if field === onField {
            task.placement = .on(Routine.parseBreaks(text, length: length))
        }
        onChange?()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === onField, let breaks = task.placement.breaks else { return }
        onField.stringValue = breaks.map(String.init).joined(separator: ", ")
    }
}

final class RoutinePicker: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    static let width: CGFloat = 440
    private static let minHeight: CGFloat = 400

    let window = BreakPickerWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
                                   styleMask: [.titled, .closable, .resizable],
                                   backing: .buffered,
                                   defer: false)
    private var routine: Routine
    private var enabled: Bool
    private let workMinutes: Int
    private let breakSeconds: Int
    private let storeDir: URL

    private let toggle = NSSwitch()
    private let body = NSStackView()
    private let lengthField = NSTextField()
    private let lengthStepper = NSStepper()
    private let lengthNote = NSTextField(labelWithString: "")
    private let taskList = NSStackView()
    private let stripTitle = NSTextField(labelWithString: "")
    private let strip = RoutineStrip()
    private let scroll = NSScrollView()
    private let document = FlippedView()
    private let bar = NSStackView()
    private var cards: [TaskCard] = []
    private var fittedHeight: CGFloat = 0

    var onChange: ((Routine, Bool) -> Void)?
    var onPreview: (() -> Void)?
    var onClose: (() -> Void)?

    init(routine: Routine, enabled: Bool, workMinutes: Int, breakSeconds: Int, storeDir: URL) {
        self.routine = routine
        self.enabled = enabled
        self.workMinutes = workMinutes
        self.breakSeconds = breakSeconds
        self.storeDir = storeDir
        super.init()

        window.title = "Break Routine"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.contentView = buildContent()
        rebuildCards()
        refreshLength()
        refreshStrip()
        applyEnabled()
        fitWindow(animate: false)
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    private var effective: Routine {
        var r = routine
        r.tasks = r.tasks.filter { !$0.name.isEmpty }
        return r
    }

    private func buildContent() -> NSView {
        let width = Self.width
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width + 40, height: 720))

        let heading = pickerLabel("Give each break something to do", size: 15, weight: .semibold)
        toggle.state = enabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggled)
        let headSpacer = NSView()
        headSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let headRow = NSStackView(views: [heading, headSpacer, toggle])
        headRow.orientation = .horizontal
        headRow.translatesAutoresizingMaskIntoConstraints = false

        let intro = wrapped(
            "Nothing new will interrupt you — this only decides what's on the screen when a break "
            + "you'd take anyway comes round. Done only unlocks after the first \(min(20, breakSeconds)) seconds, "
            + "so your eyes still get theirs.", size: 11.5, width: width)

        let start = NSPopUpButton(frame: .zero, pullsDown: true)
        start.addItem(withTitle: "Start from a routine…")
        for t in Routine.templates { start.addItem(withTitle: t.name) }
        start.menu?.addItem(.separator())
        start.addItem(withTitle: "Start over")
        start.target = self
        start.action = #selector(pickTemplate(_:))
        start.translatesAutoresizingMaskIntoConstraints = false

        lengthField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        lengthField.alignment = .center
        lengthField.delegate = self
        lengthField.widthAnchor.constraint(equalToConstant: 40).isActive = true
        lengthStepper.minValue = Double(Routine.minLength)
        lengthStepper.maxValue = Double(Routine.maxLength)
        lengthStepper.target = self
        lengthStepper.action = #selector(lengthStepped)
        let lengthRow = NSStackView(views: [pickerLabel("This routine is", size: 13), lengthField, lengthStepper,
                                            pickerLabel("breaks long, then it starts over.", size: 13)])
        lengthRow.orientation = .horizontal
        lengthRow.spacing = 6
        lengthRow.setCustomSpacing(2, after: lengthField)
        lengthRow.translatesAutoresizingMaskIntoConstraints = false
        lengthNote.font = .systemFont(ofSize: 11)
        lengthNote.textColor = .secondaryLabelColor

        taskList.orientation = .vertical
        taskList.alignment = .leading
        taskList.spacing = 10
        taskList.translatesAutoresizingMaskIntoConstraints = false

        let addTask = NSButton(title: "Add a task", target: self, action: #selector(addTaskTapped))
        addTask.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        addTask.imagePosition = .imageLeading
        addTask.bezelStyle = .rounded
        addTask.controlSize = .small
        addTask.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        strip.translatesAutoresizingMaskIntoConstraints = false
        let stripNote = wrapped(
            "Counts the breaks you're actually shown — one held for a call, or skipped because you were "
            + "already away, doesn't count — and starts over each morning.", size: 11, width: width)

        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 8
        body.translatesAutoresizingMaskIntoConstraints = false
        for view in [start, section("The routine"), lengthRow, lengthNote,
                     section("Tasks"), taskList, addTask,
                     stripTitle, strip, stripNote] as [NSView] {
            body.addArrangedSubview(view)
        }
        body.setCustomSpacing(18, after: start)
        body.setCustomSpacing(4, after: lengthRow)
        body.setCustomSpacing(18, after: lengthNote)
        body.setCustomSpacing(18, after: addTask)
        body.setCustomSpacing(10, after: stripTitle)
        body.setCustomSpacing(10, after: strip)

        let column = NSStackView(views: [headRow, intro, body])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.setCustomSpacing(16, after: intro)
        column.translatesAutoresizingMaskIntoConstraints = false

        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scroll)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let preview = NSButton(title: "Preview a break", target: self, action: #selector(previewBreak))
        preview.bezelStyle = .rounded
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        for v in [preview, spacer, done] { bar.addArrangedSubview(v) }
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)
        root.addSubview(bar)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: separator.topAnchor),

            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),

            column.topAnchor.constraint(equalTo: document.topAnchor, constant: 18),
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -18),
            column.widthAnchor.constraint(equalToConstant: width),
            headRow.widthAnchor.constraint(equalTo: column.widthAnchor),
            body.widthAnchor.constraint(equalTo: column.widthAnchor),
            taskList.widthAnchor.constraint(equalTo: body.widthAnchor),
            strip.widthAnchor.constraint(equalToConstant: width),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -14),

            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            bar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        return root
    }

    private func section(_ title: String, into label: NSTextField = NSTextField(labelWithString: "")) -> NSTextField {
        label.attributedStringValue = NSAttributedString(string: title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.8,
        ])
        return label
    }

    private func wrapped(_ text: String, size: CGFloat, width: CGFloat) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = .systemFont(ofSize: size)
        l.textColor = .secondaryLabelColor
        l.preferredMaxLayoutWidth = width
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: width).isActive = true
        return l
    }

    private func clear(_ list: NSStackView) {
        for v in list.arrangedSubviews { list.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    private func rebuildCards() {
        clear(taskList)
        cards = routine.tasks.map { TaskCard(task: $0, length: routine.length) }
        for card in cards {
            card.onChange = { [weak self] in self?.changed(structure: false) }
            card.onRemove = { [weak self, weak card] in
                guard let self = self, let card, let i = self.cards.firstIndex(where: { $0 === card }) else { return }
                self.routine.tasks.remove(at: i)
                self.rebuildCards()
                self.changed(structure: true)
            }
            card.onChooseFile = { [weak self] finish in self?.chooseFile(finish) }
            card.onPasteLink = { [weak self] finish in self?.pasteLink(finish) }
            taskList.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: taskList.widthAnchor).isActive = true
        }
        if cards.isEmpty {
            taskList.addArrangedSubview(pickerLabel("No tasks yet — every break stays a plain eye rest.",
                                                    size: 12, color: .tertiaryLabelColor))
        }
    }

    private func refreshLength() {
        lengthField.stringValue = "\(routine.length)"
        lengthStepper.integerValue = routine.length
        lengthNote.stringValue = Routine.cadence(breaks: routine.length, workMinutes: workMinutes)
            + " at your \(workMinutes)-min interval"
    }

    private func refreshStrip() {
        let r = effective
        _ = section("Your \(r.length) breaks", into: stripTitle)
        strip.items = r.slots().enumerated().map { i, task in
            guard let task else { return .init(number: i + 1, name: "eye rest", kind: .rest) }
            return .init(number: i + 1, name: task.name, kind: task.placement == .turns ? .turns : .placed)
        }
    }

    private func applyEnabled() {
        body.alphaValue = enabled ? 1 : 0.45
    }

    private func commit() {
        onChange?(effective, enabled)
    }

    private func changed(structure: Bool) {
        routine.tasks = cards.map(\.task)
        refreshStrip()
        fitWindow(animate: structure)
        commit()
    }

    private var barBlock: CGFloat { bar.fittingSize.height + 1 + 14 + 16 }

    private func fitWindow(animate: Bool) {
        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let total = ceil(document.fittingSize.height + barBlock)
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let cap = max(Self.minHeight, min(total, screen - 40))
        window.contentMinSize = NSSize(width: 480, height: Self.minHeight)
        window.contentMaxSize = NSSize(width: 480, height: cap)

        let current = window.contentRect(forFrameRect: window.frame).height
        let wasFitted = fittedHeight == 0 || abs(current - fittedHeight) < 2
        fittedHeight = cap
        guard wasFitted || current > cap else { return }
        let target = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 480, height: cap))
        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size = target.size
        window.setFrame(frame, display: true, animate: animate)
    }

    @objc private func toggled() {
        enabled = toggle.state == .on
        applyEnabled()
        commit()
    }

    @objc private func pickTemplate(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title, sender.indexOfSelectedItem > 0 else { return }
        routine = Routine.templates.first { $0.name == title }?.routine ?? Routine()
        if !routine.isEmpty, !enabled {
            enabled = true
            toggle.state = .on
            applyEnabled()
        }
        rebuildCards()
        refreshLength()
        changed(structure: true)
    }

    @objc private func addTaskTapped() {
        routine.tasks.append(Activity(name: "", seconds: 45))
        rebuildCards()
        changed(structure: true)
        window.makeFirstResponder(cards.last?.nameField)
    }

    @objc private func lengthStepped() {
        setLength(lengthStepper.integerValue)
        lengthField.stringValue = "\(routine.length)"
    }

    private func setLength(_ n: Int) {
        routine.length = max(Routine.minLength, min(Routine.maxLength, n))
        for card in cards { card.setLength(routine.length) }
        lengthStepper.integerValue = routine.length
        lengthNote.stringValue = Routine.cadence(breaks: routine.length, workMinutes: workMinutes)
            + " at your \(workMinutes)-min interval"
        changed(structure: false)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === lengthField,
              let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), n >= Routine.minLength
        else { return }
        setLength(n)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === lengthField else { return }
        lengthField.stringValue = "\(routine.length)"
    }

    private func chooseFile(_ finish: @escaping (String?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Pick a GIF (or image) to show on this break"
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url, NSImage(contentsOf: url) != nil else { finish(nil); return }
            finish(url.path)
        }
    }

    private func pasteLink(_ finish: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Paste a GIF link"
        alert.informativeText = "A Giphy, Tenor, or direct .gif link."
        alert.addButton(withTitle: "Use it")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://…"
        if let text = NSPasteboard.general.string(forType: .string), GifLoader.normalized(text) != nil {
            field.stringValue = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn,
                  let url = GifLoader.normalized(field.stringValue) else { finish(nil); return }
            GifLoader.fetch(url) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .failure:
                        NSSound.beep()
                        finish(nil)
                    case .success(let data):
                        finish((try? GifLoader.save(data, in: self.storeDir, prune: false))?.path)
                    }
                }
            }
        }
    }

    @objc private func previewBreak() { onPreview?() }

    @objc private func closeWindow() { window.performClose(nil) }
}
