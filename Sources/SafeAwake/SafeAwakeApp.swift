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
            Label(
                controller.isActive ? "SafeAwake 已开启" : "SafeAwake 已关闭",
                systemImage: controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SafeAwakeMenu: View {
    @ObservedObject var controller: WakeController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: controller.isActive ? "checkmark.shield.fill" : "moon.zzz")
                    .font(.title2)
                    .foregroundStyle(controller.isActive ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.isActive ? "保持唤醒已开启" : "保持唤醒已关闭")
                        .font(.headline)
                    Text(controller.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("持续时间", selection: $controller.selectedDurationMinutes) {
                Text("30 分钟").tag(30)
                Text("1 小时").tag(60)
                Text("2 小时").tag(120)
                Text("4 小时").tag(240)
                Text("直到手动关闭").tag(0)
            }
            .disabled(controller.isActive)

            Toggle("仅在接通电源时运行", isOn: $controller.requiresACPower)
                .disabled(controller.isActive)

            Button {
                controller.toggle()
            } label: {
                Label(
                    controller.isActive ? "停止保持唤醒" : "开始保持唤醒",
                    systemImage: controller.isActive ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(controller.isActive ? .red : .accentColor)

            Button("立即关闭显示器") {
                controller.sleepDisplayNow()
            }
            .disabled(!controller.isActive)

            Divider()

            Label("仅阻止闲置睡眠；合上上盖仍会正常睡眠。", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("SafeAwake 0.1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("退出") {
                    controller.stop()
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}
