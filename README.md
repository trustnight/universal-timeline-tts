# 通用时间轴TTS播报系统 (Universal Timeline TTS)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-blue.svg)](https://www.autohotkey.com/)

> ⚡ **99% 由 AI 制作** - 本项目主要由 AI 辅助开发完成

一个基于 AutoHotkey v2 的通用游戏时间轴语音播报系统，支持 TTS 播报、OCR 触发、倒计时条显示等功能。

## ✨ 核心功能

### 📢 TTS 时间轴播报
- 按时间轴自动播报技能提示
- 支持变量替换（队伍、职能、站位等）
- 支持职能过滤和取反播报
- 支持职称组播报（T/D/H）

### 🔍 OCR 智能触发
- 三个独立 OCR 区域监控（台词、血条、技能）
- 关键字触发 TTS 播报
- 支持冷却时间设置
- 支持同名关键字多目标配置

### ⏰ 倒计时条显示
- 可拖拽透明悬浮窗
- 显示即将发生的技能
- 实时倒计时显示

### 🎯 站位配置
- 为不同技能配置站位
- 支持多目标站位（队伍、职能）
- 变量自动替换 `{position}` `{position1}` 等

### 🎨 UI 特性
- 副本规则可视化编辑
- 支持批量导入导出
- 实时预览和调试
- 自动启动监控（颜色检测）

## 🚀 快速开始

### 环境要求
- Windows 10/11
- AutoHotkey v2.0+
- RapidOCR（已集成）

### 安装步骤

1. **下载项目**
```bash
git clone https://github.com/yourusername/universal-timeline-tts.git
cd universal-timeline-tts
```

2. **安装 AutoHotkey v2**
   - 下载：https://www.autohotkey.com/
   - 安装 v2.0 或更高版本

3. **运行程序**
```bash
双击运行 main.ahk
```

## 📖 使用指南

### 1. 基本配置

打开主界面后：
1. 设置玩家队伍（1队/2队）
2. 设置职能（MT/ST/H1/H2/D1-D4）
3. 配置 OCR 区域（框选识别区域）

### 2. 创建副本规则

**TTS 时间轴：**
```
时间    技能名称        播报内容                    目标
00:10   开场buff       准备开怪                    全部
00:30   大招           {position}站位 注意躲避     MT
```

**OCR 触发器：**
```
关键字    播报内容                    CD(秒)    职能
陨石      {position}放陨石            5         全部
分摊      前往{position}分摊          5         1队
```

**站位配置：**
```
技能名称    站位        目标
大招        A点         MT
大招        B点         ST
陨石        1点         H1
陨石        2点         D1
```

### 3. 高级功能

**职能过滤：**
- `全部` - 所有人播报
- `1队/2队` - 队伍过滤
- `MT/ST/H1/H2/D1-D4` - 职能过滤
- `T/D/H` - 职称组过滤
- `~MT` - 取反（除了MT都播报）

**变量替换：**
- `{position}` - 完整站位（如 "1 3 中间"）
- `{position1}` - 站位第一部分（如 "1"）
- `{position2}` - 站位第二部分（如 "3"）
- `{team}` - 队伍（1队/2队）

**同名技能多目标：**
```json
"boss_dialogue": {
    "降临": {"tts": "1队 前往{position}", "target": "1队"},
    "降临#2": {"tts": "2队 前往{position}", "target": "2队"}
}
```

## ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `F3` | 开始监控 |
| `F5` | 停止监控 |
| `F6` | 重置时间轴 |
| `F8` | 显示/隐藏倒计时条 |

## 📁 项目结构

```
universal-timeline-tts/
├── main.ahk                    # 主程序入口
├── ahk/
│   ├── gui/                    # GUI 界面
│   │   └── main_window.ahk
│   ├── ocr/                    # OCR 模块
│   │   ├── ocr_monitor.ahk
│   │   └── ocr_engine.ahk
│   ├── timeline/               # 时间轴控制
│   │   └── timeline_controller.ahk
│   ├── tts/                    # TTS 引擎
│   │   └── tts_sapi.ahk
│   ├── overlay/                # 悬浮窗
│   │   └── countdown_overlay.ahk
│   ├── lib/                    # 工具库
│   │   ├── config_manager.ahk
│   │   ├── logger.ahk
│   │   └── json.ahk
│   └── tools/                  # 辅助工具
│       └── region_selector.ahk
├── config/                     # 配置文件
│   └── app_config.json
├── dungeon_rules/              # 副本规则
├── libs/                       # 第三方库
│   └── rapidocr/              # OCR 引擎
└── logs/                       # 日志文件
```

## 🎮 适用游戏

理论上适用于任何需要时间轴播报的游戏，例如：
- MMORPG 副本战斗
- 音游节奏提示
- 其他需要时间提示的场景

只需根据游戏配置相应的：
- OCR 识别区域
- 时间轴事件
- 触发关键字

## 🔧 配置文件

**主配置 (`config/app_config.json`)：**
```json
{
    "player": {
        "party": "1",
        "role": "mt"
    },
    "ocr": {
        "check_interval": 0.3,
        "boss_dialogue": {...},
        "boss_hp": {...},
        "boss_skill": {...}
    },
    "tts": {
        "enabled": true,
        "rate": 1,
        "volume": 80
    }
}
```

**副本规则 (`dungeon_rules/*.json`)：**
```json
{
    "dungeon_name": "示例副本",
    "description": "副本说明",
    "timeline": [...],
    "overlay_timeline": [...],
    "positions": {...},
    "boss_dialogue": {...},
    "boss_hp": {...},
    "boss_skill": {...}
}
```

## 🤝 贡献

本项目 **99% 由 AI 制作完成**，欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

## 🙏 致谢

- [AutoHotkey v2](https://www.autohotkey.com/) - 强大的自动化脚本语言
- [RapidOCR](https://github.com/RapidAI/RapidOCR) - 高性能 OCR 引擎
- **AI Assistant** - 主要开发者 🤖

## 📮 联系方式

如有问题或建议，请提交 [Issue](https://github.com/yourusername/universal-timeline-tts/issues)。

---

⭐ 如果这个项目对你有帮助，欢迎 Star！

