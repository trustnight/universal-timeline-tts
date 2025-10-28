; ===================================================
; OCR 监控模块
; 持续监控指定区域，触发相应的播报
; ===================================================

#Include ..\lib\json.ahk
#Include ocr_engine.ahk

class OCRMonitor {
    ocrEngine := ""
    ttsEngine := ""
    configManager := ""
    
    running := false
    timerFunc := ""
    
    ; 配置
    regions := Map()
    triggers := []
    positions := Map()  ; 站位配置：技能名 -> 站位
    checkInterval := 500  ; 检查间隔（毫秒，默认500ms = 0.5秒）
    
    ; 触发历史（防止重复触发）
    triggerHistory := Map()
    defaultCooldown := 5000  ; 默认冷却时间（毫秒，5秒）
    
    ; 初始化
    __New(ocrEngine, ttsEngine, configManager) {
        this.ocrEngine := ocrEngine
        this.ttsEngine := ttsEngine
        this.configManager := configManager
        this.timerFunc := ObjBindMethod(this, "Update")
    }
    
    ; 加载配置文件
    LoadConfig(configFile) {
        try {
            if (!FileExist(configFile)) {
                OutputDebug("❌ 配置文件不存在: " configFile)
                return false
            }
            
            content := FileRead(configFile)
            config := JSON.Parse(content)
            
            ; 加载 OCR 区域
            if (config.Has("regions")) {
                this.regions := config["regions"]
                OutputDebug("✅ 加载了 " this.regions.Count " 个 OCR 区域")
            }
            
            ; 加载检查间隔（支持秒或毫秒）
            if (config.Has("check_interval")) {
                interval := config["check_interval"]
                ; 如果小于 100，假设单位是秒，否则是毫秒
                if (interval < 100) {
                    this.checkInterval := Integer(interval * 1000)
                    OutputDebug("✅ 检查间隔: " interval " 秒 (" this.checkInterval " ms)")
                } else {
                    this.checkInterval := Integer(interval)
                    OutputDebug("✅ 检查间隔: " this.checkInterval " ms")
                }
            } else {
                OutputDebug("✅ 使用默认检查间隔: " this.checkInterval " ms")
            }
            
            return true
            
        } catch as err {
            OutputDebug("❌ 加载配置失败: " err.Message)
            return false
        }
    }
    
    ; 加载副本规则
    LoadDungeonRules(dungeonFile) {
        try {
            if (!FileExist(dungeonFile)) {
                OutputDebug("❌ 副本规则文件不存在: " dungeonFile)
                return false
            }
            
            content := FileRead(dungeonFile)
            rules := JSON.Parse(content)
            
            ; 加载 OCR 触发器（按区域分类）
            this.triggers := Map()
            
            ; 优先从新格式（独立字段）加载
            hasNewFormat := false
            if (rules.Has("boss_dialogue") || rules.Has("boss_hp") || rules.Has("boss_skill")) {
                if (rules.Has("boss_dialogue")) {
                    this.triggers["boss_dialogue"] := rules["boss_dialogue"]
                }
                if (rules.Has("boss_hp")) {
                    this.triggers["boss_hp"] := rules["boss_hp"]
                }
                if (rules.Has("boss_skill")) {
                    this.triggers["boss_skill"] := rules["boss_skill"]
                }
                
                totalCount := 0
                for regionName, regionTriggers in this.triggers {
                    totalCount += regionTriggers.Count
                }
                OutputDebug("✅ 加载了 " this.triggers.Count " 个区域，共 " totalCount " 个 OCR 触发器（新格式）")
                hasNewFormat := true
            }
            
            ; 兼容旧格式（ocr_triggers 对象）
            if (!hasNewFormat && rules.Has("ocr_triggers")) {
                rawTriggers := rules["ocr_triggers"]
                
                ; 检查是新格式还是旧格式
                if (Type(rawTriggers) = "Map") {
                    ; 检查第一个键值对
                    isNewFormat := false
                    for key, value in rawTriggers {
                        ; 新格式：值是Map（区域名: {关键字: 播报}）
                        ; 旧格式：值是String（关键字: 播报）
                        if (Type(value) = "Map") {
                            isNewFormat := true
                        }
                        break
                    }
                    
                    if (isNewFormat) {
                        ; 新格式：按区域分类
                        this.triggers := rawTriggers
                        totalCount := 0
                        for regionName, regionTriggers in this.triggers {
                            totalCount += regionTriggers.Count
                        }
                        OutputDebug("✅ 加载了 " this.triggers.Count " 个区域，共 " totalCount " 个 OCR 触发器（旧格式-区域分类）")
                    } else {
                        ; 旧格式：全局触发器，转换为新格式
                        this.triggers := Map("_global", rawTriggers)
                        OutputDebug("✅ 加载了 " rawTriggers.Count " 个全局 OCR 触发器（旧格式-全局）")
                    }
                }
            }
            
            ; 加载站位配置
            if (rules.Has("positions")) {
                this.positions := rules["positions"]
                OutputDebug("✅ 加载了 " this.positions.Count " 个站位配置")
            } else {
                this.positions := Map()
                OutputDebug("⚠️ 未找到站位配置")
            }
            
            return true
            
        } catch as err {
            OutputDebug("❌ 加载副本规则失败: " err.Message)
            return false
        }
    }
    
