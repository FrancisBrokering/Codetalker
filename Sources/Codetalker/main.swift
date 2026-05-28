import AppKit
import AVFoundation

private enum OverlayMetrics {
    static let collapsedWidth: CGFloat = 14
    static let expandedWidth: CGFloat = 304
    static let collapsedHeight: CGFloat = 188
    static let expandedHeight: CGFloat = 540
}

@MainActor
protocol SideNotchHoverDelegate: AnyObject {
    func sideNotchHoverDidChange(isHovering: Bool)
}

struct CodingSession {
    let sessionID: String
    let name: String
    let elapsedTime: String
    let summary: String
    let isRunning: Bool
    let fallbackColor: NSColor
    let usesBottomIcon: Bool
    let isSelected: Bool

    init(
        sessionID: String,
        name: String,
        elapsedTime: String,
        summary: String,
        isRunning: Bool,
        fallbackColor: NSColor,
        usesBottomIcon: Bool = false,
        isSelected: Bool
    ) {
        self.sessionID = sessionID
        self.name = name
        self.elapsedTime = elapsedTime
        self.summary = summary
        self.isRunning = isRunning
        self.fallbackColor = fallbackColor
        self.usesBottomIcon = usesBottomIcon
        self.isSelected = isSelected
    }
}

private enum DockData {
    static let items: [CodingSession] = [
        CodingSession(
            sessionID: "S-1042",
            name: "Side Notch Polish",
            elapsedTime: "12m 38s",
            summary: "Updated icons and tuned the notch row spacing.",
            isRunning: false,
            fallbackColor: .systemBlue,
            isSelected: false
        ),
        CodingSession(
            sessionID: "S-1043",
            name: "Agent Layout Pass",
            elapsedTime: "4m 11s",
            summary: "Balancing row metadata and status labels.",
            isRunning: true,
            fallbackColor: .systemOrange,
            isSelected: true
        ),
        CodingSession(
            sessionID: "S-1044",
            name: "Resource Bundling",
            elapsedTime: "7m 03s",
            summary: "Bundled image assets for both notch halves.",
            isRunning: false,
            fallbackColor: .systemOrange,
            usesBottomIcon: true,
            isSelected: false
        ),
        CodingSession(
            sessionID: "S-1045",
            name: "Hover Animation",
            elapsedTime: "2m 49s",
            summary: "Testing smoother expand and collapse timing.",
            isRunning: true,
            fallbackColor: .systemPurple,
            usesBottomIcon: true,
            isSelected: false
        ),
        CodingSession(
            sessionID: "S-1046",
            name: "Build Verification",
            elapsedTime: "31s",
            summary: "Confirmed SwiftPM build after UI changes.",
            isRunning: false,
            fallbackColor: .systemBlue,
            usesBottomIcon: true,
            isSelected: false
        )
    ]
}


private enum AppAssets {
    static let codexIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "codexAppIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    static let bottomHalfIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "bottomHalfAppIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
OverlayController.shared.show()
app.run()

@MainActor
final class OverlayController {
    static let shared = OverlayController()
    private var window: SideNotchWindow?
    private var screenFrame: CGRect = .zero
    private var visibleFrame: CGRect = .zero
    private var isExpanded = false
    private var pendingCollapse: DispatchWorkItem?

    func show() {
        let window = SideNotchWindow()
        window.configure()
        let contentView = SideNotchView(frame: window.contentView?.bounds ?? .zero)
        contentView.hoverDelegate = self
        contentView.setExpanded(false, animated: false)
        window.contentView = contentView
        self.window = window
        updateScreenFrames()
        positionWindow(expanded: false, animated: false)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        print("Codetalker overlay shown at \(window.frame)")
        fflush(stdout)
    }

    private func updateScreenFrames() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        screenFrame = screen?.frame ?? .zero
        visibleFrame = screen?.visibleFrame ?? screenFrame
    }

