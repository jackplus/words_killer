# Words Killer

面向中文母语者的多语种间隔重复（SRS）背词 iOS / iPadOS 应用，基于 **SwiftUI + SwiftData + AVFoundation** 构建，纯本地离线运行，无广告、无追踪、无需登录。

## 核心特性

- **五语种结构化词库（500 词）**：内置 [`word_bank.json`](Words%20killer/Resources/word_bank.json)，覆盖 **英语、日语、韩语、法语、西班牙语**，每语种按 **入门 / 基础 / 进阶 / 高级 / 商务** 五档难度各 20 词，提供真实音标/注音、中文释义、记忆点与双语例句。
- **SwiftData 持久化与 SM-2 间隔重复**：通过 [`WordProgress`](Words%20killer/Models/WordProgress.swift) 与 [`SpacedRepetitionEngine`](Words%20killer/Services/SpacedRepetitionEngine.swift) 区分三档记忆反馈：
  - **不认识**：重置掌握阶数并追加至本轮队列末尾二次重测。
  - **模糊**：标记为待巩固状态，设定 12 小时后到期复习。
  - **认识**：递进掌握阶数，按 `1 天 → 3 天 → interval × easeFactor` 动态推算下次复习时间。
- **原生多语种语音朗读**：基于 `AVSpeechSynthesizer` 封装 [`SpeechService`](Words%20killer/Services/SpeechService.swift)，支持切卡自动朗读单词、点击喇叭单独朗读单词或例句。
- **多维自测与拼写练习**：内置 [`QuizView`](Words%20killer/Views/QuizView.swift) 与 [`QuizEngine`](Words%20killer/Services/QuizEngine.swift)，支持四选一速测（看词选义、看义选词、听音辨词）以及听音/看义拼写填空。
- **随身听学磨耳朵**：基于 [`AudioLearningController`](Words%20killer/Services/AudioLearningController.swift) 与 [`AudioPlayerView`](Words%20killer/Views/AudioPlayerView.swift)，支持后台循环自动朗读单词外语、中文释义与例句，可自定义每词朗读次数（1~3遍）、词间停顿与播放语速。
- **重点收藏与自建词库**：支持卡片一键星标收藏（Favorite）；支持通过 [`AddCustomWordView`](Words%20killer/Views/AddCustomWordView.swift) 手动录入单词或批量粘贴文本（支持逗号、斜杠、制表符分隔）导入本地 SwiftData，与内置 500 词库无缝混排训练。
- **三标签学习闭环**：
  - **背词**：按到期优先 + 新词补齐的 10 词智能组卡训练，集成左右滑卡评分、一键测验练习与随身听学入口。
  - **词库**：支持按语种、掌握状态（全部 / 错题与模糊 / 已掌握 / 已收藏 / 未学习 / 自建词）筛选与全文搜索，支持左滑重置或直接标记掌握，支持听学选定词表。
  - **统计**：汇总累计已学、已掌握、待复习、收藏生词、自建词汇量与总复习次数，展示各语种掌握进度与最近复习记录。

## 项目结构

```text
Words killer/
├── Words_killerApp.swift              # App 入口，注入 SwiftData ModelContainer
├── ContentView.swift                  # 背词主训练页（滑卡、组卡、测验与听学联动）
├── Models/
│   ├── WordModels.swift               # TargetLanguage, DifficultyLevel, RecallRating, WordItem
│   ├── WordProgress.swift             # SwiftData @Model 持久化记忆与收藏记录
│   └── CustomWordRecord.swift         # SwiftData @Model 自建生词持久化记录
├── Services/
│   ├── WordLibrary.swift              # JSON 词库加载器与自建词库合并
│   ├── SpacedRepetitionEngine.swift   # 间隔重复调度与组卡引擎
│   ├── SpeechService.swift            # AVSpeechSynthesizer 语音朗读服务（多语种+中文释义）
│   ├── AudioLearningController.swift  # 随身听学连续自动播放控制器
│   └── QuizEngine.swift               # 四选一自测与多题型生成引擎
├── Views/
│   ├── MainTabView.swift              # 底部三标签 TabView 导航
│   ├── WordCardView.swift             # 词卡主视图（状态标签 + 发音 + 收藏 + 记忆点）
│   ├── WordBookView.swift             # 词库与错题本列表页（支持自建、收藏筛选与导入）
│   ├── StatsView.swift                # 学习统计与进度页（自建词与收藏统计）
│   ├── QuizView.swift                 # 四选一自测与听音拼写测试视图
│   ├── AudioPlayerView.swift          # 随身听学沉浸播放器
│   ├── AddCustomWordView.swift        # 手动单词录入与批量导入视图
│   └── Components.swift               # 公共 UI 组件与主题色
└── Resources/
    └── word_bank.json                 # 500 词五语种结构化词库
```

## 运行与打包要求

- **Xcode**：支持 Swift 5.0 与 SwiftData 的 Xcode（建议 Xcode 16+）
- **系统要求**：当前工程配置 `IPHONEOS_DEPLOYMENT_TARGET = 26.5`（可在 Xcode Build Settings 中按需调整为 `17.0`+ 以兼容更多设备）
- **隐私政策**：纯本地存储，详见 [`PRIVACY.md`](PRIVACY.md)
