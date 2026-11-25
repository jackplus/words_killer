# Words Killer

面向中文母语者的多语种间隔重复（SRS）背词 iOS / iPadOS 应用，基于 **SwiftUI + SwiftData + Swift Charts + AVFoundation + UserNotifications** 构建，纯本地离线运行，无广告、无追踪、无需登录。

## 核心特性

- **多维训练与听学跳词**：背词支持「智能综合 / 专攻到期 / 专攻收藏」三种模式；随身听学可展开队列并跳转到指定单词。
- **今日复习与续练**：背词首页一键进入当前语种和词书的到期短练，每轮最多 6 个不同词；存在错词时可直接发起错词专练。到期词清空后可主动学新词；未完成的练习在退出 App 后仍可从原题、反馈或补练位置继续，并对越界与词条变更自动兜底。闪卡、听学和更多模式位于「更多练习」。
- **多维自测与拼写练习**：内置 [`QuizView`](Words%20killer/Views/QuizView.swift) 与 [`QuizEngine`](Words%20killer/Services/QuizEngine.swift)，支持四选一速测（看词选义、看义选词、听音辨词）及听音拼写填空（兼容智能标点与多空格、按正确前缀逐字提示、解析卡支持例句朗读/收藏/助记笔记、同步全局语速与语音包提示），测验结果自动同步 SRS 记忆进度并支持一键专练错题。
- **界面与交互更新**：统一主题设计、深浅色适配、卡片堆叠与滑动动效、触感和撤回提示，支持减少动态效果，并提供默认 / 深色 / 着色图标。

- **五语种模块化词书体系（18 册 1,800 词 + 容错加载）**：内置核心词库 [`word_bank.json`](Words%20killer/Resources/word_bank.json)（500 词）、5 册考级精选词包（**英语 CET/雅思托福、日语 JLPT、韩语 TOPIK、法语 DELF、西语 DELE**，各 30 词）、8 册场景与进阶扩展词包（**英语四六级核心 150 词、雅思托福学术读写 150 词、科技职场 100 词、生活出行 100 词，以及日/韩/法/西生活文化进阶各 50 词**）以及 4 册高阶强化词包（**GRE/GMAT 专家 150 词、熟词僻义与考研真题核心 100 词、硬核科技财经与法律前沿 100 词、日韩法西高阶表达 100 词**），通过 [`WordBankParser`](Words%20killer/Services/WordBankParser.swift) 实现逐条容错解码、确定性 ID 生成与自动去重，支持在 [`WordPacksView`](Words%20killer/Views/WordPacksView.swift) 按语种筛选、查看各词书掌握进度与独立开关。
- **6 档难度分级、精准抽取与高阶挑战模式**：支持 **零基础 → 日常进阶 → 校园四六级 → 高级学术 → 商务实战 → 硬核专家** 6 级筛选；默认开启「仅当前级别」精准抽取（可切换「含更低级别」），支持单本词书专攻、**标准 / 无音标 / 盲听模式 / 看义回忆** 4 种挑战强度与 **太简单一键标斩熟词**（直接设 60 天超长间隔，并完整支持误触撤回）。
- **词汇短练**：从背词页进入测验，按当前训练队列抽取最多 6 个不同词，轮换看词选义、看义选词和听音选词。答错后立即显示解析，轮末补练一次。结算分别显示首答和补练结果，复习计划按首答更新。同页可切换四选一速测与拼写听写。
- **文字替代与错词专练**：听音选择题可按需播放，作答前也可切换为同一词的文字题。背词页的「错词专练」聚合当前语种和词书中上次标为「不认识」的词，每轮最多 6 个，已到期优先。首答答对的词会移出下一轮，轮末补练用于巩固。
- **公开免费词库无缝接入（多格式开源词典适配）**：内置通用开源词典解析引擎，支持一键从本地文件（`.json` / `.csv` / `.tsv` / `.txt`）或剪贴板导入主流宽松协议开源词库（兼容 **skywind3000/ECDICT CSV**、**KyleBing/english-vocabulary JSON**、**Qwerty-Learner JSON**、**Bluskyo/JLPT_Vocabulary JSON** 等，自动映射 `cet4/cet6/ielts/N5–N1` 等难度标签）。
- **SwiftData 持久化与 SM-2 间隔重复**：通过 [`WordProgress`](Words%20killer/Models/WordProgress.swift)、[`ReviewEvent`](Words%20killer/Models/ReviewEvent.swift) 与 [`SpacedRepetitionEngine`](Words%20killer/Services/SpacedRepetitionEngine.swift) 统一记录卡片、测验与词库的三档记忆反馈：
  - **不认识**：重置掌握阶数并追加至本轮队列末尾二次重测。
  - **模糊**：新词或学习中的词标记为待巩固，12 小时后到期复习；已掌握的词则间隔减半、回退一阶，不再整体打回。
  - **认识**：递进掌握阶数，按 `1 天 → 3 天 → interval × easeFactor` 动态推算下次复习时间。首次「认识」只进入「学习中」，需在间隔复习中再次认出才计为「已掌握」。
