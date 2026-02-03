//
//  FeedMeApp.swift
//  FeedMe
//
//  Created by lixuan on 2026/2/3.
//

import SwiftUI

@main
struct FeedMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            ContentView()
        }
    }

    init() {
        // 应用启动时刷新一次
        Task {
            await FeedManager.shared.refreshOnLaunch()
        }
    }
}
