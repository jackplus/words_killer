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

1. **iOS 桌面与锁屏小组件（WidgetKit）**：通过 App Group 共享当前待复习词数、连续打卡天数与「每日一词」卡片。
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
