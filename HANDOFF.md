# Words Killer — 项目开发交接文档（Handoff Guide）

- **仓库地址**: `https://github.com/jackplus/words_killer.git`
- **主分支**: `main`
- **接手基线 Commit**: `81da4ea`（初始 500 词单文件词库 + 基础三标签卡片背词）
- **当前状态**: 已整合 PR #1（性能优化、CI 测试流与 SRS 精度修复）与发行准备改动（发布团队 `Y382F52F3K`、离线隐私政策页、后台语音查询与导出配置），并完成第 5 轮核心体验迭代（个人助记笔记、闪卡误触撤回、动态复习间隔预览、自建词编辑）。**本轮 37/37 项 Swift Testing 单元测试全部通过，Swift 编译 0 警告**。已创建 App Store Connect 记录 `6837619955`，最新本地改动已作为 `1.0 (3)` 成功上传 TestFlight，Apple 二进制「已验证」、构建「准备提交」，37 项测试通过；测试说明已保存，现有 internal 群组（2 名测试员）自动关联，尚未提交正式商店审核。最新商店提审进度见 [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)。

---

## 一、四轮迭代改动总览

### 迭代 1：多维测验、随身听学与自建词库（Commit `eec28f6`）
1. **多维主动回忆测验（`QuizEngine` + `QuizView`）**
   - 新增「四选一速测」（自动轮换 **看词选义 / 看义选词 / 听音辨词** 三种题型，从同语种词池抽取真实干扰项）。
   - 新增「拼写听写」模式（听音/看义拼写输入，支持大小写与空格容错、「提示首字母」与「看答案」）。
2. **随身听学 / 磨耳朵播放器（`AudioLearningController` + `AudioPlayerView`）**
   - 支持按队列自动循环连播：**外语单词发音 → 中文释义朗读（`zh-CN` TTS）→ 双语例句朗读 → 词间停顿缓冲**。
   - 支持配置每词重复遍数（1/2/3 遍）、词间停顿（1.0s～3.0s）、是否朗读释义/例句，以及 `0.75x / 1.0x / 1.25x` 三档语速。
3. **重点生词星标收藏与自建词库（`CustomWordRecord` + `AddCustomWordView`）**
   - `WordProgress` 新增 `isFavorite: Bool = false`（支持 SwiftData 轻量自动迁移），在背词卡、词库行、左滑菜单与详情页支持一键星标收藏。
   - 新增 `CustomWordRecord` SwiftData 模型，支持手动录入单词或批量粘贴文本导入，与内置词库无缝混排学习。

---

### 迭代 2：学习图表可视化、每日目标、本地提醒、主题与备份（Commit `bd8c61b`）
1. **独立打卡事件模型与统计引擎（`ReviewEvent` + `StudyAnalytics`）**
   - 新增 SwiftData 模型 `ReviewEvent`，记录每次卡片、测验、词库评分的时间戳、评分档位与来源（`card` / `quiz` / `wordbook`），解决仅靠 `WordProgress.lastReviewedAt` 在复刷旧词时覆盖历史某天打卡记录的问题，同时向下兼容旧进度数据。
   - 统一封装 `SpacedRepetitionEngine.recordReview(...)`，将 `QuizView` 答题结果正式接入 SRS 记忆曲线（一次答对记 `known`、使用提示后拼对记 `fuzzy`、答错或看答案记 `unknown`），并在测验结算页新增 **「只重测错题」** 按钮。
   - 优化智能组卡排序：`到期旧词 → 已收藏未学新词 → 普通未学新词 → 排期词`，并修复收藏未学词被误计入“当前到期需复习”的统计偏差。
2. **基于 Apple `Charts` 的数据可视化（升级 `StatsView`）**
   - **近 14 天堆叠学习趋势图**：按「认识 / 模糊 / 不认识」分色堆叠柱状图 + 每日目标基准虚线（`RuleMark`）。
   - **GitHub 风格近 12 周打卡热力图**：7 行（周一至周日对齐）× 12 列网格，5 级主题色深浅，支持点按任意日期查看当日复习次数。
   - **未来 7 天待复习预测图**：基于 SM-2 `nextReviewDate` 预测今日到期、明天、后天及未来一周复习负载。
