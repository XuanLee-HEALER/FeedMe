//
//  ContentView.swift
//  FeedMe
//
//  Created by lixuan on 2026/2/3.
//

import SwiftUI

/// 设置窗口
struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("刷新设置") {
                Picker("刷新间隔", selection: $settings.globalRefreshInterval) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { interval in
                        Text("\(interval) 分钟").tag(interval)
                    }
                }
                .onChange(of: settings.globalRefreshInterval) {
                    FeedManager.shared.resetTimer()
                }
                .accessibilityLabel("刷新间隔")
                .accessibilityHint("选择自动刷新订阅源的时间间隔")
            }

            Section("阅读行为") {
                Toggle("点击后自动标为已读", isOn: $settings.markAsReadOnClick)
                    .accessibilityLabel("点击后自动标为已读")
                    .accessibilityHint("开启后，点击文章会自动将其标记为已读")

                Picker("排序方式", selection: $settings.sortOrder) {
                    ForEach(AppSettings.SortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .accessibilityLabel("排序方式")
                .accessibilityHint("选择文章列表的排序方式")

                Stepper("列表显示条数: \(settings.displayCount)", value: $settings.displayCount, in: AppSettings.displayCountRange)
                    .accessibilityLabel("列表显示条数 \(settings.displayCount)")
                    .accessibilityHint("设置菜单中显示的文章数量")
            }

            Section("通知") {
                Toggle("启用新文章通知", isOn: $settings.enableNotifications)
                    .accessibilityLabel("启用新文章通知")
                    .accessibilityHint("开启后，有新文章时会发送系统通知")
            }

            Section("高级") {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                    .help("需要在系统设置中授权")
                    .accessibilityLabel("开机自动启动")
                    .accessibilityHint("开启后，系统启动时自动运行 FeedMe")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
        .padding()
    }
}

#Preview {
    ContentView()
}
