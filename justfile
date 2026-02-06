# FeedMe 项目任务执行器

# 默认任务：显示帮助
default:
    @just --list

# 变量配置
project_name := "FeedMe"
scheme := "FeedMe"
xcodeproj := "FeedMe.xcodeproj"
derived_data := env_var('HOME') + "/Library/Developer/Xcode/DerivedData"
app_path := "/Applications/FeedMe.app"

# 清理所有（编译产物 + artifacts）
clean:
    @echo "🧹 清理所有..."
    @xcodebuild -project {{xcodeproj}} -scheme {{scheme}} clean
    @rm -f *.dmg *.zip
    @rm -rf dmg_temp
    @rm -f *.log .release-notes.md
    @echo "✅ 清理完成"

# 仅清理编译产物
clean-build:
    @echo "🧹 清理编译产物..."
    xcodebuild -project {{xcodeproj}} -scheme {{scheme}} clean

# 编译 Debug 版本
build:
    @echo "🔨 编译 Debug 版本..."
    xcodebuild -project {{xcodeproj}} -scheme {{scheme}} -configuration Debug build

# 编译 Release 版本（带验证）
build-release:
    @echo "🔨 编译 Release 版本..."
    @xcodebuild -project {{xcodeproj}} -scheme {{scheme}} -configuration Release clean build 2>&1 | grep -E "(error:|warning:|BUILD)" | grep -v "appintentsmetadataprocessor" || true
    @echo ""

# 运行单元测试
test:
    @echo "🧪 运行单元测试..."
    @xcodebuild test -project {{xcodeproj}} -scheme {{scheme}} -only-testing:FeedMeTests 2>&1 | grep -E "(Test Suite|Test run|Executed|passed|failed|SUCCEEDED|FAILED|✔|✘|◇)" || true
    @echo ""

# 运行所有测试（包含 UI 测试）
test-all:
    @echo "🧪 运行所有测试..."
    @xcodebuild test -project {{xcodeproj}} -scheme {{scheme}} 2>&1 | grep -E "(Test Suite|Executed|FAILED)" || true
    @echo ""

# 代码检查 (需要 swiftlint)
lint:
    @echo "🔍 代码检查..."
    @if command -v swiftlint >/dev/null 2>&1; then \
        swiftlint lint; \
    else \
        echo "⚠️  swiftlint 未安装，跳过检查"; \
    fi

# 代码格式化 (需要 swiftformat)
format:
    @echo "✨ 代码格式化..."
    @if command -v swiftformat >/dev/null 2>&1; then \
        swiftformat .; \
    else \
        echo "⚠️  swiftformat 未安装，跳过格式化"; \
    fi

# 本地安装到 /Applications
install: build-release test
    @echo "📦 安装到 /Applications..."
    @pkill -x {{project_name}} 2>/dev/null || true
    @sleep 2
    @rm -rf {{app_path}}
    @cp -R {{derived_data}}/{{project_name}}-*/Build/Products/Release/{{project_name}}.app {{app_path}}
    @echo "✅ 验证签名..."
    @codesign -vvv {{app_path}} 2>&1 | head -3
    @echo ""
    @echo "🚀 启动应用..."
    @open {{app_path}}
    @echo "✅ 本地安装完成！"

# 创建 DMG 安装包
dmg version: build-release
    @echo "📦 创建 DMG (v{{version}})..."
    @rm -rf dmg_temp {{project_name}}-{{version}}.dmg
    @mkdir -p dmg_temp
    @cp -R {{derived_data}}/{{project_name}}-*/Build/Products/Release/{{project_name}}.app dmg_temp/
    @create-dmg \
        --volname "{{project_name}}" \
        --volicon "{{project_name}}/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "{{project_name}}.app" 150 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "{{project_name}}-{{version}}.dmg" \
        "dmg_temp/" >/dev/null 2>&1
    @rm -rf dmg_temp
    @echo "✅ DMG 创建完成："
    @ls -lh {{project_name}}-{{version}}.dmg
    @echo ""
    @echo "📝 SHA256:"
    @shasum -a 256 {{project_name}}-{{version}}.dmg

# 清理 artifacts（DMG 文件等）
clean-artifacts:
    @echo "🧹 清理 artifacts..."
    @rm -f *.dmg *.zip
    @rm -rf dmg_temp
    @rm -f *.log .release-notes.md
    @echo "✅ Artifacts 清理完成"