3. **每日目标、本地通知、多主题外观与 JSON 全量备份（`SettingsView` + `NotificationService` + `BackupService`）**
   - 底部导航升级为四标签（**背词 / 词库 / 统计 / 设置**）；背词页与统计页顶部新增 `DailyGoalBanner` 目标进度环，背词页次要设置改为可折叠布局以突出词卡主体，并支持自定义每轮组卡词数（5/10/15/20 词）。
   - 基于 `UserNotifications` 实现每日定时本地打卡提醒、3 秒测试通知与系统权限跳转引导。
   - 支持 **墨绿 / 深海蓝 / 靛紫 / 琥珀橙** 四套主题强调色实时切换，以及 **跟随系统 / 浅色 / 深色** 外观模式。
   - 基于 `FileDocument` 实现学习进度、自建词库与打卡记录的本地 JSON 全量导出与幂等合并恢复。

---

### 迭代 3：模块化词书、公开开源词库适配与单元测试体系（Commit `bd6df59`）
1. **逐条容错加载与防重架构（`WordBankParser` + `WordModels`）**
   - 将原本整表强耦合解码升级为 `LossyElement<WordItem>` 逐条容错解码：外部词表混入空字段或异常项时仅跳过脏数据，绝不拖垮整份词库。
   - 新增确定性 FNV-1a ID 生成器（`WordItem.makeDeterministicID`）与 `(语种, 词形)` 双重去重器，消除重复 ID 引发的 SwiftUI `ForEach` 或唯一键冲突风险。
2. **6 册模块化内置词书（扩充至 650 词）与词书管理页（`WordLibrary` + `WordPacksView`）**
   - 在核心 `word_bank.json`（500 词）基础上，新增 5 册零重叠考级词书：英语 `pack_en_exam.json`（CET-4/6 · IELTS · TOEFL · BEC）、日语 `pack_ja_jlpt.json`（JLPT N5–N1）、韩语 `pack_ko_topik.json`（TOPIK I–II）、法语 `pack_fr_delf.json`（DELF A1–B2）、西语 `pack_es_dele.json`（DELE A1–B2），支持按需独立开关启用。
3. **5 类主流开源词库无缝导入适配**
   - 支持从系统「文件」App 直接导入 `.json` / `.csv` / `.tsv` / `.txt` 词典文件或剪贴板批量粘贴，自动识别并适配：
     1. **Words Killer 原生词包 JSON**
     2. **KyleBing `english-vocabulary` JSON**（BSD-3-Clause，含词性与短语搭配提取）
     3. **Qwerty-Learner 词典 JSON**（`name` / `trans` / `usphone`）
     4. **Bluskyo `JLPT_Vocabulary` / 多语种词表 JSON**（`expression` / `reading` / `meaning` / `level`，自动将 `N5–N1` 映射五档难度）
     5. **skywind3000 `ECDICT` CSV / Anki TSV**（MIT，支持 RFC-4180 引号内逗号解析，自动根据 `zk/gk/cet4/cet6/ielts/toefl/gre` 标签推断难度）
4. **Swift Testing 自动化单元测试目标（`Words killerTests`）**
   - 在工程中新增 `Words killerTests` 单元测试 Target 与共享 Scheme `Words killer.xcscheme`，覆盖 SM-2 算法、组卡优先级、6 册词书完整性、开源词典解析、打卡统计热力图、四选一出题与备份幂等恢复。

---

### 迭代 4：App Store 上架合规与锁屏媒体控制收尾（Commit `cec76b7`）
1. **Apple 隐私清单（`Words killer/PrivacyInfo.xcprivacy`）**
   - 声明 `NSPrivacyTracking = false`、无追踪域名、无数据收集，并声明 `NSPrivacyAccessedAPICategoryUserDefaults` 官方原因码 `CA92.1`。
2. **后台音频模式与锁屏 / 耳机控制（`Config/Info.plist` + `AudioLearningController`）**
   - 写入 `UIBackgroundModes: ["audio"]`；在「随身听学」中集成 `MPNowPlayingInfoCenter` 与 `MPRemoteCommandCenter`，锁屏、灵动岛与控制中心实时显示当前单词与释义，支持锁屏按键及 AirPods 直接播放、暂停、切上一词/下一词。
