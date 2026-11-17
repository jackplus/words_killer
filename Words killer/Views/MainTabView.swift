//
//  MainTabView.swift
//  Words killer
//

import SwiftData
import SwiftUI

struct MainTabView: View {
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
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: WordProgress.self, inMemory: true)
}
