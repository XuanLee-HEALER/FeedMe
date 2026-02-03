0. 目标与非目标

目标
	•	作为状态栏应用（Menu Bar App），以最少打扰的方式浏览订阅源的最新文章。
	•	左键点击：展示“最新文章列表”
	•	右键点击：展示“应用菜单（管理/设置/刷新等）”
	•	列表超过 5 篇：折叠为 “…（更多）”，点开再看全部

非目标（第一版不做/可后续）
	•	离线全文阅读、阅读模式
	•	复杂过滤规则/全文搜索
	•	账号同步/多设备同步
	•	Feed 内图片/富文本渲染

⸻

1. 用户故事（User Stories）
	1.	作为用户，我可以添加一个订阅源（粘贴 URL 或输入站点 URL 自动发现 feed），以便看到它的更新。
	2.	作为用户，我点击状态栏图标能快速看到最新 5 条未读/最新文章。
	3.	作为用户，我可以点某条文章直接用默认浏览器打开。
	4.	作为用户，我希望看到未读数量提示（icon badge 或标题数字）。
	5.	作为用户，我右键可以进入设置、管理订阅、手动刷新、查看关于、退出。
	6.	作为用户，我可以将文章标为已读/全部标为已读，减少噪音。
	7.	作为用户，我希望应用自动刷新但不要太耗电、不要频繁打扰。

⸻

2. 信息架构与交互

2.1 状态栏图标（Menubar Icon）
	•	默认显示：图标 + （可选）未读数（例如 ● 或数字）
	•	点击区分：
	•	左键点击：弹出“文章列表菜单”
	•	右键点击：弹出“应用菜单”

实现建议：使用 NSStatusItem。右键菜单通常用 NSMenu + 事件判断（button.sendAction(on:)/tracking area）或分别配置左右键行为。

2.2 左键：文章列表菜单（核心）
菜单结构（建议）：
	•	顶部：最近更新（可选显示“最后刷新时间”）
	•	列表区：
	•	显示规则：默认显示 最新 5 条（优先未读，其次按时间倒序）
	•	每条展示：[未读点] 标题（可截断） + 右侧可选来源名（灰）
	•	点击条目：打开原文链接（默认浏览器）
	•	右侧操作（可选）：⌘+回车 打开并标记已读；或子菜单“标为已读”
	•	折叠：
	•	若条目总数 > 5：显示一行 … 更多（N）
	•	点击 更多：展开为二级菜单或弹出第二层菜单（显示全部/按源分组）
	•	底部快捷操作：
	•	刷新（显示 loading 状态）
	•	全部标为已读
	•	打开主窗口…（如果你要提供一个管理窗口）

折叠展开建议（两种选一）：
	•	A) 二级菜单：… 更多（N） -> 子菜单列出剩余文章
	•	B) 弹窗窗口：点击更多打开一个小 popover（更灵活，可滚动）

2.3 右键：应用菜单
	•	刷新所有源
	•	管理订阅源…（打开管理窗口）
	•	设置…
	•	导入/导出 OPML…（可后续）
	•	关于
	•	退出

⸻

3. 订阅源管理（管理窗口）

（建议做一个简单窗口，不做也能，但做了更像“可用产品”）

3.1 订阅源列表
每行展示：
	•	源名称（可编辑）
	•	Feed URL
	•	最近成功刷新时间
	•	未读数
	•	刷新频率（例如 15 分钟）
	•	开关：启用/禁用

操作：
	•	添加源（+）
	•	删除源（-）
	•	手动刷新单个源
	•	失败提示（例如红点 + 错误摘要：超时 / 解析失败 / 404）

3.2 添加源流程
输入框支持两种：
	1.	直接粘贴 Feed URL
	2.	粘贴站点 URL -> 自动发现 feed（抓取 HTML 的 <link rel="alternate" type="application/rss+xml|application/atom+xml">）