- **原生多语种语音朗读**：基于 `AVSpeechSynthesizer` 封装 [`SpeechService`](Words%20killer/Services/SpeechService.swift)，支持切卡自动朗读单词、点击喇叭单独朗读单词或例句，全局统一语速并在缺失系统语音包时给出引导提示。
- **随身听学磨耳朵**：基于 [`AudioLearningController`](Words%20killer/Services/AudioLearningController.swift) 与 [`AudioPlayerView`](Words%20killer/Views/AudioPlayerView.swift)，支持后台循环自动朗读单词外语、中文释义与例句，可自定义每词朗读次数（1~3遍）、词间停顿与播放语速。
- **重点收藏、个人助记笔记与自建词库**：支持卡片一键星标收藏（Favorite，未学收藏词优先组卡）；支持为任意单词编写个人助记笔记（支持词库全文检索与 JSON 备份导出）；支持通过 [`AddCustomWordView`](Words%20killer/Views/AddCustomWordView.swift) 手动录入/编辑单词或批量粘贴文本导入本地 SwiftData，与内置词库无缝混排训练。
- **学习可视化与打卡热力图**：基于 Apple `Charts` 与 [`StudyAnalytics`](Words%20killer/Services/StudyAnalytics.swift) 渲染近 14 天堆叠学习趋势图（含每日目标基准线）、GitHub 风格近 12 周打卡热力图以及未来 7 天待复习预测。
- **每日目标、本地提醒、小组件底座与 JSON 备份**：在 [`SettingsView`](Words%20killer/Views/SettingsView.swift) 中支持设定每日目标与单轮组卡数、基于 [`NotificationService`](Words%20killer/Services/NotificationService.swift) 的本地定时打卡提醒、四套主题配色与深浅外观切换、基于 [`WidgetSnapshotService`](Words%20killer/Services/WidgetSnapshotService.swift) 与 [`WidgetPreviewView`](Words%20killer/Views/WidgetPreviewView.swift) 的「每日一词」小组件实时预览与 `wordskiller://` 深度链接路由，以及基于 [`BackupService`](Words%20killer/Services/BackupService.swift) 的本地 JSON 全量备份导出与恢复。
- **四标签学习闭环**：
  - **背词**：顶部实时展示今日目标进度环与连续打卡天数，支持智能组卡、左右滑卡判词、实时预测下次复习间隔、误触一键撤回、个人助记笔记、测验与听学联动。
  - **词库**：支持按语种、掌握状态（全部 / 错题与模糊 / 已掌握 / 已收藏 / 未学习 / 自建词）筛选与全文搜索（含个人笔记），支持编辑/删除自建词，以及对当前筛选词表直接发起测验或听学。
  - **统计**：汇总核心指标、14 天趋势柱状图、12 周热力图、7 天到期预测与各语种掌握进度。
  - **设置**：管理每日计划、本地通知提醒、个性化主题外观及 JSON 数据导入导出。

## 项目结构

