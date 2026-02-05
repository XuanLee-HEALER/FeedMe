# FeedMe 开发命令

## 构建命令

### Debug 构建
```bash
xcodebuild build -project FeedMe.xcodeproj -scheme FeedMe -configuration Debug
```

### Release 构建
```bash
xcodebuild build \
  -project FeedMe.xcodeproj \
  -scheme FeedMe \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### 清理构建
```bash
xcodebuild clean -project FeedMe.xcodeproj -scheme FeedMe
rm -rf build/ DerivedData/
```

## 测试命令

### 运行所有测试
```bash
xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe
```

### 运行特定测试
```bash
xcodebuild test -project FeedMe.xcodeproj -scheme FeedMe -only-testing:FeedMeTests/TestClassName
```

## 安装和运行

### 本地安装
```bash
# 构建后复制到 Applications
cp -R build/Build/Products/Release/FeedMe.app /Applications/
```

### 直接运行（开发调试）
```bash
open build/Build/Products/Debug/FeedMe.app
```

## 发布命令

### 创建发布包
```bash
cd build/Build/Products/Release
zip -r -y FeedMe-vX.Y.Z-macOS.zip FeedMe.app
```

### 创建 Git Tag
```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

### 创建 GitHub Release
```bash
gh release create vX.Y.Z \
  --title "FeedMe vX.Y.Z" \
  --notes "Release notes here" \
  FeedMe-vX.Y.Z-macOS.zip
```

## 代码质量

### SwiftLint (如已安装)
```bash
swiftlint lint
swiftlint lint --fix  # 自动修复
```

### SwiftFormat (如已安装)
```bash
swiftformat .
```

## Git 操作

### 查看状态
```bash
git status
git log --oneline -10
```

### 提交格式
```bash
git commit -m "$(cat <<'EOF'
简短描述

详细说明（可选）

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

## 解析 Package 依赖
```bash
xcodebuild -resolvePackageDependencies -project FeedMe.xcodeproj -scheme FeedMe
```

## 查看工作流状态
```bash
gh run list --limit 5
gh run view <run-id> --log-failed
```
