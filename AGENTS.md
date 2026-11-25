# AGENTS.md — Words Killer 协作与开发指南

本文件面向在 **Words Killer**（仓库根目录 `/Volumes/Mac_Ext/WordsKiller`）中工作的 AI 编码助手与开发者，说明项目定位、技术栈、构建测试方法、受保护文件红线与核心架构约束。

> **为什么本文件放在仓库根目录而不是 `Words killer/` 内？**
> 本工程使用 Xcode 16+ 的 `PBXFileSystemSynchronizedRootGroup`，`Words killer/` 目录下的**所有文件**都会自动参与编译或被打包进 `.app` / `.ipa` 安装包。**切勿将文档、脚本、导出配置或工具文件放入 `Words killer/` 目录。**

---

## 1. 项目概览与当前阶段

- **产品定位**：面向中文母语者的五语种（英 / 日 / 韩 / 法 / 西）间隔重复（SRS）背单词 iOS / iPadOS 应用。
- **核心产品原则**：**纯本地离线、零第三方依赖、无广告、无追踪、无需登录**。所有学习进度、自建词条与复习日志仅存储在设备本地。
- **当前进度（2026-11-23）**：
  - 已完成 5 轮功能与性能迭代（6 册 650 词内置词库、5 类开源词典导入、SM-2 记忆曲线、误触撤回、动态间隔预览、个人助记笔记、四选一与拼写测验、锁屏随身听学、Swift Charts 图表与热力图、本地通知、4 套主题、JSON 备份恢复、离线隐私政策页）。
  - App Store Connect 记录已创建（Apple ID `6837619955`，Bundle ID `com.tedji.Words-killer`，SKU `words-killer-ios`，发布团队 `Y382F52F3K`）。
  - 构建 **`1.0 (3)`** 已上传 TestFlight 并通过 Apple 二进制验证，处于「准备提交」阶段，已自动关联 internal 群组的 2 名测试员，尚未提交正式 App Store 审核。
  - 完整历史与上架进度见 [`README.md`](README.md)、[`HANDOFF.md`](HANDOFF.md) 与 [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md)。

---

## 2. 技术栈与工程配置

| 维度 | 配置 / 技术选型 |
| :--- | :--- |
| **语言与并发** | Swift `5.0`，开启 `SWIFT_APPROACHABLE_CONCURRENCY = YES`、`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` |
| **工具链要求** | **Xcode 26+**（`SWIFT_DEFAULT_ACTOR_ISOLATION` 与 `objectVersion = 77` 需要 Xcode 26 及以上；CI 运行在 `macos-26` + Xcode 26，本机验证环境为 Xcode 27.2） |
| **部署目标** | `iOS 17.0` / `iPadOS 17.0`（`TARGETED_DEVICE_FAMILY = "1,2"`，Universal 通用应用） |
| **UI 框架** | SwiftUI（`@Observable`、`@AppStorage`、`NavigationStack`、4 标签 `TabView`）+ Apple `Charts` |
| **数据持久化** | SwiftData（3 个 `@Model`：`WordProgress`、`CustomWordRecord`、`ReviewEvent`）+ `UserDefaults`（偏好设置） |
| **系统框架** | `AVFoundation`（`AVSpeechSynthesizer` + `AVAudioSession`）、`MediaPlayer`（`MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`）、`UserNotifications`、`UniformTypeIdentifiers` |
| **第三方依赖** | **无**（不使用 CocoaPods / Carthage / SPM 外部包；保持零外部依赖与零追踪合规） |
| **测试框架** | Apple **Swift Testing**（`import Testing`、`@Suite`、`@Test`、`#expect`），测试目标 `Words killerTests`（当前 5 个文件、37 项单元测试） |
| **工程结构** | 单工程 `Words killer.xcodeproj` + 共享 Scheme `Words killer`，采用 `PBXFileSystemSynchronizedRootGroup` 自动同步 `Words killer/` 与 `Words killerTests/` |

