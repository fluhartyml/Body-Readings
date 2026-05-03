//
//  ContentView.swift
//  Body Readings
//
//  Created by Michael Fluharty on 5/2/26.
//

import SwiftUI

private extension Color {
    static let phosphor = Color(red: 0.20, green: 1.0, blue: 0.20)
    static let phosphorBright = Color(red: 0.40, green: 1.0, blue: 0.40)
    static let phosphorDim = Color(red: 0.0, green: 0.67, blue: 0.0)
    static let phosphorFaint = Color(red: 0.0, green: 0.4, blue: 0.0)
    static let monitorBlack = Color(red: 0.02, green: 0.05, blue: 0.02)
}

struct ContentView: View {
    @Environment(HealthStore.self) private var health
    @Environment(MotionStore.self) private var motion

    @State private var pulse = false
    @State private var isRequestingAuth = false

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        ZStack {
            Color.monitorBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    heartRateCard
                    stepsCard
                    motionCard

                    if !health.isAuthorized {
                        connectButton
                    } else {
                        refreshButton
                    }

                    if health.hasRequestedAuth && health.didFinishInitialLoad
                        && health.heartRate == nil && (health.todaysSteps == nil || health.todaysSteps == 0) {
                        openSettingsButton
                    }

                    if let error = health.lastError {
                        Text(error)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Color.phosphorBright)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
                .padding(20)
            }
            .refreshable {
                if health.isAuthorized {
                    await health.refresh()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("BODY READINGS")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.phosphorBright)
                .tracking(4)
            Text("vitals monitor")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.phosphorDim)
                .tracking(2)
        }
        .padding(.top, 12)
    }

    private var heartRateCard: some View {
        readingCard(label: "HEART RATE") {
            HStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.phosphor)
                    .scaleEffect(pulse ? 1.12 : 0.94)
                    .animation(
                        .easeInOut(duration: heartAnimationDuration).repeatForever(autoreverses: true),
                        value: pulse
                    )
                    .onAppear { pulse = true }

                VStack(alignment: .leading, spacing: 4) {
                    if let bpm = health.heartRate {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(Int(bpm.rounded()))")
                                .font(.system(size: 56, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.phosphorBright)
                            Text("BPM")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.phosphorDim)
                                .tracking(2)
                        }
                        if let date = health.heartRateTimestamp {
                            Text(Self.timestampFormatter.string(from: date))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.phosphorDim)
                        }
                    } else if !health.hasRequestedAuth {
                        Text("NOT CONNECTED")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.phosphorDim)
                    } else if !health.didFinishInitialLoad {
                        Text("READING…")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.phosphorDim)
                    } else {
                        Text("NO RECENT READING")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.phosphorDim)
                        Text("Apple Watch logs heart rate; iPhone alone has no sensor.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.phosphorFaint)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var stepsCard: some View {
        readingCard(label: "STEPS TODAY") {
            HStack(spacing: 16) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.phosphor)

                if let steps = health.todaysSteps {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(steps.formatted())
                            .font(.system(size: 56, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.phosphorBright)
                        Text("STEPS")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.phosphorDim)
                            .tracking(2)
                    }
                } else if !health.hasRequestedAuth {
                    Text("NOT CONNECTED")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.phosphorDim)
                } else if !health.didFinishInitialLoad {
                    Text("READING…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.phosphorDim)
                } else {
                    Text("0")
                        .font(.system(size: 56, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.phosphorBright)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var motionCard: some View {
        readingCard(label: "LIVE MOTION") {
            VStack(spacing: 14) {
                axisBar(label: "X", value: motion.x)
                axisBar(label: "Y", value: motion.y)
                axisBar(label: "Z", value: motion.z)
                if !motion.isAvailable {
                    Text("Accelerometer unavailable on this device.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.phosphorDim)
                }
            }
        }
    }

    private func axisBar(label: String, value: Double) -> some View {
        let magnitude = min(1.0, abs(value))
        return HStack(spacing: 12) {
            Text(label)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.phosphorBright)
                .frame(width: 24, alignment: .leading)

            GeometryReader { geo in
                let mid = geo.size.width / 2
                let barWidth = mid * magnitude
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.phosphorFaint, lineWidth: 1)
                    Rectangle()
                        .fill(Color.phosphorFaint)
                        .frame(width: 1)
                        .position(x: mid, y: geo.size.height / 2)
                    Rectangle()
                        .fill(Color.phosphor)
                        .frame(width: barWidth, height: geo.size.height - 6)
                        .offset(x: value >= 0 ? mid : mid - barWidth, y: 3)
                        .animation(.linear(duration: 0.05), value: value)
                }
            }
            .frame(height: 18)

            Text(String(format: "%+0.2f", value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.phosphorBright)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func readingCard<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.phosphorDim)
                .tracking(3)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.monitorBlack)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.phosphorFaint, lineWidth: 1)
        )
    }

    private var heartAnimationDuration: Double {
        guard let bpm = health.heartRate, bpm > 0 else { return 0.6 }
        return min(1.5, max(0.3, 60.0 / bpm / 2.0))
    }

    private var connectButton: some View {
        Button {
            Task {
                isRequestingAuth = true
                await health.requestAuthorization()
                isRequestingAuth = false
            }
        } label: {
            HStack(spacing: 10) {
                if isRequestingAuth {
                    ProgressView().tint(Color.phosphor)
                } else {
                    Image(systemName: "heart.text.square")
                }
                Text(health.lastError == nil ? "CONNECT TO HEALTH" : "TRY AGAIN")
                    .tracking(2)
            }
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundStyle(Color.phosphorBright)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.phosphor, lineWidth: 1.5)
            )
        }
        .disabled(isRequestingAuth)
    }

    private var refreshButton: some View {
        Button {
            Task { await health.refresh() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                Text("REFRESH")
                    .tracking(2)
            }
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundStyle(Color.phosphorDim)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.phosphorFaint, lineWidth: 1)
            )
        }
    }

    private var openSettingsButton: some View {
        VStack(spacing: 8) {
            Text("If readings are blank, grant access in Settings")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.phosphorDim)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                    Text("OPEN SETTINGS")
                        .tracking(2)
                }
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.phosphorBright)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.phosphorFaint, lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(HealthStore())
        .environment(MotionStore())
}
