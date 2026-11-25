# Words Killer — App Store 上架提审全清单（可直接复制粘贴）

本文档整理了当前工程已完成的合规配置，以及在 **App Store Connect** 网页后台可直接复制使用的元数据文案与打包步骤。

**最新状态（2026-11-23）**：当前本地最新改动已作为 `1.0 (3)` 上传 TestFlight，37 项测试通过；Apple 二进制「已验证」、构建「准备提交」，现有 internal 群组（2 名测试员）自动关联，测试说明已保存。详见第十一节。

---

## 一、工程配置（仍需发行签名、真机与商店后台验证）

- **Bundle Identifier**: `com.tedji.Words-killer`
- **Development Team**: `Y382F52F3K`（JI CHUNKAI，用户确认的发布团队）
- **桌面显示名称 (`CFBundleDisplayName`)**: `Words Killer`
- **最低支持系统 (`IPHONEOS_DEPLOYMENT_TARGET`)**: `iOS 17.0`（最低系统兼容性仍需设备或运行时验证）
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
- **年龄分级**: 按实际内容逐项完成新版问卷，由 App Store Connect 计算结果；不要预填「所有项均无」。本应用无广告、聊天或内置浏览器，支持用户本地导入词条。导入功能与内容相关问题需按问卷定义核对。
- **App 隐私（App Privacy）**: 选择 **「未收集数据（Data Not Collected）」**

### 2. 关键词（Keywords，100 字符内，英文逗号无空格分隔）
```text
背单词,英语,日语,韩语,法语,西班牙语,四六级,雅思,托福,JLPT,TOPIK,记忆曲线,闪卡,听写,词库,SRS,离线
```

### 3. 宣传文本（Promotional Text，170 字符内）
```text
英、日、韩、法、西五语种背词，内置 650 个词条与考级精选小词包。支持间隔复习、闪卡、测验、听写和随身听学；可导入自选词表，无广告、无需登录。离线朗读需预先安装对应系统语音。
```

### 4. 应用描述（Description）
```text
Words Killer 是一款专为中文母语者打造的纯粹、高效、多语种间隔重复（SRS）背单词应用。打开即背，学习数据保存在本机，无广告、无追踪、无需注册登录。已安装对应系统语音时可离线朗读，缺少语音时需通过系统设置下载。

【核心亮点】
• 五语种模块化词书：内置 500 个核心词条与五套各 30 词的考级精选扩展包，共 650 词。覆盖英语、日语、韩语、法语和西班牙语，配备注音、中文释义、助记和例句。精选词包用于入门与练习，不是完整考试词纲，也不代表官方考试机构背书。
• SM-2 智能记忆曲线：根据「认识 / 模糊 / 不认识」三档反馈动态推算复习间隔，优先推送到期词与星标收藏词，不认识的词追加到当轮队列再次练习。
• 多维主动回忆测验：支持看词选义、看义选词、听音辨词四选一速测，以及听音拼写填空与错题专练。
• 锁屏随身听学（磨耳朵）：支持外语发音、中文释义与双语例句自动循环连播，适配锁屏控制中心与耳机切词，通勤散步也能轻松记词。
• 开放词库自由导入：支持手动录入生词，或一键导入 JSON / CSV / TSV / TXT 外部词表（兼容 ECDICT、KyleBing、JLPT 等主流开源词典格式），并支持学习进度、自建词条和复习事件的 JSON 备份与恢复（不含学习偏好）。
• 数据统计与打卡热力图：直观呈现每日目标进度环、连续打卡天数、近 14 天学习趋势、12 周记忆热力图与未来 7 天待复习预测。
```

### 5. 网址填写与当前阻碍