```text
Words killer/
├── Words_killerApp.swift              # App 入口，注入 SwiftData ModelContainer
├── ContentView.swift                  # 背词主训练页（目标进度环、滑卡、测验与听学联动）
├── Models/
│   ├── WordModels.swift               # TargetLanguage, DifficultyLevel, RecallRating, WordItem
│   ├── WordProgress.swift             # SwiftData @Model 持久化记忆与收藏记录
│   ├── CustomWordRecord.swift         # SwiftData @Model 自建生词持久化记录
│   └── ReviewEvent.swift              # SwiftData @Model 每次复习/测验事件日志
├── Services/
│   ├── WordLibrary.swift              # 模块化多词书注册表、词书开关与自建词合并
│   ├── WordBankParser.swift           # 逐条容错解码器与多格式开源词典（ECDICT/KyleBing/JLPT）适配器
│   ├── SpacedRepetitionEngine.swift   # 间隔重复调度、组卡与统一打卡记录引擎
│   ├── StudyAnalytics.swift           # 连续打卡、14天趋势、12周热力图与7天到期预测计算
│   ├── SpeechService.swift            # AVSpeechSynthesizer 语音朗读服务（多语种+中文释义）
│   ├── AudioLearningController.swift  # 随身听学连续自动播放控制器
│   ├── QuizEngine.swift               # 四选一自测与多题型生成引擎
│   ├── NotificationService.swift      # UserNotifications 本地定时复习提醒服务
│   └── BackupService.swift            # 本地 JSON 学习进度与自建词库导出/恢复服务
├── Views/
│   ├── MainTabView.swift              # 底部四标签 TabView 导航与全局主题/外观注入
│   ├── WordCardView.swift             # 词卡主视图（状态标签 + 发音 + 收藏 + 记忆点）
│   ├── WordBookView.swift             # 词库与错题本列表页（支持筛选组测验/听学与词书入口）
│   ├── WordPacksView.swift            # 内置词书管理、公开词库推荐与外部词典文件导入页
│   ├── StatsView.swift                # 学习统计页（Swift Charts 趋势图、热力图与到期预测）
│   ├── SettingsView.swift             # 学习计划、定时提醒、主题外观与数据备份页
│   ├── QuizView.swift                 # 四选一自测、听音拼写与错题重测视图
│   ├── AudioPlayerView.swift          # 随身听学沉浸播放器
│   ├── AddCustomWordView.swift        # 手动单词录入与多格式粘贴批量导入视图
│   └── Components.swift               # 公共 UI 组件、每日目标环与多主题配色
└── Resources/
    ├── word_bank.json                 # 500 词五语种核心词库
    ├── pack_en_exam.json              # 英语 CET-4/6 · IELTS · TOEFL · BEC 扩展词包 (30词)
    ├── pack_en_cet_core.json          # 英语四六级核心高频词书 (150词)
    ├── pack_en_ielts_toefl.json       # 雅思 · 托福学术读写精选词书 (150词)
    ├── pack_en_tech_workplace.json    # 科技互联网与外企职场词书 (100词)
    ├── pack_en_daily_travel.json      # 英语生活出行与地道表达词书 (100词)
    ├── pack_en_gre_gmat.json          # GRE · GMAT 硬核专家词书 (150词)
    ├── pack_en_polysemy_kaoyan.json   # 熟词僻义与考研高阶词书 (100词)
    ├── pack_en_stem_finance_law.json  # 科技论文 · 财经法律前沿词书 (100词)
    ├── pack_ja_jlpt.json              # 日语 JLPT N5–N1 扩展词包 (30词)
    ├── pack_ja_daily_culture.json     # 日语生活旅行与文化进阶词书 (50词)
    ├── pack_ko_topik.json             # 韩语 TOPIK I–II 扩展词包 (30词)
    ├── pack_ko_daily_culture.json     # 韩语日常社交与职场进阶词书 (50词)
    ├── pack_fr_delf.json              # 法语 DELF A1–B2 扩展词包 (30词)
    ├── pack_fr_daily_culture.json     # 法语生活艺术与职场进阶词书 (50词)
    ├── pack_es_dele.json              # 西语 DELE A1–B2 扩展词包 (30词)
    ├── pack_es_daily_culture.json     # 西语旅行文化与实用商务词书 (50词)
    └── pack_multilang_master.json     # 日韩法西高阶表达与硬核词汇词书 (100词)
Words killerTests/                     # Swift Testing 自动化单元测试套件
├── SpacedRepetitionTests.swift        # SM-2 记忆曲线、分级过滤、熟词标斩与撤回持久化测试
├── WordBankParserTests.swift          # 18 册内置词书校验、坏数据容错与 4 类开源词库格式解析测试
├── StudyAnalyticsTests.swift          # 去重打卡、连续天数、14天趋势、12周热力图与到期预测测试
├── QuizAndBackupTests.swift           # 四选一出题不变量与 JSON 备份导出/幂等恢复测试
└── ReleaseReadinessTests.swift        # Info.plist、PrivacyInfo.xcprivacy 与语音兜底合规测试
```

## 运行与打包要求

- **Xcode**：支持 Swift 5.0 与 SwiftData 的 Xcode（建议 Xcode 16+）
- **系统要求**：最低支持 `iOS 17.0` / `iPadOS 17.0` 及以上设备
- **持续集成**：[`.github/workflows/ios-tests.yml`](.github/workflows/ios-tests.yml) 在每次 push 与 PR 时于 macOS 26 / Xcode 26 模拟器上编译并运行全部单元测试，失败时上传 `.xcresult` 与构建日志
- **开发交接文档**：详见 [`HANDOFF.md`](HANDOFF.md)
- **上架清单**：详见 [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md)
- **隐私政策**：纯本地存储，已内置 `PrivacyInfo.xcprivacy`，详见 [`PRIVACY.md`](PRIVACY.md)
