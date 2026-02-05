# FeedMe 开发指南

使用 `just` 任务执行器简化开发流程。

## 快速开始

### 安装依赖

```bash
brew install just create-dmg gh
```

### 常用命令

```bash
# 查看所有可用命令
just --list

# 查看当前版本
just version

# 检查依赖是否完整
just check-deps
```

## 开发流程

### 本地开发

```bash
# 打开 Xcode
just dev

# 编译 Debug 版本
just build

# 运行测试
just test

# 代码检查
just lint

# 代码格式化
just format
```

### 本地安装测试

```bash
# 一键编译、测试并安装到 /Applications
just install

# 或者使用 skill
/local-install
```

这会自动：
1. 编译 Release 版本
2. 运行所有测试
3. 停止运行中的应用
4. 安装到 /Applications
5. 验证代码签名
6. 启动应用

### 版本发布

```bash
# 使用 skill（推荐）
/release

# 或手动执行步骤
just update-version 1.3.0
just build-release
just test
just dmg 1.3.0
just commit-version 1.3.0 "Release v1.3.0: 新功能说明"

# 创建 GitHub Release
gh release create v1.3.0 FeedMe-1.3.0.dmg --title "FeedMe v1.3.0" --notes-file .release-notes.md

# 更新 Homebrew
SHA256=$(shasum -a 256 FeedMe-1.3.0.dmg | awk '{print $1}')
just update-homebrew 1.3.0 "$SHA256"

# 清理
just clean-artifacts
```

## Just Recipes 说明

| 命令 | 说明 |
|------|------|
| `just build` | 编译 Debug 版本 |
| `just build-release` | 编译 Release 版本（带验证） |
| `just test` | 运行测试 |
| `just lint` | 代码检查（需要 swiftlint） |
| `just format` | 代码格式化（需要 swiftformat） |
| `just clean` | 清理编译产物 |
| `just install` | 本地安装到 /Applications |
| `just dmg VERSION` | 创建 DMG 安装包 |
| `just clean-artifacts` | 清理发布产物（DMG 等） |
| `just update-version VERSION` | 更新版本号 |
| `just commit-version VERSION MSG` | 提交版本更新 |
| `just gh-release VERSION` | 创建 GitHub Release |
| `just update-homebrew VERSION SHA256` | 更新 Homebrew Cask |
| `just version` | 显示当前版本 |
| `just check-deps` | 检查依赖是否完整 |
| `just dev` | 打开 Xcode |

## 文件清理

`.gitignore` 已配置忽略以下文件：
- `*.dmg` - DMG 安装包
- `dmg_temp/` - DMG 临时目录
- `.release-notes.md` - Release notes 临时文件
- `*.log` - 日志文件

发布后记得运行 `just clean-artifacts` 清理这些文件。

## 技巧

### 快速重新安装

修改代码后快速测试：

```bash
just install
```

### 查看详细编译输出

```bash
xcodebuild -project FeedMe.xcodeproj -scheme FeedMe -configuration Release build
```

### 自定义 just 任务

编辑项目根目录的 `justfile` 添加自定义任务。

## 故障排查

### just 命令未找到

```bash
brew install just
```

### 编译失败

```bash
# 清理后重试
just clean && just build-release
```

### 权限问题

```bash
# 确认有写入 /Applications 的权限
ls -la /Applications/FeedMe.app
```

### 代码签名问题

```bash
# 验证签名
codesign -vvv /Applications/FeedMe.app
```

## 参考资料

- [just 官方文档](https://just.systems/)
- [Apple 开发者文档](https://developer.apple.com/documentation/)
- [项目 CLAUDE.md](./CLAUDE.md)
