# AnddleMPlayer App Store 发布

## 当前版本

- 应用名：AnddleMPlayer
- Bundle ID：`com.anddle.musicplayer`
- 版本：以 `AnddleMPlayer.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION` 为准
- 构建号：以同文件中的 `CURRENT_PROJECT_VERSION` 为准
- Team：`U5S8M9R4A4`
- 最低系统：iOS 17.0
- 设备：仅 iPhone

## 已完成检查

- Release Archive 构建成功。
- App 图标为 1024×1024，无透明通道。
- 隐私清单声明不跟踪、不收集数据，并包含 UserDefaults Required Reason API。
- 加密合规键 `ITSAppUsesNonExemptEncryption` 为 `false`。
- 七种语言资源校验通过。

版本递增规则见 `Docs/VERSIONING.md`。每次应用代码提交会自动递增修订号和构建号。

## 上传前必须完成

1. 打开 Xcode → Settings → Accounts。
2. 添加已付费的 Apple Developer 账号 `diebucn@gmail.com`。
3. 确认账号下能看到 Team `Guang Yang Personal Team (U5S8M9R4A4)`。
4. 在 Xcode Organizer 中打开已有的 Release Archive，选择 Distribute App。
5. 选择 App Store Connect → Upload，并允许 Xcode 自动生成发布证书和描述文件。

也可在账号登录后运行：

```bash
./Scripts/archive-app-store.sh
```

生成的 IPA 位于：

```text
build/AppStoreExport/
```

## App Store Connect

- 创建 App 记录时必须选择 Bundle ID `com.anddle.musicplayer`。
- 主分类建议选择“音乐”。
- 需要准备 App 描述、关键词、支持网址、隐私政策网址和 iPhone 截图。
- 如果在中国大陆区发布，还需要完成适用的 App 备案。
