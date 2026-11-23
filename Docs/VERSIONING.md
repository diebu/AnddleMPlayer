# 版本号规则

- 初始版本为 `1.0.0`，构建号从 `1` 开始。
- 每次应用代码提交自动递增修订号，例如 `1.0.1`、`1.0.2`。
- 每次应用代码提交同时把构建号加一。
- 仅修改文档、脚本或 Git 工作流时，不改变 App 版本号。
- 需要发布新功能版本时，手动执行 `./Scripts/bump-version.sh minor`。
- 需要发布大版本时，手动执行 `./Scripts/bump-version.sh major`。
- 紧急提交可通过 `SKIP_VERSION_BUMP=1 git commit ...` 跳过自动递增。

提交代码时自动执行版本递增和提交：

```bash
./Scripts/commit-changes.sh "fix: 修复播放状态"
```

该脚本会自动启用仓库内的 Git 钩子，并提交所有未忽略的修改。也可以手动
执行 `git commit`，版本递增仍会由 `.githooks/pre-commit` 完成。

首次克隆仓库后安装钩子：

```bash
git config core.hooksPath .githooks
```