校验：
	•	URL 合法
	•	能拉取到内容（HTTP 200 / 304）
	•	能解析为 RSS/Atom
	•	解析成功后自动填充源标题（feed title）

⸻

4. 数据与状态模型（实现落点）

4.1 实体
FeedSource
	•	id
	•	title
	•	siteURL（可选）
	•	feedURL
	•	isEnabled
	•	refreshIntervalMinutes
	•	lastFetchedAt
	•	etag（可选）
	•	lastModified（可选）
	•	lastError（可选：最近一次错误信息/时间）

FeedItem
	•	id（内部）
	•	sourceId
	•	guidOrId（外部唯一键，可能为空）
	•	link
	•	title
	•	publishedAt / updatedAt
	•	summary（可选）
	•	isRead
	•	firstSeenAt（你首次看到它的时间，便于排序稳定）

4.2 去重策略（非常关键）
计算一个 dedupeKey：
	1.	优先 guid/id（标准字段）
	2.	否则用 link
	3.	否则用 hash(title + publishedAt + sourceId) 兜底

数据库中对 (sourceId, dedupeKey) 做唯一约束，避免重复插入。

⸻

5. 刷新策略与性能/电量
	•	默认全局刷新间隔：15 分钟（可设 5/15/30/60）
	•	单个源可覆盖全局设置
	•	支持手动刷新
	•	后台刷新：
	•	应用常驻状态栏，可以用定时器拉取
	•	尽量使用 ETag/Last-Modified 做增量
	•	并发策略：同时最多 3–5 个源请求（避免瞬间大量连接）
	•	错误退避：
	•	连续失败时逐步延长间隔（例如 15min -> 30min -> 60min），成功后恢复
	•	网络超时：例如 10–20s（按体验调）

⸻

6. 未读与通知策略
	•	未读计数：所有源未读总和（显示在状态栏上或 icon badge）
	•	打开条目后：默认标为已读（可设置）
	•	通知（可选，默认关闭）：
	•	“有新文章”仅在某些源开启通知
	•	合并通知：一轮刷新只发一条（避免刷屏）
	•	免打扰：尊重系统 Focus，不强制弹

⸻

7. 边界与异常处理
	•	Feed URL 重定向：跟随并缓存最终 URL（可选）
	•	解析失败：记录错误 + UI 可见（管理窗口）
	•	条目缺字段：标题为空用 (untitled)，link 缺失则禁用点击
	•	时间缺失：用 firstSeenAt 排序
	•	重复更新（同一个 guid 内容改变）：可以选择“保留最新标题/时间”，但不要新增重复条目

⸻

8. 设置项（Preferences）
	•	全局刷新间隔
	•	点击条目后是否自动标为已读
	•	文章列表排序：未读优先 / 纯时间倒序
	•	列表显示条数阈值（默认 5，允许改 3–10）
	•	启动时自动运行（Launch at login）
	•	通知开关（全局/按源）

⸻

9. 验收标准（可测试）
	1.	添加一个标准 RSS 源后，能在左键菜单看到最新条目；点击可打开浏览器。
	2.	同一篇文章在多次刷新后不会重复出现（去重有效）。
	3.	条目超过 5 篇时显示 … 更多（N），点击能看到剩余条目。
	4.	右键菜单始终出现且包含：刷新、管理订阅、设置、退出。
	5.	断网/Feed 404/解析失败时不崩溃，并在管理窗口能看到错误提示。
	6.	ETag/Last-Modified 生效（如果服务端支持）：刷新后出现 304 时不重复写入条目。
	7.	未读计数与“全部标为已读”行为一致且可回归测试。

路线 A：原生 Swift/SwiftUI（最顺滑）
	•	UI：NSStatusItem + NSMenu（菜单），管理窗口用 SwiftUI
	•	网络：URLSession
	•	解析：用成熟 feed parser（Swift 有现成库可选）
	•	存储：SQLite（Core Data 或轻量 SQLite wrapper）
	•	后台：Timer + 并发队列


