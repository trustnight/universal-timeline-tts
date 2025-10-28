# GitHub 发布指南

## 📦 发布前准备

### 1. 清理项目

在发布前，删除或清空以下文件：

```bash
# 删除用户配置（保留模板）
config/app_config.json

# 删除个人副本规则（保留示例）
dungeon_rules/*.json
# 保留 dungeon_rules/example.json

# 清空日志
logs/*.log
```

### 2. 检查 .gitignore

确保 `.gitignore` 已正确配置，避免上传敏感信息。

### 3. 修改 README

将 README.md 和 README_CN.md 中的仓库地址替换为你的：
```markdown
https://github.com/yourusername/universal-timeline-tts
```

改为：
```markdown
https://github.com/你的用户名/你的仓库名
```

## 🚀 发布到 GitHub

### 方法一：通过 Git 命令行

1. **初始化 Git 仓库**
```bash
cd universal-timeline-tts
git init
```

2. **添加文件**
```bash
git add .
```

3. **提交**
```bash
git commit -m "Initial commit - Universal Timeline TTS v1.0.0"
```

4. **在 GitHub 创建仓库**
   - 访问 https://github.com/new
   - 仓库名：`universal-timeline-tts`
   - 描述：`通用时间轴TTS播报系统 - 99% 由 AI 制作`
   - 选择：Public（公开）
   - **不要**勾选 "Initialize with README"

5. **关联远程仓库**
```bash
git remote add origin https://github.com/你的用户名/universal-timeline-tts.git
git branch -M main
```

6. **推送到 GitHub**
```bash
git push -u origin main
```

### 方法二：通过 GitHub Desktop

1. 打开 GitHub Desktop
2. File -> Add Local Repository
3. 选择项目文件夹
4. 点击 "Publish repository"
5. 填写仓库信息并发布

## 🏷️ 创建 Release

### 1. 在 GitHub 网页操作

1. 进入仓库页面
2. 点击右侧 "Releases"
3. 点击 "Create a new release"
4. 填写：
   - Tag version: `v1.0.0`
   - Release title: `v1.0.0 - 首次发布`
   - Description:
   ```markdown
   ## ✨ 首次发布
   
   ### 主要功能
   - 🎤 TTS 时间轴自动播报
   - 🔍 OCR 智能触发
   - ⏰ 倒计时悬浮窗
   - 📍 站位配置系统
   - 🎯 自动启动监控
   
   ### 注意事项
   - 需要 AutoHotkey v2.0 或更高版本
   - 首次运行需要配置 OCR 区域
   - 支持 Windows 10/11
   
   ⚡ **本项目 99% 由 AI 制作完成**
   ```
5. 点击 "Publish release"

## 📝 优化仓库

### 添加 Topics（标签）

在仓库页面点击 ⚙️ 设置，添加标签：
```
autohotkey, tts, ocr, timeline, game, voice, ahk, ai-generated
```

### 添加 Description

仓库描述：
```
🎤 通用时间轴TTS播报系统 | Universal Timeline TTS - 支持自动播报、OCR触发、倒计时显示 | 99% AI制作
```

### 设置 About

- Website: 留空或填写你的博客
- Topics: autohotkey, tts, ocr, timeline
- 勾选：
  - ✅ Releases
  - ✅ Packages
  - ✅ Wiki（如需要）

## 🎨 项目徽章

在 README.md 顶部已包含：
- MIT License 徽章
- AutoHotkey 版本徽章

可选添加：
```markdown
[![GitHub release](https://img.shields.io/github/release/你的用户名/universal-timeline-tts.svg)](https://github.com/你的用户名/universal-timeline-tts/releases)
[![GitHub downloads](https://img.shields.io/github/downloads/你的用户名/universal-timeline-tts/total.svg)](https://github.com/你的用户名/universal-timeline-tts/releases)
[![GitHub stars](https://img.shields.io/github/stars/你的用户名/universal-timeline-tts.svg)](https://github.com/你的用户名/universal-timeline-tts/stargazers)
```

## 📢 推广建议

### 1. 社交媒体
- 分享到相关技术社区
- AutoHotkey 论坛
- Reddit: r/AutoHotkey
- 游戏社区（如果适用）

### 2. 项目介绍
强调特点：
- ✅ 99% AI 制作
- ✅ 功能完整
- ✅ 易于使用
- ✅ 开源免费

### 3. 演示视频（可选）
录制一个简短的演示视频展示功能

## ✅ 发布检查清单

发布前确认：

- [ ] README.md 完整
- [ ] LICENSE 文件存在
- [ ] .gitignore 配置正确
- [ ] 删除个人配置文件
- [ ] 删除个人副本规则（保留示例）
- [ ] 清空日志文件
- [ ] 修改仓库地址
- [ ] 代码可正常运行
- [ ] 示例配置正确

## 🔄 后续维护

### 更新代码
```bash
git add .
git commit -m "描述更新内容"
git push
```

### 创建新 Release
每次重要更新后创建新的 Release：
1. 更新版本号
2. 编写更新日志
3. 创建 Release

### 处理 Issues
- 及时回复用户问题
- 修复 Bug 并发布更新
- 收集功能建议

## 📞 需要帮助？

如果发布过程中遇到问题：
1. 查看 GitHub 官方文档
2. 搜索相关教程
3. 咨询 AI 助手

---

祝发布顺利！🎉