    private func positionWindow(expanded: Bool, animated: Bool) {
        guard let window else { return }
        let frame = targetFrame(expanded: expanded)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = expanded ? 0.34 : 0.24
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.86, 0.24, 1.0)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func targetFrame(expanded: Bool) -> NSRect {
        let windowWidth = expanded ? OverlayMetrics.expandedWidth : OverlayMetrics.collapsedWidth
        let windowHeight = expanded ? OverlayMetrics.expandedHeight : OverlayMetrics.collapsedHeight
        return NSRect(
            x: screenFrame.minX,
            y: visibleFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )
    }

    private func expandIfNeeded() {
        pendingCollapse?.cancel()
        pendingCollapse = nil

        guard !isExpanded,
              let contentView = window?.contentView as? SideNotchView else {
            return
        }

        isExpanded = true
        positionWindow(expanded: true, animated: true)
        contentView.setExpanded(true, animated: true)
    }

    private func scheduleCollapseIfPointerLeaves() {
        pendingCollapse?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.collapseIfPointerIsOutside()
            }
        }
        pendingCollapse = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func collapseIfPointerIsOutside() {
        guard isExpanded,
              let contentView = window?.contentView as? SideNotchView else {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let expandedFrame = targetFrame(expanded: true).insetBy(dx: -24, dy: -28)
        let collapsedHotZone = targetFrame(expanded: false).insetBy(dx: -18, dy: -28)

        guard !expandedFrame.contains(mouseLocation),
              !collapsedHotZone.contains(mouseLocation) else {
            return
        }

        pendingCollapse = nil
        isExpanded = false
        contentView.setExpanded(false, animated: true)
        positionWindow(expanded: false, animated: true)
    }
}

@MainActor
extension OverlayController: SideNotchHoverDelegate {
    func sideNotchHoverDidChange(isHovering: Bool) {
        if isHovering {
            expandIfNeeded()
        } else {
            scheduleCollapseIfPointerLeaves()
        }
    }
}

final class SideNotchWindow: NSWindow {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    func configure() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SideNotchView: NSView {
    weak var hoverDelegate: SideNotchHoverDelegate?

