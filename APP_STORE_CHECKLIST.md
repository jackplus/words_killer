# Words Killer — App Store 上架提审全清单（可直接复制粘贴）

本文档整理了当前工程已完成的合规配置，以及在 **App Store Connect** 网页后台可直接复制使用的元数据文案与打包步骤。

---

## 一、工程侧已就绪合规项（无需额外改动）

- **Bundle Identifier**: `com.tedji.Words-killer`
- **Development Team**: `5N7K59WT8G`
- **桌面显示名称 (`CFBundleDisplayName`)**: `Words Killer`
- **最低支持系统 (`IPHONEOS_DEPLOYMENT_TARGET`)**: `iOS 17.0`（覆盖 iOS 17 / 18 / 26+ 全系 iPhone 与 iPad）
- **应用分类 (`LSApplicationCategoryType`)**: `Education`（教育）
- **隐私清单 (`PrivacyInfo.xcprivacy`)**: 已内置声明 `NSPrivacyTracking = false`、无数据收集、`UserDefaults` 原因码 `CA92.1`
- **后台能力 (`UIBackgroundModes`)**: `audio`（支持「随身听学」锁屏播放、控制中心及耳机切词）
- **出口合规免填 (`ITSAppUsesNonExemptEncryption`)**: `NO`（TestFlight / 提审自动跳过加密出口弹窗）
- **应用图标 (`AppIcon.png`)**: `1024 × 1024 px`，无 Alpha 透明通道，符合 App Store 规范

---

## 二、App Store Connect 可直接粘贴文案

### 1. 基础信息
- **名称（30 字符内）**: `Words Killer - 多语种极简背单词`
- **副标题（30 字符内）**: `英日韩法西记忆曲线闪卡与随身听学`
- **主要类别**: 教育（Education）
- **次要类别**: 工具（Utilities）或 参考（Reference）
- **年龄分级**: `4+`（所有问卷项均勾选「无」）
- **App 隐私（App Privacy）**: 选择 **「未收集数据（Data Not Collected）」**

### 2. 关键词（Keywords，100 字符内，英文逗号无空格分隔）
```text
背单词,英语,日语,韩语,法语,西班牙语,四六级,雅思,托福,JLPT,TOPIK,记忆曲线,闪卡,听写,词库,SRS,离线
```

### 3. 宣传文本（Promotional Text，170 字符内）
```text
纯本地离线运行的多语种背单词利器！覆盖英、日、韩、法、西五国语言与考级词书，融合 SM-2 记忆曲线、左右滑卡、四选一与拼写测验、锁屏随身听学以及开源词典一键导入，无广告、无打扰、无需登录。
```

### 4. 应用描述（Description）
```text
Words Killer 是一款专为中文母语者打造的纯粹、高效、多语种间隔重复（SRS）背单词应用。打开即背，100% 本地离线运行，无广告、无追踪、无需注册登录。

【核心亮点】
• 五国语言模块化词书：内置英语（含四六级/雅思托福/商务）、日语（JLPT N5–N1）、韩语（TOPIK I–II）、法语（DELF）、西班牙语（DELE）分级词书，词条配备音标/假名注音、中文释义、联想助记与地道例句。
• SM-2 智能记忆曲线：根据「认识 / 模糊 / 不认识」三档反馈动态推算复习间隔，优先推送到期词与星标收藏词，当轮生词自动重测直至掌握。
• 多维主动回忆测验：支持看词选义、看义选词、听音辨词四选一速测，以及听音拼写填空与错题专练。
• 锁屏随身听学（磨耳朵）：支持外语发音、中文释义与双语例句自动循环连播，适配锁屏控制中心与耳机切词，通勤散步也能轻松记词。
• 开放词库自由导入：支持手动录入生词，或一键导入 JSON / CSV / TSV / TXT 外部词表（兼容 ECDICT、KyleBing、JLPT 等主流开源词典格式），并支持全量学习进度本地 JSON 备份与恢复。
• 数据统计与打卡热力图：直观呈现每日目标进度环、连续打卡天数、近 14 天学习趋势、12 周记忆热力图与未来 7 天待复习预测。
```

### 5. 网址填写建议
- **隐私政策网址（Privacy Policy URL）**:
  可在 GitHub 仓库 `Settings -> Pages` 开启 `Deploy from branch: main` 后填写：
  `https://jackplus.github.io/words_killer/PRIVACY`（或仓库公开文档页链接）
- **技术支持网址（Support URL）**:
  `https://github.com/jackplus/words_killer/issues`

### 6. 审核备注（App Review Notes — 给苹果审核员说明后台音频用途）
```text
Thank you for reviewing Words Killer!
1. No login or account is required. All features work 100% offline out of the box.
2. Background Audio (UIBackgroundModes: audio): Used by the "随身听学" (Hands-Free Audio Study) player (accessible via the headphone icon on the main study screen or wordbook screen), allowing users to listen to continuous vocabulary pronunciations and translations with Lock Screen / Control Center playback controls while commuting or with the screen locked.
```

---

## 三、打包上传 4 步走

1. 用 Xcode 打开 `Words killer.xcodeproj`，在 `Signing & Capabilities` 确认 Team 已选中您的 Apple Developer 账号。
2. 顶部运行目标选择 **`Any iOS Device (arm64)`**，点击菜单栏 **`Product` -> `Archive`**。
3. 在弹出的 Organizer 窗口点击 **`Distribute App` -> `App Store Connect` -> `Upload`**。
4. 构建版本处理完成后（约 5～10 分钟），先用 **TestFlight** 在真机验证锁屏听学与定时提醒，随后在 App Store Connect 关联该构建版本、上传 **6.9" iPhone** 与 **13" iPad Pro** 截图，点击 **「提交以供审核」** 即可！
