import Cocoa

final class AgentConnect: NSObject, NSWindowDelegate {
    private struct Client {
        let name: String
        let hint: String
        let snippet: (String) -> String
    }

    private static let clients: [Client] = [
        Client(name: "Claude Code",
               hint: "Paste into a terminal, then restart Claude Code.",
               snippet: { "claude mcp add -s user hearteyes -- \"\($0)\" --mcp" }),
        Client(name: "Codex",
               hint: "Add to ~/.codex/config.toml, then restart Codex.",
               snippet: { """
                   [mcp_servers.hearteyes]
                   command = "\(escaped($0))"
                   args = ["--mcp"]
                   """ }),
        Client(name: "Claude Desktop & others",
               hint: "Add to your client's MCP config — Claude Desktop's claude_desktop_config.json, "
                   + "Cursor's mcp.json — then restart it.",
               snippet: { """
                   {
                     "mcpServers": {
                       "hearteyes": {
                         "command": "\(escaped($0))",
                         "args": ["--mcp"]
                       }
                     }
                   }
                   """ }),
    ]

    private static func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static var executablePath: String {
        Bundle.main.executablePath ?? "/Applications/HeartEyes.app/Contents/MacOS/HeartEyes"
    }

    static var translocated: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    let window = BreakPickerWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                                   styleMask: [.titled, .closable],
                                   backing: .buffered,
                                   defer: false)
    private let picker = NSSegmentedControl()
    private let code = NSTextField(wrappingLabelWithString: "")
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let copy = NSButton(title: "Copy", target: nil, action: nil)

    var onClose: (() -> Void)?

    override init() {
        super.init()
        window.title = "Connect an Agent"
        window.delegate = self
        window.isReleasedWhenClosed = false
        let content = buildContent()
        window.contentView = content
        select(0)
        content.layoutSubtreeIfNeeded()
        window.setContentSize(content.fittingSize)
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    private func buildContent() -> NSView {
        let width: CGFloat = 440
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width + 40, height: 420))

        let heading = label("Let an agent set HeartEyes up", size: 15, weight: .semibold)
        let intro = wrapped(
            "HeartEyes has a built-in MCP server. Point your agent at it once and it can build a routine, "
            + "pick GIFs and lines per task, or read your week — only when you ask. Hard mode stays yours.",
            size: 11.5, width: width)

        picker.segmentCount = Self.clients.count
        for (i, c) in Self.clients.enumerated() { picker.setLabel(c.name, forSegment: i) }
        picker.selectedSegment = 0
        picker.target = self
        picker.action = #selector(pick)
        picker.translatesAutoresizingMaskIntoConstraints = false

        code.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        code.textColor = .labelColor
        code.isSelectable = true
        code.lineBreakMode = .byCharWrapping
        code.preferredMaxLayoutWidth = width - 24
        code.translatesAutoresizingMaskIntoConstraints = false
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 8
        box.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(code)

        copy.bezelStyle = .rounded
        copy.target = self
        copy.action = #selector(copySnippet)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = width - 90
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let actions = NSStackView(views: [copy, hint])
        actions.orientation = .horizontal
        actions.alignment = .firstBaseline
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false

        let column = NSStackView(views: [heading, intro, picker, box, actions])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.setCustomSpacing(16, after: intro)
        column.setCustomSpacing(12, after: picker)
        column.setCustomSpacing(10, after: box)
        column.translatesAutoresizingMaskIntoConstraints = false

        if Self.translocated {
            let warning = wrapped(
                "HeartEyes is running from a temporary copy macOS makes for downloaded apps, so this path "
                + "won't last. Move HeartEyes to Applications, reopen it, and copy from here again.",
                size: 11, width: width)
            warning.textColor = .systemOrange
            column.setCustomSpacing(14, after: actions)
            column.addArrangedSubview(warning)
        }
        let note = wrapped("The path is baked in — if you move HeartEyes later, connect again.", size: 11, width: width)
        column.setCustomSpacing(14, after: column.arrangedSubviews.last!)
        column.addArrangedSubview(note)
        root.addSubview(column)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        done.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)
        root.addSubview(done)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            column.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            column.widthAnchor.constraint(equalToConstant: width),
            picker.widthAnchor.constraint(equalTo: column.widthAnchor),
            box.widthAnchor.constraint(equalTo: column.widthAnchor),
            actions.widthAnchor.constraint(equalTo: column.widthAnchor),
            code.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            code.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            code.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            code.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.topAnchor.constraint(equalTo: column.bottomAnchor, constant: 16),
            separator.bottomAnchor.constraint(equalTo: done.topAnchor, constant: -14),
            done.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            done.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        return root
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        return l
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

    private func select(_ index: Int) {
        let client = Self.clients[index]
        code.stringValue = client.snippet(Self.executablePath)
        hint.stringValue = client.hint
        copy.title = "Copy"
    }

    @objc private func pick() { select(picker.selectedSegment) }

    @objc private func copySnippet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.stringValue, forType: .string)
        copy.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.copy.title = "Copy" }
    }

    @objc private func closeWindow() { window.performClose(nil) }
}