    private let panelWidth: CGFloat = 280
    private let rowHeight: CGFloat = 56
    private let rowGap: CGFloat = 6
    private let leftPadding: CGFloat = 12
    private let rightPadding: CGFloat = 12
    private let topPadding: CGFloat = 14
    private let bottomPadding: CGFloat = 16
    private var trackingArea: NSTrackingArea?
    private var isExpanded = false
    private var selectedRowIndex = DockData.items.firstIndex(where: { $0.isSelected }) ?? 0
    private var rowViews: [DockRowView] = []
    private let settingsIconView = SettingsIconView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        buildRows()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        buildRows()
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeAlways,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hoverDelegate?.sideNotchHoverDidChange(isHovering: true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverDelegate?.sideNotchHoverDidChange(isHovering: false)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        needsDisplay = true

        if expanded {
            subviews.forEach { $0.isHidden = false }
            subviews.forEach { $0.alphaValue = animated ? 0 : 1 }
        }

        let updates = {
            for subview in self.subviews {
                subview.alphaValue = expanded ? 1 : 0
            }
        }

        if animated {
            let animation = {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = expanded ? 0.18 : 0.10
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
                    context.allowsImplicitAnimation = true
                    for subview in self.subviews {
                        subview.animator().alphaValue = expanded ? 1 : 0
                    }
                } completionHandler: {
                    if !expanded {
                        Task { @MainActor in
                            self.subviews.forEach { $0.isHidden = true }
                        }
                    }
                }
            }

            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    if self.isExpanded {
                        animation()
                    }
                }
            } else {
                animation()
            }
        } else {
            updates()
            subviews.forEach { $0.isHidden = !expanded }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.clear.setFill()
        dirtyRect.fill()

        if bounds.width <= OverlayMetrics.collapsedWidth + 1 {
            NSColor.black.setFill()
            let radius = bounds.width / 2
            let handle = NSBezierPath()
            handle.move(to: CGPoint(x: 0, y: 0))
            handle.line(to: CGPoint(x: bounds.width - radius, y: 0))
            handle.curve(
                to: CGPoint(x: bounds.width, y: radius),
                controlPoint1: CGPoint(x: bounds.width - radius * 0.45, y: 0),
                controlPoint2: CGPoint(x: bounds.width, y: radius * 0.45)
            )
            handle.line(to: CGPoint(x: bounds.width, y: bounds.height - radius))
            handle.curve(
                to: CGPoint(x: bounds.width - radius, y: bounds.height),
                controlPoint1: CGPoint(x: bounds.width, y: bounds.height - radius * 0.45),
                controlPoint2: CGPoint(x: bounds.width - radius * 0.45, y: bounds.height)
            )
            handle.line(to: CGPoint(x: 0, y: bounds.height))
            handle.close()
            handle.fill()

            NSColor.white.withAlphaComponent(0.12).setFill()
            NSBezierPath(
                roundedRect: CGRect(x: 8, y: bounds.midY - 58, width: 2, height: 116),
                xRadius: 1,
                yRadius: 1
            ).fill()
            return
        }

        NSColor.black.setFill()
        drawMainNotchBody()
    }

    private func drawMainNotchBody() {
        let topY: CGFloat = 0
        let bottomY = bounds.height
        let leftX: CGFloat = 0
        let rightX = panelWidth + 6
        let rightRadius: CGFloat = 38
        let smooth: CGFloat = 0.56

        let body = NSBezierPath()
        body.move(to: CGPoint(x: leftX, y: topY))
        body.line(to: CGPoint(x: rightX - rightRadius, y: topY))
        body.curve(
            to: CGPoint(x: rightX, y: topY + rightRadius),
            controlPoint1: CGPoint(x: rightX - rightRadius * (1 - smooth), y: topY),
            controlPoint2: CGPoint(x: rightX, y: topY + rightRadius * smooth)
        )
        body.line(to: CGPoint(x: rightX, y: bottomY - rightRadius))
        body.curve(
            to: CGPoint(x: rightX - rightRadius, y: bottomY),
            controlPoint1: CGPoint(x: rightX, y: bottomY - rightRadius * (1 - smooth)),
            controlPoint2: CGPoint(x: rightX - rightRadius * (1 - smooth), y: bottomY)
        )
        body.line(to: CGPoint(x: leftX, y: bottomY))
        body.close()
        body.fill()
    }

    override func layout() {
        super.layout()
        let rowWidth = panelWidth - leftPadding - rightPadding
        let waveformHeight: CGFloat = 44

        subviews.first(where: { $0.identifier?.rawValue == "waveform" })?.frame = CGRect(
            x: leftPadding,
            y: topPadding,
            width: rowWidth,
            height: waveformHeight
        )

        var y = topPadding + waveformHeight + 10
        for row in rowViews {
            row.frame = CGRect(x: leftPadding, y: y, width: rowWidth, height: rowHeight)
            y += rowHeight + rowGap
        }

        let settingsSize: CGFloat = 28
        settingsIconView.frame = CGRect(
            x: panelWidth - rightPadding - settingsSize,
            y: bounds.height - bottomPadding - settingsSize,
            width: settingsSize,
            height: settingsSize
        )
    }

    private func buildRows() {
        addSubview(AudioWaveformPillView())

        for (index, item) in DockData.items.enumerated() {
            let row = DockRowView(item: item, isSelected: index == selectedRowIndex) { [weak self] in
                self?.selectRow(at: index)
            }
            rowViews.append(row)
            addSubview(row)
        }

        addSubview(settingsIconView)
    }

    private func selectRow(at selectedIndex: Int) {
        selectedRowIndex = selectedIndex
        for (index, row) in rowViews.enumerated() {
            row.setSelected(index == selectedIndex)
        }
    }
}

final class SettingsIconView: NSView {
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("settings")
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        imageView.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = NSColor.white.withAlphaComponent(0.76)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        imageView.frame = bounds.insetBy(dx: 5, dy: 5)
    }
}

final class AudioWaveformPillView: NSView {
    private let waveformView = AudioWaveformView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("waveform")
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(waveformView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        waveformView.frame = bounds.insetBy(dx: 10, dy: 8)
    }
}