3. **最低系统版本与 Info.plist 发行键完善**
   - `IPHONEOS_DEPLOYMENT_TARGET` 从 `26.5` 下调为 **`17.0`**（大幅扩展可安装设备范围）；
   - 配置 `CFBundleDisplayName = "Words Killer"`、`CFBundleDevelopmentRegion = "zh-Hans"`、`LSApplicationCategoryType = "public.app-category.education"`、`ITSAppUsesNonExemptEncryption = NO`。
4. **TTS 离线语音包缺失兜底提示与提审手册**
   - `SpeechService.resolveBestVoice` 支持同语系口音回退（如缺失 `fr-FR` 自动回退 `fr-CA`）及缺失检测横幅提示 `VoicePackNoticeBanner`；
   - 新增 `ReleaseReadinessTests.swift` 自动化校验产物合规性，并编写可直接复制粘贴的提审指南 [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md)。

---

## 二、新增与修改文件清单

### 1. 数据模型（`Words killer/Models/`）
| 文件路径 | 状态 | 说明 |
| :--- | :---: | :--- |
| `Words killer/Models/WordModels.swift` | 修改 | 扩展语种/考纲难度弹性解析、`WordItem` 容错解码、确定性 ID 生成与 `WordPackDescriptor` |
| `Words killer/Models/WordProgress.swift` | 修改 | 新增 `isFavorite: Bool = false` 星标收藏持久化属性 |
| `Words killer/Models/CustomWordRecord.swift` | 新增 | 用户自建与外部导入单词的 SwiftData `@Model` |
| `Words killer/Models/ReviewEvent.swift` | 新增 | 每次卡片/测验/词库复习打卡事件的 SwiftData `@Model` |

### 2. 核心业务服务（`Words killer/Services/`）
| 文件路径 | 状态 | 说明 |
| :--- | :---: | :--- |
| `Words killer/Services/WordLibrary.swift` | 修改 | 6 册内置模块化词书注册表、词书启停过滤与自建词合并 |
| `Words killer/Services/WordBankParser.swift` | 新增 | 逐条容错解码、防重与 5 类开源词库格式（JSON/CSV/TSV）解析器 |
| `Words killer/Services/SpacedRepetitionEngine.swift` | 修改 | 新增 `recordReview` 统一双写接口，优化收藏未学新词优先组卡逻辑 |
| `Words killer/Services/StudyAnalytics.swift` | 新增 | 今日去重学词数、连续打卡天数、14天趋势、12周热力图与7天到期预测纯函数计算 |
| `Words killer/Services/SpeechService.swift` | 修改 | 新增中文释义朗读、异步完成回调、1.25x 语速、后台连播音频模式与语音包缺失检测 |
| `Words killer/Services/AudioLearningController.swift` | 新增 | 随身听学多阶段异步循环调度器 + 锁屏 `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` |
| `Words killer/Services/QuizEngine.swift` | 新增 | 四选一三种子题型与同语种干扰项生成引擎 |
| `Words killer/Services/NotificationService.swift` | 新增 | `UserNotifications` 本地每日定时复习提醒与测试通知封装 |
| `Words killer/Services/BackupService.swift` | 新增 | 学习进度、自建词库与打卡事件的 JSON `FileDocument` 导出与幂等恢复 |

### 3. 界面视图与入口（`Words killer/Views/` 及根目录）
| 文件路径 | 状态 | 说明 |
| :--- | :---: | :--- |
| `Words killer/Words_killerApp.swift` | 修改 | 注册 `[WordProgress.self, CustomWordRecord.self, ReviewEvent.self]` 容器 |
| `Words killer/ContentView.swift` | 修改 | 新增今日目标进度环、可折叠语种难度面板、测验/听学入口、星标收藏与语音包提示横幅 |
| `Words killer/Views/MainTabView.swift` | 修改 | 升级为四标签导航（背词/词库/统计/设置），注入全局主题色与深浅色模式 |
| `Words killer/Views/WordCardView.swift` | 修改 | 词卡右上角新增星标收藏按钮 |
| `Words killer/Views/WordBookView.swift` | 修改 | 新增已收藏/自建词筛选、词书中心入口、当前筛选列表直接发起测验/听学、自建词删除 |
| `Words killer/Views/WordPacksView.swift` | 新增 | 内置 6 册词书独立开关、公开免费词库协议目录与本地 JSON/CSV/TSV 文件导入页 |
| `Words killer/Views/AddCustomWordView.swift` | 新增 | 单词手动录入与多格式剪贴板批量解析预览导入页 |
| `Words killer/Views/QuizView.swift` | 新增 | 四选一速测、听音拼写测试、SRS 进度同步与错题专练结算页 |
| `Words killer/Views/AudioPlayerView.swift` | 新增 | 随身听学沉浸式卡片播放器与播放偏好面板 |
| `Words killer/Views/StatsView.swift` | 新增/升级 | 接入 `Charts` 渲染 14 天趋势图、12 周交互式热力图与 7 天到期预测图 |
| `Words killer/Views/SettingsView.swift` | 新增 | 每日目标、每轮词数、本地通知提醒、四套主题与外观模式、JSON 备份导出/恢复与重置 |
| `Words killer/Views/Components.swift` | 修改 | 新增 `AccentTheme`、`AppearanceMode`、`DailyGoalBanner` 与 `VoicePackNoticeBanner` |

