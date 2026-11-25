//
//  AppDeepLink.swift
//  Words killer
//
//  URL routing contract shared between the main app and future WidgetKit extensions.
//

import Foundation
import Observation

enum AppTab: Int, Hashable, CaseIterable, Sendable {
    case study = 0
    case wordbook = 1
    case stats = 2
    case settings = 3
}

enum StudyRouteAction: Equatable, Sendable {
    case openToday
    case openMistakes
}

nonisolated enum AppDeepLink: Equatable, Sendable {
    static let scheme = "wordskiller"

    case today
    case mistakes
    case word(id: String)
    case stats

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .today:
            components.host = "today"
        case .mistakes:
            components.host = "mistakes"
        case .word(let id):
            components.host = "word"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
        case .stats:
            components.host = "stats"
        }
        return components.url ?? URL(string: "\(Self.scheme)://today")!
    }

    static func parse(_ url: URL) -> AppDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              let host = components.host?.lowercased() else {
            return nil
        }

        switch host {
        case "today":
            return .today
        case "mistakes":
            return .mistakes
        case "stats":
            return .stats
        case "word":
            if let queryID = components.queryItems?.first(where: { $0.name == "id" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !queryID.isEmpty {
                return .word(id: queryID)
            }
            let pathID = components.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pathID.isEmpty else { return nil }
            return .word(id: pathID)
        default:
            return nil
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .study
    var pendingStudyAction: StudyRouteAction?
    var pendingWordDetailID: String?

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let link = AppDeepLink.parse(url) else { return false }
        navigate(to: link)
        return true
    }

    func navigate(to link: AppDeepLink) {
        switch link {
        case .today:
            selectedTab = .study
            pendingStudyAction = .openToday
        case .mistakes:
            selectedTab = .study
            pendingStudyAction = .openMistakes
        case .word(let id):
            selectedTab = .wordbook
            pendingWordDetailID = id
        case .stats:
            selectedTab = .stats
        }
    }
}