final class MicrophoneLevelMonitor: @unchecked Sendable {
    static let shared = MicrophoneLevelMonitor()

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var didAttemptStart = false
    private var currentLevel: CGFloat = 0

    var level: CGFloat {
        lock.lock()
        defer { lock.unlock() }
        return currentLevel
    }

    func startIfNeeded() {
        guard !didAttemptStart else { return }
        didAttemptStart = true

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startEngine()
        case .notDetermined:
            guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
                return
            }

            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else { return }
                    self?.startEngine()
                }
            }
        case .denied, .restricted:
            return
        @unknown default:
            return
        }
    }

    private func startEngine() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = channelData[index]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            let normalizedLevel = min(1, max(0, CGFloat(rms) * 12))
            self?.updateLevel(normalizedLevel)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            updateLevel(0, smoothing: 0)
        }
    }

    private func updateLevel(_ level: CGFloat, smoothing: CGFloat = 0.68) {
        lock.lock()
        currentLevel = currentLevel * smoothing + level * (1 - smoothing)
        lock.unlock()
    }
}

final class AudioWaveformView: NSView {
    private let barCount = 28
    private var bars: [CGFloat]
    private var displayLink: Timer?
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        self.bars = Array(repeating: 0.12, count: barCount)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else {
            MicrophoneLevelMonitor.shared.startIfNeeded()
            startAnimatingIfNeeded()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !bars.isEmpty else { return }

        let availableWidth = bounds.width
        let barWidth: CGFloat = 2
        let spacing = max(4, (availableWidth - CGFloat(barCount) * barWidth) / CGFloat(max(1, barCount - 1)))
        let centerY = bounds.midY
        let maxBarHeight = bounds.height * 0.70

        NSColor.white.withAlphaComponent(0.86).setFill()

        for (index, value) in bars.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            let height = max(4, min(maxBarHeight, value * maxBarHeight))
            let y = centerY - height / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            path.fill()
        }
    }

    private func startAnimatingIfNeeded() {
        guard displayLink == nil else { return }

        displayLink = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(displayLink!, forMode: .common)
    }

    private func tick() {
        phase += 0.16

        let inputLevel = MicrophoneLevelMonitor.shared.level
        let idleMovement = (sin(phase) + 1) * 0.035
        let newValue = min(1, max(0.08, inputLevel + idleMovement))

        bars.removeFirst()
        bars.append(newValue)

        for index in bars.indices {
            let ripple = (sin(phase + CGFloat(index) * 0.46) + 1) * 0.04
            bars[index] = min(1, max(0.08, bars[index] * 0.90 + ripple))
        }

        needsDisplay = true
    }
}

final class DockRowView: NSView {
    private let session: CodingSession
    private let iconView: AppIconView
    private let onSelect: () -> Void
    private let nameLabel = NSTextField(labelWithString: "")
    private let sessionIDLabel = NSTextField(labelWithString: "")
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let thinkingView = ShimmeringStatusView()
    private var isSelected: Bool

