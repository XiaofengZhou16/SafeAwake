# SafeAwake

SafeAwake 是一个轻量、开源的 macOS 菜单栏 App。它让 Mac 在显示器关闭时继续执行用户启动的长任务，例如 Codex、编译、数据分析或下载，同时保留 macOS 原有的合盖睡眠与低电量保护。

## 安全原则

- 只使用 Apple 公开的 `ProcessInfo` activity API 阻止**闲置睡眠**。
- 不修改 `pmset` 持久设置，不需要管理员权限。
- 不绕过物理合盖睡眠。
- 默认仅在接通电源时工作；拔掉电源后自动停止。
- 即使允许电池供电，电量 ≤20% 或无法读取时也会停止；恢复供电后需手动开启。
- 支持定时结束，避免忘记关闭。
- App 退出或崩溃后，系统断言随进程自动释放。

## 功能

- 菜单栏一键开启/关闭。
- 30 分钟、1 小时、2 小时、4 小时或手动停止。
- 运行中可直接调整持续时间并重新计时，不会中断当前防休眠请求。
- 一键开启保持唤醒并关闭显示器，减少重复操作。
- 菜单栏直接显示剩余时间，运行中可在原截止时间上追加 30 分钟。
- 状态 HUD、剩余时间环和即时操作反馈。
- 自动保存持续时间和电源策略偏好。
- 清楚显示当前电源状态、剩余时间与自动停止原因。
- 电源策略与安全说明折叠收纳，主界面聚焦开始、时长和结束。
- 再次打开 App 可显示独立控制面板，菜单栏空间不足时仍可操作。

停止仅释放 SafeAwake 自己的请求，不会强制电脑睡眠；系统设置和其他 App 仍可能阻止睡眠。电源与定时状态约每 5 秒检查一次，系统唤醒后也会重新检查。重启 App 不会自动恢复保持唤醒。

熄屏不等于锁屏；离开前可用 `Control + Command + Q` 锁屏。SafeAwake 不检测 Codex 任务是否完成，也不能保证网络连接或任务本身持续正常。

> SafeAwake 不会让 MacBook 在无外接显示器的情况下强制合盖运行。合盖属于 macOS 的强制睡眠路径；需要合盖工作时，请使用 Apple 支持的闭盖外接显示器模式。

## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac

## 从源码运行

```bash
swift run SafeAwake
```

## 构建本地 App

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/SafeAwake.app
```

首次本地构建采用 ad-hoc 签名。正式下载版本将在后续里程碑中加入 Developer ID 签名、公证与可验证的 GitHub Release。

## 测试

```bash
swift test
```

## 路线图

- [ ] 单次认证、最长 30 分钟的合盖会话（仅安全策略原型，尚不可用；见[安全门槛](docs/lid-session-safety.md)）
- [x] 保存用户偏好的持续时间和电源策略
- [ ] 登录时启动（默认关闭）
- [ ] 任务结束时自动停止保持唤醒
- [ ] 多语言界面
- [ ] Developer ID 签名、公证和自动化 Release
- [ ] 菜单栏图标与项目截图

## 贡献

欢迎通过 Issue 提交使用场景、问题和改进建议。功能设计应继续遵守“安全、临时、可逆、不绕过合盖睡眠”的边界。

## 设计参考

v0.2 的菜单栏信息层级和即时反馈模式参考了开源项目 [VenkateshDas/pulse](https://github.com/VenkateshDas/pulse)。SafeAwake 仅借鉴交互思路，保持独立实现和更窄的安全功能边界。

v0.3 参考高星项目 KeepingYouAwake 的轻量定时交互和 Stats 的菜单栏状态可见性，结合本项目的安全边界改进。来源、取舍与验证记录见 [交互设计说明](docs/interaction-design.md)。

## License

[MIT](LICENSE)
