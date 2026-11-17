//
//  Words_killerApp.swift
//  Words killer
//
//  Created by TedJi on 2026/6/19.
//

import SwiftData
import SwiftUI

@main
struct Words_killerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [WordProgress.self, CustomWordRecord.self])
    }
}