    init(item: CodingSession, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.session = item
        self.iconView = AppIconView(item: item)
        self.onSelect = onSelect
        self.isSelected = isSelected
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("row")
        wantsLayer = true
        layer?.cornerRadius = 9
        updateBackground()
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onSelect()
    }

    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected
        updateBackground()
    }

    override func layout() {
        super.layout()
        let iconSize: CGFloat = 36
        iconView.frame = CGRect(x: 4, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)

        let textX: CGFloat = 46
        let textWidth = max(0, bounds.width - textX - 6)
        let elapsedWidth: CGFloat = 60
        nameLabel.frame = CGRect(x: textX, y: 4, width: max(0, textWidth - elapsedWidth - 8), height: 18)
        elapsedLabel.frame = CGRect(x: bounds.width - elapsedWidth - 6, y: 5, width: elapsedWidth, height: 16)
        sessionIDLabel.frame = CGRect(x: textX, y: 22, width: textWidth, height: 13)

        if session.isRunning {
            thinkingView.frame = CGRect(x: textX, y: 36, width: min(96, textWidth), height: 16)
            summaryLabel.frame = .zero
        } else {
            thinkingView.frame = .zero
            summaryLabel.frame = CGRect(x: textX, y: 37, width: textWidth, height: 15)
        }
    }

    private func configureSubviews() {
        addSubview(iconView)

        nameLabel.stringValue = session.name
        nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = NSColor.white.withAlphaComponent(0.9)
        configureForSingleLineTruncation(nameLabel)
        addSubview(nameLabel)

        elapsedLabel.stringValue = session.elapsedTime
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        elapsedLabel.textColor = NSColor.white.withAlphaComponent(0.72)
        elapsedLabel.alignment = .right
        configureForSingleLineTruncation(elapsedLabel)
        addSubview(elapsedLabel)

        sessionIDLabel.stringValue = session.sessionID
        sessionIDLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        sessionIDLabel.textColor = NSColor.white.withAlphaComponent(0.48)
        configureForSingleLineTruncation(sessionIDLabel)
        addSubview(sessionIDLabel)

        summaryLabel.stringValue = session.summary
        summaryLabel.font = .systemFont(ofSize: 11, weight: .medium)
        summaryLabel.textColor = NSColor.white.withAlphaComponent(0.64)
        configureForSingleLineTruncation(summaryLabel)
        summaryLabel.isHidden = session.isRunning
        addSubview(summaryLabel)

        thinkingView.isHidden = !session.isRunning
        addSubview(thinkingView)
    }

    private func updateBackground() {
        layer?.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.17).cgColor : NSColor.clear.cgColor
    }

    private func configureForSingleLineTruncation(_ label: NSTextField) {
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.cell?.truncatesLastVisibleLine = true
    }
}

final class ShimmeringStatusView: NSView {
    private let shimmerLayer = CAGradientLayer()
    private let textMaskLayer = CATextLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        shimmerLayer.colors = [
            NSColor.white.withAlphaComponent(0.48).cgColor,
            NSColor.white.withAlphaComponent(1).cgColor,
            NSColor.white.withAlphaComponent(0.48).cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [-0.75, -0.35, 0.05]
        shimmerLayer.mask = textMaskLayer
        layer?.addSublayer(shimmerLayer)

        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        textMaskLayer.string = "Thinking..."
        textMaskLayer.font = font.fontName as CFTypeRef
        textMaskLayer.fontSize = font.pointSize
        textMaskLayer.foregroundColor = NSColor.white.cgColor
        textMaskLayer.alignmentMode = .left
        textMaskLayer.truncationMode = .end
        textMaskLayer.isWrapped = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        textMaskLayer.contentsScale = scale
        shimmerLayer.contentsScale = scale
        shimmerLayer.frame = bounds
        textMaskLayer.frame = bounds.insetBy(dx: 0, dy: 1)
        startShimmerIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            shimmerLayer.removeAnimation(forKey: "thinkingShimmer")
        } else {
            startShimmerIfNeeded()
        }
    }

    private func startShimmerIfNeeded() {
        guard window != nil, bounds.width > 0, shimmerLayer.animation(forKey: "thinkingShimmer") == nil else {
            return
        }

        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.75, -0.35, 0.05]
        sweep.toValue = [0.95, 1.35, 1.75]
        sweep.duration = 1.2
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(sweep, forKey: "thinkingShimmer")
    }
}

final class AppIconView: NSView {
    private let imageView = NSImageView()
    private let item: CodingSession
    private let iconImage: NSImage?

    init(item: CodingSession) {
        self.item = item
        self.iconImage = item.usesBottomIcon ? AppAssets.bottomHalfIcon : AppAssets.codexIcon
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.masksToBounds = true

        imageView.image = iconImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 9
        imageView.layer?.masksToBounds = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard iconImage == nil else { return }

        let path = NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9)
        item.fallbackColor.setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: CGRect(x: -8, y: -8, width: bounds.width * 0.9, height: bounds.height * 0.9)).fill()

        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: CGRect(x: bounds.width * 0.42, y: bounds.height * 0.42, width: bounds.width, height: bounds.height)).fill()
    }
}
