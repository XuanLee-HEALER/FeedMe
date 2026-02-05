//
//  ArticleMenuItemView.swift
//  FeedMe
//
//  Created by Claude on 2026/2/4.
//

import Cocoa

/// 两行展示的文章菜单项视图
final class ArticleMenuItemView: NSView {
    private let itemId: String
    private let articleTitle: String
    private let sourceName: String
    private let timeString: String
    private let isRead: Bool
    private let link: String

    /// 标已读回调
    var onMarkAsRead: ((String) -> Void)?
    /// 打开文章回调
    var onOpenArticle: ((String, String) -> Void)?

    /// 高亮状态（由外部通过 NSMenuDelegate 驱动）
    var isHighlighted: Bool = false {
        didSet {
            if isHighlighted != oldValue {
                updateAppearance()
            }
        }
    }

    /// 高亮背景视图
    private let highlightView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = .selection
        view.isEmphasized = true
        view.blendingMode = .behindWindow
        view.isHidden = true
        return view
    }()

    /// 未读圆点
    private let unreadDot: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 3
        return view
    }()

    /// 第一行标签
    private let firstLineLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// 第二行标签
    private let secondLineLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // UI 配置
    private static let viewWidth: CGFloat = 280
    private static let viewHeight: CGFloat = 40
    private static let horizontalPadding: CGFloat = 12
    private static let verticalPadding: CGFloat = 6
    private static let unreadDotSize: CGFloat = 6
    private static let tooltipLineLength = 40

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// 格式化 tooltip，超过指定长度自动换行
    private static func formatTooltip(_ text: String) -> String {
        guard text.count > tooltipLineLength else { return text }

        var result = ""
        var currentLineLength = 0

        for char in text {
            if currentLineLength >= tooltipLineLength {
                result.append("\n")
                currentLineLength = 0
            }
            result.append(char)
            currentLineLength += 1
        }

        return result
    }

    init(item: FeedItem, sourceName: String) {
        self.itemId = item.id
        self.articleTitle = item.displayTitle
        self.sourceName = sourceName
        self.timeString = Self.timeFormatter.localizedString(for: item.displayDate, relativeTo: Date())
        self.isRead = item.isRead
        self.link = item.link

        super.init(frame: NSRect(x: 0, y: 0, width: Self.viewWidth, height: Self.viewHeight))

        setupViews()
        updateContent()

        // 设置悬浮提示显示完整标题
        self.toolTip = Self.formatTooltip(articleTitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        addSubview(highlightView)
        highlightView.frame = bounds
        highlightView.autoresizingMask = [.width, .height]

        if !isRead {
            addSubview(unreadDot)
            unreadDot.frame = NSRect(
                x: Self.horizontalPadding,
                y: (bounds.height - Self.unreadDotSize) / 2,
                width: Self.unreadDotSize,
                height: Self.unreadDotSize
            )
        }

        let leftPadding = Self.horizontalPadding + (isRead ? 0 : Self.unreadDotSize + 6)

        addSubview(firstLineLabel)
        firstLineLabel.frame = NSRect(
            x: leftPadding,
            y: bounds.height - Self.verticalPadding - 14,
            width: bounds.width - leftPadding - Self.horizontalPadding,
            height: 14
        )

        addSubview(secondLineLabel)
        secondLineLabel.frame = NSRect(
            x: leftPadding,
            y: Self.verticalPadding,
            width: bounds.width - leftPadding - Self.horizontalPadding,
            height: 18
        )
    }

    private func updateContent() {
        firstLineLabel.stringValue = "\(sourceName)  ·  \(timeString)"
        secondLineLabel.stringValue = articleTitle
        updateAppearance()
    }

    private func updateAppearance() {
        highlightView.isHidden = !isHighlighted

        if isHighlighted {
            firstLineLabel.textColor = .white.withAlphaComponent(0.8)
            secondLineLabel.textColor = .white
            unreadDot.layer?.backgroundColor = NSColor.white.cgColor
        } else {
            firstLineLabel.textColor = .secondaryLabelColor
            secondLineLabel.textColor = .labelColor
            unreadDot.layer?.backgroundColor = NSColor.systemBlue.cgColor
        }
    }

    // MARK: - Hit Test

    /// 让所有点击都由本视图处理，防止子视图（NSTextField）截获鼠标事件
    override func hitTest(_ point: NSPoint) -> NSView? {
        return bounds.contains(point) ? self : nil
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // 左键点击：先关闭菜单，再触发动作
        let menu = enclosingMenuItem?.menu
        menu?.cancelTracking()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onOpenArticle?(self.itemId, self.link)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // 右键点击：触发标记已读，菜单保持打开
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onMarkAsRead?(self.itemId)
        }
    }
}
