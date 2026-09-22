# SafeAwake

SafeAwake 是一个轻量、开源的 macOS 菜单栏 App。它让 Mac 在显示器关闭时继续执行用户启动的长任务，例如 Codex、编译、数据分析或下载，同时保留 macOS 原有的合盖睡眠与低电量保护。

## 安全原则

- 只使用 Apple 公开的 `ProcessInfo` activity API 阻止**闲置睡眠**。
- 不修改 `pmset` 持久设置，不需要管理员权限。
- 不绕过物理合盖睡眠。
- 默认仅在接通电源时工作；拔掉电源后自动停止。
- 支持定时结束，避免忘记关闭。
- App 退出或崩溃后，系统断言随进程自动释放。

## 功能

- 菜单栏一键开启/关闭。
- 30 分钟、1 小时、2 小时、4 小时或手动停止。
- 一键关闭显示器，后台任务继续运行。
- 清楚显示剩余时间与自动停止原因。

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

- [ ] 保存用户偏好的持续时间和电源策略
- [ ] 登录时启动（默认关闭）
- [ ] 任务结束时自动停止保持唤醒
- [ ] 多语言界面
- [ ] Developer ID 签名、公证和自动化 Release
- [ ] 菜单栏图标与项目截图

## 贡献

欢迎通过 Issue 提交使用场景、问题和改进建议。功能设计应继续遵守“安全、临时、可逆、不绕过合盖睡眠”的边界。

## License

[MIT](LICENSE)