RSS 相关的“最小实现清单”（你可以当作开发任务拆分）
	1.	FeedSource CRUD（添加/删除/禁用）
	2.	拉取 + 解析 RSS/Atom
	3.	去重入库 + 未读状态
	4.	状态栏 UI：左键列表 + 右键菜单
	5.	折叠逻辑：>5 显示更多
	6.	刷新策略（定时 + 手动 + 失败退避）
	7.	设置项（至少：刷新间隔、点击已读、显示条数）
	8.	基础错误展示（管理窗口或菜单底部提示）

⸻


基于你的需求，我将 PRD 拆解成一个更细化的开发任务分解。每个模块都将包含开发目标、结构和技术实现要点。

1. 项目结构与基础架构

1.1. 项目结构
	•	Main.swift：应用入口，包含生命周期管理
	•	FeedSource.swift：处理订阅源的类（增删改查）
	•	FeedItem.swift：文章实体类（数据模型）
	•	FeedFetcher.swift：获取并解析 RSS 的类
	•	FeedParser.swift：解析 RSS/Atom 格式的具体实现
	•	FeedStorage.swift：持久化存储（SQLite/CoreData）
	•	MenuController.swift：状态栏菜单及右键菜单控制
	•	FeedManager.swift：管理 Feed 刷新与去重逻辑
	•	AppSettings.swift：用户配置管理（刷新间隔、已读设置等）

1.2. 核心依赖
	•	SwiftUI（用于创建窗口和界面）
	•	Combine（响应式更新）
	•	SQLite（用于存储 Feed 数据）或者 原生存储
	•	URLSession（网络请求）
	•	SwiftFeedParser（用来解析 RSS/Atom）

2. 功能模块拆解与开发任务

2.1 FeedSource 模块：管理订阅源
目标：
	•	管理用户添加、删除、更新和禁用订阅源。
	•	支持 Feed URL 和站点 URL 自动获取 Feed。

数据结构：

struct FeedSource {
    var id: String
    var title: String
    var feedURL: String
    var isEnabled: Bool
    var refreshIntervalMinutes: Int
    var lastFetchedAt: Date?
    var lastError: String?
}

开发任务：
	•	添加源：接受 Feed URL 或站点 URL，自动解析 Feed。
	•	删除源：从管理列表中移除订阅源。
	•	更新源：修改源信息（例如更新间隔或启用状态）。
	•	禁用源：关闭源但不删除，方便重新启用。

2.2 FeedItem 模块：管理文章条目
目标：
	•	解析和存储每个源的文章（去重、标记已读）。

数据结构：

struct FeedItem {
    var id: String   // 唯一标识符，可以用 guid 或链接
    var sourceId: String
    var title: String
    var link: String
    var publishedAt: Date
    var summary: String
    var isRead: Bool
    var firstSeenAt: Date
}

开发任务：
	•	去重：通过 guid 或 link 去重。若文章已存在，则不再重复拉取。
	•	标记已读：用户点击后，更新条目状态为已读，自动清除或标记。
	•	存储条目：将文章条目存储到数据库中，确保永久保存。

2.3 FeedFetcher 模块：拉取并解析 RSS
目标：
	•	定期拉取订阅源，并通过 FeedParser 解析内容。

开发任务：
	•	拉取 RSS 数据：使用 URLSession 获取 RSS 数据。
	•	增量更新：利用 ETag 和 Last-Modified 实现增量更新，减少流量消耗。
	•	解析 RSS：用 SwiftFeedParser 或自定义解析器，提取条目。

示例代码：

func fetchFeed(url: String) {
    let urlRequest = URLRequest(url: URL(string: url)!)
    URLSession.shared.dataTask(with: urlRequest) { data, response, error in
        if let data = data, let feed = try? FeedParser.parse(data) {
            self.saveFeedData(feed)
        }
    }.resume()
}

