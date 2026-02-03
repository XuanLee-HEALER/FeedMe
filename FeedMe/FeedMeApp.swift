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

    // 注意：启动刷新已移至 AppDelegate.applicationDidFinishLaunching
    // 避免双重触发导致重复请求
}
