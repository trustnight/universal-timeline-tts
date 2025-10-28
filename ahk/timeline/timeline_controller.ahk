; ===================================================
; TTS轴控制器
; 根据副本规则文件控制TTS轴播报
; ===================================================

#Include ..\lib\json.ahk
#Include ..\gui\timeline_overlay.ahk

class TimelineController {
    tts := ""
    configManager := ""
    overlay := ""  ; 倒计时悬浮窗
    running := false
    startTime := 0
    timeline := []  ; 完整TTS轴（用于TTS播报）
    overlayTimeline := []  ; 倒计时条显示TTS轴（如果未配置，fallback到timeline）
    positions := Map()  ; 当前副本的站位配置（技能名 -> 站位）
    playerParty := "all"  ; 当前玩家队伍（all、1、2）
    playerRole := "all"  ; 当前玩家职业（all、MT、H1、D1、D2、ST、H2、D3、D4）
    currentIndex := 0
    timelineDone := false  ; TTS轴播报是否完成
    timerFunc := ""
    
    __New(ttsEngine, configManager := "") {
        this.tts := ttsEngine
        this.configManager := configManager
        this.timerFunc := ObjBindMethod(this, "Update")
        
        ; 创建悬浮窗
        if (configManager) {
            this.overlay := TimelineOverlay(configManager)
            
            ; 读取队伍和职业配置
            if (configManager.config.Has("player")) {
                player := configManager.config["player"]
                if (player.Has("party")) {
                    this.playerParty := player["party"]
                }
                if (player.Has("role")) {
                    this.playerRole := player["role"]
                }
            }
        }
    }
    
    ; 设置玩家目标（队伍+职业）
    SetPlayerTarget(party, role) {
        this.playerParty := party
        this.playerRole := role
        OutputDebug("✅ 目标已设置为: 队伍=" party " 职业=" role)
    }
    
    ; 启动TTS轴
    Start(dungeonFile) {
        if (this.running) {
            OutputDebug("⚠️ TTS轴已在运行")
            return false
        }
        
        ; 加载副本规则
        if (!this.LoadDungeon(dungeonFile)) {
            return false
        }
        
        ; 重置状态
        this.running := true
        this.startTime := A_TickCount
        this.currentIndex := 0
        this.timelineDone := false  ; 重置播报完成标记
        this.lastOverlayHash := ""  ; 清空哈希缓存，确保首次显示
        
        ; 启动更新定时器（500ms = 每秒2次，足够流畅且不闪烁）
        SetTimer(this.timerFunc, 500)
        
        OutputDebug("✅ TTS轴已启动")
        
        ; 显示倒计时悬浮窗（如果启用）
        if (this.overlay && this.configManager) {
            showOverlay := this.configManager.GetNested("monitor", "show_timeline_overlay")
            if (showOverlay) {
                this.overlay.Show()
            }
        }
        
        return true
    }
    
    ; 停止TTS轴
    Stop() {
        if (!this.running) {
            return false
        }
        
        this.running := false
        this.timelineDone := false  ; 重置标记
        SetTimer(this.timerFunc, 0)
        this.lastOverlayHash := ""  ; 清空哈希缓存
        
        OutputDebug("✅ TTS轴已停止")
        
        ; 隐藏倒计时悬浮窗
        if (this.overlay) {
            this.overlay.Hide()
        }
        
        return true
    }
    
    ; 检查是否运行中
    IsRunning() {
        return this.running
    }
    