### 目录结构速查

```text
.
├── AGENTS.md                           # 本文件（AI 助手与开发约束）
├── README.md                           # 产品与代码结构总览
├── HANDOFF.md                          # 迭代历史、架构约定与 v1.2+ 演进规划
├── APP_STORE_CHECKLIST.md              # App Store 提审文案、签名记录与 TestFlight 进度
├── PRIVACY.md                          # 隐私政策源文件（需与内置副本保持一致）
├── .github/workflows/ios-tests.yml     # GitHub Actions CI（push/PR 自动跑模拟器测试）
├── Config/
│   ├── Info.plist                      # 合并到自动生成 Info.plist 的补充配置（UIBackgroundModes: audio）
│   ├── ExportOptions-AppStore.plist    # 本地导出 App Store IPA 配置（destination = export）
│   └── ExportOptions-Upload.plist      # 上传至 App Store Connect 配置（destination = upload，慎用）
├── Words killer.xcodeproj/             # Xcode 工程与共享 Scheme
├── Words killer/                       # App 主 Target（文件系统自动同步组，所有文件会参与构建/打包）
│   ├── Words_killerApp.swift           # 入口，注入 SwiftData ModelContainer
│   ├── ContentView.swift               # 背词主页面（滑卡、撤回、间隔预览、笔记、测验/听学入口）
│   ├── PrivacyInfo.xcprivacy           # App Store 隐私清单（CA92.1 / 零追踪）
│   ├── Assets.xcassets/                # AppIcon（1024×1024 无 Alpha）与 AccentColor
│   ├── Models/                         # WordModels / WordProgress / CustomWordRecord / ReviewEvent
│   ├── Services/                       # SRS、词库、解析器、统计、语音、听学、测验、通知、备份
│   ├── Views/                          # MainTabView、WordCardView、WordBookView、WordPacksView、StatsView、SettingsView、QuizView、AudioPlayerView、AddCustomWordView、PrivacyPolicyView、Components
│   └── Resources/                      # 6 册内置词库 JSON（650 词）+ PrivacyPolicy.md 离线副本
├── Words killerTests/                  # Swift Testing 单元测试 Target（37 项测试）
└── artifacts/                          # 本地发布归档、IPA、截图与日志（已 .gitignore，勿提交）
```

---

## 3. 如何构建、测试与打包

> **重要**：所有涉及 `Words killer.xcodeproj` 和 `Words killer`（含空格）的命令务必加引号。代码改动完成后必须保证 **Swift 编译 0 警告** 且 **全部单元测试通过**。

### 3.1 模拟器编译检查（无需签名）

```bash
xcodebuild \
  -project "Words killer.xcodeproj" \
  -scheme "Words killer" \
  -sdk iphonesimulator \
  -derivedDataPath /tmp/WordsKillerDerivedData \
  build \
  CODE_SIGNING_ALLOWED=NO
```

### 3.2 运行全部单元测试（推荐，自动选取可用 iPhone 模拟器）

模拟器名称会随 Xcode 版本变化（与 CI `.github/workflows/ios-tests.yml` 逻辑一致），推荐先动态取可用 iPhone UDID 再执行测试：

```bash
SIM_UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
def version(rt):
    m = re.search(r"iOS-(\d+)-(\d+)", rt)
    return (int(m.group(1)), int(m.group(2))) if m else (-1, -1)
for rt in sorted(devices, key=version, reverse=True):
    if version(rt) == (-1, -1): continue
    phones = [d for d in devices[rt] if d["name"].startswith("iPhone")]
    if phones:
        print(phones[0]["udid"])
        break
')

xcodebuild test \
  -project "Words killer.xcodeproj" \
  -scheme "Words killer" \
  -destination "id=${SIM_UDID}" \
  -derivedDataPath /tmp/WordsKillerDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

**只运行单个测试套件**（快速迭代调试时使用）：

```bash
xcodebuild test \
  -project "Words killer.xcodeproj" \
  -scheme "Words killer" \
  -destination "id=${SIM_UDID}" \
  -only-testing:"Words killerTests/SpacedRepetitionTests" \
  -derivedDataPath /tmp/WordsKillerDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

