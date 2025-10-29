; ===================================================
; 配置管理器
; 处理配置的加载、保存、默认值生成
; ===================================================

#Include json.ahk

class ConfigManager {
    configFile := ""
    config := Map()
    defaultConfig := Map()
    
    ; 初始化
    __New(configFile) {
        this.configFile := configFile
        this.InitDefaultConfig()
    }
    
    ; 初始化默认配置
    InitDefaultConfig() {
        ; 应用配置默认值
        this.defaultConfig := Map()
        
        
        ; 游戏窗口设置
        this.defaultConfig["game"] := Map(
            "window_title", ""  ; 游戏窗口标题（留空则不激活）
        )
        
        ; TTS 设置
        this.defaultConfig["tts"] := Map(
            "enabled", true,
            "rate", 0,
            "volume", 100,
            "voice", ""
        )
        
        ; OCR 设置
        this.defaultConfig["ocr"] := Map(
            "check_interval", 0.5,
            "confidence_threshold", 0.5
        )
        
        ; 监控选项
        this.defaultConfig["monitor"] := Map(
            "enable_timeline", true,
            "enable_ocr", true,
            "show_timeline_overlay", true,  ; 显示TTS轴倒计时悬浮窗
            "current_dungeon", ""  ; 当前选择的副本文件名
        )
        
        ; 玩家设置
        this.defaultConfig["player"] := Map(
            "party", "all",  ; 队伍：all（全部）、1（1队）、2（2队）
            "role", "all"    ; 职业：all（全部）、MT、H1、D1、D2、ST、H2、D3、D4
        )
        
        ; 热键设置
        this.defaultConfig["hotkeys"] := Map(
            "toggle_monitor", "F5",
            "test_tts", "F6",
            "toggle_window", "F7",
            "reload", "F8"
        )
        
        ; 日志设置
        this.defaultConfig["logging"] := Map(
            "debug_mode", false,
            "write_to_file", true,
            "max_file_size_mb", 10
        )
        
        ; 窗口设置
        this.defaultConfig["window"] := Map(
            "width", 900,
            "height", 700,
            "remember_position", true,
            "start_minimized", false
        )
        
        ; TTS轴倒计时悬浮窗设置
        this.defaultConfig["timeline_overlay"] := Map(
            "x", 100,
            "y", 100,
            "width", 400,
            "height", 120,
            "opacity", 220,  ; 窗口透明度 (0-255)
            "bg_color", "0x010101",  ; 背景颜色（用于TransColor，保持透明）
            "bar_bg_color", "0x333333",  ; 进度条背景颜色
            "bar_color", "0xFFFFFF",  ; 进度条前景颜色（白色）
            "skill_text_color", "0xFFFFFF",  ; 技能名称文字颜色（白色）
            "time_text_color", "0xFFFF00"  ; 倒计时文字颜色（黄色）
        )
    }
    
    ; 加载配置
    Load() {
        try {
            ; 检查配置文件是否存在
            if (!FileExist(this.configFile)) {
                g_Logger.Info("配置文件不存在，创建默认配置")
                return this.CreateDefaultConfig()
            }
            
            ; 读取配置文件
            g_Logger.Debug("正在读取配置文件: " this.configFile)
            content := FileRead(this.configFile)
            g_Logger.Debug("文件读取成功，准备解析 JSON")
            
            this.config := JSON.Parse(content)
            g_Logger.Debug("JSON 解析成功")
            
            ; 合并默认配置（添加新增的配置项）
            this.MergeWithDefaults()
            g_Logger.Debug("配置合并完成")
            
            g_Logger.Info("配置加载成功")
            return true
            
        } catch as err {
            g_Logger.Error("加载配置失败: " err.Message " (位置: " err.Line ")")
            g_Logger.Debug("错误详情 What: " err.What)
            g_Logger.Debug("错误详情 File: " err.File)
            g_Logger.Debug("错误堆栈:`n" err.Stack)
            ; 不要覆盖用户的配置文件！备份后再创建
            if (FileExist(this.configFile)) {
                backupFile := this.configFile ".backup"
                try {
                    if (FileExist(backupFile)) {
                        FileDelete(backupFile)
                    }
                    FileCopy(this.configFile, backupFile, true)
                    g_Logger.Info("已备份损坏的配置文件到: " backupFile)
                } catch {
                    g_Logger.Error("备份配置文件失败")
                }
            }
            return this.CreateDefaultConfig()
        }
    }
    
