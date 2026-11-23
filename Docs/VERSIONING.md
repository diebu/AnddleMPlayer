# 版本号规则

- 初始版本为 `1.0.0`，构建号从 `1` 开始。
- Git 每次提交自动递增修订号，例如 `1.0.1`、`1.0.2`。
- 每次提交同时把构建号加一。
- 需要发布新功能版本时，手动执行 `./Scripts/bump-version.sh minor`。
- 需要发布大版本时，手动执行 `./Scripts/bump-version.sh major`。
- 紧急提交可通过 `SKIP_VERSION_BUMP=1 git commit ...` 跳过自动递增。

安装或修复 Git 钩子：

```bash
git config core.hooksPath .githooks
```