    ; 加载副本规则
    LoadDungeon(dungeonFile) {
        try {
            ; 读取文件
            if (!FileExist(dungeonFile)) {
                MsgBox("❌ 副本文件不存在: " dungeonFile, "错误")
                return false
            }
            
            content := FileRead(dungeonFile)
            
            ; 解析 JSON
            rules := JSON.Parse(content)
            
            ; 加载TTS轴
            if (rules.Has("timeline")) {
                this.timeline := rules["timeline"]
                OutputDebug("✅ 副本规则已加载，共 " this.timeline.Length " 个事件")
            } else {
                this.timeline := []
                OutputDebug("⚠️ 副本规则中没有TTS轴数据")
            }
            
            ; 加载倒计时条TTS轴（如果有则用，没有则fallback到timeline）
            if (rules.Has("overlay_timeline") && rules["overlay_timeline"].Length > 0) {
                this.overlayTimeline := rules["overlay_timeline"]
                OutputDebug("✅ 倒计时条配置已加载，共 " this.overlayTimeline.Length " 个技能")
            } else {
                ; 如果没有配置overlay_timeline，使用timeline
                this.overlayTimeline := this.timeline
                OutputDebug("ℹ️ 倒计时条未单独配置，使用完整TTS轴")
            }
            
            ; 加载站位配置（如果有）
            if (rules.Has("positions")) {
                this.positions := rules["positions"]
                OutputDebug("✅ 站位配置已加载，共 " this.positions.Count " 个技能")
            } else {
                this.positions := Map()
                OutputDebug("ℹ️ 未配置站位信息")
            }
            
            return true
            
        } catch as err {
            MsgBox("❌ 加载副本规则失败: " err.Message, "错误")
            return false
        }
    }
    
    ; 更新TTS轴
    Update() {
        if (!this.running) {
            return
        }
        
        ; 计算当前时间（秒）
        currentTime := (A_TickCount - this.startTime) / 1000
        
        ; 检查是否有需要触发的事件（TTS轴播报）
        if (!this.timelineDone) {
            while (this.currentIndex < this.timeline.Length) {
                event := this.timeline[this.currentIndex + 1]
                
                if (!event.Has("time")) {
                    this.currentIndex++
                    continue
                }
                
                eventTime := event["time"]
                
                if (currentTime >= eventTime) {
                    ; 触发事件
                    this.TriggerEvent(event)
                    this.currentIndex++
                } else {
                    break
                }
            }
            
            ; 检查TTS轴播报是否完成
            if (this.currentIndex >= this.timeline.Length) {
                this.timelineDone := true
                OutputDebug("✅ TTS轴播报已完成，倒计时条继续运行")
            }
        }
        
        ; 【独立】更新悬浮窗显示（不受TTS轴播报影响）
        ; 悬浮窗会一直显示，直到用户手动停止
        this.UpdateOverlay(currentTime)
        
        ; 不再自动停止！让用户手动控制所有模块
        ; TTS轴、OCR、倒计时条都是独立的，只有用户主动停止才会结束
    }
    
    ; 更新悬浮窗显示（显示未来3个技能）
    ; 返回值：是否还有未完成的倒计时事件
    UpdateOverlay(currentTime) {
        if (!this.overlay) {
            return false
        }
        
        ; 使用倒计时条TTS轴（overlayTimeline）而不是完整TTS轴
        if (!this.overlayTimeline || this.overlayTimeline.Length = 0) {
            this.overlay.ShowWaiting()
            return false
        }
        
        ; 收集所有未来的事件（时间 > currentTime）
        upcomingEvents := []
        
        for event in this.overlayTimeline {
            if (!event.Has("time") || !event.Has("skill_name")) {
                continue
            }
            
            eventTime := event["time"]
            skillName := event["skill_name"]
            remainingSeconds := Round(eventTime - currentTime)
            
            ; 只收集剩余时间 > 0 的事件
            if (remainingSeconds > 0) {
                upcomingEvents.Push(Map(
                    "skillName", skillName,
                    "remainingSeconds", remainingSeconds,
                    "totalSeconds", eventTime,
                    "eventTime", eventTime  ; 用于排序
                ))
            }
        }
        
        ; 如果没有未来事件，显示完成状态并返回 false
        if (upcomingEvents.Length = 0) {
            this.overlay.ShowWaiting("✅ 倒计时已完成")
            return false
        }
        
        ; 按时间排序（从近到远）
        upcomingEvents := this.SortEventsByTime(upcomingEvents)
        
        ; 只取前3个
        displayEvents := []
        maxDisplay := Min(3, upcomingEvents.Length)
        Loop maxDisplay {
            displayEvents.Push(upcomingEvents[A_Index])
        }
        
        ; ⚠️ 防闪烁优化：生成当前状态的哈希，只在变化时才更新
        currentHash := ""
        for event in displayEvents {
            currentHash .= event["skillName"] . ":" . event["remainingSeconds"] . "|"
        }
        
        ; 如果和上次一样，跳过更新（但仍返回 true 表示有事件）
        if (this.HasOwnProp("lastOverlayHash") && this.lastOverlayHash = currentHash) {
            return true
        }
        this.lastOverlayHash := currentHash
        
        ; 更新悬浮窗
        this.overlay.UpdateMultiple(displayEvents)
        
        ; 返回 true 表示还有未完成的倒计时事件
        return true
    }
    
