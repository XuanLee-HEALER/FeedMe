//
//  OPMLService.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// OPML 导入/导出服务
final class OPMLService {
    static let shared = OPMLService()

    private init() {}

    // MARK: - 导入

    /// 从 OPML 数据导入订阅源
    /// - Parameter data: OPML 文件数据
    /// - Returns: 解析出的订阅源列表
    func importOPML(from data: Data) throws -> [FeedSource] {
        let parser = OPMLParser(data: data)
        return try parser.parse()
    }

    /// 从 URL 导入 OPML
    /// - Parameter url: OPML 文件 URL
    /// - Returns: 解析出的订阅源列表
    func importOPML(from url: URL) async throws -> [FeedSource] {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try importOPML(from: data)
    }

    // MARK: - 导出

    /// 导出订阅源为 OPML 数据
    /// - Parameter sources: 要导出的订阅源
    /// - Returns: OPML 文件数据
    func exportOPML(sources: [FeedSource]) -> Data {
        let generator = OPMLGenerator(sources: sources)
        return generator.generate()
    }
}

// MARK: - OPML 解析器

private class OPMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var sources: [FeedSource] = []
    private var parseError: Error?

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [FeedSource] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error = parseError {
            throw error
        }

        return sources
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName == "outline" else { return }

        // 检查是否是 feed 条目（有 xmlUrl 属性）
        if let xmlUrl = attributeDict["xmlUrl"], !xmlUrl.isEmpty {
            let title = attributeDict["title"] ?? attributeDict["text"] ?? "未命名"
            let siteUrl = attributeDict["htmlUrl"]

            let source = FeedSource(
                title: title,
                siteURL: siteUrl,
                feedURL: xmlUrl
            )
            sources.append(source)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

// MARK: - OPML 生成器

private struct OPMLGenerator {
    let sources: [FeedSource]

    func generate() -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>FeedMe Subscriptions</title>
                <dateCreated>\(ISO8601DateFormatter().string(from: Date()))</dateCreated>
            </head>
            <body>

        """

        for source in sources {
            let title = escapeXML(source.title)
            let feedURL = escapeXML(source.feedURL)
            let siteURL = source.siteURL.map { escapeXML($0) } ?? ""

            xml += """
                    <outline type="rss" text="\(title)" title="\(title)" xmlUrl="\(feedURL)" htmlUrl="\(siteURL)"/>

            """
        }

        xml += """
            </body>
        </opml>
        """

        return xml.data(using: .utf8) ?? Data()
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