现有 5 个测试套件及覆盖范围：
- `SpacedRepetitionTests`（9 项）：SM-2 算法、已掌握词模糊减半、收藏优先组卡、间隔预览、`recordReview` 与 `undoReview`。
- `WordBankParserTests`（10 项）：6 册内置词书完整性（650 词 / 每语种 130 词 / 显式 `id`）、容错解码、词书缓存、4 类开源词典格式适配。
- `StudyAnalyticsTests`（6 项）：今日去重词数、连续打卡（含跨 91 天窗口按需加载）、14 天趋势、12 周热力图、7 天到期预测。
- `QuizAndBackupTests`（4 项）：四选一去重与正确索引、JSON 备份往返幂等恢复、旧版 v1（无 `customNote`）向下兼容。
- `ReleaseReadinessTests`（8 项）：`Info.plist` 发行键、`PrivacyInfo.xcprivacy` 校验、离线隐私政策校验、`SpeechService` 取消/并发竞态/语音回退。

### 3.3 Release 编译与本地归档验证

**无签名 Release 归档（验证真机 `arm64` 编译与资源打包，产物不可上传）**：

```bash
xcodebuild archive \
  -project "Words killer.xcodeproj" \
  -scheme "Words killer" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/WordsKiller-unsigned.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

**签名归档 + 本地导出 IPA（仅在用户要求打包发布时执行，需本机已登录 Team `Y382F52F3K`）**：

```bash
xcodebuild archive \
  -project "Words killer.xcodeproj" \
  -scheme "Words killer" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/WordsKiller-signed.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/WordsKiller-signed.xcarchive \
  -exportPath /tmp/WordsKiller-export \
  -exportOptionsPlist Config/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

> **禁止擅自上传**：`Config/ExportOptions-Upload.plist` 会直接向 App Store Connect 上传二进制。**除非用户明确要求上传并已确认版本号 / 构建号**，否则严禁使用该 plist 执行 `-exportArchive`。

### 3.4 隐私政策一致性检查

每次改动隐私相关文本后，运行以下命令确认两份文件完全一致（无输出即为通过）：

```bash
diff -u PRIVACY.md "Words killer/Resources/PrivacyPolicy.md"
```

---

## 4. 哪些文件不能动（以及高风险联动文件）

### 🔴 严禁擅自修改或删除（必须经用户明确确认）

1. **发布标识与签名配置（`Words killer.xcodeproj/project.pbxproj`）**
   - `PRODUCT_BUNDLE_IDENTIFIER`（主工程 `com.tedji.Words-killer`、测试目标 `com.tedji.Words-killerTests`）——已绑定 App Store Connect 记录 `6837619955` 与 Store Provisioning Profile。
   - `DEVELOPMENT_TEAM`（`Y382F52F3K`，JI CHUNKAI）——不要改回历史旧团队 `5N7K59WT8G` 或清空。
   - `MARKETING_VERSION`（`1.0`）与 `CURRENT_PROJECT_VERSION`（当前已递增至 `3` 并上传 TestFlight）——不可回退构建号，也不要在未要求发版时随意改动版本号。
   - `IPHONEOS_DEPLOYMENT_TARGET`（`17.0`）——不可随意抬升导致丧失 iOS 17–25 兼容性。
   - `INFOPLIST_KEY_CFBundleDisplayName`（`Words Killer`）、`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`（`NO`）、`INFOPLIST_KEY_LSApplicationCategoryType`（`public.app-category.education`）——其中前两项受 `ReleaseReadinessTests` 强校验。
   - `PBXFileSystemSynchronizedRootGroup` 结构——不要手改 `project.pbxproj` 去手动注册单个 Swift 文件。