### 4. 词库资源、工程配置、文档与测试
| 文件路径 | 状态 | 说明 |
| :--- | :---: | :--- |
| `Words killer/Resources/pack_*.json`（5 个文件） | 新增 | 英（CET/雅思托福）、日（JLPT）、韩（TOPIK）、法（DELF）、西（DELE）各 30 词扩展包 |
| `Words killer/PrivacyInfo.xcprivacy` | 新增 | App Store 必需隐私清单（声明 `CA92.1` 与零追踪） |
| `Config/Info.plist` | 新增 | 补充合并 `UIBackgroundModes = ["audio"]` |
| `Words killer.xcodeproj/project.pbxproj` | 修改 | 下调 `IPHONEOS_DEPLOYMENT_TARGET = 17.0`、配置 `zh-Hans`、配置 `Words killerTests` 目标 |
| `Words killer.xcodeproj/xcshareddata/xcschemes/Words killer.xcscheme` | 新增 | 共享 Scheme，关联主工程与单元测试 Target |
| `Words killerTests/*.swift`（5 个文件） | 新增 | 21 项 Swift Testing 自动化单元测试（算法、词库解析、统计、备份与上架合规） |
| `APP_STORE_CHECKLIST.md` / `README.md` | 新增/修改 | App Store 提审全套可直接粘贴文案与最新架构说明 |

---

## 三、数据持久化与关键架构约定（供后续开发参考）

### 1. SwiftData 模型列表
容器注册于 `Words_killerApp.swift`，包含 3 个 `@Model` 实体：
- `WordProgress`（唯一键 `@Attribute(.unique) var wordID: String`）：每个词一条记录，维护 SM-2 `masteryLevel`、`easeFactor`、`intervalDays`、`nextReviewDate` 与 `isFavorite`。
- `CustomWordRecord`（唯一键 `@Attribute(.unique) var id: String`，以 `"custom-"` 为前缀）：存储手动录入与外部文件导入词条。
- `ReviewEvent`（唯一键 `@Attribute(.unique) var id: String`）：追加式打卡事件流，驱动趋势图与热力图。

> **迁移注意**：后续若为已有 `@Model` 新增字段，务必提供默认值（如 `var note: String = ""`）或设为 Optional，以保持 SwiftData 自动轻量级迁移兼容。

### 2. `@AppStorage` / `UserDefaults` 配置键速查表
| Key 名称 | 类型 | 默认值 | 用途 |
| :--- | :---: | :---: | :--- |
| `selectedLanguage` | `String` | `"english"` | 当前训练目标语种 |
| `selectedDifficulty` | `String` | `"beginner"` | 当前训练难度上限 |
| `autoSpeakOnCard` | `Bool` | `true` | 切卡时是否自动朗读单词 |
| `speechSpeed` | `String` | `"normal"` | 朗读语速（`slow` / `normal` / `fast`） |
| `dailyGoal` | `Int` | `20` | 每日目标背词数 |
| `challengeSize` | `Int` | `10` | 单轮智能组卡词数（5 / 10 / 15 / 20） |
| `isPreferenceExpanded` | `Bool` | `false` | 背词页次要语音设置折叠状态 |
| `disabledWordPackIDs` | `String` | `""` | 逗号分隔的已停用内置扩展词书 ID 列表 |
| `dailyReminderEnabled` | `Bool` | `false` | 是否开启每日定时本地通知 |
| `reminderHour` / `reminderMinute` | `Int` | `20` / `30` | 每日提醒时间（默认 20:30） |
| `accentTheme` | `String` | `"forest"` | 主题色（`forest` / `ocean` / `indigo` / `sunset`） |
| `appearanceMode` | `String` | `"system"` | 外观模式（`system` / `light` / `dark`） |

