//
//  MainTabView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @AppStorage("accentTheme") private var accentThemeRawValue = AccentTheme.forest.rawValue
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.system.rawValue

    private var selectedTheme: AccentTheme {
        AccentTheme(rawValue: accentThemeRawValue) ?? .forest
    }

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("背词", systemImage: "rectangle.stack.fill")
                }

            WordBookView()
                .tabItem {
                    Label("词库", systemImage: "book.closed.fill")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .environment(\.accentTheme, selectedTheme)
        .tint(selectedTheme.color)
        .preferredColorScheme(selectedAppearance.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: selectedTheme)
        .animation(.easeInOut(duration: 0.25), value: selectedAppearance)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self, ReviewEvent.self], inMemory: true)
}