    ; 启动监控
    Start() {
        if (this.running) {
            OutputDebug("⚠️ OCR 监控已在运行")
            return false
        }
        
        if (!this.ocrEngine.initialized) {
            OutputDebug("❌ OCR 引擎未初始化")
            return false
        }
        
        this.running := true
        SetTimer(this.timerFunc, this.checkInterval)
        
        OutputDebug("✅ OCR 监控已启动")
        return true
    }
    
    ; 停止监控
    Stop() {
        if (!this.running) {
            return false
        }
        
        this.running := false
        SetTimer(this.timerFunc, 0)
        
        OutputDebug("✅ OCR 监控已停止")
        return true
    }
    
    ; 更新循环
    Update() {
        if (!this.running) {
            return
        }
        
        try {
            startTime := A_TickCount
            regionCount := 0
            
            ; 检查所有已配置的 OCR 区域
            for regionName, regionConfig in this.regions {
                ; 检查区域是否启用
                if (regionConfig.Has("enabled") && !regionConfig["enabled"]) {
                    continue
                }
                
                ; 获取区域坐标
                if (!regionConfig.Has("x1") || !regionConfig.Has("y1") || 
                    !regionConfig.Has("x2") || !regionConfig.Has("y2")) {
                    continue
                }
                
                regionCount++
                x1 := Integer(regionConfig["x1"])
                y1 := Integer(regionConfig["y1"])
                x2 := Integer(regionConfig["x2"])
                y2 := Integer(regionConfig["y2"])
                
                ; OCR 识别该区域
                ocrText := this.ocrEngine.GetTextOnly(x1, y1, x2, y2)
                
                if (ocrText != "") {
                    OutputDebug("🔍 [" regionName "] OCR: " ocrText)
                    ; 检查是否匹配任何触发器
                    this.CheckTriggersAgainstText(ocrText, regionName)
                }
            }
            
            ; 性能监控
            elapsedTime := A_TickCount - startTime
            global g_Logger
            if (elapsedTime > 500) {
                OutputDebug("⚠️ OCR 检测耗时: " elapsedTime "ms (扫描了 " regionCount " 个区域)")
                if (g_Logger) {
                    g_Logger.Warning("OCR 检测较慢: " elapsedTime "ms")
                }
            } else if (regionCount > 0) {
                OutputDebug("⏱️ OCR 检测: " elapsedTime "ms (" regionCount " 区域)")
            }
        } catch as err {
            OutputDebug("❌ 监控循环错误: " err.Message)
        }
    }
    