### 3. 工程关键设计细节（Gotchas）
1. **为什么 `Config/Info.plist` 放在 `Words killer/` 目录之外？**
   本工程采用 Xcode 16+ 的 `PBXFileSystemSynchronizedRootGroup`（自动同步 `Words killer/` 下所有文件）。若把 `Info.plist` 放在 `Words killer/` 内，资源拷贝阶段会与 `GENERATE_INFOPLIST_FILE = YES` 产生 `Multiple commands produce Info.plist` 冲突；放在根目录 `Config/Info.plist` 并配合 `INFOPLIST_FILE = Config/Info.plist` 可由 Xcode 自动干净合并。
2. **为什么 `SpeechService` 区分普通点读与连续后台听学的 AudioSession 选项？**
   iOS 规定只有当 `.playback` 会话**不带** `.mixWithOthers` / `.duckOthers` 时，系统锁屏与控制中心才会挂载 `MPNowPlayingInfoCenter` 播放控件。因此单卡点读开启 `.duckOthers`（不打断用户背景音乐），进入「随身听学」时自动切换为独占 `.playback` 以激活锁屏与耳机切词控件。
3. **全局并发隔离**：主工程与 `Words killerTests` 均开启了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，新增服务若为纯值计算或 `FileDocument` 序列化需注意隔离边界。

---

## 四、常用编译、测试与发布命令

```bash
# 1. 命令行编译验证（模拟器）
xcodebuild -scheme "Words killer" \
  -sdk iphonesimulator \
  -derivedDataPath /tmp/WordsKillerDerivedData \
  build CODE_SIGNING_ALLOWED=NO

# 2. 运行全部 35 项 Swift Testing 单元测试（请将 name 替换为本机已安装的模拟器名称）
xcodebuild test -scheme "Words killer" \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro" \
  -derivedDataPath /tmp/WordsKillerDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

- **App Store 打包与提审步骤**：请直接参阅仓库根目录的 [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md)。

---

## 五、后续版本演进建议（v1.2+ Roadmap）

1. **iOS 桌面与锁屏小组件（WidgetKit，应用端底座已就绪）**：`WidgetSnapshot`、`DailyWordSelector`、`WidgetSnapshotStore`（自动探测 App Group `group.com.tedji.Words-killer`，未配置时无警告降级）、`wordskiller://` 深度链接路由、设置页实时预览及扩展源码模板 `Config/WidgetExtensionTemplate/WordsKillerWidgetExtension.swift` 已落地；后续只需在 Xcode 开启 App Group Capability 并挂载 Widget Extension Target 即可上线。
2. **iCloud（CloudKit）可选同步**：在保持免登录纯苹果生态隐私的前提下，为同 Apple ID 下的 iPhone 与 iPad 自动同步学习进度、助记笔记与自建词库。
3. **多维复习过滤（已完成）**：背词主页已支持「智能综合 / 专攻到期 / 专攻收藏」训练模式，详见下节。


## 六、本地后续改动与构建 1.0 (3)（2026-11-23）

本次提交基于 `c59dca1`，包含已打包为 TestFlight 构建 `1.0 (3)` 的以下改动：

- **多维训练模式**：新增 `StudyMode.smart / dueOnly / favoritesOnly`，背词页支持智能综合、专攻到期与专攻收藏；新偏好键 `studyFilterMode` 不覆盖旧键，无匹配词时返回空队列。
- **听学队列跳转**：`AudioLearningController.jumpToWord(at:)` 支持点击指定词，拦截越界索引，并保留跳转前的播放/暂停语义。
- **学习交互与界面**：新增 `Views/DesignSystem.swift`、主题环境注入、可读列宽、深浅色背景、卡片堆叠、滑动退出、差异化触感、Toast 撤回提示、庆祝和测验动画；按减少动态效果设置降级。
- **图标**：使用本地新增的默认、深色、着色三套 1024×1024 无 Alpha 图标，未重新绘制或覆盖源图。
- **验证**：37/37 测试通过，新增到期/收藏筛选及听学跳词测试。iPhone 浅/深色、iPad 浅色首屏检查通过；真机触感、锁屏音频及完整辅助功能仍需 TestFlight 实测。
- **打包与证据**：用户明确确认版本 `1.0 (3)` 后将工程构建号 2 更新为 3。本地记录、源码补丁/新增文件、逐文件哈希、签名归档、发行 IPA、测试结果与截图保存在 `artifacts/testflight-2026-11-23/`，不覆盖历史目录。上传结果以 `APP_STORE_CHECKLIST.md` 最新记录为准。