2. **发行配置文件（`Config/`）**
   - `Config/Info.plist`：**必须保留在 `Config/` 下，绝不可移入 `Words killer/`**（否则与 `GENERATE_INFOPLIST_FILE = YES` 冲突报 `Multiple commands produce Info.plist`）；不可删除 `UIBackgroundModes: ["audio"]`。
   - `Config/ExportOptions-AppStore.plist` 与 `Config/ExportOptions-Upload.plist`：已验证通过 `plutil -lint` 与真实上传，不要擅自改动 `teamID`、`destination` 或签名配置。

3. **合规清单与应用图标**
   - `Words killer/PrivacyInfo.xcprivacy`：App Store 必需隐私清单，受 `ReleaseReadinessTests` 强校验（`NSPrivacyTracking = false`、`CA92.1`）。除非新增需声明的 Apple Required Reason API，否则不要修改。
   - `Words killer/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 与 `Contents.json`：已验收为 `1024 × 1024` 无 Alpha 通道图标，不要覆盖或引入透明通道。

4. **内置词库中已有词条的 `id` 字段（`Words killer/Resources/*.json`）**
   - 包含 `word_bank.json`（500 词）及 `pack_en_exam.json`、`pack_ja_jlpt.json`、`pack_ko_topik.json`、`pack_fr_delf.json`、`pack_es_dele.json`（各 30 词，共 650 词）。
   - 每个词条的显式 `id` 是用户本地 `WordProgress.wordID` 的持久化主键。**严禁修改或删除已有词条的 `id`**，否则会孤立用户的学习进度与助记笔记；且 `WordBankParserTests` 强断言 6 册词包总词数 `650`、每语种 `130`、每条显式声明 `id`。

5. **共享构建方案、CI 与本地发布证据**
   - `Words killer.xcodeproj/xcshareddata/xcschemes/Words killer.xcscheme`：CI 与本地 `xcodebuild` 共享方案，勿随意更改 Target 关联。
   - `.github/workflows/ios-tests.yml`：保持 `macos-26` + Xcode 26+ 测试流稳定。
   - `artifacts/`：存放本地签名归档、IPA、TestFlight 证据与截图（已被 `.gitignore` 忽略）。**切勿删除、覆盖历史发布目录，更不要 `git add -f` 提交进仓库。**
   - `Words killer.xcodeproj/xcuserdata/`：个人 Xcode 状态（已被 `.gitignore`），不要提交。

### 🟡 高风险联动文件（修改时必须遵守约定）

1. **隐私政策双副本同步**
   - `PRIVACY.md` 与 `Words killer/Resources/PrivacyPolicy.md` **必须逐字节保持一致**。`ReleaseReadinessTests` 会检查离线副本包含关键段落与支持链接。
2. **SwiftData 持久化模型（`Words killer/Models/WordProgress.swift`、`CustomWordRecord.swift`、`ReviewEvent.swift`）**
   - 为避免线上升级崩溃，新增存储字段**必须提供默认值或设为 Optional**（维持 SwiftData 自动轻量级迁移）；禁止重命名或删除已有存储属性。
   - 任何模型字段变更**必须同步更新 `BackupService.swift`**（导出 DTO + 恢复逻辑），并确保旧版 v1 备份 JSON 仍可无损恢复（参见 `QuizAndBackupTests.legacyV1BackupWithoutCustomNoteRestoresCleanly`）。
   - 注意：当前 3 个模型均使用了 `@Attribute(.unique)`；未来若规划 iCloud / CloudKit 同步，需先设计去重与无 unique 约束迁移方案（CloudKit 不支持 `@Attribute(.unique)`）。
3. **已有 `@AppStorage` / `UserDefaults` 键名**
   - 禁止随意重命名以下已持久化键名，否则升级后重置用户偏好：
     `selectedLanguage`、`selectedDifficulty`、`autoSpeakOnCard`、`speechSpeed`、`dailyGoal`、`challengeSize`、`isPreferenceExpanded`、`disabledWordPackIDs`、`dailyReminderEnabled`、`reminderHour`、`reminderMinute`、`accentTheme`、`appearanceMode`。

---

## 5. 核心架构红线与已知坑点（Gotchas）

修改业务逻辑或 UI 时，务必遵守以下已经过血泪修复沉淀下来的工程约束：

1. **主线程与并发隔离（`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`）**
   - 纯解析/计算模块（`WordBankParser`、`WordModels`）显式标注 `nonisolated`，导入外部大词典文件与批量粘贴解析必须在后台（`Task.detached`）执行，避免阻塞主线程。
   - `AVSpeechSynthesisVoice.speechVoices()` 在部分系统/模拟器上可能阻塞主线程导致启动白屏；**必须保持在 `Task.detached` 后台线程调用**（见 `SpeechService.swift`），不可在主线程同步调用。
2. **语音回调竞态与锁屏媒体控制**
   - `SpeechService` 按 `ObjectIdentifier(utterance)` 追踪回调；中断上一条朗读时**必须触发且仅触发一次**旧 completion，否则 `AudioLearningController` 中的 `withCheckedContinuation` 会永久挂起。
   - `SpeechService.configureAudioSession()` 故意区分普通点读（`.duckOthers`）与连续听学（空选项 `[]`）——iOS 只有在 `.playback` 不含 `.mixWithOthers`/`.duckOthers` 时才挂载锁屏与控制中心 `MPNowPlayingInfoCenter` 控件，切勿“顺手统一”。
3. **SwiftData 查询与 SwiftUI 渲染性能**
   - `ReviewEvent` 会随使用时长无限增长：**禁止在 View 中对 `ReviewEvent` 使用无界 `@Query`**。`ContentView` 与 `StatsView` 仅查询最近 `StudyAnalytics.recentWindowDays`（91 天）窗口，长连续打卡触发边界时再按需仅拉取 `reviewedAt` 列；`SettingsView` 仅查 `fetchCount`，导出/恢复/重置时按需读取。
   - 在 `WordBookView`、`StatsView` 等视图的 `body` 中，先将 `progressMap`、`allWords`、`filteredWords` 等派生集合**单次求值成局部变量**再供列表行与工具栏复用，切勿在 `ForEach` / `filter` 闭包内重复构建字典。
4. **SM-2 掌握语义与撤回闭环**
   - 所有卡片/测验/词库评分写入必须统一通过 `SpacedRepetitionEngine.recordReview(...)` 双写 `WordProgress` 与 `ReviewEvent`。
   - 首次「认识」进入 `masteryLevel = 2`（「学习中」），达到 `masteryLevel >= 3`（`WordProgress.masteredThreshold`）才计为「已掌握」；已掌握词点「模糊」执行间隔减半 + 回退一阶（不低于 1 天），不打回 12 小时。
   - 撤回（`undoReview`）回滚新词时，若用户已对其收藏或添加个人笔记，需保留记录仅重置 SRS 字段，不可连带误删用户元数据。
   - `WordItem.makeDeterministicID` 仅由 `(language, term)` 推导，刻意排除 `difficulty`，确保调整难度不孤立已有进度。
5. **隐私与功能边界**
   - 严禁引入任何网络统计、崩溃上报 SDK、广告 SDK 或账号系统；若确实需要新增系统权限或网络请求，必须先征得用户确认并同步更新 `PrivacyInfo.xcprivacy`、`PRIVACY.md` 与 `Words killer/Resources/PrivacyPolicy.md`。

---

## 6. 开发与提交流程约定

1. **修改前**：阅读相关模块及对应测试文件；涉及发版、隐私、词库或工程配置时先核对 `APP_STORE_CHECKLIST.md` 与本文件第 4 节。
2. **新增文件**：Swift 源码直接放入 `Words killer/` 对应子目录，测试文件放入 `Words killerTests/`，Xcode 自动同步，无需手动编辑 `project.pbxproj`。
3. **验证门槛**：
   - 运行模拟器全量单元测试（37/37+ 通过、0 失败、0 跳过、Swift 编译 0 警告）。
   - 如新增/调整核心算法、解析格式、数据迁移或合规配置，补充对应 Swift Testing 测试用例。
   - 若修改了隐私文本，执行 `diff -u PRIVACY.md "Words killer/Resources/PrivacyPolicy.md"` 确认零差异。
4. **文档同步**：重要功能变更更新 `README.md` / `HANDOFF.md`；发布状态或构建号变更更新 `APP_STORE_CHECKLIST.md`。
5. **Git 卫生**：切勿提交 `artifacts/`、`DerivedData/`、`xcuserdata/` 或 `.DS_Store`；保持工作区干净，不覆盖用户尚未提交的发版改动。

---

## 7. 本仓库的多模型分工（Codex 是主 Agent）

**Codex** 负责需求、派工、集成、审查和测试，小改动直接在本地完成。设计存在取舍时找 Antigravity，能单独验收的模块才考虑 Grok 写手，需要第二份代码审查时再找 Grok 审查员。按任务选用，避免每次迭代都跑完整套。

### 调用边界

- 对外派工走本节包装脚本，使用当前会话沙箱，网络权限按次审批。保持脚本的 `plan`、`dontAsk`、读写和工具限制，禁用自动批准与绕过沙箱的参数。Codex 主 Agent 可以直接完成工作，也可以在会话允许时使用内置子 Agent。
- 默认给外部模型的上下文限于合成示例、公开资料和经筛选的非敏感摘要。私有源码、diff、未跟踪文件或包含私有细节的 spec 需获用户对接收服务及文件范围的明确授权。沙箱权限控制工具行为，发送范围需要单独核对。Grok 的 `workspace` 和 `read-only` 配置允许读取工作目录之外的文件，不等同于文件白名单。 [Grok Build 沙箱](https://docs.x.ai/build/features/sandbox)
- macOS 上，Grok 会自行应用沙箱，避免额外用 `sandbox-exec` 套住 Grok 包装脚本。若启动时报 `sandbox initialization failed: Operation not permitted`，先检查是否叠加了 `sandbox-exec`。临时验证需要禁止访问真实仓库时，在临时目录配置 Grok 自身的 sandbox profile，写手继承 `workspace`，审查员继承 `read-only`，两者都用 `deny` 拒绝读写真实仓库路径。保留包装脚本的工具限制和当前会话审批。若所需隔离无法生效，转由 Codex 本地处理。
- 先用各 CLI 的默认型号，调用时省略 `--model` 并检查是否继承了 `ADVISOR_MODEL`、`WORKER_MODEL` 或 `REVIEW_MODEL`。有明确需求时才指定当前账号已确认可用的型号。遇到 `unknown model id`，去掉本次型号覆盖后再试。
- 外发被拦截、登录不可用或工作区有改动时，Codex 在本地继续。只有已获对应授权且确有必要时，才从干净基线制作仅含所需文件的临时副本。禁止为派工擅自暂存、提交、还原或移走用户的工作区改动。

### Antigravity (`scripts/ask-advisor`)

用 `agy` 的 `plan` 模式比较方案、检查交互和中文文案，或给出容易遗漏的边界场景。默认沿用 CLI 选型。短文案可选当前账号可用的低延迟档，跨模块设计可选更高推理档。用 `--model` 或 `ADVISOR_MODEL` 单次指定已确认可用的型号，仓库不固定型号。保留 `/plan` 展开，勿重新加上 `--disable-slash-commands`。查看 stderr 的权限提示，确认输出覆盖了提问。 [Antigravity 模型](https://antigravity.google/docs/models) · [Headless 模式](https://antigravity.google/docs/cli/headless/) · [Plan 模式](https://antigravity.google/docs/cli/modes)

```bash
scripts/ask-advisor -- '根据这份设计摘要，列出最多三个影响用户的风险，并给出最小替代方案。'
```

按需用 `--file` 附上已获授权的文本。脚本会复制文件内容，在同一个日志目录下复用顾问工作区，同一日志目录的调用应串行。

### Grok Build 写手 (`scripts/code-worker`)

适合接口和验收条件明确的实现，例如纯 Swift 逻辑及对应的 Swift Testing 用例。任务说明列出起始基线、允许改动的文件、输入输出、必须保留的行为、验收场景和交付内容。让写手汇报改动与已知限制，并把修改留在 worktree。脚本禁止 Grok 跑 shell，测试由 Codex 执行。 [Grok Build 设置](https://docs.x.ai/build/settings)

```bash
AGENT_CODE_ROOT=/Volumes/Mac_Ext scripts/code-worker --task-file /tmp/task.md --branch worker-vocabulary-round
```

上述命令适用于原仓库。它要求工作区干净（含未跟踪文件），并在 `../WordsKiller-wt/<branch>` 创建 worktree。每个写手独占一个分支与 worktree，文件范围须互不重叠。临时副本则使用该副本所在的父目录作为 `AGENT_CODE_ROOT`。

### Grok Build 审查员 (`scripts/grok-review`)

优先对明确的验收点和高风险行为审查，例如 SM-2 写入次数、旧数据兼容和 SwiftUI 交互竞态。用 `--diff-file` 提交已核对、获授权的补丁，并将 `--cwd` 指向仅含已获授权上下文的审查目录。直接对完整工作树调用 `--base` 会收集相对基线的改动和部分未跟踪文件，先核对实际范围。Grok 复审 Grok 写手时属于分开的审查会话，跨模型判断由 Codex 负责。 [Grok Build Headless](https://docs.x.ai/build/cli/headless-scripting)

```bash
scripts/grok-review --cwd /tmp/review-context --diff-file /tmp/approved.diff -- '核对列出的验收条件，指出可复核的阻塞问题。'
```

审查超时后先查日志，区分实际超时、认证失败和型号错误。确认是超时后，用同一份获授权补丁、同一只读目录和 CLI 默认型号重试一次。缩短附加提问到关键验收点，适当提高 `--timeout`（例如从 60 秒提高到 100 秒）。再次超时则由 Codex 本地审查，并记录外部审查未完成。

### 交接与验收

1. 记录脚本返回的 worktree、起始 SHA 和退出状态。检查相对该 SHA 的完整 diff 及 `git status --short`，逐个核对未跟踪文件、越界改动和敏感文件提示。
2. Codex 逐条复核 `Blocking` 的证据和触发条件，按需采纳 `Non-blocking`。同一问题与外部审查员最多往返两轮，剩余分歧由 Codex 依据代码和测试裁决，产品取舍交用户决定。
3. 在可构建的工作树验证受影响行为。只纳入已审查的改动，再对集成结果执行第 6 节的验证。来自临时副本的结果按任务文件逐项纳入，并检查与本地进行中改动的冲突。

### 必须先问人的事（不要交给 worker，也不要自己做）

- 删除数据或做破坏性 git 操作（`reset --hard`、强制推送、删分支）
- 花钱、下单、改计费
- 对外发消息（邮件、Slack、社交、评论）
- 改权限、密钥、证书、`.env`、签名/发布证书
- 发布到 App Store / TestFlight（签名和上架保持手动）
- 向其他项目或全局目录安装工具、改 `~/.zshrc`、改 `~/.gemini/`、`~/.grok/` 或 `~/.codex/` 配置

### 并行

默认同时最多派两个写手，有第三个互不重叠的任务时可增至三个，并遵守当前会话的调度限制。