- 2026-11-18 已验证仓库公开、`has_pages = false`。**目前不要填写** `https://jackplus.github.io/words_killer/PRIVACY`，该站点尚未部署。
- 隐私政策源文件：[PRIVACY.md](PRIVACY.md)；App 内离线副本为 `Words killer/Resources/PrivacyPolicy.md`，修改政策时两份须同步。
- 可将政策发布为公开网页后填入最终 URL；如使用 GitHub 文档页，应先将本次更新推送并在未登录环境验证 `https://github.com/jackplus/words_killer/blob/main/PRIVACY.md` 可读。
- 技术支持网址候选：`https://github.com/jackplus/words_killer/issues`。提交前确认 Issues 已开启且开发者会持续处理；用户需要 GitHub 账号才能提交反馈。
- App 内入口：「设置 → 隐私政策」和「帮助与反馈」。

### 6. 审核备注（App Review Notes — 给苹果审核员说明后台音频用途）
```text
Thank you for reviewing Words Killer!
1. No login or account is required. Study data stays on the device. Speech works offline when the corresponding Apple system voices are installed; missing voices may need to be downloaded in system settings. The app includes 650 words, not complete exam curricula.
2. Privacy policy is available offline under Settings (设置) > Privacy Policy (隐私政策). JSON backup export is user-initiated and contains progress, custom words, and review events, not preferences.
3. Background Audio (UIBackgroundModes: audio): Used by the "随身听学" (Hands-Free Audio Study) player (accessible via the headphone icon on the main study screen or wordbook screen), allowing users to listen to continuous vocabulary pronunciations and translations with Lock Screen / Control Center playback controls while commuting or with the screen locked.
```

---

## 三、打包上传 4 步走

1. 用 Xcode 打开 `Words killer.xcodeproj`，在 `Signing & Capabilities` 确认 Team 已选中您的 Apple Developer 账号。
2. 顶部运行目标选择 **`Any iOS Device (arm64)`**，点击菜单栏 **`Product` -> `Archive`**。
3. 在弹出的 Organizer 窗口点击 **`Distribute App` -> `App Store Connect` -> `Upload`**。
4. 构建处理完成后，先用 **TestFlight** 在真机完成下方验收，再关联构建与截图。处理时间以后台为准。通过检查后再提交审核，建议选择「手动发布」。


## 四、免费首发：商店后台建档顺序

已确认：用户已有付费 Apple Developer 会员，尚未创建 App Store Connect 记录，首发免费。发行地区尚待确认。