    ; 按时间排序事件（冒泡排序，从近到远）
    SortEventsByTime(events) {
        if (events.Length <= 1) {
            return events
        }
        
        ; 简单的冒泡排序
        n := events.Length
        Loop n - 1 {
            i := A_Index
            Loop n - i {
                j := A_Index
                if (events[j]["eventTime"] > events[j + 1]["eventTime"]) {
                    ; 交换
                    temp := events[j]
                    events[j] := events[j + 1]
                    events[j + 1] := temp
                }
            }
        }
        
        return events
    }
    
    ; 触发事件
    TriggerEvent(event) {
        if (!event.Has("tts_template")) {
            return
        }
        
        ; 目标过滤：检查事件target是否匹配当前玩家设置
        if (event.Has("target")) {
            eventTarget := event["target"]
            
            ; 如果目标是"忽略"，直接跳过此事件
            if (eventTarget = "忽略") {
                skillName := event.Has("skill_name") ? event["skill_name"] : "未知"
                global g_Logger
                g_Logger.Debug("⏭️ 跳过事件（目标为忽略）: " skillName)
                return
            }
            
            ; 新格式：直接比较（如 "1队", "2队", "MT", "H1" 等）
            ; 支持取反：~MT 表示除了MT之外都播报
            if (eventTarget != "全部") {
                ; 转换玩家队伍和职能为显示格式
                currentParty := this.playerParty = "1" ? "1队" : this.playerParty = "2" ? "2队" : ""
                currentRole := this.playerRole = "all" ? "" : StrUpper(this.playerRole)
                
                ; 检查是否为取反模式（以 ~ 开头）
                isNegation := SubStr(eventTarget, 1, 1) = "~"
                actualTarget := isNegation ? SubStr(eventTarget, 2) : eventTarget
                
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
                    skillName := event.Has("skill_name") ? event["skill_name"] : "未知"
                    global g_Logger
                    g_Logger.Debug("⏭️ 跳过事件（目标不匹配）: " skillName " - 需要:[" eventTarget "] 当前:[" currentParty "/" currentRole "]")
                    return
                }
            }
        }
        
        ; 获取技能名称（用于占位符替换）
        skillName := event.Has("skill_name") ? event["skill_name"] : ""
        
        ttsText := event["tts_template"]
        
        ; 替换模板变量（传入技能名称，用于 {position} 占位符替换）
        ttsText := this.ReplaceVariables(ttsText, skillName)
        
        ; 异步播报（不阻塞TTS轴）
        this.tts.Speak(ttsText, false)
        
