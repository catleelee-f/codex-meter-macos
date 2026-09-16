# 参与贡献

欢迎提交可复现的问题、文档修正和小范围 Pull Request。当前维护重点见 [路线图](ROADMAP.md)。

## 本地开发

需要 macOS 13 或更新版本和 Xcode Command Line Tools。克隆仓库后运行：

```bash
bash scripts/test-offline.sh
bash scripts/build.sh
```

离线测试自动生成合成日志，覆盖累计计数、增量读取、缓存、文件截断、项目/周汇总和账号响应解析；无需 Codex 账号、网络或个人会话日志。构建生成 Apple Silicon + Intel 通用应用。

可选的本机验证：

- `bash scripts/test-parser.sh`：读取自己的 Codex sessions。
- `bash scripts/test-account-sync.sh`：使用现有登录状态查询账号额度，需要网络。

这两项个人环境测试不在 CI 中运行。不要将其输出中的个人路径或用量直接贴入公开 Issue。

## 提交 Issue

先搜索已有 Issue。问题报告请包含应用版本、macOS 版本、芯片类型、复现步骤、期望与实际结果，以及脱敏截图。额度问题请说明面板显示“账号实时”“账号缓存”还是“本地快照”。

不要上传原始会话、认证文件、Token 或完整请求头。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## 提交 PR

1. 从最新 main 创建分支，一次解决一个问题。
2. 解析器改动需增加合成回归测试，保留缺失、单个和多个额度窗口的兼容性。
3. 运行离线测试与通用构建；界面改动附上脱敏截图和手动操作结果。
4. 在 PR 中说明问题、改变后的行为和验证结果。
5. 等待 macOS CI 成功后合并。CI 不代表界面操作或真实账号同步已经验证。

## 发布

维护者确认版本号和 CHANGELOG、离线测试、通用构建及 CI 后创建 Release。安装包只放 Release 附件，并附 SHA-256；不提交构建缓存或个人材料。当前应用使用 ad-hoc 签名，尚未 Apple 公证。

提交贡献即表示你同意按仓库 MIT 许可证提供该贡献。
