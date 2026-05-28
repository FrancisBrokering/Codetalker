import SwiftUI

private struct CodingSession: Identifiable, Equatable {
    let id: String
    let name: String
    let elapsedTime: String
    let summary: String
    let isRunning: Bool
    let accent: Color
    let iconName: String
}

private enum DemoSessions {
    static let items: [CodingSession] = [
        CodingSession(
            id: "S-1042",
            name: "Side Notch Polish",
            elapsedTime: "12m 38s",
            summary: "Updated icons and tuned the notch row spacing.",
            isRunning: false,
            accent: .blue,
            iconName: "sidebar.left"
        ),
        CodingSession(
            id: "S-1043",
            name: "Agent Layout Pass",
            elapsedTime: "4m 11s",
            summary: "Balancing row metadata and status labels.",
            isRunning: true,
            accent: .orange,
            iconName: "sparkles"
        ),
        CodingSession(
            id: "S-1044",
            name: "Resource Bundling",
            elapsedTime: "7m 03s",
            summary: "Bundled image assets for both notch halves.",
            isRunning: false,
            accent: .orange,
            iconName: "shippingbox"
        ),
        CodingSession(
            id: "S-1045",
            name: "Hover Animation",
            elapsedTime: "2m 49s",
            summary: "Testing smoother expand and collapse timing.",
            isRunning: true,
            accent: .purple,
            iconName: "cursorarrow.motionlines"
        ),
        CodingSession(
            id: "S-1046",
            name: "Build Verification",
            elapsedTime: "31s",
            summary: "Confirmed Swift build after UI changes.",
            isRunning: false,
            accent: .cyan,
            iconName: "checkmark.seal"
        )
    ]
}

struct ContentView: View {
    @State private var selectedSession = DemoSessions.items.first(where: \.isRunning) ?? DemoSessions.items[0]
    @State private var hoveredSessionID: CodingSession.ID?
    @State private var isPaused = false
    @State private var isListening = false
    @State private var lastAction = "Hover a row to preview speech, or choose a session to talk to it."

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.04, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                header
                sessionList
                controls
                statusLine
            }
            .padding(14)
            .frame(width: 344)
            .background(.black)
            .clipShape(.rect(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 28, x: 12, y: 18)
            .padding()
        }
        .frame(minWidth: 380, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CodeTalker", systemImage: "waveform")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(isListening ? "Listening" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isListening ? .green : .white.opacity(0.7))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.10), in: Capsule())
            }

            WaveformView(isActive: isListening && !isPaused)
                .frame(height: 42)
                .padding(.horizontal, 10)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    private var sessionList: some View {
        VStack(spacing: 6) {
            ForEach(DemoSessions.items) { session in
                SessionRow(
                    session: session,
                    isSelected: selectedSession == session,
                    isHovered: hoveredSessionID == session.id,
                    isPaused: isPaused
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSession = session
                    lastAction = "Selected \(session.name). Voice input will route to \(session.id)."
                }
                .onHover { hovering in
                    hoveredSessionID = hovering ? session.id : nil
                    if hovering {
                        lastAction = "Previewing speech for \(session.name)."
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            ControlButton(
                title: isPaused ? "Resume" : "Pause",
                systemImage: isPaused ? "play.fill" : "pause.fill",
                isActive: isPaused
            ) {
                isPaused.toggle()
                lastAction = isPaused ? "Paused speech for \(selectedSession.name)." : "Resumed speech for \(selectedSession.name)."
            }

            ControlButton(title: "Replay", systemImage: "arrow.counterclockwise") {
                lastAction = "Replaying the latest response for \(selectedSession.name)."
            }

            ControlButton(
                title: isListening ? "Stop" : "Voice",
                systemImage: isListening ? "mic.fill" : "mic",
                isActive: isListening
            ) {
                isListening.toggle()
                lastAction = isListening ? "Listening for input to \(selectedSession.name)." : "Stopped voice input."
            }
        }
    }

    private var statusLine: some View {
        Text(lastAction)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.62))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }
}

private struct SessionRow: View {
    let session: CodingSession
    let isSelected: Bool
    let isHovered: Bool
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(session.accent.gradient)

                Image(systemName: session.iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(session.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(session.elapsedTime)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text(session.id)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))

                if session.isRunning && !isPaused {
                    ShimmerText("Thinking...")
                } else {
                    Text(session.summary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected {
            return .white.opacity(0.17)
        }
        if isHovered {
            return .white.opacity(0.10)
        }
        return .clear
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(isActive ? 0.98 : 0.82))
        .background(isActive ? .white.opacity(0.20) : .white.opacity(0.10), in: Capsule())
    }
}

private struct WaveformView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<28, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(isActive ? 0.90 : 0.46))
                        .frame(width: 2, height: barHeight(index: index, time: time))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = time * (isActive ? 5.8 : 1.4) + Double(index) * 0.52
        let wave = (sin(phase) + 1) / 2
        let intensity = isActive ? 1.0 : 0.42
        return 5 + CGFloat(wave) * 26 * intensity
    }
}

private struct ShimmerText: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        TimelineView(.animation) { context in
            let progress = (context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2)) / 1.2

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.42), location: max(0, progress - 0.28)),
                            .init(color: .white, location: progress),
                            .init(color: .white.opacity(0.42), location: min(1, progress + 0.28))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(height: 14, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
