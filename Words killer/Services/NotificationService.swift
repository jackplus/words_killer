//
//  NotificationService.swift
//  Words killer
//

import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationService {
    static let dailyReminderIdentifier = "com.tedji.words_killer.daily_reminder"

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var statusMessage: String?

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            return granted
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    @discardableResult
    func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        dailyGoal: Int,
        dueCount: Int
    ) async -> Bool {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            statusMessage = "通知权限已关闭，请前往系统设置开启 Words Killer 的通知权限。"
            return false
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Words Killer · 每日背词打卡"
        if dueCount > 0 {
            content.body = "当前有 \(dueCount) 个到期单词等待巩固，花 3 分钟完成今日 \(dailyGoal) 词目标吧！"
        } else {
            content.body = "是时候花 3 分钟完成今日 \(dailyGoal) 词目标，延续连续打卡记录啦！"
        }
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            let formattedTime = String(format: "%02d:%02d", hour, minute)
            statusMessage = "已设定每天 \(formattedTime) 准时推送学习提醒。"
            return true
        } catch {
            statusMessage = "提醒设定失败：\(error.localizedDescription)"
            return false
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.dailyReminderIdentifier]
        )
        statusMessage = "已关闭每日定时提醒。"
    }

    func sendTestReminder(dailyGoal: Int, dueCount: Int) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            statusMessage = "无法发送测试提醒：请先在系统设置中允许通知。"
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Words Killer · 提醒测试成功"
        content.body = dueCount > 0
            ? "通知工作正常！您当前有 \(dueCount) 个待复习词，今日目标 \(dailyGoal) 词。"
            : "通知工作正常！准备好开启今日 \(dailyGoal) 词挑战了吗？"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "com.tedji.words_killer.test_reminder",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            statusMessage = "测试通知已发出，退到后台或锁屏 3 秒后即可收到。"
        } catch {
            statusMessage = "发送测试提醒失败：\(error.localizedDescription)"
        }
    }
}
