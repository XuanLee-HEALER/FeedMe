# 任务完成检查清单

## 代码修改后必做

### 1. 编译检查
```bash
xcodebuild build -project FeedMe.xcodeproj -scheme FeedMe -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|warning:|BUILD)"
```
- [ ] 无编译错误
- [ ] 审视警告是否需要处理

### 2. 代码质量检查
- [ ] 新增的 URL 打开操作使用 http/https 白名单校验
- [ ] 网络请求有大小限制和超时设置
- [ ] Task 中的 @State 更新使用 @MainActor
- [ ] 无强制解包（除非确定安全）
- [ ] 中文注释说明复杂逻辑

### 3. 功能测试
- [ ] 本地运行应用验证功能
- [ ] 测试正常路径
- [ ] 测试错误处理路径

## 发布前必做

### 1. 版本检查
- [ ] 更新版本号（如需要）
- [ ] 更新 CHANGELOG / Release Notes

### 2. 完整构建
```bash
xcodebuild clean build -project FeedMe.xcodeproj -scheme FeedMe -configuration Release ...
```

### 3. 本地验证
- [ ] 安装到 /Applications 测试
- [ ] 验证菜单栏图标显示
- [ ] 验证添加/刷新/删除订阅源
- [ ] 验证文章点击打开浏览器

### 4. 提交和推送
- [ ] git add 相关文件
- [ ] 编写清晰的 commit message
- [ ] git push

### 5. 等待 CI
- [ ] GitHub Actions 构建成功
- [ ] 检查是否有新的警告

## 发布版本

### 创建 Release
```bash
git tag vX.Y.Z
git push origin vX.Y.Z
# GitHub Actions 自动创建 Release
```

### 更新 Release Notes
```bash
gh release edit vX.Y.Z --notes "..."
```

## 常见问题

### 编译失败
1. 清理 DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/FeedMe-*`
2. 重新解析依赖: `xcodebuild -resolvePackageDependencies ...`

### CI 失败
1. 检查 GRDB 版本兼容性（需要 Swift 6.0 tools version）
2. 检查 Swift 并发 actor isolation 问题