    ; 检查文本是否匹配触发器
    CheckTriggersAgainstText(ocrText, regionName) {
        ; 获取当前区域的触发器
        triggersToCheck := Map()
        
        ; 从副本规则中查找该区域的触发器
        if (this.triggers.Has(regionName)) {
            triggersToCheck := this.triggers[regionName]
        } else if (this.triggers.Has("_global")) {
            ; 兼容旧格式的全局触发器
            triggersToCheck := this.triggers["_global"]
        }
        
        if (triggersToCheck.Count = 0) {
            return
        }
        
        ; 检查触发器
        for keyword, triggerData in triggersToCheck {
            ; 支持两种格式：
            ; 1. 旧格式：关键字 → "播报内容"
            ; 2. 新格式：关键字 → {tts: "播报内容", cooldown: 30}
            ttsTemplate := ""
            cooldownMs := this.defaultCooldown
            
            if (Type(triggerData) = "String") {
                ; 旧格式：直接是字符串
                ttsTemplate := triggerData
            } else if (Type(triggerData) = "Map") {
                ; 新格式：包含 tts、cooldown 和 target
                if (triggerData.Has("tts")) {
                    ttsTemplate := triggerData["tts"]
                }
                if (triggerData.Has("cooldown")) {
                    cooldownMs := Integer(triggerData["cooldown"]) * 1000  ; 秒转毫秒
                }
                
                ; 目标过滤
                if (triggerData.Has("target")) {
                    triggerTarget := triggerData["target"]
                    
                    ; 如果目标是"忽略"，跳过此触发器
                    if (triggerTarget = "忽略") {
                        global g_Logger
                        g_Logger.Debug("⏭️ 跳过OCR触发（目标为忽略）: [" keyword "]")
                        continue
                    }
                    
                    if (triggerTarget != "全部") {
                        ; 获取当前玩家队伍和职能
                        playerParty := this.configManager.GetNested("player", "party")
                        if (playerParty = "") {
                            playerParty := "all"
                        }
                        playerRole := this.configManager.GetNested("player", "role")
                        if (playerRole = "") {
                            playerRole := "all"
                        }
                        
                        ; 转换为显示格式
                        currentParty := playerParty = "1" ? "1队" : playerParty = "2" ? "2队" : ""
                        currentRole := playerRole = "all" ? "" : StrUpper(playerRole)
                        
                        ; 检查是否为取反模式（以 ~ 开头）
                        isNegation := SubStr(triggerTarget, 1, 1) = "~"
                        actualTarget := isNegation ? SubStr(triggerTarget, 2) : triggerTarget
                        
                        ; 检查是否匹配队伍、职能或职称组
                        isMatch := false
                        if (actualTarget = currentParty || actualTarget = currentRole) {
                            isMatch := true
                        } else if (actualTarget = "T" && (currentRole = "MT" || currentRole = "ST")) {
                            ; T = 坦克组
                            isMatch := true
                        } else if (actualTarget = "D" && (currentRole = "D1" || currentRole = "D2" || currentRole = "D3" || currentRole = "D4")) {
                            ; D = 输出组
                            isMatch := true
                        } else if (actualTarget = "H" && (currentRole = "H1" || currentRole = "H2")) {
                            ; H = 奶妈组
                            isMatch := true
                        }
                        
                        ; 如果是取反模式，反转匹配结果
                        if (isNegation) {
                            isMatch := !isMatch
                        }
                        
                        if (!isMatch) {
                            global g_Logger
                            g_Logger.Debug("⏭️ 跳过OCR触发（目标不匹配）: [" keyword "] 需要:[" triggerTarget "] 当前:[" currentParty "/" currentRole "]")
                            continue
                        }
                    }
                }
            }
            
            if (!ttsTemplate) {
                continue
            }
            
            ; 检查文本中是否包含关键字（去掉#数字后缀）
            actualKeyword := InStr(keyword, "#") ? SubStr(keyword, 1, InStr(keyword, "#") - 1) : keyword
            if (InStr(ocrText, actualKeyword)) {
                ; 检查冷却时间（使用区域名+实际关键字作为ID，去掉#后缀以共享冷却）
                triggerID := regionName "_" actualKeyword
                if (this.triggerHistory.Has(triggerID)) {
                    lastTime := this.triggerHistory[triggerID]
                    elapsedTime := A_TickCount - lastTime
                    if (elapsedTime < cooldownMs) {
                        remainingCd := Round((cooldownMs - elapsedTime) / 1000, 1)
                        OutputDebug("⏳ [" regionName "] 关键字 [" keyword "] 冷却中 (剩余 " remainingCd "s)")
                        continue  ; 还在冷却中
                    }
                }
                
                ; 记录触发时间
                this.triggerHistory[triggerID] := A_TickCount
                
                ; 替换模板变量
                ttsText := ttsTemplate
                
                ; 替换 {position}、{position1}、{position2} 等占位符
                ; 获取当前玩家的队伍和职能（转换为目标格式）
                playerParty := this.configManager.GetNested("player", "party")
                if (playerParty = "") {
                    playerParty := "all"
                }
                playerRole := this.configManager.GetNested("player", "role")
                if (playerRole = "") {
                    playerRole := "all"
                }
                currentParty := playerParty = "1" ? "1队" : playerParty = "2" ? "2队" : ""
                currentRole := playerRole = "all" ? "" : StrUpper(playerRole)
                
                ; 调试输出（同时输出到日志文件）
                global g_Logger
                g_Logger.Debug("🔍 [站位查找] 关键字: " keyword " -> 实际关键字: " actualKeyword)
                g_Logger.Debug("   玩家配置: party=" playerParty ", role=" playerRole)
                g_Logger.Debug("   转换后: currentParty=" currentParty ", currentRole=" currentRole)
                g_Logger.Debug("   positions总数: " this.positions.Count)
                
                ; 查找匹配的站位配置
                posData := ""
                
                ; 遍历所有站位配置（包括 "技能名" 和 "技能名#2" 等）
                for key, data in this.positions {
                    ; 提取技能名（去掉可能的 #数字 后缀）
                    keySkillName := InStr(key, "#") ? SubStr(key, 1, InStr(key, "#") - 1) : key
                    
                    g_Logger.Debug("   遍历key: [" key "] -> skillName: [" keySkillName "]")
                    
                    ; 使用 actualKeyword 匹配（去掉触发器的#后缀）
                    if (keySkillName != actualKeyword) {
                        g_Logger.Debug("     → 跳过（技能名不匹配）")
                        continue
                    }
                    
                    ; 调试输出：找到了匹配的技能名
                    g_Logger.Debug("   ✓ 找到匹配技能: [" key "] | dataType: " Type(data))
                    
                    ; 检查是否是旧格式（String）
                    if (Type(data) = "String") {
                        ; 旧格式：直接是站位字符串，所有人都能用
                        g_Logger.Debug("     → 旧格式，直接使用: " data)
                        posData := data
                        break
                    }
                    
                    ; 新格式：检查target是否匹配
                    if (Type(data) = "Map") {
                        target := data.Get("target", "全部")
                        position := data.Get("position", "")
                        g_Logger.Debug("     → target=[" target "] position=[" position "]")
                        g_Logger.Debug("     → 比较: target=[" target "] vs currentParty=[" currentParty "] vs currentRole=[" currentRole "]")
                        
                        ; 判断target是否匹配
                        if (target = "全部") {
                            ; 全部：所有人都能用
                            g_Logger.Debug("     ✅ 匹配成功：全部")
                            posData := data
                            break
                        } else if (target = currentParty) {
                            ; 匹配队伍（如"1队"）
                            g_Logger.Debug("     ✅ 匹配成功：队伍 " target " = " currentParty)
                            posData := data
                            break
                        } else if (target = currentRole) {
                            ; 匹配职能（如"MT"）
                            g_Logger.Debug("     ✅ 匹配成功：职能 " target " = " currentRole)
                            posData := data
                            break
                        } else {
                            g_Logger.Debug("     ❌ 不匹配：继续查找")
                        }
                    } else {
                        g_Logger.Debug("     ⚠️ 未知格式: " Type(data))
                    }
                }
                
                if (posData = "") {
                    g_Logger.Debug("  ⚠️ 未找到匹配的站位配置")
                } else {
                    g_Logger.Debug("  ✅ 最终选择的站位数据: " (Type(posData) = "String" ? posData : posData.Get("position", "")))
                }
                
                if (posData != "") {
                    ; 支持新旧两种格式
                    if (Type(posData) = "String") {
                        ; 旧格式：直接是站位字符串
                        positionValue := posData
                    } else if (Type(posData) = "Map") {
                        ; 新格式：包含position和target
                        positionValue := posData.Has("position") ? posData["position"] : ""
                    } else {
                        positionValue := ""
                    }
                    
                    if (positionValue = "") {
                        ; 如果没有站位值，移除所有占位符
                        ttsText := StrReplace(ttsText, "{position}", "")
                        Loop 9 {
                            ttsText := StrReplace(ttsText, "{position" A_Index "}", "")
                        }
                    } else {
                    
                    ; 分割站位（支持空格或逗号分隔）
                    positions := []
                    parts := StrSplit(positionValue, ",")
                    for part in parts {
                        trimmedPart := Trim(part)
                        if (InStr(trimmedPart, " ")) {
                            ; 如果包含空格，再按空格分割
                            subParts := StrSplit(trimmedPart, " ")
                            for subPart in subParts {
                                trimmed := Trim(subPart)
                                if (trimmed != "") {
                                    positions.Push(trimmed)
                                }
                            }
                        } else if (trimmedPart != "") {
                            positions.Push(trimmedPart)
                        }
                    }
                    
                    ; 替换 {position1}, {position2}, ... {position9}
                    Loop 9 {
                        placeholder := "{position" A_Index "}"
                        if (InStr(ttsText, placeholder)) {
                            if (positions.Length >= A_Index) {
                                ttsText := StrReplace(ttsText, placeholder, positions[A_Index])
                            } else {
                                ttsText := StrReplace(ttsText, placeholder, "")
                            }
                        }
                    }
                    
                    ; 替换 {position}（使用第一个站位）
                        if (InStr(ttsText, "{position}")) {
                            if (positions.Length > 0) {
                                ttsText := StrReplace(ttsText, "{position}", positions[1])
                                OutputDebug("  💡 使用站位配置: [" keyword "] → " positions[1])
                            } else {
                                ttsText := StrReplace(ttsText, "{position}", "")
                            }
                        }
                    }
                } else {
                    ; 如果没有配置，移除所有占位符
                    if (InStr(ttsText, "{position}")) {
                        ttsText := StrReplace(ttsText, "{position}", "")
                        Loop 9 {
                            ttsText := StrReplace(ttsText, "{position" A_Index "}", "")
                        }
                        OutputDebug("  ⚠️ 未找到站位配置 [" keyword "]，已移除占位符")
                    }
                }
                
                ; 优先播报（打断TTS轴播报）
                ; OCR 触发的是紧急播报，应该立即播放
                this.ttsEngine.SpeakWithPriority(ttsText)
                
                ; 记录日志
                global g_Logger
                cdInfo := cooldownMs != this.defaultCooldown ? " (CD: " Round(cooldownMs/1000) "s)" : ""
                OutputDebug("🎯 [" regionName "] 匹配关键字: " keyword " → " ttsText cdInfo)
                if (g_Logger) {
                    g_Logger.Info("OCR触发: [" keyword "] → " ttsText cdInfo)
                }
                
                ; 找到匹配就退出，避免重复触发
                break
            }
        }
    }

    
    ; 清除触发历史
    ClearHistory() {
        this.triggerHistory := Map()
    }
}

