# Words Killer

面向中文母语者的多语种间隔重复（SRS）背词 iOS / iPadOS 应用，基于 **SwiftUI + SwiftData + Swift Charts + AVFoundation + UserNotifications** 构建，纯本地离线运行，无广告、无追踪、无需登录。

## 核心特性

- **五语种模块化词书体系（6 册 650 词 + 容错加载）**：内置核心词库 [`word_bank.json`](Words%20killer/Resources/word_bank.json)（500 词）及五套考级扩展词包（**英语 CET/雅思托福、日语 JLPT、韩语 TOPIK、法语 DELF、西语 DELE**，各 30 词），通过 [`WordBankParser`](Words%20killer/Services/WordBankParser.swift) 实现逐条容错解码、确定性 ID 生成与自动去重，支持在 [`WordPacksView`](Words%20killer/Views/WordPacksView.swift) 按需独立开关词书。
- **公开免费词库无缝接入（多格式开源词典适配）**：内置通用开源词典解析引擎，支持一键从本地文件（`.json` / `.csv` / `.tsv` / `.txt`）或剪贴板导入主流宽松协议开源词库（兼容 **skywind3000/ECDICT CSV**、**KyleBing/english-vocabulary JSON**、**Qwerty-Learner JSON**、**Bluskyo/JLPT_Vocabulary JSON** 等，自动映射 `cet4/cet6/ielts/N5–N1` 等难度标签）。
- **SwiftData 持久化与 SM-2 间隔重复**：通过 [`WordProgress`](Words%20killer/Models/WordProgress.swift)、[`ReviewEvent`](Words%20killer/Models/ReviewEvent.swift) 与 [`SpacedRepetitionEngine`](Words%20killer/Services/SpacedRepetitionEngine.swift) 统一记录卡片、测验与词库的三档记忆反馈：
  - **不认识**：重置掌握阶数并追加至本轮队列末尾二次重测。
  - **模糊**：标记为待巩固状态，设定 12 小时后到期复习。
  - **认识**：递进掌握阶数，按 `1 天 → 3 天 → interval × easeFactor` 动态推算下次复习时间。
- **原生多语种语音朗读**：基于 `AVSpeechSynthesizer` 封装 [`SpeechService`](Words%20killer/Services/SpeechService.swift)，支持切卡自动朗读单词、点击喇叭单独朗读单词或例句。
- **多维自测与拼写练习**：内置 [`QuizView`](Words%20killer/Views/QuizView.swift) 与 [`QuizEngine`](Words%20killer/Services/QuizEngine.swift)，支持四选一速测（看词选义、看义选词、听音辨词）及听音拼写填空，测验结果自动同步 SRS 记忆进度并支持一键专练错题。
- **随身听学磨耳朵**：基于 [`AudioLearningController`](Words%20killer/Services/AudioLearningController.swift) 与 [`AudioPlayerView`](Words%20killer/Views/AudioPlayerView.swift)，支持后台循环自动朗读单词外语、中文释义与例句，可自定义每词朗读次数（1~3遍）、词间停顿与播放语速。
- **重点收藏与自建词库**：支持卡片一键星标收藏（Favorite，未学收藏词优先组卡）；支持通过 [`AddCustomWordView`](Words%20killer/Views/AddCustomWordView.swift) 手动录入单词或批量粘贴文本导入本地 SwiftData，与内置 500 词库无缝混排训练。
- **学习可视化与打卡热力图**：基于 Apple `Charts` 与 [`StudyAnalytics`](Words%20killer/Services/StudyAnalytics.swift) 渲染近 14 天堆叠学习趋势图（含每日目标基准线）、GitHub 风格近 12 周打卡热力图以及未来 7 天待复习预测。
- **每日目标、本地提醒与 JSON 备份**：在 [`SettingsView`](Words%20killer/Views/SettingsView.swift) 中支持设定每日目标与单轮组卡数、基于 [`NotificationService`](Words%20killer/Services/NotificationService.swift) 的本地定时打卡提醒、四套主题配色与深浅外观切换，以及基于 [`BackupService`](Words%20killer/Services/BackupService.swift) 的本地 JSON 全量备份导出与恢复。
- **四标签学习闭环**：
  - **背词**：顶部实时展示今日目标进度环与连续打卡天数，支持智能组卡、左右滑卡判词、测验与听学联动。
  - **词库**：支持按语种、掌握状态（全部 / 错题与模糊 / 已掌握 / 已收藏 / 未学习 / 自建词）筛选与全文搜索，支持对当前筛选词表直接发起测验或听学。
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
    ├── pack_en_exam.json              # 英语 CET-4/6 · IELTS · TOEFL · BEC 扩展词包
    ├── pack_ja_jlpt.json              # 日语 JLPT N5–N1 扩展词包
    ├── pack_ko_topik.json             # 韩语 TOPIK I–II 扩展词包
    ├── pack_fr_delf.json              # 法语 DELF A1–B2 扩展词包
    └── pack_es_dele.json              # 西语 DELE A1–B2 扩展词包
Words killerTests/                     # Swift Testing 自动化单元测试套件
├── SpacedRepetitionTests.swift        # SM-2 记忆曲线、收藏优先组卡与持久化闭环测试
├── WordBankParserTests.swift          # 6 册内置词书校验、坏数据容错与 4 类开源词库格式解析测试
├── StudyAnalyticsTests.swift          # 去重打卡、连续天数、14天趋势、12周热力图与到期预测测试
└── QuizAndBackupTests.swift           # 四选一出题不变量与 JSON 备份导出/幂等恢复测试
```

## 运行与打包要求

- **Xcode**：支持 Swift 5.0 与 SwiftData 的 Xcode（建议 Xcode 16+）
- **系统要求**：当前工程配置 `IPHONEOS_DEPLOYMENT_TARGET = 26.5`（可在 Xcode Build Settings 中按需调整为 `17.0`+ 以兼容更多设备）
- **隐私政策**：纯本地存储，详见 [`PRIVACY.md`](PRIVACY.md)