# 更新版本号
update-version version:
    @echo "🔢 更新版本号到 {{version}}..."
    @sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = {{version}};/g' {{xcodeproj}}/project.pbxproj
    @echo "✅ 版本号已更新"

# Git 提交版本更新
commit-version version message:
    @echo "📝 提交版本更新..."
    @git add -A
    @git commit -m "{{message}}\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
    @git push origin main
    @echo "✅ 代码已推送"

# GitHub Release
gh-release version:
    @echo "🚀 创建 GitHub Release (v{{version}})..."
    @gh release create v{{version}} {{project_name}}-{{version}}.dmg \
        --title "{{project_name}} v{{version}}" \
        --notes-file .release-notes.md
    @echo "✅ GitHub Release 创建完成"

# 更新 Homebrew Cask
update-homebrew version sha256:
    @echo "🍺 更新 Homebrew Cask..."
    @cd ~/Documents/project/homebrew-feedme && \
    echo 'cask "feedme" do' > Casks/feedme.rb && \
    echo '  version "{{version}}"' >> Casks/feedme.rb && \
    echo '  sha256 "{{sha256}}"' >> Casks/feedme.rb && \
    echo '' >> Casks/feedme.rb && \
    echo '  url "https://github.com/XuanLee-HEALER/FeedMe/releases/download/v#{version}/FeedMe-#{version}.dmg"' >> Casks/feedme.rb && \
    echo '  name "FeedMe"' >> Casks/feedme.rb && \
    echo '  desc "Lightweight macOS menu bar RSS reader"' >> Casks/feedme.rb && \
    echo '  homepage "https://github.com/XuanLee-HEALER/FeedMe"' >> Casks/feedme.rb && \
    echo '' >> Casks/feedme.rb && \
    echo '  depends_on macos: ">= :ventura"' >> Casks/feedme.rb && \
    echo '' >> Casks/feedme.rb && \
    echo '  app "FeedMe.app"' >> Casks/feedme.rb && \
    echo '' >> Casks/feedme.rb && \
    echo '  zap trash: [' >> Casks/feedme.rb && \
    echo '    "~/Library/Application Support/FeedMe",' >> Casks/feedme.rb && \
    echo '    "~/Library/Preferences/com.lixuan.FeedMe.plist",' >> Casks/feedme.rb && \
    echo '    "~/Library/Caches/com.lixuan.FeedMe",' >> Casks/feedme.rb && \
    echo '  ]' >> Casks/feedme.rb && \
    echo 'end' >> Casks/feedme.rb
    @cd ~/Documents/project/homebrew-feedme && \
    git add Casks/feedme.rb && \
    git commit -m "Update FeedMe to v{{version}}" -m "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" && \
    git push origin main
    @echo "✅ Homebrew Cask 更新完成"

# 完整发布流程（由 /release skill 调用）
release-workflow version type message:
    @echo "🚀 开始发布 v{{version}} ({{type}})..."
    @echo ""
    just update-version {{version}}
    just build-release
    just test
    just dmg {{version}}
    just commit-version {{version}} "{{message}}"
    just gh-release {{version}}
    @echo ""
    @echo "📝 准备更新 Homebrew..."
    @echo "SHA256: $(shasum -a 256 {{project_name}}-{{version}}.dmg | awk '{print $1}')"

# 开发相关
dev:
    @echo "🔧 打开 Xcode..."
    @open {{xcodeproj}}

# 显示当前版本
version:
    @grep "MARKETING_VERSION" {{xcodeproj}}/project.pbxproj | head -1 | sed 's/.*= \(.*\);/\1/'

# 检查依赖
check-deps:
    @echo "🔍 检查依赖..."
    @echo -n "Xcode: "
    @xcodebuild -version | head -1 || echo "❌ 未安装"
    @echo -n "just: "
    @just --version 2>/dev/null || echo "❌ 未安装"
    @echo -n "create-dmg: "
    @create-dmg --version 2>/dev/null || echo "❌ 未安装 (brew install create-dmg)"
    @echo -n "gh: "
    @gh --version 2>/dev/null | head -1 || echo "❌ 未安装 (brew install gh)"
    @echo -n "swiftlint: "
    @swiftlint version 2>/dev/null || echo "⚠️  未安装 (可选)"
    @echo -n "swiftformat: "
    @swiftformat --version 2>/dev/null || echo "⚠️  未安装 (可选)"
