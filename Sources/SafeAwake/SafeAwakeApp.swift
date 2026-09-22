import AppKit
import SafeAwakeCore
import SwiftUI

@main
struct SafeAwakeApp: App {
    @StateObject private var controller = WakeController()

    var body: some Scene {
        MenuBarExtra {
            SafeAwakeMenu(controller: controller)
        } label: {
            Image(systemName: controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(controller.isActive ? "SafeAwake 已开启" : "SafeAwake 已关闭")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SafeAwakeMenu: View {
    @ObservedObject var controller: WakeController

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            statusCard

            if let feedback = controller.feedbackMessage {
                FeedbackBadge(message: feedback, tone: controller.feedbackTone)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            durationCard
            powerCard
            actionCard
            footer
        }
        .padding(14)
        .frame(width: 344)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [AwakeTheme.accent.opacity(0.08), .clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .animation(AwakeTheme.Motion.snappy, value: controller.isActive)
        .animation(AwakeTheme.Motion.smooth, value: controller.feedbackMessage)
        .onAppear { controller.refreshPowerState() }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                StatusRing(
                    isActive: controller.isActive,
                    fraction: controller.remainingFraction(now: context.date)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(controller.isActive ? "Mac 保持唤醒中" : "Mac 可正常休眠")
                    .font(.system(size: 14, weight: .semibold))
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(statusDetail(at: context.date))
                        .font(.system(size: 10.5))
                        .foregroundStyle(AwakeTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 6)

            Toggle("保持唤醒", isOn: activeBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(controller.isActive ? "关闭保持唤醒" : "开启保持唤醒")
        }
        .awakeCard(padding: 13)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("持续时间", systemImage: "timer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AwakeTheme.textSecondary)
                Spacer()
                if controller.isActive {
                    Text("点击即可重新计时")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                ForEach(WakeDuration.options) { option in
                    DurationChip(
                        option: option,
                        isSelected: controller.selectedDurationMinutes == option.minutes
                    ) {
                        withAnimation(AwakeTheme.Motion.snappy) {
                            controller.setDuration(minutes: option.minutes)
                        }
                    }
                }
            }
        }
        .awakeCard()
    }

    private var powerCard: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.isOnACPower ? "powerplug.fill" : "battery.50percent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(controller.isOnACPower ? AwakeTheme.accent : AwakeTheme.warning)
                .frame(width: 22, height: 22)
                .background(
                    (controller.isOnACPower ? AwakeTheme.accent : AwakeTheme.warning).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AwakeTheme.Radius.small, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("仅接通电源时运行")
                    .font(.system(size: 11, weight: .medium))
                Text(controller.isOnACPower ? "当前已接通电源" : "当前使用电池供电")
                    .font(.system(size: 9.5))
                    .foregroundStyle(AwakeTheme.textSecondary)
            }

            Spacer()

            Toggle("仅接通电源时运行", isOn: $controller.requiresACPower)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(controller.isActive)
                .help(controller.isActive ? "请先关闭保持唤醒再修改" : "断开电源时自动停止")
        }
        .awakeCard()
    }

    private var actionCard: some View {
        VStack(spacing: 8) {
            Button {
                controller.sleepDisplayNow()
            } label: {
                Label("关闭显示器，任务继续运行", systemImage: "display")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AwakeTheme.accent)
            .controlSize(.regular)
            .clipShape(Capsule())
            .disabled(!controller.isActive)

            Label("仅阻止闲置睡眠；物理合盖仍会正常睡眠。", systemImage: "lock.shield")
                .font(.system(size: 9.5))
                .foregroundStyle(AwakeTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .awakeCard()
    }

    private var footer: some View {
        HStack {
            Text("SafeAwake 0.2.0")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("退出 SafeAwake") {
                controller.stop(feedback: nil)
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(AwakeTheme.textSecondary)
        }
        .padding(.horizontal, 2)
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { controller.isActive },
            set: { enabled in
                if enabled {
                    _ = controller.start()
                } else {
                    controller.stop()
                }
            }
        )
    }

    private func statusDetail(at date: Date) -> String {
        guard controller.isActive else { return controller.statusMessage }
        guard let remaining = controller.remainingText(now: date) else {
            return "持续到你手动关闭"
        }
        return "剩余 \(remaining)"
    }
}

private struct StatusRing: View {
    let isActive: Bool
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.09), lineWidth: 5)
            Circle()
                .trim(from: 0, to: isActive ? max(0.035, fraction) : 0)
                .stroke(
                    AwakeTheme.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AwakeTheme.Motion.smooth, value: fraction)
            Image(systemName: isActive ? "cup.and.saucer.fill" : "moon.zzz.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? AwakeTheme.accent : AwakeTheme.textSecondary)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }
}

private struct DurationChip: View {
    let option: WakeDuration
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(option.compactLabel)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? AwakeTheme.accent
                        : Color.primary.opacity(isHovered ? 0.10 : 0.055),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(option.label)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeedbackBadge: View {
    let message: String
    let tone: FeedbackTone

    private var tint: Color {
        tone == .success ? AwakeTheme.accent : AwakeTheme.warning
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.11), in: Capsule())
    }
}