    ; 创建默认配置
    CreateDefaultConfig() {
        try {
            ; 确保目录存在
            configDir := ""
            SplitPath(this.configFile, , &configDir)
            
            if (configDir && !DirExist(configDir)) {
                DirCreate(configDir)
            }
            
            ; 复制默认配置
            this.config := this.DeepCopy(this.defaultConfig)
            
            ; 保存到文件
            this.Save()
            
            g_Logger.Info("已创建默认配置文件")
            return true
            
        } catch as err {
            g_Logger.Error("创建默认配置失败: " err.Message)
            return false
        }
    }
    
    ; 合并默认配置（添加缺失的配置项）
    MergeWithDefaults() {
        for key, value in this.defaultConfig {
            if (!this.config.Has(key)) {
                this.config[key] := this.DeepCopy(value)
            } else if (Type(value) = "Map") {
                ; 递归合并子配置
                this.MergeMapWithDefaults(this.config[key], value)
            }
        }
    }
    
    ; 递归合并 Map
    MergeMapWithDefaults(target, source) {
        for key, value in source {
            if (!target.Has(key)) {
                target[key] := this.DeepCopy(value)
            } else if (Type(value) = "Map" && Type(target[key]) = "Map") {
                this.MergeMapWithDefaults(target[key], value)
            }
        }
    }
    
    ; 深拷贝
    DeepCopy(obj) {
        if (Type(obj) = "Map") {
            newMap := Map()
            for key, value in obj {
                newMap[key] := this.DeepCopy(value)
            }
            return newMap
        } else if (Type(obj) = "Array") {
            newArray := []
            for value in obj {
                newArray.Push(this.DeepCopy(value))
            }
            return newArray
        } else {
            return obj
        }
    }
    
    ; 保存配置
    Save() {
        try {
            ; 生成 JSON
            jsonText := JSON.Stringify(this.config, "  ")
            
            ; 删除旧文件
            if (FileExist(this.configFile)) {
                FileDelete(this.configFile)
            }
            
            ; 写入新文件
            FileAppend(jsonText, this.configFile, "UTF-8")
            
            g_Logger.Info("配置保存成功")
            return true
            
        } catch as err {
            g_Logger.Error("保存配置失败: " err.Message)
            return false
        }
    }
    
    ; 获取配置值
    Get(key, defaultValue := "") {
        if (this.config.Has(key)) {
            return this.config[key]
        }
        return defaultValue
    }
    
    ; 设置配置值
    Set(key, value) {
        this.config[key] := value
    }
    
    ; 获取嵌套配置值
    GetNested(keys*) {
        current := this.config
        
        for key in keys {
            if (Type(current) = "Map" && current.Has(key)) {
                current := current[key]
            } else {
                return ""
            }
        }
        
        return current
    }
    
    ; 设置嵌套配置值
    SetNested(keys, value) {
        ; 确保 keys 是数组
        if (Type(keys) != "Array") {
            g_Logger.Error("SetNested: keys 必须是数组，实际类型: " Type(keys))
            return false
        }
        
        keysLen := keys.Length
        if (keysLen = 0) {
            return false
        }
        
        current := this.config
        
        ; 导航到倒数第二级
        if (keysLen > 1) {
            loop (keysLen - 1) {
                key := keys[A_Index]
                
                if (!current.Has(key)) {
                    current[key] := Map()
                }
                
                if (Type(current[key]) != "Map") {
                    current[key] := Map()
                }
                
                current := current[key]
            }
        }
        
        ; 设置最后一级
        lastKey := keys[keysLen]
        current[lastKey] := value
        
        return true
    }
    
    ; 重置为默认配置
    Reset() {
        this.config := this.DeepCopy(this.defaultConfig)
        this.Save()
        g_Logger.Info("配置已重置为默认值")
    }
    
    ; 导出配置
    Export(filePath) {
        try {
            jsonText := JSON.Stringify(this.config, "  ")
            
            if (FileExist(filePath)) {
                FileDelete(filePath)
            }
            
            FileAppend(jsonText, filePath, "UTF-8")
            
            g_Logger.Info("配置已导出: " filePath)
            return true
            
        } catch as err {
            g_Logger.Error("导出配置失败: " err.Message)
            return false
        }
    }
    
    ; 导入配置
    Import(filePath) {
        try {
            if (!FileExist(filePath)) {
                g_Logger.Error("配置文件不存在: " filePath)
                return false
            }
            
            content := FileRead(filePath)
            this.config := JSON.Parse(content)
            
            ; 合并默认配置
            this.MergeWithDefaults()
            
            ; 保存
            this.Save()
            
            g_Logger.Info("配置已导入: " filePath)
            return true
            
        } catch as err {
            g_Logger.Error("导入配置失败: " err.Message)
            return false
        }
    }
}