2.4 FeedParser 模块：解析 RSS/Atom
目标：
	•	解析 RSS/Atom 格式并返回 FeedItem 数据。

开发任务：
	•	解析 XML：处理 RSS 格式的 XML，提取 title、link、guid、publishedAt 等字段。
	•	支持 Atom 和 RSS：同时支持两种格式。

示例代码：

class FeedParser {
    static func parse(_ data: Data) throws -> [FeedItem] {
        // 解析 RSS 或 Atom 数据，返回 FeedItem 列表
        let xmlParser = XMLParser(data: data)
        var items = [FeedItem]()

        // 解析逻辑...

        return items
    }
}

2.5 FeedStorage 模块：持久化存储（SQLite）
目标：
	•	使用 SQLite 存储 FeedSource 和 FeedItem 数据。
	•	提供增、删、改、查功能。

开发任务：
	•	存储结构：设计数据库表结构，分别存储 Feed 源和 Feed 项。
	•	数据库操作：提供增删查改接口，支持事务处理。

示例代码：

class FeedStorage {
    func saveFeedSource(_ source: FeedSource) {
        // 保存订阅源到 SQLite 数据库
    }

    func fetchFeedItems(for sourceId: String) -> [FeedItem] {
        // 获取某个源的所有文章条目
        return []
    }
}

2.6 MenuController 模块：状态栏菜单与交互
目标：
	•	创建状态栏图标和右键菜单。
	•	显示订阅源的文章列表。

开发任务：
	•	状态栏图标：使用 NSStatusItem 创建状态栏图标。
	•	菜单内容：左键点击时显示订阅源的文章列表，右键点击时显示应用设置和管理菜单。
	•	折叠与展开：如果文章超出 5 条，显示 … 更多，点击后展开。

示例代码：

class MenuController {
    func createMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "RSS"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ""))
        statusItem.menu = menu
    }

    @objc func openSettings() {
        // 打开设置窗口
    }
}

2.7 AppSettings 模块：用户设置
目标：
	•	提供用户配置管理（如刷新间隔、已读设置）。

开发任务：
	•	刷新间隔：允许用户设置全局刷新频率。
	•	已读设置：设置点击条目后是否自动标记为已读。

示例代码：

class AppSettings {
    var refreshInterval: Int // 刷新间隔（分钟）
    var markAsReadOnClick: Bool // 点击是否标记为已读
}

3. 其他开发要点

3.1 错误处理与重试机制
	•	失败的订阅源需要标记失败信息，并在下次自动重试。
	•	提供可视化反馈（如在管理界面中展示“失败原因”）。

3.2 通知与未读计数
	•	允许在状态栏图标上显示未读数量。
	•	支持在获取新内容时通过系统通知提醒用户。

3.3 单元测试与 UI 测试
	•	编写单元测试覆盖 Feed 解析、去重、存储和菜单显示。
	•	使用 XCTest 验证 Feed 拉取与解析是否成功。

4. 界面与交互

4.1 左键点击：显示文章列表（最多 5 篇）
	•	每个条目展示标题和来源，点击跳转到源页面。
	•	超过 5 篇时展示 … 更多，点击展开。
	•	可点击标记已读或显示文章摘要。

4.2 右键点击：显示应用菜单
	•	提供刷新、设置、退出等操作。

5. 验收标准
	1.	成功添加和移除订阅源，能拉取并解析 RSS。
	2.	状态栏图标显示最新未读数，点击显示文章列表。
	3.	支持折叠超过 5 篇文章并能展开查看。
	4.	右键菜单支持刷新、设置和退出功能。
	5.	文章点击后能正确打开浏览器。
	6.	系统通知和未读数实时更新。
	7.	所有配置项可保存并且重新启动后有效。

⸻

这样，你可以从模块化角度着手开发，确保每个模块独立且功能清晰。如果有其他具体细节或设计问题，可以随时问我。