1. 登录 [开发者后台](https://developer.apple.com/account/resources/identifiers/list) 确认 Team 与工程 `Y382F52F3K` 一致；确认或注册 Explicit App ID `com.tedji.Words-killer`。若标识符不属于该团队，先解决归属，不要随意换 Bundle ID。
2. [App Store Connect](https://appstoreconnect.apple.com/) → Apps → ＋ → New App：iOS、简体中文、名称见上方、Bundle ID 选上述标识符、SKU 建议 `words-killer-ios`（首次创建前核对，SKU 不是 Bundle ID）。名称是否可用以后台为准。
3. 版本 `1.0`、价格「免费」、无内购；选择发行地区。教育分类不等于儿童类别，不要仅因是学习 App 勾选 Made for Kids。
4. 填隐私、年龄问卷、版权权利人、审核联系人姓名/电话/邮箱；联系人信息为真实信息，无需在聊天中发送密码或验证码。发行地区涉及的账号声明按后台实际要求完成。
5. 上传签名构建，进行 TestFlight 验收；配置元数据、隐私网址和真实截图后提交。发布方式建议「手动发布」。

## 五、提审前验收门槛

- [ ] Release 归档通过，且发行导出/上传验证通过（无签名归档不能上传）。
- [ ] 全部自动化测试通过；最低支持 iOS 17 的设备或运行时另做兼容性测试。
- [ ] 真机安装、重启后进度仍保留；卡片评分、四类测验、收藏、自建词正常。
- [ ] 锁屏持续听学至少 5 分钟；控制中心、耳机切词、来电/中断后恢复均通过。
- [ ] 通知允许/拒绝、后台定时触发、关闭提醒均符合预期。
- [ ] JSON 导出→恢复，词条/进度/复习事件一致；损坏文件提示正常。
- [ ] 清空进度保留自建词；删除自建词符合界面说明。
- [ ] 飞行模式下五语种朗读；缺少系统语音时出现明确提示。
- [ ] iPhone 与 iPad、横屏、大字体、深浅色下无关键信息遮挡；隐私入口可用。
- [ ] 内置词条、翻译、例句及图标的来源与再分发权利由权利人确认。当前词书中的 MIT 标签不等于已提供来源证据；仓库尚无来源清单，不应据标签推定权利已核验。
- [ ] 公开隐私及支持 URL 在未登录环境可读；联系人、版权、地区声明完整。
- [ ] 商店截图来自真实 App，不以原型图代替。建议各准备背词、词库、测验、听学、统计 5 张；初始空统计页面不能冒充已有学习效果。

截图尺寸按 [Apple 最新规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 核对：大屏 iPhone 可用 `1320 × 2868` 等允许尺寸，13 英寸 iPad 可用 `2064 × 2752`。以后台对应设备槽位为准。

## 六、首轮本地验证记录（2026-11-18；签名问题已在下一节解决）

- GitHub 远端 HEAD 与检查前本地 HEAD 一致：`e7f610f1e166bb770fa8121b0f327ed6d33e0014`。本次改动尚未提交或推送。
- 基线：21/21 测试通过；最终修改后：24/24 测试通过，无失败、跳过或运行时警告。设备：iPhone 18 Pro / iOS 27.2 模拟器。
- Release arm64 无签名归档成功：`/tmp/WordsKiller-1.0-release.xcarchive`，版本 `1.0 (1)`、最低 iOS `17.0`、后台模式 `audio`。**该产物不能直接上传**。
- 签名归档失败：缺少 `com.tedji.Words-killer` 的 iOS App Development provisioning profile。本机只发现 Apple Development 身份，发行导出尚未验证；用户已确认付费账号登录且 Team 一致；加 `-allowProvisioningUpdates` 重试仍报 `No Account for Team "5N7K59WT8G"`，当前命令行无法使用有效团队凭据。需在 Xcode Accounts 刷新或重新认证账号，并在 Signing & Capabilities 检查签名。
- AppIcon 已验证 `1024 × 1024`、无 Alpha。公开仓库已启用 Issues，尚未启用 Pages。
- 构建有工具提示：未依赖 AppIntents，因此跳过对应元数据提取；没有 Swift 编译警告。
- 原始构建日志与截图保存在本地 `artifacts/release-1.0/`（已加入 gitignore）；测试结果包为 `/tmp/WordsKillerReleaseReady.xcresult`。截图仅为首屏候选，完整商店素材尚待补齐。
- 启动诊断：iOS 27.2 新模拟器开启自动朗读时首屏白屏；关闭自动朗读后恢复。采样显示主线程在 `speechVoices()` 等待系统语音服务。已将语音查询移至后台，增加取消及旧 utterance 回调隔离；自动朗读开启时首屏已能显示。iPhone 与 iPad 均已保存真实首屏候选截图（`iphone-study-fixed.png` / `ipad-study-fixed.png`）。系统语音服务本身和真机播放仍需验证。原有 TTS 单元测试也会同步查询系统语音，已将语言匹配提取为纯函数，自动化校验不再依赖模拟器语音服务的可用性。
- 本次没有创建商店记录、上传构建、提交审核或发布。真机、iOS 17、完整界面及内容权利验收仍未完成。

复验命令（替换目标模拟器 ID 与结果包路径，结果包路径不能已存在）：

```bash
xcodebuild test -project "Words killer.xcodeproj" -scheme "Words killer" \
  -destination "platform=iOS Simulator,id=BEFC62EB-D02B-44DE-B7F0-CAB78B8F04BA" \
  -derivedDataPath /tmp/WordsKillerReleasePrep CODE_SIGNING_ALLOWED=NO

xcodebuild archive -project "Words killer.xcodeproj" -scheme "Words killer" \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath /tmp/WordsKiller-1.0-unsigned.xcarchive CODE_SIGNING_ALLOWED=NO
```

## 七、TestFlight 打包与测试准备（2026-11-18 续）

### 签名问题与解决记录

重新登录后再次尝试自动签名归档，仍报 `No Account for Team "5N7K59WT8G"`。
进一步核对发现：工程 Team 为 `5N7K59WT8G`；本机唯一有效 Apple Development 证书的 OU 为 `Y382F52F3K`（JI CHUNKAI），现代 Xcode 描述文件目录的 18 份 profile 也全部属于 `Y382F52F3K`，最近选择团队同为 `Y382F52F3K`。当前没有找到 Words Killer 的匹配 profile。

用户已明确确认使用 `Y382F52F3K` 发布，工程及测试目标的 Debug / Release 团队已统一更正。随后签名归档成功，`codesign --verify --deep --strict` 通过：版本 `1.0 (1)`、Bundle ID `com.tedji.Words-killer`、Team `Y382F52F3K`。归档阶段使用 Apple Development 身份，后续发行导出需重新签名，不能把开发签名归档视为发行 IPA。

本次签名归档和发行导出均已成功。持久化归档：`artifacts/release-1.0/testflight/WordsKiller-1.0.xcarchive`（原始归档 `/tmp/WordsKiller-1.0-Y382F52F3K.xcarchive`）。历史失败日志保留在 `artifacts/release-1.0/testflight/archive-attempt.log`。

### 11 月 18 日历史产物

- **发行 IPA**：`artifacts/release-1.0/testflight/export/Words killer.ipa`。
- **版本**：`1.0 (1)`，最低系统 `iOS 17.0`。
- **发行签名**：`Apple Distribution: JI CHUNKAI (Y382F52F3K)`。
- **Store profile**：`iOS Team Store Provisioning Profile: com.tedji.Words-killer`；明确 App ID 为 `Y382F52F3K.com.tedji.Words-killer`，`get-task-allow = false`，无设备列表限制，有效期至 `2027-10-05`（以描述文件时间为准）。
- **验证**：导出的 IPA 解包后 `codesign --verify --deep --strict` 通过；隐私清单存在；政策正文与仓库源文件相同；出口加密声明为 `false`。
- **SHA-256**：`fb0e57ba5da67e008b997d1767977cb9adcada3d57e8fd76035228fb5ba6b955`。
- **证据**：同目录 `ipa-verification.json`、`archive-signed.log`、`export.log`，完整导出目录包含发行相关文件。
- **上传状态**：尚未上传；用户确认 App Store Connect 记录尚未创建。上传后仍需等待 Apple 处理和校验，不能把本地验签视为服务器验证通过。
- **测试**：沿用已通过的 24 项测试，本轮仅修改签名配置和发布文档，没有修改 App 逻辑；签名归档与发行导出已验证本轮配置。

### 可复用导出配置

已新增 `Config/ExportOptions-AppStore.plist`，使用当前 Xcode 支持的 `app-store-connect` 方法、自动签名和本地导出，团队继承实际签名归档。保留构建号，由工程决定版本，包含上传符号；不限制为只能用于内部测试的构建。配置已通过 `plutil -lint`，已实际成功导出并验证 Apple Distribution 签名。

团队确认且归档成功后执行：

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/WordsKiller-1.0-Y382F52F3K.xcarchive \
  -exportPath artifacts/release-1.0/testflight/export \
  -exportOptionsPlist Config/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

本地导出与上传为两步；此配置的 `destination = export` 不会自动上传。 已另备 `Config/ExportOptions-Upload.plist`（`destination = upload`，Team 固定 `Y382F52F3K`），通过格式检查；应仅在 App 记录创建并核对后用于上传现有签名归档。上传前核对版本与构建号，避免与 App Store Connect 已存在构建重复。

### 商店记录与内部测试顺序

用户确认：尚未创建 App Store Connect 记录。建档必须使用发布团队 `Y382F52F3K`。用户已执行安全登录保存；随后实际检查仍跳回登录页（`authResult=FAILED`），未能取得已认证的 Apps 页面，故尚未代建记录或上传。诊断保存在本地 `artifacts/release-1.0/testflight/app-store-connect-status.json`。

可直接填写：

| 字段 | 值 |
| --- | --- |
| 平台 | iOS |
| 名称候选 | Words Killer - 多语种极简背单词（可用性以后台为准） |
| 主要语言 | 简体中文 |
| Bundle ID | `com.tedji.Words-killer`（发行导出已成功获取明确 Store profile） |
| SKU | `words-killer-ios`（创建前确认未使用） |
| 用户访问权限 | 按团队实际权限需求选择 |

入口：[App Store Connect → Apps](https://appstoreconnect.apple.com/apps) → ＋ → New App。发布价格与地区稍后在商店配置，不影响先建立记录。

1. 在最终发布团队的 App Store Connect 创建或核对记录：iOS、简体中文、Bundle ID `com.tedji.Words-killer`、SKU 建议 `words-killer-ios`，名称是否可用以后台为准。
2. 使用 Xcode Organizer 的 `Distribute App → App Store Connect` 上传签名归档，或使用 Transporter 上传导出的 IPA。等待后台构建处理完成，不将本地打包成功视为上传成功。
3. TestFlight 中核对版本与构建号、出口合规状态，填写测试信息及有效反馈邮箱。建议先建立内部测试组，仅加入已有 App 访问权限的团队成员，再关联构建。
4. 在 iPhone / iPad 安装 TestFlight 后验证下方重点。内部测试与外部测试是不同流程；外部首个构建需按后台要求接受 Beta App Review。
5. 内部验收通过后再准备外部测试或正式商店审核。发布地区、版权、公开隐私政策和正式截图继续按本清单完成。

### 可粘贴的测试说明（What to Test）

```text
欢迎测试 Words Killer 1.0！本版本无需登录，包含英语、日语、韩语、法语和西班牙语共 650 个内置词条，支持自建词及文件导入。

请重点验证：
1. 首次打开与再次启动均能显示背词页面；自动朗读不应阻塞界面。
2. 三档评分、收藏、测验和听写正常；退出并重启后进度保留。
3. 随身听学锁屏播放至少 5 分钟，检查控制中心、耳机切词及音频中断后的行为。
4. 允许与拒绝通知权限、设置提醒及关闭提醒均符合预期。
5. JSON 导出再恢复后，进度、自建词和复习记录一致。导出不含学习偏好。
6. 设置页隐私政策可离线阅读；iPad、横屏、大字体及深浅色下能访问主要操作。

离线朗读需预先安装对应系统语音。请反馈设备型号、系统版本、App 构建号、复现步骤及截图；请勿在公开反馈中提交完整个人备份。
```

[Apple TestFlight 官方流程](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)：构建可测试 90 天；内部测试员需为有权限的 App Store Connect 用户，首个外部测试构建需要 Beta 审核。正式 App Store 发布不等同于 TestFlight 构建上传。

## 八、官方依据（2026-11-18 核对）

- [上传工具链要求](https://developer.apple.com/news/upcoming-requirements/)：当前要求 Xcode 26+ 与 iOS 26+ SDK；本机 Xcode 27.2 / iOS 27.2 SDK 满足该最低工具链要求。
- [审核指南 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)：商店与 App 内均需可访问的隐私政策。
- [年龄分级问卷](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)：按功能和内容作答，由系统计算分级。


## 九、最新 GitHub 版本验证与上传尝试（2026-11-21）

- GitHub 与本地基线一致：`c59dca1284c4814292ac40e6fa9947265215066b`。新增个人助记笔记、评分撤回、动态复习间隔、自建词编辑，合入 PR #1 的性能、语音回调、测验选项及 SRS 修复。
- 为区分 11 月 18 日的旧产物，本轮将工程构建号从 `1` 更新为 `2`，版本仍为 `1.0`，发布团队仍为 `Y382F52F3K`；未修改业务逻辑。
- 本机 Xcode 27.2 / iPhone 18 Pro iOS 27.2 模拟器：35/35 测试通过，0 失败、0 跳过、无记录到的运行时警告。Swift 编译无警告；工具提示未使用 AppIntents，跳过对应元数据提取。
- Release 签名归档和发行导出成功。IPA 解包后签名、团队、明确 App ID、非调试 Store profile、版本 `1.0 (2)`、隐私清单及隐私正文验证通过；在运行过旧版的 iPhone 模拟器安装启动，自动朗读开启时首屏正常。
- 本地产物与证据：`artifacts/testflight-2026-11-21/`，包含 `WordsKiller-1.0-2.xcarchive`、`export/Words killer.ipa`、`Tests.xcresult`、`test-summary.json`、`verification.json`、`launch-iphone.png`、`what-to-test.txt` 及构建/导出/上传日志。
- 本地 IPA SHA-256：`fcc006b8756ed4ac47c26d0744151d2bba6486bb98b57813503e759c1596aa58`。
- 已通过本机 Xcode 执行真实上传尝试；Apple 返回 `App record with bundle identifier "com.tedji.Words-killer" not found on App Store Connect`，上传未成功。该错误确认当前上传团队下缺少匹配商店记录；尚无 TestFlight 构建处理结果。
- 用户正在 Codex 内置浏览器登录并确认/创建记录。记录需为 JI CHUNKAI 团队、iOS、简体中文、Bundle ID `com.tedji.Words-killer`、SKU 建议 `words-killer-ios`。取得记录后可直接重试现有签名归档，无需重建。
- GitHub 最新 CI 任务最终为 cancelled，本地完整测试结果与远端结果分别保留，不将其标为远端通过。运行链接：https://github.com/jackplus/words_killer/actions/runs/44879932305 。

- 用户确认内置浏览器登录后，使用同一签名归档再次上传，仍报相同匹配记录不存在错误（`upload-retry.log`）。当前浏览器打开了一个 App 的 TestFlight 页面，但其 Bundle ID / 团队归属尚未核对；需读取该记录的 App 信息，区分记录缺失、Bundle ID 不一致和账号访问问题。


## 十、商店记录已创建，重新上传中（2026-11-21）

- 已直接连接 Codex 当前内置浏览器并读取真实已登录页面，确认当前 App Store Connect 团队为 JI CHUNKAI；此前使用的 TinyFish 是独立会话，不能代表内置浏览器状态。
- 已确认旧页面 Apple ID `6824498979` 属于“语音笔记与纪要”，不是 Words Killer。团队原 Apps 列表中没有 Words Killer，导致上传接口返回匹配记录缺失。
- 用户在最终提交时明确确认建档字段，随后已成功创建 `Words Killer - 多语种极简背单词`。新 Apple ID：`6837619955`；主要语言：简体中文；SKU：`words-killer-ios`；Bundle ID：`com.tedji.Words-killer`；平台：iOS。均已在新记录 App 信息页核验。
- Apple 提示用户访问权限设置保存失败，记录当前为所有团队用户可访问，与确认的完全访问范围一致，未额外添加用户。
- App 信息链接：https://appstoreconnect.apple.com/apps/6837619955/distribution/info 。
- TestFlight 链接：https://appstoreconnect.apple.com/teams/87c2efdb-0337-4b83-b4bd-95ef36cb5a8d/apps/6837619955/testflight 。
- 已对同一验证通过的 `1.0 (2)` 签名归档重试上传，2026-11-21 16:05:32（Asia/Taipei）Xcode 返回 `Upload succeeded`、`EXPORT SUCCEEDED`，Apple 已开始处理安装包。日志为本地 `artifacts/testflight-2026-11-21/upload-after-create.log`。TestFlight 已完成处理，列表状态为「准备提交」；构建元数据页二进制状态为「已验证」。

- 已读取 Apple 构建元数据：版本 `1.0`、构建号 `2`、Bundle ID `com.tedji.Words-killer`、最低 iOS `17.0`、架构 `arm64`、符号包含、非豁免加密为「否」。服务端签名权限 `application-identifier = Y382F52F3K.com.tedji.Words-killer`、`com.apple.developer.team-identifier = Y382F52F3K`、`get-task-allow = false`，与本地发行配置一致。
- 构建 ID：`e33b28ad-fdc4-484b-ac2c-6d227a127a95`。构建详情：https://appstoreconnect.apple.com/teams/87c2efdb-0337-4b83-b4bd-95ef36cb5a8d/apps/6837619955/testflight/ios/e33b28ad-fdc4-484b-ac2c-6d227a127a95 。
- 已保存简体中文「测试内容」，包含本次笔记、撤回、复习间隔、自建词编辑及语音/导入回归重点。尚未添加测试群组或测试员，也未提交 Beta 外部审核或正式商店审核。后续需确定测试人员后分配构建。


## 十一、最新本地改动与构建 1.0 (3)（2026-11-23）

- **代码来源**：GitHub 与本地 HEAD 仍为 `c59dca1284c4814292ac40e6fa9947265215066b`。本轮打包时包含此基线之上的本地改动和新增文件；本次 Git 提交包含这些改动及更新后的发布文档，归档、IPA 和日志保留本地。
- **新增功能**：智能综合/专攻到期/专攻收藏训练模式；听学队列点击跳词并保留播放状态；卡片堆叠、滑动评分动效、触感、撤回 Toast、完成庆祝、测验反馈；全局界面与主题重设计；默认/深色/着色三套图标。
- **版本确认**：用户明确确认上传 `1.0 (3)` 并将工程构建号由 2 更新为 3。Bundle ID `com.tedji.Words-killer`、团队 `Y382F52F3K`、最低系统 iOS 17.0 保持一致。未改动导出/上传 plist 配置或既有词条 ID。
- **本机验证**：37/37 测试通过，0 失败、0 跳过；Swift 编译 0 警告，仅有未使用 AppIntents 的工具提示。新增测试覆盖到期/收藏筛选和听学跳转边界。签名 Release 归档和本地发行导出通过；IPA 解包验签、明确 Store profile、非调试签名、版本、隐私清单及隐私正文校验通过。
- **界面与资源**：iPhone 浅/深色、iPad 浅色首屏检查通过；三套图标均为 1024×1024 且无 Alpha。真机触感、锁屏音频及完整辅助功能仍需 TestFlight 实测，不将截图检查等同于完整交互验收。
- **发布证据**：新目录 `artifacts/testflight-2026-11-23/` 保存源码二进制补丁、新增文件副本、逐文件哈希、`Tests.xcresult`、`test-summary.json`、`WordsKiller-1.0-3.xcarchive`、`export/Words killer.ipa`、`verification.json`、三张首屏截图、`what-to-test.txt` 与构建/导出/上传日志。历史发布目录没有删除或覆盖。
- **IPA SHA-256**：`92e5b822ba64778c5f11a296529da6e0d6ef2388986cbb8594f699bfc717e516`。
- **上传结果**：2026-11-23 13:23:36（Asia/Taipei），Xcode 返回 `Upload succeeded` 和 `EXPORT SUCCEEDED`。内置浏览器已看到版本 1.0 构建 3「正在处理」。Apple 后续已处理完成，二进制「已验证」、构建「准备提交」。

- **服务端最终核对**：构建 ID `e8b9af31-fe0b-4bf7-8271-7e72bab2b1cb`，版本 `1.0`、构建 `3`、Bundle ID `com.tedji.Words-killer`、Team `Y382F52F3K`、最低 iOS `17.0`、架构 `arm64`、包含符号、非豁免加密为「否」，与发行归档一致。
- **测试分配**：现有 `internal` 内部群组自动关联本构建，页面显示 2 名测试员；没有手动修改群组或测试员。已保存本轮简体中文测试内容。未提交外部 Beta 或正式商店审核。
- **构建详情**：https://appstoreconnect.apple.com/teams/87c2efdb-0337-4b83-b4bd-95ef36cb5a8d/apps/6837619955/testflight/ios/e8b9af31-fe0b-4bf7-8271-7e72bab2b1cb 。

## 十二、构建 1.0 (4) 发布验证（2026-11-25）

- 用户明确确认上传版本 1.0、构建号 4。Bundle ID、发布团队、最低 iOS 版本和发行导出配置沿用现有工程。
- 本轮包含 18 册 1,800 词、六档难度、今日复习与退出续练、错词专练、听音转文字、拼写容错和提示、解析收藏与笔记、每日一词和 App 内小组件预览。桌面与锁屏小组件的 Extension 仍为模板，外部 URL scheme 尚未注册，当前通过 App 内路由预览跳转。
- 发布前 64 项 Swift Testing 测试全部通过，Swift 编译无警告。签名 Release 归档成功，核实版本 1.0 (4)、Bundle ID、Team 和最低 iOS 17.0。
- 新发布目录为 `artifacts/testflight-2026-11-25/`，包含测试结果、归档、发行导出和日志。原有 650 个词条 ID 保留，隐私政策双副本一致。
- GitHub 功能提交为 `ce071bd9ff62ae4581c90f1adb9321584f08b57b`，已推送 `origin/main`。
- IPA 本地验签与 Store profile 校验通过，`get-task-allow = false`，归属团队 `Y382F52F3K`。IPA SHA-256 为 `93325be8a8b4b4fd1095e9c01c07a6ccbdab9d07e41f1112fe92638c6fa178f4`。
- 2026-11-25 10:44:05（Asia/Taipei），Xcode 返回 `Upload succeeded` 和 `EXPORT SUCCEEDED`，日志确认 `Uploaded package is processing`。Apple 已接收 1.0 (4) 并开始处理。
- 用户登录后已核对 Apple 服务端：1.0 (4) 二进制「已验证」、构建「准备提交」，最低 iOS 17.0、arm64、符号包含、非豁免加密为「否」，Team `Y382F52F3K`、Bundle ID 与发行归档一致。
- 已保存简体中文「测试内容」并重新打开页面核实，现有 internal 内部群组自动关联 2 名测试员。尚未提交外部 Beta 或正式商店审核。
- 构建 ID 为 `2522b0dc-1013-4144-9672-a92f6781a273`。 [构建详情](https://appstoreconnect.apple.com/teams/87c2efdb-0337-4b83-b4bd-95ef36cb5a8d/apps/6837619955/testflight/ios/2522b0dc-1013-4144-9672-a92f6781a273)
- GitHub 功能提交的 CI 在 Xcode 26 编译首页时出现 SwiftUI 类型检查超时，本机 Xcode 27.2 的 64 项测试与归档均通过。上传后另作首页表达式拆分以兼容 CI，未改变题目与复习规则；该源码修复不包含在已上传的 1.0 (4) 中。
- 兼容修复提交 `98792b3` 在本机全量 64 项测试通过；[GitHub Actions 回归](https://github.com/jackplus/words_killer/actions/runs/45535626290)最终取消，未取得云端通过结果。

## 十三、构建 1.0 (5) 发布验证（2026-11-25）

- 本轮新增首页「复习 / 背新词」并行入口与听音选词自动朗读，包含此前上传后补充的 Xcode 26 编译兼容修复；不改持久化模型、词条 ID、隐私与签名配置。
- 重新运行 iPhone 18 Pro Max 模拟器全量 66 项测试通过，Swift 编译 0 警告，未签名 Release arm64 归档通过；隐私双副本零差异，发行 plist 校验通过。
- 发布准备、测试、未签名归档及测试说明位于 `artifacts/testflight-2026-11-25-build5/`，历史目录保留。用户明确确认上传 1.0 (5)，工程构建号已由 4 递增为 5；签名归档和上传结果待后续核实。