- **上传完成**：`1.0 (3)` 已通过 Apple 二进制验证，TestFlight 显示「准备提交」并自动关联 internal 群组的 2 名测试员。本轮新增功能与发布文档随本次提交一并同步 GitHub；尚未提交正式审核。

## 七、词汇练习迭代（2026-11-24）

- **工作区基线**：`2cc8562` 之后的本地改动将词库扩展到 18 册 1,800 词，引入六档难度、单书专攻、四种闪卡挑战以及可撤回的快速标记熟词。
- **已实现**：背词页默认进入「词汇短练」，从当前队列抽取最多 6 个不同词，轮换形、义、音题型并即时解析。错词在轮末以同题型补练一次，重新抽取并洗牌选项。首答沿用测验来源写入 SM-2，结算分别展示首答和补练成绩。参考多邻国公开说明中的词汇、听力和错题练习。 [听力练习](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-listening-skills/) · [错题回流](https://blog.duolingo.com/october-2026-update/)
- **验证**：iPhone 18 Pro 模拟器通过 44 项 Swift Testing 测试和一项独立端到端测试。端到端短练完成 6 题首答和 4 题补练，SwiftData 中有 6 笔测验记录，分别对应 6 个首答词。

## 八、文字替代与跨轮错词专练（2026-11-24）

- **文字替代**：听音选择题由用户触发朗读，可在作答前就地切换为同一词的看词选义。切换不记分，答错后按实际题型补练。拼写听写保留原有朗读方式。
- **错词专练**：在背词页单独进入，从当前语种和词书的学习进度筛选上次标为「不认识」且已有评分时间的词。先排已到期词，同一组内按失误时间从近到远排序，每轮最多 6 词。每轮重新读取本地进度，首答答对的词不再进入下一轮。已补练但首答答错的词会继续保留。
- **进度一致性**：词汇短练和错词专练仅在首答写入复习计划。如果测验更新了仍可撤回卡片评分的词，结束该轮卡片的撤回历史，防止旧快照覆盖新进度。
- **验证**：iPhone 18 Pro 模拟器通过 49 项 Swift Testing 测试和 1 项独立端到端测试，覆盖听音转文字、补练、重启后的语种与词书隔离、答对移出错词及撤回冲突。读取测试库确认 7 笔测验记录对应 7 次首答，冲突词保留后来答对后的进度。
- **小规模试用**：已确定同人 A/B 方案、核查两项指标的可计算范围，并备好本地统计脚本。现有数据为模拟器 QA，词义配对暂缓，待真人对照达到预设门槛后再推进。 [试用方案与口径](VOCABULARY_PILOT.md)

## 九、今日复习与本地续练

- **背词首页**：优先提供一轮续练，其次在当前语种和词书范围内按到期时间选择最多 6 个不同词，复习覆盖该范围的所有难度。清空到期词后，用户可按所选难度范围主动学新词。闪卡、速测、听学和错词专练均可从「更多练习」打开。
- **保存与恢复**：一份设备本地的临时练习进度保存在 SwiftData，包含题序、选项、文字替代、答案和补练位置。首答记录、排期和练习进度共用一次提交。切换语种或词书、删词、待答词在别处被评分、成功导入备份或重置进度后，旧轮次结束。备份仍导入和导出学习数据，临时练习独立保存在本机。
- **练习结果**：结算区分首答与补练，列出错词的下次复习时间和当前范围剩余到期词。用户可以继续复习、在无到期词时开启新词，或进入错词专练。错题补练不改变排期。
- **验证**：54 项 Swift Testing 测试通过。iPhone 18 Pro 模拟器验证未答、反馈、听音切换和补练阶段重启恢复，以及从结算进入错词专练。测试库中 4 次首答对应 4 笔测验记录，完成后临时练习已清除。iPhone 17e 在辅助功能大字号下通过首页、首题和暂停检查。端到端测试使用临时测试工程和合成学习记录。
- **真人验收**：在同一设备和词书上对比旧版与新版，记录从背词首页可操作到首题呈现的时间、点击数、开轮与结算时间，覆盖无声场景、大字和 VoiceOver。次日首答正确率与覆盖率沿用现有 A/B 口径，词义配对仍由试用门槛决定。 [真人试用方案](VOCABULARY_PILOT.md)

## 十、练习反馈与题目质量（2026-11-25）

- 拼写结算显示「首次独立拼对」。使用字母提示或曾拼错的词，纠正后记为模糊并列入巩固词；空白输入不计错，已答完的输入锁定。末题可直接查看成绩。
- 看义选词排除同语种、归一化后释义相同的干扰词。题库中没有合适的干扰项时沿用现有的少选项行为。
- 本轮采用模拟器验收。真人次日结果继续沿用原试用方案，词义配对保留在试用原型。
- 验证通过 56 项 Swift Testing 测试，Swift 编译无警告。临时界面工程实测三题分别使用提示、纠错和独立拼写，结算为 1/3；拼对后键盘收起。首次界面测试受键盘遮挡失败，复测覆盖键盘提交和下一题入口。

## 十一、主练习闭环、拼写容错与续练加固（2026-11-25）

- **拼写容错与逐字提示（`QuizEngine` + `QuizView`）**：新增 `QuizEngine.isSpellingMatch`（忽略首尾空白、折叠连续空格、兼容 iOS 智能弯撇号与连字符、不区分大小写）和 `QuizEngine.nextSpellingHint`（按最长正确前缀仅揭示下一字符，避免输错后缀时一次性剧透整词）。
- **练习语音与收藏笔记闭环（`QuizView` + `WordBookView`）**：测验与词库同步全局 `@AppStorage("speechSpeed")` 朗读语速，并在测验页展示 `VoicePackNoticeBanner` 离线语音包缺失指引；测验解析卡新增例句朗读、星标收藏与个人助记笔记展示/编辑（按 `wordID` 直查 SwiftData 避免覆盖刚提交的 SRS 进度），结算错词列表区分「不认识 / 待巩固」并支持星标收藏，且仅在存在真正 `.unknown` 错词时展示「错词专练」入口，避免拼写仅提示巩固后点进空列表。
- **今日复习续练加固与首页快捷入口（`TodayPractice` + `ContentView`）**：`TodayPracticeState.isValid` 补齐空题单、`index` 越界与 `retryQuestions` 词条变更校验；背词首页在保持「开始复习 / 继续复习 / 学新词」主按钮与一键直达不变的前提下，当当前范围存在错词时展示「错词专练（N 词）」次级入口，并在自建词内容编辑或进度记录数变更时即时刷新。
- **验证**：iPhone 18 Pro 模拟器通过 **59/59 项** Swift Testing 单元测试（新增拼写归一化、逐字提示与续练越界/过期补练校验 3 项测试），Swift 编译 0 警告，`PRIVACY.md` 与内置副本零差异。词义配对继续按试用门槛暂缓。

## 十二、WidgetKit 小组件底座、每日一词与深度链接（2026-11-25）

- **共享快照与每日一词引擎（`WidgetSnapshotService.swift`）**：
  - 定义主 App 与未来 Widget Extension 可共享编译的 `WidgetSnapshot`、`WidgetDailyWord`、`DailyWordSelector`、`WidgetSnapshotBuilder` 与 `WidgetSnapshotStore`。
  - `DailyWordSelector` 按「已到期旧词 → 收藏未掌握 → 未学新词 → 兜底」分层，并以自然日 FNV-1a 种子实现同日确定性、跨日自动轮换。
  - `WidgetSnapshotStore` 通过 `containerURL(forSecurityApplicationGroupIdentifier:)` 自动探测 App Group（`group.com.tedji.Words-killer`）：未开启权限时零沙箱警告降级到标准 `UserDefaults`，开启后无需改代码即可自动切入共享容器并触发 `WidgetCenter.shared.reloadAllTimelines()`。
- **深度链接与全局路由（`AppDeepLink.swift` + `MainTabView` / `ContentView` / `WordBookView`）**：
  - 支持 `wordskiller://today`、`wordskiller://mistakes`、`wordskiller://word?id=<id>`（兼容 `/word/<id>`）与 `wordskiller://stats` 路由；通过 `@Observable AppRouter` 联动四标签导航、今日复习/错词专练自动拉起与词库词条详情直达。
  - 背词首页刷新、备份恢复与清空进度均自动同步或清理小组件快照，同时严格保持背词首页主按钮与一次点击直达体验不变。
- **App 内实时预览与扩展模板（`WidgetPreviewView.swift` + `SettingsView.swift` + `Config/WidgetExtensionTemplate/WordsKillerWidgetExtension.swift`）**：
  - 设置页新增「桌面与锁屏小组件」页面，提供桌面小号/中号（每日一词支持朗读、换一词与隐藏中文释义开关）、锁屏矩形与锁屏圆形实时预览，点按即可实测深度链接跳转。
  - 在 `Config/WidgetExtensionTemplate/` 预置完整的 WidgetKit Extension 源码模板，不改动 `project.pbxproj` 签名与 Entitlements，保持现有 TestFlight 打包流程零风险。
- **验证**：iPhone 18 Pro 模拟器通过 **64/64 项** Swift Testing 单元测试（新增 `WidgetAndDeepLinkTests` 5 项测试），Swift 编译 0 警告，`PRIVACY.md` 与内置副本零差异。

## 十三、GitHub 同步与 TestFlight 1.0 (4)（2026-11-25）

- 用户确认上传 1.0 (4)，本轮发布前重新运行 64 项全量测试并完成签名 Release 归档。所有本地功能、试用原型、匿名模板和多 Agent 包装脚本一并纳入 GitHub 同步范围。
- 桌面与锁屏 Extension 目前为模板，App 内小组件预览和路由可测试。真人次日数据及真机验收仍待收集，词义配对仅在试用原型内。
- 构建导出、上传及 Apple 处理结果以 `APP_STORE_CHECKLIST.md` 第十二节为准。归档、IPA 与日志位于新的本地发布目录 `artifacts/testflight-2026-11-25/`。
- 功能代码已以 `ce071bd` 推送 GitHub main。2026-11-25 10:44:05（Asia/Taipei）Xcode 确认 1.0 (4) 上传成功。用户登录后已确认 Apple 二进制「已验证」、构建「准备提交」，internal 群组自动关联 2 名测试员，测试说明保存并核实。
- 上传后补充了 Xcode 26 的首页表达式与观察链拆分，修复编译器类型检查超时；最新 GitHub 代码包含此兼容修复，已上传构建对应 `ce071bd`。

## 十四、实测体验修复：双入口并行与听音选词自动播音（2026-11-25）

- **背词首页并行保留「复习」与「背新词」（`ContentView` + `QuizView`）**：
  - 背词主面板升级为「今日学习」，同时展示当前范围的「待复习」与「可背新词（含当前难度）」余量，并列提供「开始复习 / 继续复习」与「背新词 / 继续背新词」双入口，不再因存在到期词而隐藏背新词。
  - 若存在未完成续练并显式切换至另一种学习，先安全清理临时续练草稿（已完成的首答进度与打卡记录已落盘零丢失）再开启新轮次；结算页同步提供「继续复习」与「背新词」双出口。
- **听音选词自动朗读（`QuizEngine` + `QuizView`）**：
  - 新增 `QuizEngine.shouldAutoSpeak(question:hasAnswered:)`；当首次呈现或切入未作答的「听音选词」题（含首轮、续练恢复及错题补练）时，按全局 `speechSpeed` 自动朗读当前单词；已作答反馈态、非听音题或切换「不便听音，换文字题」后不重复触发，切题前先停止旧朗读防止串音。
- **验证**：新增 `autoSpeakRuleTargetsOnlyUnansweredAudioQuestions` 与 `switchingFromDueReviewToNewWordsPreservesCompletedReviewProgress` 两项测试，iPhone 18 Pro 模拟器全量通过 **66/66 项** Swift Testing 单元测试，Swift 编译 0 警告，`PRIVACY.md` 与内置副本零差异。
- **发布准备**：本轮发布前在 iPhone 18 Pro Max 重新运行全量 66 项测试，0 失败、0 跳过；未签名 Release arm64 归档通过。用户已确认上传 1.0 (5)，发行结果见 `APP_STORE_CHECKLIST.md` 第十三节。