        ; 输出日志
        OutputDebug("🎯 TTS轴事件: " (skillName != "" ? skillName : "未知技能") " - " ttsText)
    }
    
    ; 替换模板中的变量
    ReplaceVariables(text, skillName := "") {
        ; 替换 {position}、{position1}、{position2} 等占位符
        ; 从当前副本的站位配置中查找对应的站位
        posData := ""
        positionValue := ""
        
        if (skillName != "" && this.positions) {
            ; 获取当前玩家的队伍和职能
            currentParty := this.playerParty = "1" ? "1队" : this.playerParty = "2" ? "2队" : ""
            currentRole := this.playerRole = "all" ? "" : StrUpper(this.playerRole)
            
            ; 调试输出
            global g_Logger
            g_Logger.Debug("🔍 [TTS轴-站位查找] 技能: " skillName)
            g_Logger.Debug("   玩家配置: party=" this.playerParty ", role=" this.playerRole)
            g_Logger.Debug("   转换后: currentParty=" currentParty ", currentRole=" currentRole)
            
            ; 遍历所有站位配置，查找匹配的
            for key, data in this.positions {
                ; 提取技能名（去掉可能的 #数字 后缀）
                keySkillName := InStr(key, "#") ? SubStr(key, 1, InStr(key, "#") - 1) : key
                
                if (keySkillName != skillName) {
                    continue
                }
                
                g_Logger.Debug("   ✓ 找到匹配技能: [" key "]")
                
                ; 检查是否是旧格式（String）
                if (Type(data) = "String") {
                    ; 旧格式：直接是站位字符串，所有人都能用
                    g_Logger.Debug("     → 旧格式，直接使用: " data)
                    posData := data
                    positionValue := data
                    break
                }
                
                ; 新格式：检查target是否匹配
                if (Type(data) = "Map") {
                    target := data.Get("target", "全部")
                    position := data.Get("position", "")
                    g_Logger.Debug("     → target=[" target "] position=[" position "]")
                    
                    ; 如果目标是"忽略"，跳过此配置
                    if (target = "忽略") {
                        g_Logger.Debug("     ⏭️ 跳过（目标为忽略）")
                        continue
                    }
                    
                    ; 判断target是否匹配（支持取反）
                    if (target = "全部") {
                        g_Logger.Debug("     ✅ 匹配成功：全部")
                        posData := data
                        positionValue := position
                        break
                    } else {
                        ; 检查是否为取反模式（以 ~ 开头）
                        isNegation := SubStr(target, 1, 1) = "~"
                        actualTarget := isNegation ? SubStr(target, 2) : target
                        
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
                        
                        if (isMatch) {
                            g_Logger.Debug("     ✅ 匹配成功：" target (isNegation ? " (取反)" : ""))
                            posData := data
                            positionValue := position
                            break
                        } else {
                            g_Logger.Debug("     ❌ 不匹配：继续查找")
                        }
                    }
                }
            }
            
            if (posData = "") {
                g_Logger.Debug("  ⚠️ 未找到匹配的站位配置")
            } else {
                g_Logger.Debug("  ✅ 最终选择的站位: " positionValue)
            }
            
            if (positionValue = "") {
                ; 如果没有站位值，移除所有占位符
                text := StrReplace(text, "{position}", "")
                Loop 9 {
                    text := StrReplace(text, "{position" A_Index "}", "")
                }
                return text
            }
            
            ; 分割站位（支持空格或逗号分隔）
            positions := []
            ; 先用逗号分割，再用空格分割
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
            
            ; 替换 {position}（使用完整站位字符串）
            if (InStr(text, "{position}")) {
                text := StrReplace(text, "{position}", positionValue)
            }
            
            ; 替换 {position1}, {position2}, ... {position9}（使用分割后的各个部分）
            Loop 9 {
                placeholder := "{position" A_Index "}"
                if (InStr(text, placeholder)) {
                    if (positions.Length >= A_Index) {
                        text := StrReplace(text, placeholder, positions[A_Index])
                    } else {
                        text := StrReplace(text, placeholder, "")
                    }
                }
            }
        } else {
            ; 如果没有配置该技能的站位，移除所有占位符
            text := StrReplace(text, "{position}", "")
            Loop 9 {
                text := StrReplace(text, "{position" A_Index "}", "")
            }
        }
        
        return text
    }
}

