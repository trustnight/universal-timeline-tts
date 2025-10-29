; ===================================================
; DBM 播报系统 - AHK v2 主入口
; 纯 AHK v2 实现，包括 GUI、OCR、TTS、TTS轴控制
; ===================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent  ; 保持脚本运行

; 设置工作目录
SetWorkingDir A_ScriptDir

; 包含核心模块
#Include ahk\lib\json.ahk
#Include ahk\lib\logger.ahk
#Include ahk\lib\config_manager.ahk
#Include ahk\tools\region_selector.ahk
#Include ahk\tts\tts_engine.ahk
#Include ahk\timeline\timeline_controller.ahk
#Include ahk\ocr\ocr_engine.ahk
#Include ahk\ocr\ocr_monitor.ahk
#Include ahk\gui\main_window.ahk

; ===================================================
; 全局变量
; ===================================================

global g_Logger := ""
global g_ConfigManager := ""
global g_TTS := ""
global g_Timeline := ""
global g_OCR := ""
global g_OCRMonitor := ""
global g_MainWindow := ""
global g_CurrentDungeon := ""

; ===================================================
; 应用程序类
; ===================================================

class DBMApp {
    logger := ""
    configManager := ""
    tts := ""
    timeline := ""
    ocr := ""
    ocrMonitor := ""
    mainWindow := ""
    
    ; 自动启动功能
    autoStartTimer := ""
    autoStartEnabled := false
    autoStartTriggered := false
    
    ; 初始化
    Init() {
        ; 初始化日志系统（最先初始化）
        this.logger := Logger("logs")
        global g_Logger := this.logger
        
        this.logger.Info("🚀 DBM 播报系统启动中...")
        
        ; 初始化配置管理器
        this.configManager := ConfigManager("config\app_config.json")
        global g_ConfigManager := this.configManager
        
        ; 加载配置（会自动生成默认配置）
        this.configManager.Load()
        
        ; 设置 DEBUG 模式
        debugMode := this.configManager.GetNested("logging", "debug_mode")
        if (debugMode) {
            this.logger.SetDebugMode(true)
            this.logger.Debug("DEBUG 模式已启用")
        }
        
        ; 创建主窗口
        this.mainWindow := MainWindow()
        
        ; 设置日志控件
        this.logger.SetGuiControl(this.mainWindow.GetLogControl())
    
    ; 初始化 TTS
        this.logger.Info("初始化 TTS 引擎...")
        this.tts := TTSEngine()
        if (!this.tts.Init()) {
            this.logger.Error("TTS 引擎初始化失败")
        MsgBox("❌ TTS 引擎初始化失败", "错误")
        ExitApp
    }
        
        ; 应用 TTS 配置
        ttsRate := this.configManager.GetNested("tts", "rate")
        ttsVolume := this.configManager.GetNested("tts", "volume")
        if (ttsRate != "") {
            this.tts.SetRate(Integer(ttsRate))
        }
        if (ttsVolume != "") {
            this.tts.SetVolume(Integer(ttsVolume))
        }
        
        this.logger.Info("TTS 引擎初始化完成")
    
    ; 初始化TTS轴控制器
        this.logger.Info("初始化TTS轴控制器...")
        this.timeline := TimelineController(this.tts, this.configManager)
        
        ; 初始化 OCR
        this.logger.Info("初始化 OCR 引擎...")
        this.ocr := OCREngine()
        if (!this.ocr.Init()) {
            this.logger.Error("OCR 引擎初始化失败")
            MsgBox("⚠️ OCR 引擎初始化失败`n某些功能可能不可用", "警告")
        } else {
            this.logger.Info("OCR 引擎初始化完成")
        }
        
        ; 初始化 OCR 监控器
        this.logger.Info("初始化 OCR 监控器...")
        this.ocrMonitor := OCRMonitor(this.ocr, this.tts, this.configManager)
        
        ; 设置回调
        this.SetupCallbacks()
        
        ; 加载配置到界面
        this.mainWindow.LoadConfig(this.configManager.config)
        
        ; 加载TTS语音列表
        this.LoadTtsVoices()
        
        ; 加载自动启动配置
        this.UpdateAutoStartStatus()
        
        ; 恢复自动启动勾选状态
        enabled := this.configManager.GetNested("auto_start", "enabled")
        if (enabled) {
            this.mainWindow.autoStartCheck.Value := 1
            this.StartAutoStartDetection()
        }
        
        ; 加载副本列表
        this.RefreshDungeons()
        
        ; 加载 OCR 区域
        this.LoadOcrRegions()
        
        this.logger.Info("✅ DBM 播报系统初始化完成")
        
        ; 显示启动提示
        this.mainWindow.UpdateStatusBar("就绪 - 按 F12 显示/隐藏窗口")
    }
    
    ; 设置回调
    SetupCallbacks() {
        ; 配置页面回调
        this.mainWindow.SetCallback("OnSaveConfig", ObjBindMethod(this, "OnSaveConfig"))
        this.mainWindow.SetCallback("OnTestTts", ObjBindMethod(this, "OnTestTts"))
        this.mainWindow.SetCallback("OnTtsRateChange", ObjBindMethod(this, "OnTtsRateChange"))
        this.mainWindow.SetCallback("OnTtsVolumeChange", ObjBindMethod(this, "OnTtsVolumeChange"))
        this.mainWindow.SetCallback("OnTtsVoiceChange", ObjBindMethod(this, "OnTtsVoiceChange"))
        this.mainWindow.SetCallback("OnRefreshVoices", ObjBindMethod(this, "OnRefreshVoices"))
        
        ; 监控页面回调（合并后的）
        this.mainWindow.SetCallback("OnRefreshDungeons", ObjBindMethod(this, "OnRefreshDungeons"))
        this.mainWindow.SetCallback("OnDungeonChange", ObjBindMethod(this, "OnDungeonChange"))
        this.mainWindow.SetCallback("OnNewDungeon", ObjBindMethod(this, "OnNewDungeon"))
        this.mainWindow.SetCallback("OnEditDungeon", ObjBindMethod(this, "OnEditDungeon"))
        this.mainWindow.SetCallback("OnDeleteDungeon", ObjBindMethod(this, "OnDeleteDungeon"))
        this.mainWindow.SetCallback("OnMonitorOptionChange", ObjBindMethod(this, "OnMonitorOptionChange"))
        this.mainWindow.SetCallback("OnRoleChange", ObjBindMethod(this, "OnRoleChange"))
        this.mainWindow.SetCallback("OnStartMonitor", ObjBindMethod(this, "OnStartMonitor"))
        this.mainWindow.SetCallback("OnStopMonitor", ObjBindMethod(this, "OnStopMonitor"))
        this.mainWindow.SetCallback("OnSetOverlayPosition", ObjBindMethod(this, "OnSetOverlayPosition"))
        this.mainWindow.SetCallback("OnReloadOcrConfig", ObjBindMethod(this, "OnReloadOcrConfig"))
        this.mainWindow.SetCallback("OnSelectRegion", ObjBindMethod(this, "OnSelectRegion"))
        this.mainWindow.SetCallback("OnTestOcrRegion", ObjBindMethod(this, "OnTestOcrRegion"))
        this.mainWindow.SetCallback("OnDeleteOcrRegion", ObjBindMethod(this, "OnDeleteOcrRegion"))
        
        ; 日志页面回调
        this.mainWindow.SetCallback("OnClearLog", ObjBindMethod(this, "OnClearLog"))
        this.mainWindow.SetCallback("OnExportLog", ObjBindMethod(this, "OnExportLog"))
        this.mainWindow.SetCallback("OnRefreshLog", ObjBindMethod(this, "OnRefreshLog"))
        
        ; DEBUG 模式回调
        this.mainWindow.SetCallback("OnDebugModeChange", ObjBindMethod(this, "OnDebugModeChange"))
        
        ; OCR 间隔改变回调
        this.mainWindow.SetCallback("OnOcrIntervalChange", ObjBindMethod(this, "OnOcrIntervalChange"))
        
        ; 热键配置回调
        this.mainWindow.SetCallback("OnSaveHotkeys", ObjBindMethod(this, "OnSaveHotkeys"))
        this.mainWindow.SetCallback("OnResetHotkeys", ObjBindMethod(this, "OnResetHotkeys"))
        
        ; 队伍和职业选择回调
        this.mainWindow.SetCallback("OnPartyChange", ObjBindMethod(this, "OnPartyChange"))
    }
    
    ; 监控选项改变时自动保存
    OnMonitorOptionChange() {
        ; 只保存 monitor 部分配置
        this.configManager.SetNested(["monitor", "enable_timeline"], this.mainWindow.enableTimelineCheck.Value)
        this.configManager.SetNested(["monitor", "enable_ocr"], this.mainWindow.enableOcrCheck.Value)
        this.configManager.SetNested(["monitor", "show_timeline_overlay"], this.mainWindow.showOverlayCheck.Value)
        
        ; 保存到文件
        if (this.configManager.Save()) {
            this.logger.Debug("监控选项已自动保存: TTS轴=" this.mainWindow.enableTimelineCheck.Value " OCR=" this.mainWindow.enableOcrCheck.Value " 倒计时=" this.mainWindow.showOverlayCheck.Value)
        }
    }
    
    ; 职能选择改变时自动保存
    OnPartyChange() {
        ; 解析队伍
        partyText := this.mainWindow.partyCombo.Text
        partyValue := "all"
        if (partyText = "1队") {
            partyValue := "1"
        } else if (partyText = "2队") {
            partyValue := "2"
        }
        
        ; 保存到配置
        this.configManager.SetNested(["player", "party"], partyValue)
        if (this.configManager.Save()) {
            this.logger.Debug("队伍已自动保存: " partyValue)
        }
        
        ; 通知TTS轴控制器更新队伍和职业
        if (this.timeline) {
            roleValue := this.GetCurrentRoleValue()
            this.timeline.SetPlayerTarget(partyValue, roleValue)
        }
    }
    
    OnRoleChange() {
        ; 解析职业
        roleText := this.mainWindow.roleCombo.Text
        roleValue := "all"
        if (roleText = "MT" || roleText = "H1" || roleText = "D1" || roleText = "D2" || roleText = "ST" || roleText = "H2" || roleText = "D3" || roleText = "D4") {
            roleValue := roleText
        }
        
        ; 保存到配置
        this.configManager.SetNested(["player", "role"], roleValue)
        if (this.configManager.Save()) {
            this.logger.Debug("职业已自动保存: " roleValue)
        }
        
        ; 通知TTS轴控制器更新队伍和职业
        if (this.timeline) {
            partyValue := this.GetCurrentPartyValue()
            this.timeline.SetPlayerTarget(partyValue, roleValue)
        }
    }
    
    ; 副本切换时自动保存
    OnDungeonChange(dungeonFile) {
        ; 保存到配置
        this.configManager.SetNested(["monitor", "current_dungeon"], dungeonFile)
        if (this.configManager.Save()) {
            this.logger.Debug("副本已自动保存: " dungeonFile)
        }
    }
    
    ; 获取当前队伍值
    GetCurrentPartyValue() {
        partyText := this.mainWindow.partyCombo.Text
        if (partyText = "1队") {
            return "1"
        } else if (partyText = "2队") {
            return "2"
        }
        return "all"
    }
    
    ; 获取当前职业值
    GetCurrentRoleValue() {
        roleText := this.mainWindow.roleCombo.Text
        if (roleText = "MT" || roleText = "H1" || roleText = "D1" || roleText = "D2" || roleText = "ST" || roleText = "H2" || roleText = "D3" || roleText = "D4") {
            return roleText
        }
        return "all"
    }
    
    ; 保存配置回调
    OnSaveConfig() {
        this.logger.Info("保存配置...")
        
        ; 从 GUI 获取所有配置值
        guiConfig := this.mainWindow.GetConfigValues()
        
        ; 逐个字段合并，而不是覆盖整个对象
        for key, value in guiConfig {
            if (Type(value) = "Map") {
                ; 如果是 Map，逐个字段合并
                for subKey, subValue in value {
                    this.configManager.SetNested([key, subKey], subValue)
                }
            } else {
                this.configManager.Set(key, value)
            }
        }
        
        ; 保存到文件
        if (this.configManager.Save()) {
            this.logger.Info("配置已保存")
            this.mainWindow.ShowMessage("保存成功", "配置已保存", "Success")
            this.mainWindow.UpdateStatusBar("配置已保存")
        } else {
            this.logger.Error("配置保存失败")
            this.mainWindow.ShowMessage("保存失败", "配置保存失败", "Error")
        }
    }
    
    ; 测试 TTS 回调
    OnTestTts() {
        text := "TTS 播报测试"
        this.tts.Speak(text, false)  ; 异步播报
        this.mainWindow.UpdateStatusBar("测试 TTS: " text)
    }
    
    ; TTS 语速改变回调
    OnTtsRateChange(value) {
        this.tts.SetRate(value)
        this.configManager.SetNested(["tts", "rate"], value)
        this.configManager.Save()  ; 自动保存
        this.logger.Debug("TTS 语速已更改: " value)
    }
    
    ; TTS 音量改变回调
    OnTtsVolumeChange(value) {
        this.tts.SetVolume(value)
        this.configManager.SetNested(["tts", "volume"], value)
        this.configManager.Save()  ; 自动保存
        this.logger.Debug("TTS 音量已更改: " value)
    }
    
    ; TTS 语音改变回调
    OnTtsVoiceChange(voiceName) {
        this.logger.Debug("切换TTS语音: " voiceName)
        if (this.tts.SetVoiceByName(voiceName)) {
            this.logger.Info("TTS语音已切换: " voiceName)
            this.configManager.SetNested(["tts", "voice"], voiceName)
            this.configManager.Save()
        } else {
            this.logger.Error("切换TTS语音失败: " voiceName)
        }
    }
    
    ; 刷新语音列表回调
    OnRefreshVoices() {
        this.logger.Info("刷新TTS语音列表")
        this.LoadTtsVoices()
    }
    
    ; 加载TTS语音列表
    LoadTtsVoices() {
        try {
            voices := this.tts.GetAvailableVoices()
            
            if (voices.Length = 0) {
                this.logger.Error("未找到任何TTS语音")
                this.mainWindow.ttsVoiceCombo.Delete()
                this.mainWindow.ttsVoiceCombo.Add(["未找到语音"])
                this.mainWindow.ttsVoiceCombo.Choose(1)
                return
            }
            
            ; 清空并重新填充下拉框
            this.mainWindow.ttsVoiceCombo.Delete()
            voiceNames := []
            for voice in voices {
                voiceNames.Push(voice["name"])
            }
            this.mainWindow.ttsVoiceCombo.Add(voiceNames)
            
            ; 从配置加载选中的语音
            savedVoice := this.configManager.GetNested("tts", "voice")
            currentVoice := this.tts.GetCurrentVoiceName()
            
            ; 查找匹配的语音索引
            selectedIndex := 1
            if (savedVoice != "") {
                for index, voiceName in voiceNames {
                    if (InStr(voiceName, savedVoice) || voiceName = savedVoice) {
                        selectedIndex := index
                        break
                    }
                }
            } else if (currentVoice != "") {
                ; 如果没有保存的语音，使用当前语音
                for index, voiceName in voiceNames {
                    if (voiceName = currentVoice) {
                        selectedIndex := index
                        break
                    }
                }
            }
            
            this.mainWindow.ttsVoiceCombo.Choose(selectedIndex)
            this.logger.Info("已加载 " voices.Length " 个TTS语音")
            
        } catch as err {
            this.logger.Error("加载TTS语音列表失败: " err.Message)
        }
    }
    
    ; 刷新副本列表回调
    OnRefreshDungeons() {
        this.RefreshDungeons()
        this.mainWindow.UpdateStatusBar("副本列表已刷新")
    }
    
    ; 刷新副本列表
    RefreshDungeons() {
        dungeons := []
        
        try {
            if (DirExist("dungeon_rules")) {
                loop files "dungeon_rules\*.json" {
                    dungeons.Push(A_LoopFileName)
                }
            }
        } catch as err {
            OutputDebug("❌ 刷新副本列表失败: " err.Message)
        }
        
        this.mainWindow.UpdateDungeonList(dungeons)
        
        ; 恢复之前选择的副本
        savedDungeon := this.configManager.GetNested("monitor", "current_dungeon")
        if (savedDungeon != "") {
            ; 查找副本在列表中的索引
            for index, dungeon in dungeons {
                if (dungeon = savedDungeon) {
                    this.mainWindow.dungeonCombo.Choose(index)
                    this.logger.Debug("已恢复副本选择: " savedDungeon)
                    break
                }
            }
        }
        
        return dungeons  ; 返回副本列表
    }
    
    ; 启动统一监控回调
    OnStartMonitor(dungeonFile, enableTimeline, enableOcr) {
        ; 检查是否至少启用了一个监控
        if (!enableTimeline && !enableOcr) {
            this.logger.Error("未选择任何监控选项")
            this.mainWindow.ShowMessage("提示", "请至少勾选一个监控选项（TTS轴或OCR）", "Warning")
            
            ; 确保按钮状态正确
            this.mainWindow.startMonitorBtn.Enabled := true
            this.mainWindow.stopMonitorBtn.Enabled := false
            return
        }
        
        ; 检查副本文件
        if (dungeonFile = "") {
            this.logger.Error("未选择副本")
            this.mainWindow.ShowMessage("错误", "请选择副本", "Warning")
            
            ; 确保按钮状态正确
            this.mainWindow.startMonitorBtn.Enabled := true
            this.mainWindow.stopMonitorBtn.Enabled := false
            return
        }
        
        dungeonPath := "dungeon_rules\" dungeonFile
        global g_CurrentDungeon := dungeonFile
        
        statusMsg := ""
        timelineStarted := false
        ocrStarted := false
        
        ; 启动TTS轴（如果勾选）
        if (enableTimeline) {
            if (!this.timeline.running) {
                this.logger.Info("启动TTS轴: " dungeonFile)
        if (this.timeline.Start(dungeonPath)) {
                    this.logger.Info("TTS轴已启动")
                    statusMsg .= "✓ TTS轴播报已启动`n"
                    timelineStarted := true
                } else {
                    this.logger.Error("TTS轴启动失败")
                    statusMsg .= "✗ TTS轴播报启动失败`n"
                }
            } else {
                statusMsg .= "✓ TTS轴播报已在运行`n"
                timelineStarted := true
            }
        }
        
        ; 启动OCR（如果勾选）
        if (enableOcr) {
            if (!this.ocrMonitor.running) {
                this.logger.Info("启动 OCR 监控...")
                
                ; 加载配置
                if (!this.ocrMonitor.LoadConfig("config\ocr_regions.json")) {
                    this.logger.Error("加载 OCR 配置失败")
                    statusMsg .= "✗ OCR 监控启动失败（配置加载失败）`n"
                } else {
                    ; 加载副本规则
                    this.ocrMonitor.LoadDungeonRules(dungeonPath)
                    
                    ; 启动监控
                    if (this.ocrMonitor.Start()) {
                        this.logger.Info("OCR 监控已启动")
                        statusMsg .= "✓ OCR 监控已启动`n"
                        ocrStarted := true
                    } else {
                        this.logger.Error("OCR 监控启动失败")
                        statusMsg .= "✗ OCR 监控启动失败`n"
                    }
                }
            } else {
                statusMsg .= "✓ OCR 监控已在运行`n"
                ocrStarted := true
            }
        }
        
        ; 更新状态显示
        if (statusMsg != "") {
            statusMsg .= "`n"
        }
        statusMsg .= "副本: " dungeonFile
        statusMsg .= "`n启动时间: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        this.mainWindow.UpdateMonitorStatus(statusMsg)
            
            ; 更新按钮状态
        if (timelineStarted || ocrStarted) {
            this.mainWindow.startMonitorBtn.Enabled := false
            this.mainWindow.stopMonitorBtn.Enabled := true
            this.mainWindow.UpdateStatusBar("DBM 已启动")
            
            ; 语音提示（异步，不阻塞）
            if (this.tts) {
                this.tts.Speak("DBM 已启动", false)
            }
        } else {
            this.mainWindow.ShowMessage("错误", "监控启动失败", "Error")
            
            ; 确保按钮状态正确
            this.mainWindow.startMonitorBtn.Enabled := true
            this.mainWindow.stopMonitorBtn.Enabled := false
        }
    }
    
    ; 停止统一监控回调
    OnStopMonitor() {
        ; 检查是否有监控在运行
        if (!this.timeline.running && !this.ocrMonitor.running) {
            this.logger.Info("监控未运行，忽略停止操作")
            this.mainWindow.ShowMessage("提示", "监控未运行", "Info")
            
            ; 确保按钮状态正确
            this.mainWindow.startMonitorBtn.Enabled := true
            this.mainWindow.stopMonitorBtn.Enabled := false
            return
        }
        
        this.logger.Info("停止监控")
        
        statusMsg := "停止监控...`n`n"
        
        ; 停止TTS轴
        if (this.timeline.running) {
        if (this.timeline.Stop()) {
            this.logger.Info("TTS轴已停止")
                statusMsg .= "✓ TTS轴播报已停止`n"
            }
        }
        
        ; 停止OCR
        if (this.ocrMonitor.running) {
            if (this.ocrMonitor.Stop()) {
                this.logger.Info("OCR 监控已停止")
                statusMsg .= "✓ OCR 监控已停止`n"
            }
        }
        
        ; 重置自动启动的单次触发状态并重新开始检测
        if (this.autoStartTriggered && this.mainWindow.autoStartCheck.Value) {
            this.autoStartTriggered := false
            this.logger.Info("🔄 自动启动已重置，重新开始颜色检测")
            this.UpdateAutoStartStatus()
            this.StartAutoStartDetection()
        }
        
        statusMsg .= "`n停止时间: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        this.mainWindow.UpdateMonitorStatus(statusMsg)
        this.mainWindow.UpdateStatusBar("DBM 已停止")
            
            ; 恢复按钮状态
        this.mainWindow.startMonitorBtn.Enabled := true
        this.mainWindow.stopMonitorBtn.Enabled := false
        
        ; 不再语音播报停止信息
    }
    
    ; 设置倒计时条位置
    OnSetOverlayPosition() {
        if (!this.timeline.overlay) {
            this.mainWindow.ShowMessage("错误", "倒计时窗口未初始化", "Error")
            return
        }
        
        this.logger.Info("进入倒计时条位置设置模式")
        
        ; 进入预览模式
        this.timeline.overlay.EnterPreviewMode()
        
        ; 提示用户
        MsgBox("📍 倒计时条设置`n`n" .
               "• 拖动：点击窗口任意位置拖动`n" .
               "• 大小：拖动窗口右下角调整大小`n" .
               "• 透明度：右键 → 设置透明度`n" .
               "• 颜色：右键 → 设置颜色（下拉选择+预设）`n" .
               "• 完成：右键 → 完成设置（自动保存）", 
               "提示", "Icon!")
    }
    
    ; 重新加载 OCR 配置回调
    OnReloadOcrConfig() {
        this.logger.Info("重新加载 OCR 配置")
        this.LoadOcrRegions()
        this.mainWindow.UpdateStatusBar("OCR 配置已重新加载")
    }
    
    ; 测试OCR区域回调
    OnTestOcrRegion(selectedRow) {
        try {
            ; 获取选中的区域信息
            regionName := this.mainWindow.ocrRegionList.GetText(selectedRow, 1)
            x1 := Integer(this.mainWindow.ocrRegionList.GetText(selectedRow, 2))
            y1 := Integer(this.mainWindow.ocrRegionList.GetText(selectedRow, 3))
            x2 := Integer(this.mainWindow.ocrRegionList.GetText(selectedRow, 4))
            y2 := Integer(this.mainWindow.ocrRegionList.GetText(selectedRow, 5))
            
            this.logger.Info("测试OCR区域: " regionName)
            
            ; 检查OCR引擎是否已初始化
            if (!this.ocr.initialized) {
                this.logger.Error("OCR 引擎未初始化")
                this.mainWindow.ShowMessage("错误", "OCR 引擎未初始化", "Error")
            return
        }
        
            ; 创建测试文件夹
            testDir := "ocr_test"
            if (!DirExist(testDir)) {
                DirCreate(testDir)
            }
            
            ; 执行OCR识别
            this.mainWindow.UpdateStatusBar("正在识别区域: " regionName "...")
            
            ; 先截图保存（用于调试）
            ; 每个区域类型只保存一个截图文件，覆盖旧文件
            screenshotPath := A_WorkingDir "\" testDir "\" regionName ".bmp"
            screenshotSaved := false
            
            try {
                this.ocr.SaveScreenshot(x1, y1, x2, y2, screenshotPath)
                if (FileExist(screenshotPath)) {
                    screenshotSaved := true
                    this.logger.Info("测试截图已保存: " screenshotPath)
                }
            } catch as err {
                this.logger.Error("保存测试截图失败: " err.Message)
            }
            
            ; 执行OCR识别
            ocrText := this.ocr.GetTextOnly(x1, y1, x2, y2)
            
            if (ocrText = "") {
                ocrText := "(未识别到任何文字)"
            }
            
            ; 显示识别结果
            resultMsg := "区域: " regionName "`n"
            resultMsg .= "坐标: (" x1 ", " y1 ") - (" x2 ", " y2 ")`n"
            if (screenshotSaved && FileExist(screenshotPath)) {
                resultMsg .= "截图: " screenshotPath " ✓`n"
            } else {
                resultMsg .= "截图: 保存失败`n"
            }
            resultMsg .= "─────────────────────────`n"
            resultMsg .= "识别结果:`n" ocrText
            
            MsgBox(resultMsg, "OCR 测试结果", "Iconi")
            
            this.logger.Info("OCR测试结果: " ocrText)
            this.mainWindow.UpdateStatusBar("OCR测试完成，截图已保存")
            
        } catch as err {
            this.logger.Error("测试OCR区域失败: " err.Message)
            this.mainWindow.ShowMessage("错误", "测试OCR区域失败: " err.Message, "Error")
        }
    }
    
    ; 删除OCR区域回调
    OnDeleteOcrRegion(selectedRow) {
        try {
            ; 获取选中的区域信息
            regionName := this.mainWindow.ocrRegionList.GetText(selectedRow, 1)
            
            ; 确认删除
            result := MsgBox("确定要删除区域 `"" regionName "`" 吗？", "确认删除", "YesNo Icon?")
            
            if (result = "No") {
        return
    }
    
            this.logger.Info("删除OCR区域: " regionName)
            
            ; 从配置文件中删除
            configFile := "config\ocr_regions.json"
            
            if (!FileExist(configFile)) {
                this.mainWindow.ShowMessage("错误", "配置文件不存在", "Error")
                return
            }
            
            content := FileRead(configFile)
            config := JSON.Parse(content)
            
            if (!config.Has("regions")) {
                this.mainWindow.ShowMessage("错误", "配置格式错误", "Error")
                return
            }
            
            ; 查找并删除该区域（通过显示名称匹配）
            regionKey := ""
            for key, regionConfig in config["regions"] {
                if (regionConfig.Has("name") && regionConfig["name"] = regionName) {
                    regionKey := key
                    break
                }
            }
            
            if (regionKey = "") {
                this.mainWindow.ShowMessage("错误", "未找到该区域", "Error")
                return
            }
            
            ; 删除区域
            config["regions"].Delete(regionKey)
            
            ; 保存文件
            jsonText := JSON.Stringify(config, "  ")
            
            ; 确保config文件夹存在
            if (!DirExist("config")) {
                DirCreate("config")
            }
            
            if (FileExist(configFile)) {
                FileDelete(configFile)
            }
            
            FileAppend(jsonText, configFile, "UTF-8")
            
            ; 重新加载显示
        this.LoadOcrRegions()
            
            this.logger.Info("OCR区域已删除: " regionName)
            this.mainWindow.ShowMessage("成功", "区域已删除", "Success")
            this.mainWindow.UpdateStatusBar("区域已删除: " regionName)
            
        } catch as err {
            this.logger.Error("删除OCR区域失败: " err.Message)
            this.mainWindow.ShowMessage("错误", "删除失败: " err.Message, "Error")
        }
    }
    
    ; 新建副本回调
    OnNewDungeon() {
        ; 输入副本名称
        ib := InputBox("请输入新副本名称:", "新建副本")
        
        if (ib.Result = "Cancel" || ib.Value = "") {
            return
        }
        
        dungeonName := Trim(ib.Value)
        fileName := dungeonName ".json"
        
        ; 确保dungeon_rules文件夹存在
        if (!DirExist("dungeon_rules")) {
            DirCreate("dungeon_rules")
        }
        
        dungeonPath := "dungeon_rules\" fileName
        
        ; 检查是否已存在
        if (FileExist(dungeonPath)) {
            this.mainWindow.ShowMessage("错误", "该副本已存在", "Error")
            return
        }
        
        ; 创建新副本规则（手动构建JSON以避免Map嵌套序列化问题）
        ; 保存文件
        try {
            ; 手动构建JSON字符串
            jsonText := '{'
            jsonText .= '`n    "dungeon_name": "' dungeonName '",'
            jsonText .= '`n    "description": "新建的副本规则",'
            jsonText .= '`n    "timeline": [],'
            jsonText .= '`n    "overlay_timeline": [],'
            jsonText .= '`n    "positions": {},'
            jsonText .= '`n    "boss_dialogue": {},'
            jsonText .= '`n    "boss_hp": {},'
            jsonText .= '`n    "boss_skill": {}'
            jsonText .= '`n}'
            
            FileAppend(jsonText, dungeonPath, "UTF-8")
            
            this.logger.Info("新建副本: " dungeonName)
            
            ; 刷新副本列表并获取列表
            dungeons := this.RefreshDungeons()
            
            ; 选择新建的副本
            for index, dungeon in dungeons {
                if (dungeon = fileName) {
                    this.mainWindow.dungeonCombo.Choose(index)
                    break
                }
            }
            
            this.mainWindow.ShowMessage("成功", "副本已创建: " dungeonName, "Success")
            
            ; 直接打开编辑器
            this.ShowDungeonRulesEditor(dungeonPath)
            
        } catch as err {
            this.logger.Error("创建副本失败: " err.Message)
            this.mainWindow.ShowMessage("错误", "创建失败: " err.Message, "Error")
        }
    }
    
    ; 编辑副本回调
    OnEditDungeon(dungeonFile) {
        this.logger.Info("编辑副本规则: " dungeonFile)
        
        dungeonPath := "dungeon_rules\" dungeonFile
        
        ; 打开副本规则编辑器
        this.ShowDungeonRulesEditor(dungeonPath)
    }
    
    ; 删除副本回调
    OnDeleteDungeon(dungeonFile) {
        ; 确认删除
        result := MsgBox("确定要删除副本 `"" dungeonFile "`" 吗？`n`n此操作无法撤销！", "确认删除", "YesNo Icon!")
        
        if (result = "No") {
            return
        }
        
        dungeonPath := "dungeon_rules\" dungeonFile
        
        try {
            FileDelete(dungeonPath)
            this.logger.Info("删除副本: " dungeonFile)
            this.mainWindow.ShowMessage("成功", "副本已删除", "Success")
            this.RefreshDungeons()
        } catch as err {
            this.logger.Error("删除副本失败: " err.Message)
            this.mainWindow.ShowMessage("错误", "删除失败: " err.Message, "Error")
        }
    }
    
    ; 显示副本规则编辑器
    ShowDungeonRulesEditor(dungeonPath) {
        ; 加载副本规则
        try {
            if (!FileExist(dungeonPath)) {
                this.mainWindow.ShowMessage("错误", "副本文件不存在", "Error")
                return
            }
            
            content := FileRead(dungeonPath)
            rules := JSON.Parse(content)
            
            ; 获取TTS轴
            timeline := rules.Has("timeline") ? rules["timeline"] : []
            
            ; 获取倒计时条TTS轴
            overlayTimeline := rules.Has("overlay_timeline") ? rules["overlay_timeline"] : []
            
            ; 获取所有区域的触发器（直接从顶级字段读取）
            allTriggers := Map(
                "boss_dialogue", rules.Has("boss_dialogue") ? rules["boss_dialogue"] : Map(),
                "boss_hp", rules.Has("boss_hp") ? rules["boss_hp"] : Map(),
                "boss_skill", rules.Has("boss_skill") ? rules["boss_skill"] : Map()
            )
            
            ; 兼容旧格式（如果存在 ocr_triggers）
            if (rules.Has("ocr_triggers")) {
                for regionKey, regionTriggers in rules["ocr_triggers"] {
                    if (allTriggers.Has(regionKey)) {
                        allTriggers[regionKey] := regionTriggers
                    }
                }
            }
            
            ; 创建编辑窗口
            dungeonName := rules.Has("dungeon_name") ? rules["dungeon_name"] : "未命名"
            editGui := Gui("+Owner" this.mainWindow.gui.Hwnd, "编辑副本规则 - " dungeonName)
            editGui.SetFont("s10", "Microsoft YaHei UI")
            
            ; 副本名称编辑
            editGui.Add("Text", "x20 y15", "副本名称:")
            dungeonNameEdit := editGui.Add("Edit", "x100 y10 w400")
            dungeonNameEdit.Value := dungeonName
            
            editGui.Add("Text", "x520 y15", "说明: 包含TTS轴和OCR触发器")
            
            ; 获取站位配置
            positions := rules.Has("positions") ? rules["positions"] : Map()
            
            ; 创建Tab页签（6个Tab：TTS轴 + 倒计时条 + 3个OCR区域 + 站位配置）
            tabControl := editGui.Add("Tab3", "x20 y45 w960 h520", ["⏱️ TTS轴", "⏰ 倒计时条", "💬 BOSS台词区", "❤️ BOSS血条区", "⚔️ BOSS技能区", "📍 站位配置"])
            
            ; ========== Tab 1: TTS轴 ==========
            tabControl.UseTab("⏱️ TTS轴")
            
            editGui.Add("Text", "x40 y80", "说明: 按照时间顺序播报技能提示")
            
            editGui.Add("Text", "x40 y110", "TTS轴事件列表:")
            timelineList := editGui.Add("ListView", "x40 y135 w900 h320 +LV0x8 +Grid", ["时间", "技能名称", "播报内容", "职能"])
            ; 设置扩展样式：LVS_EX_FULLROWSELECT (0x20) | LVS_EX_GRIDLINES (0x1)
            SendMessage(0x1036, 0, 0x21, timelineList)  ; LVM_SETEXTENDEDLISTVIEWSTYLE
            timelineList.ModifyCol(1, 80)
            timelineList.ModifyCol(2, 150)
            timelineList.ModifyCol(3, 450)
            timelineList.ModifyCol(4, 200)
            
            ; 加载TTS轴（显示为 分:秒 格式）
            for event in timeline {
                timeInSeconds := event.Has("time") ? event["time"] : 0
                timeDisplay := this.FormatTimeDisplay(timeInSeconds)
                target := event.Has("target") ? event["target"] : "全部"
                timelineList.Add("", timeDisplay, 
                                     event.Has("skill_name") ? event["skill_name"] : "",
                                     event.Has("tts_template") ? event["tts_template"] : "",
                                     target)
            }
            
            ; 编辑区域
            editGui.Add("Text", "x40 y470", "时间:")
            timeEdit := editGui.Add("Edit", "x80 y465 w60")
            editGui.Add("Text", "x145 y470", "(如：54 或 2:54)")
            
            editGui.Add("Text", "x280 y470", "技能名称:")
            skillEdit := editGui.Add("Edit", "x355 y465 w130")
            
            editGui.Add("Text", "x500 y470", "播报内容:")
            timeTtsEdit := editGui.Add("Edit", "x570 y465 w150")
            
            editGui.Add("Text", "x730 y470", "目标:")
            targetCombo := editGui.Add("DropDownList", "x770 y465 w80", [
                "全部",
                "1队",
                "2队",
                "T",
                "D",
                "H",
                "MT",
                "H1",
                "D1",
                "D2",
                "ST",
                "H2",
                "D3",
                "D4",
                "忽略"
            ])
            targetCombo.Choose(1)
            targetNegateCheck := editGui.Add("Checkbox", "x855 y467 w60", "取反")
            targetNegateCheck.Value := 0
            
            ; 按钮
            editGui.Add("Button", "x40 y510 w100 h35", "➕ 添加").OnEvent("Click", (*) => this.OnAddTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList))
            editGui.Add("Button", "x150 y510 w100 h35", "⬆️ 插入").OnEvent("Click", (*) => this.OnInsertTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList))
            editGui.Add("Button", "x260 y510 w100 h35", "✏️ 修改").OnEvent("Click", (*) => this.OnUpdateTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList))
            editGui.Add("Button", "x370 y510 w100 h35", "🗑️ 删除").OnEvent("Click", (*) => this.OnDeleteTimelineClick(timelineList))
            editGui.Add("Button", "x480 y510 w140 h35", "📋 从倒计时条复制").OnEvent("Click", (*) => this.OnCopyFromOverlayClick(overlayTimeline, timelineList))
            timelineList.OnEvent("DoubleClick", (*) => this.OnTimelineDoubleClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList))
            
            ; ========== Tab 2: 倒计时条 ==========
            tabControl.UseTab("⏰ 倒计时条")
            
            editGui.Add("Text", "x40 y80", "说明: 配置倒计时悬浮窗显示的技能（留空则显示所有TTS轴技能）")
            
            editGui.Add("Text", "x40 y110", "倒计时条显示技能:")
            overlayList := editGui.Add("ListView", "x40 y135 w900 h320 +LV0x8 +Grid", ["时间", "技能名称"])
            ; 设置扩展样式：LVS_EX_FULLROWSELECT (0x20) | LVS_EX_GRIDLINES (0x1)
            SendMessage(0x1036, 0, 0x21, overlayList)  ; LVM_SETEXTENDEDLISTVIEWSTYLE
            overlayList.ModifyCol(1, 150)
            overlayList.ModifyCol(2, 730)
            
            ; 加载倒计时条TTS轴
            for event in overlayTimeline {
                timeInSeconds := event.Has("time") ? event["time"] : 0
                timeDisplay := this.FormatTimeDisplay(timeInSeconds)
                overlayList.Add("", timeDisplay, 
                                event.Has("skill_name") ? event["skill_name"] : "")
            }
            
            ; 编辑区域
            editGui.Add("Text", "x40 y470", "时间:")
            overlayTimeEdit := editGui.Add("Edit", "x80 y465 w80")
            editGui.Add("Text", "x165 y470", "(如：54 或 2:54)")
            
            editGui.Add("Text", "x310 y470", "技能名称:")
            overlaySkillEdit := editGui.Add("Edit", "x390 y465 w200")
            
            ; 按钮
            editGui.Add("Button", "x40 y510 w100 h35", "➕ 添加").OnEvent("Click", (*) => this.OnAddOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList))
            editGui.Add("Button", "x150 y510 w100 h35", "⬆️ 插入").OnEvent("Click", (*) => this.OnInsertOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList))
            editGui.Add("Button", "x260 y510 w100 h35", "✏️ 修改").OnEvent("Click", (*) => this.OnUpdateOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList))
            editGui.Add("Button", "x370 y510 w100 h35", "🗑️ 删除").OnEvent("Click", (*) => this.OnDeleteOverlayClick(overlayList))
            editGui.Add("Button", "x480 y510 w120 h35", "📋 从TTS轴复制").OnEvent("Click", (*) => this.OnCopyFromTimelineClick(timeline, overlayList))
            overlayList.OnEvent("DoubleClick", (*) => this.OnOverlayDoubleClick(overlayTimeEdit, overlaySkillEdit, overlayList))
            
            ; ========== Tab 3: 站位配置 ==========
            tabControl.UseTab("📍 站位配置")
            
            editGui.Add("Text", "x40 y80", "说明: 配置技能对应的站位，副本规则中使用 {position} 占位符时会自动替换")
            editGui.Add("Text", "x50 y100 c0x666666", "• 支持多个站位（用空格或逗号隔开）: 如 '3点 2点' 或 '3点, 2点'")
            editGui.Add("Text", "x50 y120 c0x666666", "• 在播报内容中使用: 单个站位配置项使用{position}")
            editGui.Add("Text", "x50 y140 c0x666666", "• 在播报内容中使用: {position1} 为第1个, {position2} 为第2个")
            editGui.Add("Text", "x40 y170", "技能站位映射:")
            positionList := editGui.Add("ListView", "x40 y190 w900 h265 +LV0x8 +Grid", ["技能名称", "站位", "职能"])
            ; 设置扩展样式：LVS_EX_FULLROWSELECT (0x20) | LVS_EX_GRIDLINES (0x1)
            SendMessage(0x1036, 0, 0x21, positionList)  ; LVM_SETEXTENDEDLISTVIEWSTYLE
            positionList.ModifyCol(1, 350)
            positionList.ModifyCol(2, 380)
            positionList.ModifyCol(3, 150)
            
            ; 加载站位配置
            if (positions) {
                for key, posData in positions {
                    ; 支持新旧两种格式
                    if (Type(posData) = "String") {
                        ; 旧格式：直接是站位字符串
                        ; 去掉可能的后缀 #数字
                        skillName := InStr(key, "#") ? SubStr(key, 1, InStr(key, "#") - 1) : key
                        positionList.Add("", skillName, posData, "全部")
                    } else if (Type(posData) = "Map") {
                        ; 新格式：包含position和target
                        ; 去掉可能的后缀 #数字
                        skillName := InStr(key, "#") ? SubStr(key, 1, InStr(key, "#") - 1) : key
                        posValue := posData.Has("position") ? posData["position"] : ""
                        target := posData.Has("target") ? posData["target"] : "全部"
                        positionList.Add("", skillName, posValue, target)
                    }
                }
            }
            
            ; 编辑区域
            editGui.Add("Text", "x40 y470", "技能名称:")
            posSkillEdit := editGui.Add("Edit", "x120 y465 w200")
            
            editGui.Add("Text", "x340 y470", "站位:")
            posValueEdit := editGui.Add("Edit", "x380 y465 w180")
            
            editGui.Add("Text", "x580 y470", "目标:")
            posTargetCombo := editGui.Add("DropDownList", "x620 y465 w80", [
                "全部",
                "1队",
                "2队", 
                "T",
                "D",
                "H",
                "MT",
                "H1",
                "D1",
                "D2",
                "ST",
                "H2",
                "D3",
                "D4",
                "忽略"
            ])
            posTargetCombo.Choose(1)
            posNegateCheck := editGui.Add("Checkbox", "x705 y467 w60", "取反")
            posNegateCheck.Value := 0
            
            ; 按钮
            editGui.Add("Button", "x40 y510 w100 h35", "➕ 添加").OnEvent("Click", (*) => this.OnAddPositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList))
            editGui.Add("Button", "x150 y510 w100 h35", "⬆️ 插入").OnEvent("Click", (*) => this.OnInsertPositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList))
            editGui.Add("Button", "x260 y510 w100 h35", "✏️ 修改").OnEvent("Click", (*) => this.OnUpdatePositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList))
            editGui.Add("Button", "x370 y510 w100 h35", "🗑️ 删除").OnEvent("Click", (*) => this.OnDeletePositionClick(positionList))
            positionList.OnEvent("DoubleClick", (*) => this.OnPositionDoubleClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList))
            
            ; ========== Tab 4-6: OCR 触发器 ==========
            triggerLists := Map()
            keywordEdits := Map()
            ttsEdits := Map()
            cdEdits := Map()
            targetCombos := Map()
            
            ; 区域配置
            regions := [
                {key: "boss_dialogue", name: "💬 BOSS台词区", desc: "识别BOSS读条技能"},
                {key: "boss_hp", name: "❤️ BOSS血条区", desc: "识别BOSS血量百分比"},
                {key: "boss_skill", name: "⚔️ BOSS技能区", desc: "识别技能图标文字"}
            ]
            
            ; 为每个区域创建Tab页内容
            for region in regions {
                tabControl.UseTab(region.name)
                
                editGui.Add("Text", "x40 y80", "说明: " region.desc)
                
                ; 触发器列表
                editGui.Add("Text", "x40 y110", "触发器列表:")
                triggerList := editGui.Add("ListView", "x40 y135 w900 h320 +LV0x8 +Grid", ["关键字", "播报内容", "CD(秒)", "职能"])
                ; 设置扩展样式：LVS_EX_FULLROWSELECT (0x20) | LVS_EX_GRIDLINES (0x1)
                SendMessage(0x1036, 0, 0x21, triggerList)  ; LVM_SETEXTENDEDLISTVIEWSTYLE
                triggerList.ModifyCol(1, 200)
                triggerList.ModifyCol(2, 450)
                triggerList.ModifyCol(3, 80)
                triggerList.ModifyCol(4, 150)
                
                ; 加载该区域的触发器
                if (allTriggers.Has(region.key)) {
                    for keyword, triggerData in allTriggers[region.key] {
                        ; 支持两种格式
                        if (Type(triggerData) = "String") {
                            ; 旧格式：直接是字符串
                            triggerList.Add("", keyword, triggerData, "5", "全部")
                        } else if (Type(triggerData) = "Map") {
                            ; 新格式：包含 tts、cooldown 和 target
                            ttsText := triggerData.Has("tts") ? triggerData["tts"] : ""
                            cooldown := triggerData.Has("cooldown") ? triggerData["cooldown"] : 5
                            target := triggerData.Has("target") ? triggerData["target"] : "全部"
                            triggerList.Add("", keyword, ttsText, cooldown, target)
                        }
                    }
                }
                
                ; 编辑区域
                editGui.Add("Text", "x40 y470", "关键字:")
                keywordEdit := editGui.Add("Edit", "x110 y465 w200")
                
                editGui.Add("Text", "x330 y470", "播报内容:")
                ttsEdit := editGui.Add("Edit", "x410 y465 w270")
                
                editGui.Add("Text", "x690 y470", "CD:")
                cdEdit := editGui.Add("Edit", "x720 y465 w40")
                cdEdit.Value := "5"  ; 默认5秒
                
                editGui.Add("Text", "x770 y470", "目标:")
                triggerTargetCombo := editGui.Add("DropDownList", "x810 y465 w80", [
                    "全部",
                    "1队",
                    "2队",
                    "T",
                    "D",
                    "H",
                    "MT",
                    "H1",
                    "D1",
                    "D2",
                    "ST",
                    "H2",
                    "D3",
                    "D4",
                    "忽略"
                ])
                triggerTargetCombo.Choose(1)
                triggerNegateCheck := editGui.Add("Checkbox", "x895 y467 w60", "取反")
                triggerNegateCheck.Value := 0
                
                ; 按钮
                addBtn := editGui.Add("Button", "x40 y510 w100 h35", "➕ 添加")
                insertBtn := editGui.Add("Button", "x150 y510 w100 h35", "⬆️ 插入")
                updateBtn := editGui.Add("Button", "x260 y510 w100 h35", "✏️ 修改")
                deleteBtn := editGui.Add("Button", "x370 y510 w100 h35", "🗑️ 删除")
                
                ; 保存控件引用
                triggerLists[region.key] := triggerList
                keywordEdits[region.key] := keywordEdit
                ttsEdits[region.key] := ttsEdit
                cdEdits[region.key] := cdEdit
                
                ; 保存控件引用
                targetCombos[region.key] := triggerTargetCombo
                
                ; 绑定事件（调用辅助方法创建独立作用域）
                this.BindTriggerEvents(addBtn, insertBtn, updateBtn, deleteBtn, triggerList, keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck)
            }
            
            tabControl.UseTab()
            
            ; 底部全局按钮
            saveBtn := editGui.Add("Button", "x670 y580 w100 h35", "💾 保存全部")
            applyBtn := editGui.Add("Button", "x780 y580 w100 h35", "✅ 应用")
            cancelBtn := editGui.Add("Button", "x890 y580 w100 h35", "❌ 取消")
            
            ; 绑定保存按钮事件（保存并关闭）
            saveBtn.OnEvent("Click", (*) => this.OnSaveAllRulesClick(dungeonNameEdit, timelineList, overlayList, positionList, triggerLists, dungeonPath, editGui))
            
            ; 绑定应用按钮事件（保存但不关闭）
            applyBtn.OnEvent("Click", (*) => this.OnApplyRulesClick(dungeonNameEdit, timelineList, overlayList, positionList, triggerLists, dungeonPath, editGui))
            
            ; 绑定取消按钮事件
            cancelBtn.OnEvent("Click", (*) => editGui.Destroy())
            
            editGui.Show("w1000 h630 Center")
            
        } catch as err {
            this.logger.Error("打开副本规则编辑器失败: " err.Message)
            this.mainWindow.ShowMessage("错误", "打开编辑器失败: " err.Message, "Error")
        }
    }
    
    ; TTS轴编辑器 - 添加按钮
    OnAddTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList) {
        timeInput := timeEdit.Value
        skillName := skillEdit.Value
        ttsText := timeTtsEdit.Value
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (targetNegateCheck.Value) {
            target := "~" . target
        }
        
        if (timeInput = "" || skillName = "" || ttsText = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间（支持 "秒" 或 "分:秒" 格式）
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 添加到列表（显示为 分:秒 格式）
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        timelineList.Add("", timeDisplay, skillName, ttsText, target)
        
        ; 清空输入框
        timeEdit.Value := ""
        skillEdit.Value := ""
        timeTtsEdit.Value := ""
        targetCombo.Choose(1)
    }
    
    ; TTS轴编辑器 - 插入按钮（在选中项前面插入）
    OnInsertTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList) {
        timeInput := timeEdit.Value
        skillName := skillEdit.Value
        ttsText := timeTtsEdit.Value
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (targetNegateCheck.Value) {
            target := "~" . target
        }
        
        if (timeInput = "" || skillName = "" || ttsText = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间（支持 "秒" 或 "分:秒" 格式）
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 获取选中的行
        selectedRow := timelineList.GetNext(0, "Focused")
        
        ; 格式化显示时间
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        
        if (selectedRow = 0) {
            ; 如果没有选中项，添加到末尾
            timelineList.Add("", timeDisplay, skillName, ttsText, target)
            MsgBox("未选择行，已添加到末尾", "提示", "Icon!")
        } else {
            ; 在选中行前面插入
            timelineList.Insert(selectedRow, "", timeDisplay, skillName, ttsText, target)
        }
        
        ; 清空输入框
        timeEdit.Value := ""
        skillEdit.Value := ""
        timeTtsEdit.Value := ""
        targetCombo.Choose(1)
    }
    
    ; TTS轴编辑器 - 修改按钮
    OnUpdateTimelineClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList) {
        ; 检查选中的项数量
        selectedCount := 0
        rowNumber := 0
        firstSelectedRow := 0
        Loop {
            rowNumber := timelineList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            if (firstSelectedRow = 0) {
                firstSelectedRow := rowNumber
            }
            selectedCount++
        }
        
        if (selectedCount = 0) {
            MsgBox("请先选择要修改的项", "提示", "Icon!")
            return
        }
        
        if (selectedCount > 1) {
            MsgBox("一次只能修改一项，请只选择一项", "提示", "Icon!")
            return
        }
        
        timeInput := timeEdit.Value
        skillName := skillEdit.Value
        ttsText := timeTtsEdit.Value
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (targetNegateCheck.Value) {
            target := "~" . target
        }
        
        if (timeInput = "" || skillName = "" || ttsText = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间（支持 "秒" 或 "分:秒" 格式）
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 修改列表项（显示为 分:秒 格式）
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        timelineList.Modify(firstSelectedRow, "", timeDisplay, skillName, ttsText, target)
        
        ; 清空输入框
        timeEdit.Value := ""
        skillEdit.Value := ""
        timeTtsEdit.Value := ""
        targetCombo.Choose(1)
    }
    
    ; TTS轴编辑器 - 删除按钮（支持批量删除）
    OnDeleteTimelineClick(timelineList) {
        ; 收集所有选中的行（从后往前删除，避免索引错乱）
        selectedRows := []
        rowNumber := 0
        Loop {
            rowNumber := timelineList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            selectedRows.Push(rowNumber)
        }
        
        if (selectedRows.Length = 0) {
            MsgBox("请先选择要删除的项", "提示", "Icon!")
            return
        }
        
        ; 从后往前删除（避免索引变化）
        Loop selectedRows.Length {
            timelineList.Delete(selectedRows[selectedRows.Length - A_Index + 1])
        }
    }
    
    ; TTS轴编辑器 - 双击填充编辑框
    OnTimelineDoubleClick(timeEdit, skillEdit, timeTtsEdit, targetCombo, targetNegateCheck, timelineList) {
        selectedRow := timelineList.GetNext(0, "Focused")
        
        if (selectedRow > 0) {
            timeEdit.Value := timelineList.GetText(selectedRow, 1)
            skillEdit.Value := timelineList.GetText(selectedRow, 2)
            timeTtsEdit.Value := timelineList.GetText(selectedRow, 3)
            target := timelineList.GetText(selectedRow, 4)
            
            ; 检查是否为取反模式（以 ~ 开头）
            if (SubStr(target, 1, 1) = "~") {
                targetNegateCheck.Value := 1
                target := SubStr(target, 2)  ; 去掉 ~
            } else {
                targetNegateCheck.Value := 0
            }
            
            ; 直接选择目标
            try {
                targetCombo.Choose(target)
            } catch {
                targetCombo.Choose(1)  ; 如果失败，选择"全部"
            }
        }
    }
    
    ; 解析时间输入（支持多种格式）→ 返回秒数
    ParseTimeInput(timeInput) {
        timeInput := Trim(timeInput)
        
        ; 检查是否包含冒号（分:秒格式）
        if (InStr(timeInput, ":")) {
            parts := StrSplit(timeInput, ":")
            if (parts.Length != 2) {
                return -1  ; 格式错误
            }
            
            minutes := Trim(parts[1])
            seconds := Trim(parts[2])
            
            ; 验证是否都是数字
            if (!IsNumber(minutes) || !IsNumber(seconds)) {
                return -1
            }
            
            ; 转换为总秒数
            totalSeconds := Integer(minutes) * 60 + Integer(seconds)
            return totalSeconds
        }
        ; 纯数字格式（秒）
        else if (IsNumber(timeInput)) {
            return Integer(timeInput)
        }
        
        ; 无法识别的格式
        return -1
    }
    
    ; 格式化时间显示（秒数 → 分:秒格式）
    FormatTimeDisplay(seconds) {
        if (!IsNumber(seconds)) {
            return seconds  ; 如果不是数字，直接返回
        }
        
        totalSeconds := Integer(seconds)
        minutes := totalSeconds // 60
        secs := Mod(totalSeconds, 60)
        
        ; 格式：M:SS（秒数始终两位）
        return minutes ":" Format("{:02}", secs)
    }
    
    ; 将职能代码转换为显示文本
    ; 将目标值（如"1-MT"）转换为显示文本（如"1队-MT"）
    GetTargetDisplay(targetValue) {
        parts := StrSplit(targetValue, "-")
        if (parts.Length != 2) {
            return "全部"
        }
        
        partyPart := parts[1]
        rolePart := parts[2]
        
        partyDisplay := ""
        if (partyPart = "1") {
            partyDisplay := "1队"
        } else if (partyPart = "2") {
            partyDisplay := "2队"
        } else {
            partyDisplay := "全部"
        }
        
        roleDisplay := ""
        if (rolePart = "all") {
            roleDisplay := "全部"
        } else {
            roleDisplay := rolePart
        }
        
        if (partyDisplay = "全部" && roleDisplay = "全部") {
            return "全部"
        } else if (partyDisplay = "全部") {
            return roleDisplay
        } else if (roleDisplay = "全部") {
            return partyDisplay
        } else {
            return partyDisplay "-" roleDisplay
        }
    }
    
    ; 将队伍和职业选择转换为目标值（如"1-MT"）
    GetTargetValue(partyCombo, roleCombo) {
        partyText := partyCombo.Text
        partyValue := "all"
        if (partyText = "1队") {
            partyValue := "1"
        } else if (partyText = "2队") {
            partyValue := "2"
        }
        
        roleText := roleCombo.Text
        roleValue := "all"
        if (roleText = "全部") {
            roleValue := "all"
        } else if (roleText = "MT" || roleText = "H1" || roleText = "D1" || roleText = "D2" || roleText = "ST" || roleText = "H2" || roleText = "D3" || roleText = "D4") {
            roleValue := roleText
        }
        
        return partyValue "-" roleValue
    }
    
    ; 从 ListBox 多选中获取目标组合（返回数组）
    ; ListBox 包含: 全部, 1队, 2队, MT, H1, D1, D2, ST, H2, D3, D4
    GetTargetsFromListBox(listBox) {
        targets := []
        selectedIndexes := []
        
        ; 获取所有选中的索引
        i := 0
        Loop {
            i := listBox.GetNext(i)
            if (i = 0) {
                break
            }
            selectedIndexes.Push(i)
        }
        
        if (selectedIndexes.Length = 0) {
            ; 没有选择，默认为全部
            targets.Push({party: "all", role: "all", display: "全部"})
            return targets
        }
        
        ; 获取选中的文本
        selectedTexts := []
        for idx in selectedIndexes {
            selectedTexts.Push(listBox.GetText(idx))
        }
        
        ; 如果选中了"全部"，忽略其他选择
        if (this.ArrayContains(selectedTexts, "全部")) {
            targets.Push({party: "all", role: "all", display: "全部"})
            return targets
        }
        
        ; 分离队伍和职能
        parties := []
        roles := []
        
        for text in selectedTexts {
            if (text = "1队" || text = "2队") {
                parties.Push(text)
            } else {
                ; MT, H1, D1, D2, ST, H2, D3, D4
                roles.Push(text)
            }
        }
        
        ; 如果没选队伍，默认全部队伍
        if (parties.Length = 0) {
            parties.Push("all")
        }
        
        ; 如果没选职能，默认全部职能
        if (roles.Length = 0) {
            roles.Push("all")
        }
        
        ; 组合所有队伍和职能
        for party in parties {
            for role in roles {
                partyValue := (party = "1队") ? "1" : (party = "2队") ? "2" : "all"
                roleValue := (role = "all") ? "all" : role
                
                ; 构建显示文本
                if (partyValue = "all" && roleValue = "all") {
                    display := "全部"
                } else if (partyValue = "all") {
                    display := role
                } else if (roleValue = "all") {
                    display := party
                } else {
                    display := party "-" role
                }
                
                targets.Push({
                    party: partyValue,
                    role: roleValue,
                    display: display
                })
            }
        }
        
        return targets
    }
    
    ; 辅助方法：检查数组是否包含某个值
    ArrayContains(arr, value) {
        for item in arr {
            if (item = value) {
                return true
            }
        }
        return false
    }
    
    ; 将目标显示文本（如"1队-MT"）反向解析为目标值（如"1-MT"）
    ParseTargetDisplay(targetDisplay) {
        if (targetDisplay = "全部") {
            return "all-all"
        }
        
        ; 分解显示文本
        parts := StrSplit(targetDisplay, "-")
        
        partyValue := "all"
        roleValue := "all"
        
        if (parts.Length = 2) {
            ; 格式：1队-MT
            partyPart := Trim(parts[1])
            rolePart := Trim(parts[2])
            
            if (partyPart = "1队") {
                partyValue := "1"
            } else if (partyPart = "2队") {
                partyValue := "2"
            }
            
            if (rolePart = "MT" || rolePart = "H1" || rolePart = "D1" || rolePart = "D2" || rolePart = "ST" || rolePart = "H2" || rolePart = "D3" || rolePart = "D4") {
                roleValue := rolePart
            }
        } else if (parts.Length = 1) {
            ; 单独的队伍或职业
            part := Trim(parts[1])
            if (part = "1队") {
                partyValue := "1"
            } else if (part = "2队") {
                partyValue := "2"
            } else if (part = "MT" || part = "H1" || part = "D1" || part = "D2" || part = "ST" || part = "H2" || part = "D3" || part = "D4") {
                roleValue := part
            }
        }
        
        return partyValue "-" roleValue
    }
    
    ; 根据队伍选择更新职业下拉框选项（用于副本规则编辑器）
    UpdateRoleComboForParty(partyCombo, roleCombo) {
        partyText := partyCombo.Text
        currentRole := roleCombo.Text
        
        if (partyText = "1队") {
            ; 1队：MT、H1、D1、D2
            roleCombo.Delete()
            roleCombo.Add(["全部", "MT", "H1", "D1", "D2"])
            ; 尝试保持选择，如果当前选择不在新列表中，则选择"全部"
            if (currentRole = "全部" || currentRole = "MT" || currentRole = "H1" || currentRole = "D1" || currentRole = "D2") {
                roleMap := Map("全部", 1, "MT", 2, "H1", 3, "D1", 4, "D2", 5)
                if (roleMap.Has(currentRole)) {
                    roleCombo.Choose(roleMap[currentRole])
                } else {
                    roleCombo.Choose(1)
                }
            } else {
                roleCombo.Choose(1)
            }
        } else if (partyText = "2队") {
            ; 2队：ST、H2、D3、D4
            roleCombo.Delete()
            roleCombo.Add(["全部", "ST", "H2", "D3", "D4"])
            ; 尝试保持选择
            if (currentRole = "全部" || currentRole = "ST" || currentRole = "H2" || currentRole = "D3" || currentRole = "D4") {
                roleMap := Map("全部", 1, "ST", 2, "H2", 3, "D3", 4, "D4", 5)
                if (roleMap.Has(currentRole)) {
                    roleCombo.Choose(roleMap[currentRole])
                } else {
                    roleCombo.Choose(1)
                }
            } else {
                roleCombo.Choose(1)
            }
        } else {
            ; 全部：显示所有职业
            roleCombo.Delete()
            roleCombo.Add(["全部", "MT", "H1", "D1", "D2", "ST", "H2", "D3", "D4"])
            ; 尝试保持选择
            roleMap := Map("全部", 1, "MT", 2, "H1", 3, "D1", 4, "D2", 5, "ST", 6, "H2", 7, "D3", 8, "D4", 9)
            if (roleMap.Has(currentRole)) {
                roleCombo.Choose(roleMap[currentRole])
            } else {
                roleCombo.Choose(1)
            }
        }
    }
    
    ; 触发器编辑器 - 添加按钮
    OnAddTriggerClick(keywordEdit, ttsEdit, cdEdit, targetCombo, triggerNegateCheck, triggerList) {
        keyword := Trim(keywordEdit.Value)
        ttsText := Trim(ttsEdit.Value)
        cd := Trim(cdEdit.Value)
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (triggerNegateCheck.Value) {
            target := "~" . target
        }
        
        ; 验证CD值
        if (cd = "" || !IsNumber(cd)) {
            cd := "5"  ; 默认5秒
        }
        
        ; 调试信息
        this.logger.Debug("添加触发器 - 关键字: [" keyword "] | 播报: [" ttsText "] | CD: " cd "s | 目标: " target)
        
        if (keyword = "" || ttsText = "") {
            MsgBox("请输入关键字和播报内容", "提示", "Icon!")
            return
        }
        
        triggerList.Add("", keyword, ttsText, cd, target)
        keywordEdit.Value := ""
        ttsEdit.Value := ""
        cdEdit.Value := "5"
        targetCombo.Choose(1)
        triggerNegateCheck.Value := 0
    }
    
    ; 触发器编辑器 - 插入按钮（在选中项前面插入）
    OnInsertTriggerClick(keywordEdit, ttsEdit, cdEdit, targetCombo, triggerNegateCheck, triggerList) {
        keyword := Trim(keywordEdit.Value)
        ttsText := Trim(ttsEdit.Value)
        cd := Trim(cdEdit.Value)
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (triggerNegateCheck.Value) {
            target := "~" . target
        }
        
        ; 验证CD值
        if (cd = "" || !IsNumber(cd)) {
            cd := "5"
        }
        
        ; 调试信息
        this.logger.Debug("插入触发器 - 关键字: [" keyword "] | 播报: [" ttsText "] | CD: " cd "s | 目标: " target)
        
        if (keyword = "" || ttsText = "") {
            MsgBox("请输入关键字和播报内容", "提示", "Icon!")
            return
        }
        
        ; 获取选中的行
        selectedRow := triggerList.GetNext(0, "Focused")
        
        if (selectedRow = 0) {
            ; 没有选中，添加到末尾
            triggerList.Add("", keyword, ttsText, cd, target)
        } else {
            ; 在选中项前插入
            triggerList.Insert(selectedRow, "", keyword, ttsText, cd, target)
        }
        
        keywordEdit.Value := ""
        ttsEdit.Value := ""
        cdEdit.Value := "5"
        targetCombo.Choose(1)
        triggerNegateCheck.Value := 0
    }
    
    ; 触发器编辑器 - 修改按钮
    OnUpdateTriggerClick(keywordEdit, ttsEdit, cdEdit, targetCombo, triggerNegateCheck, triggerList) {
        ; 检查选中的项数量
        selectedCount := 0
        rowNumber := 0
        firstSelectedRow := 0
        Loop {
            rowNumber := triggerList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            if (firstSelectedRow = 0) {
                firstSelectedRow := rowNumber
            }
            selectedCount++
        }
        
        if (selectedCount = 0) {
            MsgBox("请选择要修改的触发器", "提示", "Icon!")
            return
        }
        
        if (selectedCount > 1) {
            MsgBox("一次只能修改一项，请只选择一项", "提示", "Icon!")
            return
        }
        
        keyword := Trim(keywordEdit.Value)
        ttsText := Trim(ttsEdit.Value)
        cd := Trim(cdEdit.Value)
        target := targetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (triggerNegateCheck.Value) {
            target := "~" . target
        }
        
        ; 验证CD值
        if (cd = "" || !IsNumber(cd)) {
            cd := "5"
        }
        
        ; 调试信息
        this.logger.Debug("修改触发器 - 关键字: [" keyword "] | 播报: [" ttsText "] | CD: " cd "s | 目标: " target)
        
        if (keyword = "" || ttsText = "") {
            MsgBox("请输入关键字和播报内容", "提示", "Icon!")
            return
        }
        
        triggerList.Modify(firstSelectedRow, "", keyword, ttsText, cd, target)
        
        ; 清空输入框
        keywordEdit.Value := ""
        ttsEdit.Value := ""
        cdEdit.Value := "5"
        targetCombo.Choose(1)
        triggerNegateCheck.Value := 0
    }
    
    ; 触发器编辑器 - 删除按钮（支持批量删除）
    OnDeleteTriggerClick(triggerList) {
        ; 收集所有选中的行
        selectedRows := []
        rowNumber := 0
        Loop {
            rowNumber := triggerList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            selectedRows.Push(rowNumber)
        }
        
        if (selectedRows.Length = 0) {
            MsgBox("请选择要删除的触发器", "提示", "Icon!")
            return
        }
        
        ; 从后往前删除（避免索引变化）
        Loop selectedRows.Length {
            triggerList.Delete(selectedRows[selectedRows.Length - A_Index + 1])
        }
    }
    
    ; 触发器编辑器 - 双击事件
    OnTriggerDoubleClick(keywordEdit, ttsEdit, cdEdit, targetCombo, triggerNegateCheck, triggerList) {
        selectedRow := triggerList.GetNext(0, "Focused")
        if (selectedRow > 0) {
            keywordEdit.Value := triggerList.GetText(selectedRow, 1)
            ttsEdit.Value := triggerList.GetText(selectedRow, 2)
            cdEdit.Value := triggerList.GetText(selectedRow, 3)
            target := triggerList.GetText(selectedRow, 4)
            
            ; 检查是否为取反模式（以 ~ 开头）
            if (SubStr(target, 1, 1) = "~") {
                triggerNegateCheck.Value := 1
                target := SubStr(target, 2)  ; 去掉 ~
            } else {
                triggerNegateCheck.Value := 0
            }
            
            ; 直接选择目标
            try {
                targetCombo.Choose(target)
            } catch {
                targetCombo.Choose(1)  ; 如果失败，选择"全部"
            }
        }
    }
    
    ; 副本规则编辑器 - 应用按钮（保存但不关闭）
    OnApplyRulesClick(dungeonNameEdit, timelineList, overlayList, positionList, triggerLists, dungeonPath, editGui) {
        newDungeonName := Trim(dungeonNameEdit.Value)
        
        if (newDungeonName = "") {
            MsgBox("副本名称不能为空", "错误", "IconX")
            return
        }
        
        ; 收集TTS轴
        newTimeline := []
        timelineCount := timelineList.GetCount()
        
        Loop timelineCount {
            timeStr := timelineList.GetText(A_Index, 1)
            skillName := timelineList.GetText(A_Index, 2)
            ttsText := timelineList.GetText(A_Index, 3)
            targetDisplay := timelineList.GetText(A_Index, 4)
            
            ; 只要有时间和技能名就保存（播报内容可以为空）
            if (timeStr != "" && skillName != "") {
                ; 将"分:秒"格式转回秒数
                timeInSeconds := this.ParseTimeInput(timeStr)
                if (timeInSeconds = -1) {
                    ; 如果解析失败，跳过这条
                    continue
                }
                
                ; 如果播报内容为空，使用技能名称作为默认播报
                if (ttsText = "") {
                    ttsText := skillName
                }
                
                eventMap := Map(
                    "time", timeInSeconds,
                    "skill_name", skillName,
                    "tts_template", ttsText
                )
                
                ; 如果不是"全部"，才添加target字段
                if (targetDisplay != "全部") {
                    eventMap["target"] := targetDisplay
                }
                
                newTimeline.Push(eventMap)
            }
        }
        
        ; 收集倒计时条TTS轴
        newOverlayTimeline := []
        overlayCount := overlayList.GetCount()
        
        Loop overlayCount {
            timeStr := overlayList.GetText(A_Index, 1)
            skillName := overlayList.GetText(A_Index, 2)
            
            if (timeStr != "" && skillName != "") {
                ; 将"分:秒"格式转回秒数
                timeInSeconds := this.ParseTimeInput(timeStr)
                if (timeInSeconds = -1) {
                    ; 如果解析失败，跳过这条
                    continue
                }
                
                newOverlayTimeline.Push(Map(
                    "time", timeInSeconds,
                    "skill_name", skillName
                ))
            }
        }
        
        ; 收集站位配置（新格式：简化版本）
        newPositions := Map()
        positionCount := positionList.GetCount()
        
        ; 使用数组来保存多个同名技能的配置
        tempPositions := []
        
        Loop positionCount {
            skillName := positionList.GetText(A_Index, 1)
            position := positionList.GetText(A_Index, 2)
            target := positionList.GetText(A_Index, 3)
            
            if (skillName != "" && position != "") {
                tempPositions.Push({
                    skillName: skillName,
                    position: position,
                    target: target
                })
            }
        }
        
        ; 将数组转换为Map格式
        ; 如果同一技能名有多个目标，使用"技能名#数字"作为键
        skillCounts := Map()
        for item in tempPositions {
            skillName := item.skillName
            
            if (!skillCounts.Has(skillName)) {
                skillCounts[skillName] := 0
            }
            skillCounts[skillName]++
            
            count := skillCounts[skillName]
            
            ; 保存为Map格式
            posMap := Map(
                "position", item.position,
                "target", item.target
            )
            
            ; 如果是第一个，直接用技能名作为键；否则添加后缀
            if (count = 1) {
                newPositions[skillName] := posMap
            } else {
                newPositions[skillName "#" count] := posMap
            }
        }
        
        ; 收集所有区域的触发器（新格式：支持CD和target，支持同名关键字）
        allTriggers := Map()
        
        for regionKey, triggerList in triggerLists {
            regionTriggers := Map()
            rowCount := triggerList.GetCount()
            
            ; 使用数组暂存，然后统计同名关键字数量
            tempTriggers := []
            
            Loop rowCount {
                keyword := triggerList.GetText(A_Index, 1)
                ttsText := triggerList.GetText(A_Index, 2)
                cdText := triggerList.GetText(A_Index, 3)  ; 读取CD列
                target := triggerList.GetText(A_Index, 4)  ; 读取目标列
                
                if (keyword != "" && ttsText != "") {
                    ; 验证CD值
                    cd := IsNumber(cdText) ? Integer(cdText) : 5
                    
                    tempTriggers.Push({
                        keyword: keyword,
                        ttsText: ttsText,
                        cd: cd,
                        target: target
                    })
                }
            }
            
            ; 统计同名关键字，使用 "关键字#数字" 格式
            keywordCounts := Map()
            for item in tempTriggers {
                keyword := item.keyword
                
                if (!keywordCounts.Has(keyword)) {
                    keywordCounts[keyword] := 0
                }
                keywordCounts[keyword]++
                
                count := keywordCounts[keyword]
                
                ; 保存为新格式（包含tts、cooldown和target）
                triggerMap := Map(
                    "tts", item.ttsText,
                    "cooldown", item.cd
                )
                
                ; 如果不是"全部"，才添加target字段
                if (item.target != "全部") {
                    triggerMap["target"] := item.target
                }
                
                ; 如果是第一个，直接用关键字；否则添加后缀
                if (count = 1) {
                    regionTriggers[keyword] := triggerMap
                } else {
                    regionTriggers[keyword "#" count] := triggerMap
                }
            }
            
            allTriggers[regionKey] := regionTriggers
        }
        
        ; 保存到副本规则文件（但不关闭窗口）
        if (this.SaveCompleteRulesToFile(dungeonPath, newDungeonName, newTimeline, newOverlayTimeline, newPositions, allTriggers)) {
            this.logger.Info("副本规则已应用: " newDungeonName)
            this.mainWindow.ShowMessage("成功", "副本规则已应用", "Success")
            this.RefreshDungeons()
            ; 注意：不调用 editGui.Destroy()，保持窗口打开
        } else {
            this.logger.Error("应用副本规则失败")
            this.mainWindow.ShowMessage("错误", "应用失败", "Error")
        }
    }
    
    ; 副本规则编辑器 - 保存全部按钮
    OnSaveAllRulesClick(dungeonNameEdit, timelineList, overlayList, positionList, triggerLists, dungeonPath, editGui) {
        newDungeonName := Trim(dungeonNameEdit.Value)
        
        if (newDungeonName = "") {
            MsgBox("副本名称不能为空", "错误", "IconX")
            return
        }
        
        ; 收集TTS轴
        newTimeline := []
        timelineCount := timelineList.GetCount()
        
        Loop timelineCount {
            timeStr := timelineList.GetText(A_Index, 1)
            skillName := timelineList.GetText(A_Index, 2)
            ttsText := timelineList.GetText(A_Index, 3)
            targetDisplay := timelineList.GetText(A_Index, 4)
            
            ; 只要有时间和技能名就保存（播报内容可以为空）
            if (timeStr != "" && skillName != "") {
                ; 将"分:秒"格式转回秒数
                timeInSeconds := this.ParseTimeInput(timeStr)
                if (timeInSeconds = -1) {
                    ; 如果解析失败，跳过这条
                    continue
                }
                
                ; 如果播报内容为空，使用技能名称作为默认播报
                if (ttsText = "") {
                    ttsText := skillName
                }
                
                eventMap := Map(
                    "time", timeInSeconds,
                    "skill_name", skillName,
                    "tts_template", ttsText
                )
                
                ; 如果不是"全部"，才添加target字段
                if (targetDisplay != "全部") {
                    eventMap["target"] := targetDisplay
                }
                
                newTimeline.Push(eventMap)
            }
        }
        
        ; 收集倒计时条TTS轴
        newOverlayTimeline := []
        overlayCount := overlayList.GetCount()
        
        Loop overlayCount {
            timeStr := overlayList.GetText(A_Index, 1)
            skillName := overlayList.GetText(A_Index, 2)
            
            if (timeStr != "" && skillName != "") {
                ; 将"分:秒"格式转回秒数
                timeInSeconds := this.ParseTimeInput(timeStr)
                if (timeInSeconds = -1) {
                    ; 如果解析失败，跳过这条
                    continue
                }
                
                newOverlayTimeline.Push(Map(
                    "time", timeInSeconds,
                    "skill_name", skillName
                ))
            }
        }
        
        ; 收集站位配置（新格式：简化版本）
        newPositions := Map()
        positionCount := positionList.GetCount()
        
        ; 使用数组来保存多个同名技能的配置
        tempPositions := []
        
        Loop positionCount {
            skillName := positionList.GetText(A_Index, 1)
            position := positionList.GetText(A_Index, 2)
            target := positionList.GetText(A_Index, 3)
            
            if (skillName != "" && position != "") {
                tempPositions.Push({
                    skillName: skillName,
                    position: position,
                    target: target
                })
            }
        }
        
        ; 将数组转换为Map格式
        ; 如果同一技能名有多个目标，使用"技能名#数字"作为键
        skillCounts := Map()
        for item in tempPositions {
            skillName := item.skillName
            
            if (!skillCounts.Has(skillName)) {
                skillCounts[skillName] := 0
            }
            skillCounts[skillName]++
            
            count := skillCounts[skillName]
            
            ; 保存为Map格式
            posMap := Map(
                "position", item.position,
                "target", item.target
            )
            
            ; 如果是第一个，直接用技能名作为键；否则添加后缀
            if (count = 1) {
                newPositions[skillName] := posMap
            } else {
                newPositions[skillName "#" count] := posMap
            }
        }
        
        ; 收集所有区域的触发器（新格式：支持CD和target，支持同名关键字）
        allTriggers := Map()
        
        for regionKey, triggerList in triggerLists {
            regionTriggers := Map()
            rowCount := triggerList.GetCount()
            
            ; 使用数组暂存，然后统计同名关键字数量
            tempTriggers := []
            
            Loop rowCount {
                keyword := triggerList.GetText(A_Index, 1)
                ttsText := triggerList.GetText(A_Index, 2)
                cdText := triggerList.GetText(A_Index, 3)  ; 读取CD列
                target := triggerList.GetText(A_Index, 4)  ; 读取目标列
                
                if (keyword != "" && ttsText != "") {
                    ; 验证CD值
                    cd := IsNumber(cdText) ? Integer(cdText) : 5
                    
                    tempTriggers.Push({
                        keyword: keyword,
                        ttsText: ttsText,
                        cd: cd,
                        target: target
                    })
                }
            }
            
            ; 统计同名关键字，使用 "关键字#数字" 格式
            keywordCounts := Map()
            for item in tempTriggers {
                keyword := item.keyword
                
                if (!keywordCounts.Has(keyword)) {
                    keywordCounts[keyword] := 0
                }
                keywordCounts[keyword]++
                
                count := keywordCounts[keyword]
                
                ; 保存为新格式（包含tts、cooldown和target）
                triggerMap := Map(
                    "tts", item.ttsText,
                    "cooldown", item.cd
                )
                
                ; 如果不是"全部"，才添加target字段
                if (item.target != "全部") {
                    triggerMap["target"] := item.target
                }
                
                ; 如果是第一个，直接用关键字；否则添加后缀
                if (count = 1) {
                    regionTriggers[keyword] := triggerMap
                } else {
                    regionTriggers[keyword "#" count] := triggerMap
                }
            }
            
            allTriggers[regionKey] := regionTriggers
        }
        
        ; 保存到副本规则文件
        if (this.SaveCompleteRulesToFile(dungeonPath, newDungeonName, newTimeline, newOverlayTimeline, newPositions, allTriggers)) {
            this.logger.Info("副本规则已保存: " newDungeonName)
            this.mainWindow.ShowMessage("成功", "副本规则已保存", "Success")
            this.RefreshDungeons()
            editGui.Destroy()
        } else {
            this.logger.Error("保存副本规则失败")
            this.mainWindow.ShowMessage("错误", "保存失败", "Error")
        }
    }
    
    ; 保存完整的副本规则到文件
    SaveCompleteRulesToFile(dungeonPath, dungeonName, timeline, overlayTimeline, positions, allTriggers) {
        try {
            this.logger.Debug("开始保存副本规则到: " dungeonPath)
            
            ; 读取现有文件获取description
            description := "副本规则配置"
            if (FileExist(dungeonPath)) {
                content := FileRead(dungeonPath)
                rules := JSON.Parse(content)
                if (rules.Has("description")) {
                    description := rules["description"]
                }
            }
            
            this.logger.Debug("positions 类型: " Type(positions) ", 数量: " positions.Count)
            this.logger.Debug("allTriggers 类型: " Type(allTriggers) ", 数量: " allTriggers.Count)
            
            ; 构建完整规则（按照配置页面顺序）
            newRules := Map(
                "dungeon_name", dungeonName,
                "description", description,
                "timeline", timeline,
                "overlay_timeline", overlayTimeline,
                "positions", positions,
                "boss_dialogue", allTriggers.Has("boss_dialogue") ? allTriggers["boss_dialogue"] : Map(),
                "boss_hp", allTriggers.Has("boss_hp") ? allTriggers["boss_hp"] : Map(),
                "boss_skill", allTriggers.Has("boss_skill") ? allTriggers["boss_skill"] : Map()
            )
            
            this.logger.Debug("开始序列化 JSON...")
            ; 保存文件
            jsonText := JSON.Stringify(newRules, "    ")
            this.logger.Debug("JSON 序列化完成，长度: " StrLen(jsonText))
            
            ; 确保dungeon_rules文件夹存在
            if (!DirExist("dungeon_rules")) {
                DirCreate("dungeon_rules")
            }
            
            if (FileExist(dungeonPath)) {
                FileDelete(dungeonPath)
            }
            
            FileAppend(jsonText, dungeonPath, "UTF-8")
            
            return true
            
        } catch as err {
            this.logger.Error("保存副本规则文件失败: " err.Message)
            return false
        }
    }
    
    ; TTS轴列表按时间排序
    SortTimelineByTime(timelineList) {
        ; 收集所有行数据
        items := []
        rowCount := timelineList.GetCount()
        Loop rowCount {
            timeStr := timelineList.GetText(A_Index, 1)
            skillName := timelineList.GetText(A_Index, 2)
            ttsText := timelineList.GetText(A_Index, 3)
            target := timelineList.GetText(A_Index, 4)
            
            ; 如果职能为空，默认为"全部"
            if (target = "") {
                target := "全部"
            }
            
            ; 将时间转换为秒数用于排序
            timeInSeconds := this.ParseTimeInput(timeStr)
            if (timeInSeconds = -1) {
                timeInSeconds := 999999  ; 无效时间排到最后
            }
            
            items.Push(Map("time", timeInSeconds, "timeStr", timeStr, "skill", skillName, "tts", ttsText, "target", target))
        }
        
        ; 排序（时间从小到大）- 使用冒泡排序
        Loop items.Length - 1 {
            i := A_Index
            Loop items.Length - i {
                j := A_Index + i
                if (items[i]["time"] > items[j]["time"]) {
                    ; 交换
                    temp := items[i]
                    items[i] := items[j]
                    items[j] := temp
                }
            }
        }
        
        ; 清空列表并重新添加（包含职能字段）
        timelineList.Delete()
        for item in items {
            timelineList.Add("", item["timeStr"], item["skill"], item["tts"], item["target"])
        }
    }
    
    ; 倒计时条列表按时间排序
    SortOverlayByTime(overlayList) {
        ; 收集所有行数据
        items := []
        rowCount := overlayList.GetCount()
        Loop rowCount {
            timeStr := overlayList.GetText(A_Index, 1)
            skillName := overlayList.GetText(A_Index, 2)
            
            ; 将时间转换为秒数用于排序
            timeInSeconds := this.ParseTimeInput(timeStr)
            if (timeInSeconds = -1) {
                timeInSeconds := 999999  ; 无效时间排到最后
            }
            
            items.Push(Map("time", timeInSeconds, "timeStr", timeStr, "skill", skillName))
        }
        
        ; 排序（时间从小到大）- 使用冒泡排序
        Loop items.Length - 1 {
            i := A_Index
            Loop items.Length - i {
                j := A_Index + i
                if (items[i]["time"] > items[j]["time"]) {
                    ; 交换
                    temp := items[i]
                    items[i] := items[j]
                    items[j] := temp
                }
            }
        }
        
        ; 清空列表并重新添加
        overlayList.Delete()
        for item in items {
            overlayList.Add("", item["timeStr"], item["skill"])
        }
    }
    
    ; ========== 倒计时条编辑器回调 ==========
    
    ; 倒计时条 - 添加按钮
    OnAddOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList) {
        timeInput := overlayTimeEdit.Value
        skillName := overlaySkillEdit.Value
        
        if (timeInput = "" || skillName = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 添加到列表
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        overlayList.Add("", timeDisplay, skillName)
        
        ; 清空输入框
        overlayTimeEdit.Value := ""
        overlaySkillEdit.Value := ""
    }
    
    ; 倒计时条 - 插入按钮
    OnInsertOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList) {
        timeInput := overlayTimeEdit.Value
        skillName := overlaySkillEdit.Value
        
        if (timeInput = "" || skillName = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 获取选中的行
        selectedRow := overlayList.GetNext(0, "Focused")
        
        ; 格式化显示时间
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        
        if (selectedRow = 0) {
            overlayList.Add("", timeDisplay, skillName)
            MsgBox("未选择行，已添加到末尾", "提示", "Icon!")
        } else {
            overlayList.Insert(selectedRow, "", timeDisplay, skillName)
        }
        
        ; 清空输入框
        overlayTimeEdit.Value := ""
        overlaySkillEdit.Value := ""
    }
    
    ; 倒计时条 - 修改按钮
    OnUpdateOverlayClick(overlayTimeEdit, overlaySkillEdit, overlayList) {
        ; 检查选中的项数量
        selectedCount := 0
        rowNumber := 0
        firstSelectedRow := 0
        Loop {
            rowNumber := overlayList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            if (firstSelectedRow = 0) {
                firstSelectedRow := rowNumber
            }
            selectedCount++
        }
        
        if (selectedCount = 0) {
            MsgBox("请先选择一行", "提示", "Icon!")
            return
        }
        
        if (selectedCount > 1) {
            MsgBox("一次只能修改一项，请只选择一项", "提示", "Icon!")
            return
        }
        
        timeInput := overlayTimeEdit.Value
        skillName := overlaySkillEdit.Value
        
        if (timeInput = "" || skillName = "") {
            MsgBox("请填写完整信息", "提示", "Icon!")
            return
        }
        
        ; 解析时间
        timeInSeconds := this.ParseTimeInput(timeInput)
        if (timeInSeconds = -1) {
            MsgBox("时间格式错误！`n`n支持格式：`n• 纯秒数：54`n• 分:秒：2:54", "错误", "IconX")
            return
        }
        
        ; 更新列表
        timeDisplay := this.FormatTimeDisplay(timeInSeconds)
        overlayList.Modify(firstSelectedRow, "", timeDisplay, skillName)
        
        ; 清空输入框
        overlayTimeEdit.Value := ""
        overlaySkillEdit.Value := ""
    }
    
    ; 倒计时条 - 删除按钮（支持批量删除）
    OnDeleteOverlayClick(overlayList) {
        ; 收集所有选中的行
        selectedRows := []
        rowNumber := 0
        Loop {
            rowNumber := overlayList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            selectedRows.Push(rowNumber)
        }
        
        if (selectedRows.Length = 0) {
            MsgBox("请先选择一行", "提示", "Icon!")
            return
        }
        
        ; 从后往前删除（避免索引变化）
        Loop selectedRows.Length {
            overlayList.Delete(selectedRows[selectedRows.Length - A_Index + 1])
        }
    }
    
    ; 倒计时条 - 双击加载
    OnOverlayDoubleClick(overlayTimeEdit, overlaySkillEdit, overlayList) {
        selectedRow := overlayList.GetNext(0, "Focused")
        
        if (selectedRow > 0) {
            overlayTimeEdit.Value := overlayList.GetText(selectedRow, 1)
            overlaySkillEdit.Value := overlayList.GetText(selectedRow, 2)
        }
    }
    
    ; TTS轴 - 从倒计时条复制
    OnCopyFromOverlayClick(overlayTimeline, timelineList) {
        if (overlayTimeline.Length = 0) {
            MsgBox("倒计时条为空，无法复制", "提示", "Icon!")
            return
        }
        
        ; 收集TTS轴中已有的技能名称
        existingSkills := Map()
        existingCount := timelineList.GetCount()
        Loop existingCount {
            skillName := timelineList.GetText(A_Index, 2)
            if (skillName != "") {
                existingSkills[skillName] := true
            }
        }
        
        ; 从倒计时条复制不重复的技能（复制时间，播报内容留空）
        addedCount := 0
        for event in overlayTimeline {
            if (event.Has("skill_name")) {
                skillName := event["skill_name"]
                
                ; 如果TTS轴里已经有这个技能，跳过
                if (existingSkills.Has(skillName)) {
                    continue
                }
                
                ; 复制时间和技能名（播报内容默认为技能名称，职能默认为"全部"）
                timeDisplay := event.Has("time") ? this.FormatTimeDisplay(event["time"]) : ""
                timelineList.Add("", timeDisplay, skillName, skillName, "全部")
                addedCount++
            }
        }
        
        if (addedCount > 0) {
            ; 按时间排序
            this.SortTimelineByTime(timelineList)
            MsgBox("已从倒计时条添加 " addedCount " 个新技能并按时间排序`n（已存在的技能已跳过，播报内容默认为技能名称）", "成功", "Icon!")
        } else {
            MsgBox("TTS轴已包含所有倒计时条技能，无需添加", "提示", "Icon!")
        }
    }
    
    ; 倒计时条 - 从TTS轴复制
    OnCopyFromTimelineClick(timeline, overlayList) {
        if (timeline.Length = 0) {
            MsgBox("TTS轴为空，无法复制", "提示", "Icon!")
            return
        }
        
        ; 收集倒计时条中已有的技能名称
        existingSkills := Map()
        existingCount := overlayList.GetCount()
        Loop existingCount {
            skillName := overlayList.GetText(A_Index, 2)
            if (skillName != "") {
                existingSkills[skillName] := true
            }
        }
        
        ; 从TTS轴复制不重复的技能（复制时间和技能名）
        addedCount := 0
        for event in timeline {
            if (event.Has("skill_name")) {
                skillName := event["skill_name"]
                
                ; 如果倒计时条里已经有这个技能，跳过
                if (existingSkills.Has(skillName)) {
                    continue
                }
                
                ; 复制时间和技能名
                timeDisplay := event.Has("time") ? this.FormatTimeDisplay(event["time"]) : ""
                overlayList.Add("", timeDisplay, skillName)
                addedCount++
            }
        }
        
        if (addedCount > 0) {
            ; 按时间排序
            this.SortOverlayByTime(overlayList)
            MsgBox("已从TTS轴添加 " addedCount " 个新技能并按时间排序`n（已存在的技能已跳过）", "成功", "Icon!")
        } else {
            MsgBox("倒计时条已包含所有TTS轴技能，无需添加", "提示", "Icon!")
        }
    }
    
    ; ========== 站位配置编辑器回调 ==========
    
    ; 站位配置 - 添加按钮
    OnAddPositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList) {
        skillName := Trim(posSkillEdit.Value)
        position := Trim(posValueEdit.Value)
        target := posTargetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (posNegateCheck.Value) {
            target := "~" . target
        }
        
        if (skillName = "" || position = "") {
            MsgBox("请填写技能名称和站位", "提示", "Icon!")
            return
        }
        
        ; 检查是否已存在（技能名+目标不能重复）
        rowCount := positionList.GetCount()
        Loop rowCount {
            existingSkill := positionList.GetText(A_Index, 1)
            existingTarget := positionList.GetText(A_Index, 3)
            if (existingSkill = skillName && existingTarget = target) {
                MsgBox("该技能名和目标的组合已存在！`n`n技能: " skillName "`n目标: " target "`n`n请使用修改功能", "提示", "Icon!")
                return
            }
        }
        
        ; 添加到列表
        positionList.Add("", skillName, position, target)
        
        ; 清空输入框
        posSkillEdit.Value := ""
        posValueEdit.Value := ""
        posTargetCombo.Choose(1)
    }
    
    ; 站位配置 - 插入按钮（在选中项前面插入）
    OnInsertPositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList) {
        skillName := Trim(posSkillEdit.Value)
        position := Trim(posValueEdit.Value)
        target := posTargetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (posNegateCheck.Value) {
            target := "~" . target
        }
        
        if (skillName = "" || position = "") {
            MsgBox("请填写技能名称和站位", "提示", "Icon!")
            return
        }
        
        ; 检查是否已存在（技能名+目标不能重复）
        rowCount := positionList.GetCount()
        Loop rowCount {
            existingSkill := positionList.GetText(A_Index, 1)
            existingTarget := positionList.GetText(A_Index, 3)
            if (existingSkill = skillName && existingTarget = target) {
                MsgBox("该技能名和目标的组合已存在！`n`n技能: " skillName "`n目标: " target "`n`n请使用修改功能", "提示", "Icon!")
                return
            }
        }
        
        ; 获取选中的行
        selectedRow := positionList.GetNext(0, "Focused")
        
        if (selectedRow = 0) {
            ; 没有选中，添加到末尾
            positionList.Add("", skillName, position, target)
        } else {
            ; 在选中项前插入
            positionList.Insert(selectedRow, "", skillName, position, target)
        }
        
        ; 清空输入框
        posSkillEdit.Value := ""
        posValueEdit.Value := ""
        posTargetCombo.Choose(1)
    }
    
    ; 站位配置 - 修改按钮
    OnUpdatePositionClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList) {
        ; 检查选中的项数量
        selectedCount := 0
        rowNumber := 0
        firstSelectedRow := 0
        Loop {
            rowNumber := positionList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            if (firstSelectedRow = 0) {
                firstSelectedRow := rowNumber
            }
            selectedCount++
        }
        
        if (selectedCount = 0) {
            MsgBox("请先选中要修改的项", "提示", "Icon!")
            return
        }
        
        if (selectedCount > 1) {
            MsgBox("一次只能修改一项，请只选择一项", "提示", "Icon!")
            return
        }
        
        skillName := Trim(posSkillEdit.Value)
        position := Trim(posValueEdit.Value)
        target := posTargetCombo.Text
        
        ; 如果勾选了"取反"，在目标前添加 ~
        if (posNegateCheck.Value) {
            target := "~" . target
        }
        
        if (skillName = "" || position = "") {
            MsgBox("请填写技能名称和站位", "提示", "Icon!")
            return
        }
        
        ; 更新选中项
        positionList.Modify(firstSelectedRow, "", skillName, position, target)
        
        ; 清空输入框
        posSkillEdit.Value := ""
        posValueEdit.Value := ""
        posTargetCombo.Choose(1)
    }
    
    ; 站位配置 - 删除按钮（支持批量删除）
    OnDeletePositionClick(positionList) {
        ; 收集所有选中的行
        selectedRows := []
        rowNumber := 0
        Loop {
            rowNumber := positionList.GetNext(rowNumber)
            if (rowNumber = 0) {
                break
            }
            selectedRows.Push(rowNumber)
        }
        
        if (selectedRows.Length = 0) {
            MsgBox("请先选中要删除的项", "提示", "Icon!")
            return
        }
        
        ; 从后往前删除（避免索引变化）
        Loop selectedRows.Length {
            positionList.Delete(selectedRows[selectedRows.Length - A_Index + 1])
        }
    }
    
    ; 站位配置 - 双击加载
    OnPositionDoubleClick(posSkillEdit, posValueEdit, posTargetCombo, posNegateCheck, positionList) {
        selectedRow := positionList.GetNext(0, "Focused")
        if (selectedRow > 0) {
            posSkillEdit.Value := positionList.GetText(selectedRow, 1)
            posValueEdit.Value := positionList.GetText(selectedRow, 2)
            target := positionList.GetText(selectedRow, 3)
            
            ; 检查是否为取反模式（以 ~ 开头）
            if (SubStr(target, 1, 1) = "~") {
                posNegateCheck.Value := 1
                target := SubStr(target, 2)  ; 去掉 ~
            } else {
                posNegateCheck.Value := 0
            }
            
            ; 直接根据文本选择（DropDownList.Choose支持文本参数）
            try {
                posTargetCombo.Choose(target)
            } catch {
                posTargetCombo.Choose(1)  ; 如果失败，选择"全部"
            }
        }
    }
    
    ; 绑定触发器事件（辅助方法，避免闭包陷阱）
    ; 每次调用都创建新的作用域，参数是值传递
    BindTriggerEvents(addBtn, insertBtn, updateBtn, deleteBtn, triggerList, keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck) {
        addBtn.OnEvent("Click", (*) => this.OnAddTriggerClick(keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck, triggerList))
        insertBtn.OnEvent("Click", (*) => this.OnInsertTriggerClick(keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck, triggerList))
        updateBtn.OnEvent("Click", (*) => this.OnUpdateTriggerClick(keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck, triggerList))
        deleteBtn.OnEvent("Click", (*) => this.OnDeleteTriggerClick(triggerList))
        triggerList.OnEvent("DoubleClick", (*) => this.OnTriggerDoubleClick(keywordEdit, ttsEdit, cdEdit, triggerTargetCombo, triggerNegateCheck, triggerList))
    }
    
    ; 框选区域回调
    OnSelectRegion() {
        ; 获取选择的区域类型
        regionType := this.mainWindow.regionTypeCombo.Text
        
        this.logger.Info("启动区域选择工具 - 类型: " regionType)
        
        ; 获取游戏窗口标题
        windowTitle := this.configManager.GetNested("game", "window_title")
        
        if (windowTitle = "" || !windowTitle) {
            ; 提示用户先配置窗口标题
            result := MsgBox(
                "未配置游戏窗口标题！`n`n"
                "建议先在 配置 页面设置游戏窗口标题，"
                "这样可以自动激活游戏窗口进行截取。`n`n"
                "是否继续（不激活窗口）？", 
                "提示", 
                "YesNo Icon?"
            )
            
            if (result = "No") {
        return
            }
        }
        
        this.mainWindow.Hide()  ; 隐藏主窗口
        
        ; 创建回调函数（传入区域类型）
        callback := ObjBindMethod(this, "OnRegionSelected", regionType)
        
        ; 启动选择器（传入窗口标题）
        SelectRegion(callback, windowTitle)
    }
    
    ; 区域选择完成回调
    OnRegionSelected(regionType, x1, y1, x2, y2) {
        ; 显示选择结果
        this.logger.Info("选择的区域: (" x1 ", " y1 ") - (" x2 ", " y2 ")")
        
        ; 根据区域类型映射到配置名称
        regionNameMap := Map(
            "BOSS台词区", "boss_dialogue",
            "BOSS血条区", "boss_hp",
            "BOSS技能区", "boss_skill"
        )
        
        if (regionNameMap.Has(regionType)) {
            regionName := regionNameMap[regionType]
            displayName := regionType
            
            ; 添加到配置
            this.AddOcrRegion(regionName, displayName, x1, y1, x2, y2)
            
            ; 重新加载显示
            this.LoadOcrRegions()
            
            this.logger.Info("已添加 OCR 区域: " displayName " (" regionName ")")
            this.mainWindow.ShowMessage("成功", "OCR 区域已添加: " displayName, "Success")
        } else {
            this.logger.Error("未知的区域类型: " regionType)
            this.mainWindow.ShowMessage("错误", "未知的区域类型", "Error")
        }
        
        ; 显示主窗口
        this.mainWindow.Show()
    }
    
    ; 添加 OCR 区域
    AddOcrRegion(name, displayName, x1, y1, x2, y2) {
        try {
            configFile := "config\ocr_regions.json"
            config := Map()
            
            ; 读取现有配置
            if (FileExist(configFile)) {
                content := FileRead(configFile)
                ; 检查文件是否为空或只有空白
                content := Trim(content)
                if (content != "") {
                    try {
                        parsed := JSON.Parse(content)
                        ; 确保解析结果是 Map
                        if (Type(parsed) = "Map") {
                            config := parsed
                        }
                    } catch {
                        ; 解析失败，使用空 Map
                        config := Map()
                    }
                }
            }
            
            ; 确保有 regions 键
            if (!config.Has("regions")) {
                config["regions"] := Map()
            }
            
            ; 添加新区域
            config["regions"][name] := Map(
                "name", displayName,
                "x1", x1,
                "y1", y1,
                "x2", x2,
                "y2", y2,
                "enabled", true
            )
            
            ; 保存
            jsonText := JSON.Stringify(config, "  ")
            
            ; 确保config文件夹存在
            if (!DirExist("config")) {
                DirCreate("config")
            }
            
            if (FileExist(configFile)) {
                FileDelete(configFile)
            }
            
            FileAppend(jsonText, configFile, "UTF-8")
            
            return true
        } catch as err {
            this.logger.Error("添加 OCR 区域失败: " err.Message)
            return false
        }
    }
    
    ; DEBUG 模式改变回调
    OnDebugModeChange(enabled) {
        this.logger.SetDebugMode(enabled)
        this.configManager.SetNested(["logging", "debug_mode"], enabled)
        this.configManager.Save()  ; 自动保存
        
        if (enabled) {
            this.logger.Info("DEBUG 模式已启用")
        } else {
            this.logger.Info("DEBUG 模式已禁用")
        }
    }
    
    ; OCR 间隔改变回调
    OnOcrIntervalChange(value) {
        try {
            interval := Float(value)
            if (interval >= 0.1 && interval <= 10) {
                this.configManager.SetNested(["ocr", "check_interval"], interval)
                this.configManager.Save()  ; 自动保存
                this.logger.Debug("OCR 检查间隔已更改: " interval)
            }
        } catch {
            ; 忽略无效输入
        }
    }
    
    ; 清空日志回调
    OnClearLog() {
        this.logger.ClearGui()
        this.logger.Info("日志已清空")
    }
    
    ; 导出日志回调
    OnExportLog() {
        ; 确保logs文件夹存在
        if (!DirExist("logs")) {
            DirCreate("logs")
        }
        
        filename := "logs\export_" FormatTime(, "yyyyMMdd_HHmmss") ".log"
        
        if (this.logger.ExportLogs(filename)) {
            this.logger.Info("日志已导出: " filename)
            this.mainWindow.ShowMessage("成功", "日志已导出到: " filename, "Success")
        } else {
            this.logger.Error("日志导出失败")
            this.mainWindow.ShowMessage("错误", "日志导出失败", "Error")
        }
    }
    
    ; 刷新日志回调
    OnRefreshLog() {
        ; 重新设置 GUI 控件（会自动刷新显示）
        this.logger.SetGuiControl(this.mainWindow.GetLogControl())
        
        ; 手动更新一次
        allLogs := this.logger.GetAllLogs()
        this.mainWindow.logEdit.Value := allLogs
        
        this.logger.Info("日志已刷新")
    }
    
    ; 保存热键配置
    OnSaveHotkeys() {
        this.logger.Info("保存热键配置...")
        
        ; 从 GUI 获取配置
        guiConfig := this.mainWindow.GetConfigValues()
        
        ; 合并到配置管理器
        if (guiConfig.Has("hotkeys")) {
            this.configManager.Set("hotkeys", guiConfig["hotkeys"])
        }
        
        ; 保存
        if (this.configManager.Save()) {
            this.logger.Info("热键配置已保存（重启程序后生效）")
            this.mainWindow.ShowMessage("保存成功", "热键配置已保存`n请重启程序使热键生效", "Success")
        } else {
            this.logger.Error("热键配置保存失败")
            this.mainWindow.ShowMessage("保存失败", "热键配置保存失败", "Error")
        }
    }
    
    ; 恢复默认热键
    OnResetHotkeys() {
        this.logger.Info("恢复默认热键")
        this.mainWindow.ResetHotkeys()
        this.mainWindow.ShowMessage("已恢复", "热键已恢复为默认值`n点击保存以应用", "Info")
    }
    
    ; 加载 OCR 区域
    LoadOcrRegions() {
        try {
            configFile := "config\ocr_regions.json"
            
            if (FileExist(configFile)) {
                content := FileRead(configFile)
                ; 检查文件是否为空
                content := Trim(content)
                
                if (content != "") {
                    config := JSON.Parse(content)
                    
                    if (Type(config) = "Map" && config.Has("regions")) {
                        this.mainWindow.UpdateOcrRegions(config["regions"])
                        this.logger.Info("已加载 " config["regions"].Count " 个 OCR 区域")
                    } else {
                        this.logger.Info("OCR 区域配置为空")
                        this.mainWindow.UpdateOcrRegions(Map())
                    }
                } else {
                    this.logger.Info("OCR 区域配置文件为空")
                    this.mainWindow.UpdateOcrRegions(Map())
                }
            } else {
                this.logger.Info("OCR 区域配置文件不存在，将在首次框选时创建")
                this.mainWindow.UpdateOcrRegions(Map())
            }
        } catch as err {
            this.logger.Error("加载 OCR 区域失败: " err.Message)
            this.mainWindow.UpdateOcrRegions(Map())
        }
    }
    
    ; ===========================================
    ; 自动启动功能相关
    ; ===========================================
    
    ; 更新自动启动状态显示
    UpdateAutoStartStatus() {
        x1 := this.configManager.GetNested("auto_start", "region_x1")
        y1 := this.configManager.GetNested("auto_start", "region_y1")
        x2 := this.configManager.GetNested("auto_start", "region_x2")
        y2 := this.configManager.GetNested("auto_start", "region_y2")
        color := this.configManager.GetNested("auto_start", "target_color")
        
        ; 根据触发状态显示不同信息
        if (this.autoStartTriggered) {
            status := "✅ 已触发（单次） | 停止监控后可再次触发"
            this.mainWindow.autoStartStatus.SetFont("cGreen")
        } else if (x1 && color) {
            status := "✅ 已配置 | 区域: (" x1 "," y1 ") - (" x2 "," y2 ") | 颜色: " color
            this.mainWindow.autoStartStatus.SetFont("cGreen")
        } else if (x1) {
            status := "⚠️ 区域已设置，请完成取色"
            this.mainWindow.autoStartStatus.SetFont("cFF8800")  ; 橙色
        } else {
            status := "未配置"
            this.mainWindow.autoStartStatus.SetFont("c808080")  ; 灰色
        }
        
        this.mainWindow.autoStartStatus.Value := status
    }
    
    ; 启动自动检测
    StartAutoStartDetection() {
        if (this.autoStartTimer) {
            return
        }
        
        this.autoStartEnabled := true
        this.autoStartTriggered := false
        
        ; 每200ms检测一次
        this.autoStartTimer := SetTimer(ObjBindMethod(this, "CheckAutoStartCondition"), 200)
        
        this.logger.Info("🎯 自动启动检测已启动")
        this.mainWindow.autoStartStatus.Value := "🔍 监控中..."
        this.mainWindow.autoStartStatus.SetFont("cBlue")
    }
    
    ; 停止自动检测
    StopAutoStartDetection() {
        if (this.autoStartTimer) {
            SetTimer(this.autoStartTimer, 0)
            this.autoStartTimer := ""
        }
        
        this.autoStartEnabled := false
        this.logger.Info("⏹️ 自动启动检测已停止")
        this.UpdateAutoStartStatus()
    }
    
    ; 检查自动启动条件
    CheckAutoStartCondition() {
        ; 如果已触发或未启用，直接返回
        if (this.autoStartTriggered || !this.autoStartEnabled) {
            return
        }
        
        ; 获取配置
        x1 := this.configManager.GetNested("auto_start", "region_x1")
        y1 := this.configManager.GetNested("auto_start", "region_y1")
        x2 := this.configManager.GetNested("auto_start", "region_x2")
        y2 := this.configManager.GetNested("auto_start", "region_y2")
        targetColor := this.configManager.GetNested("auto_start", "target_color")
        
        if (!x1 || !targetColor) {
            return
        }
        
        ; 在区域内搜索目标颜色
        try {
            CoordMode("Pixel", "Screen")
            foundX := 0, foundY := 0
            found := PixelSearch(&foundX, &foundY, x1, y1, x2, y2, targetColor, 5)  ; 容差改为5（精确匹配）
            
            ; 调试信息：显示检测状态
            static checkCount := 0
            checkCount++
            if (Mod(checkCount, 10) = 0) {  ; 每10次检测输出一次
                this.logger.Debug("自动启动检测 #" checkCount ": " (found ? "找到颜色" : "未找到") " | 目标: " targetColor)
            }
            
            if (found) {
                ; 找到目标颜色，触发自动启动
                actualColor := PixelGetColor(foundX, foundY)
                this.logger.Info("🎯 检测到目标颜色！")
                this.logger.Info("   位置: (" foundX ", " foundY ")")
                this.logger.Info("   目标颜色: " targetColor)
                this.logger.Info("   实际颜色: " actualColor)
                
                ; 标记为已触发（单次有效）
                this.autoStartTriggered := true
                
                ; 停止检测
                this.StopAutoStartDetection()
                
                ; 更新状态（保持勾选，只改变状态提示）
                this.UpdateAutoStartStatus()
                
                ; 自动启动监控（使用当前选择的副本和监控选项）
                dungeonFile := this.mainWindow.dungeonCombo.Text
                enableTimeline := this.mainWindow.enableTimelineCheck.Value
                enableOcr := this.mainWindow.enableOcrCheck.Value
                
                if (dungeonFile && (enableTimeline || enableOcr)) {
                    this.OnStartMonitor(dungeonFile, enableTimeline, enableOcr)
                } else {
                    this.logger.Warning("⚠️ 自动启动失败：未选择副本或监控选项")
                }
            }
        } catch as err {
            this.logger.Error("颜色检测出错: " err.Message)
        }
    }
    
    ; 框选自动启动区域
    OnSelectAutoStartRegion() {
        this.logger.Info("开始框选自动启动检测区域")
        
        ; 获取窗口标题
        windowTitle := this.configManager.GetNested("game", "window_title")
        if (!windowTitle) {
            MsgBox("请先在游戏设置中配置窗口标题", "提示", "IconX")
            return
        }
        
        ; 隐藏主窗口
        this.mainWindow.Hide()
        Sleep(300)  ; 等待窗口完全隐藏
        
        ; 创建回调函数
        callback := ObjBindMethod(this, "OnAutoStartRegionSelected")
        
        ; 使用统一的区域选择器（传入窗口标题）
        SelectRegion(callback, windowTitle)
    }
    
    ; 自动启动区域选择完成回调
    OnAutoStartRegionSelected(x1, y1, x2, y2) {
        ; 保存区域
        this.configManager.SetNested(["auto_start", "region_x1"], x1)
        this.configManager.SetNested(["auto_start", "region_y1"], y1)
        this.configManager.SetNested(["auto_start", "region_x2"], x2)
        this.configManager.SetNested(["auto_start", "region_y2"], y2)
        this.configManager.Save()
        
        this.logger.Info("自动启动区域已设置: (" x1 "," y1 ") - (" x2 "," y2 ")")
        
        ; 显示主窗口
        this.mainWindow.Show()
        
        ; 更新状态显示
        this.UpdateAutoStartStatus()
    }
    
    ; 取色设置
    OnSetAutoStartColor() {
        ; 检查区域是否已设置
        x1 := this.configManager.GetNested("auto_start", "region_x1")
        if (!x1) {
            MsgBox("请先框选区域", "提示", "IconX")
            return
        }
        
        ; 获取窗口标题
        windowTitle := this.configManager.GetNested("game", "window_title")
        
        this.logger.Info("开始取色")
        
        ; 隐藏主窗口
        this.mainWindow.Hide()
        Sleep(300)
        
        ; 激活游戏窗口
        if (windowTitle && windowTitle != "") {
            try {
                if (WinExist(windowTitle)) {
                    WinActivate(windowTitle)
                    Sleep(500)  ; 等待窗口激活
                    this.logger.Info("已激活窗口: " windowTitle)
                }
            } catch as err {
                this.logger.Error("激活窗口失败: " err.Message)
            }
        }
        
        ; 创建取色提示窗口（更美观的设计）
        tipGui := Gui("+AlwaysOnTop +ToolWindow +Border")
        tipGui.BackColor := "0x2C2C2C"
        tipGui.SetFont("s11 cWhite Bold", "Microsoft YaHei UI")
        
        ; 标题
        tipGui.Add("Text", "x20 y15 w320 Center", "🎨 颜色取色器")
        tipGui.SetFont("s10 cWhite", "Microsoft YaHei UI")
        
        ; 操作说明
        tipGui.Add("Text", "x20 y45 w320", "• 移动鼠标到目标颜色位置")
        tipGui.Add("Text", "x20 y70 w320", "• 按 空格键 完成取色")
        tipGui.Add("Text", "x20 y95 w320", "• 按 ESC 取消")
        
        ; 分割线
        tipGui.Add("Text", "x20 y120 w320 h1 Background0x555555")
        
        ; 当前颜色显示
        tipGui.SetFont("s10 cYellow Bold", "Microsoft YaHei UI")
        colorText := tipGui.Add("Text", "x20 y130 w320", "当前颜色: 0x000000")
        
        ; 颜色预览框
        colorBox := tipGui.Add("Progress", "x20 y160 w320 h50 Background0x000000 -Smooth")
        
        tipGui.Show("Center w360 h230")
        
        ; 实时显示鼠标位置的颜色
        currentColor := "0x000000"
        Loop {
            if (GetKeyState("Space", "P")) {
                break
            }
            if (GetKeyState("Escape", "P")) {
                tipGui.Destroy()
                this.mainWindow.Show()
                return
            }
            
            MouseGetPos(&mx, &my)
            currentColor := PixelGetColor(mx, my)
            colorText.Value := "当前颜色: " currentColor
            colorBox.Opt("Background" currentColor)
            Sleep(50)
        }
        
        tipGui.Destroy()
        this.mainWindow.Show()
        
        ; 保存颜色
        this.configManager.SetNested(["auto_start", "target_color"], currentColor)
        this.configManager.Save()
        
        this.logger.Info("目标颜色已设置: " currentColor)
        
        ; 更新状态显示
        this.UpdateAutoStartStatus()
    }
    
    ; 启用/禁用自动启动
    OnAutoStartToggle() {
        enabled := this.mainWindow.autoStartCheck.Value
        
        if (enabled) {
            ; 检查是否已配置
            x1 := this.configManager.GetNested("auto_start", "region_x1")
            color := this.configManager.GetNested("auto_start", "target_color")
            
            if (!x1 || !color) {
                MsgBox("请先完成区域框选和取色设置", "提示", "IconX")
                this.mainWindow.autoStartCheck.Value := 0
                return
            }
            
            ; 启动自动检测
            this.StartAutoStartDetection()
        } else {
            ; 停止自动检测
            this.StopAutoStartDetection()
        }
        
        ; 保存勾选状态
        this.configManager.SetNested(["auto_start", "enabled"], enabled)
        this.configManager.Save()
        this.logger.Info("自动启动勾选状态已保存: " (enabled ? "启用" : "禁用"))
    }
    
    ; 修改检测间隔
    OnAutoStartIntervalChange() {
        interval := this.mainWindow.autoStartInterval.Value
        
        ; 验证范围（至少50ms）
        if (interval < 50) {
            interval := 50
            this.mainWindow.autoStartInterval.Value := interval
        }
        
        ; 保存到配置
        this.configManager.SetNested(["auto_start", "check_interval"], interval)
        this.configManager.Save()
        this.logger.Info("自动启动检测间隔已更新: " interval "ms")
        
        ; 如果正在检测，重启以应用新间隔
        if (this.autoStartTimer && !this.autoStartTriggered) {
            this.StopAutoStartDetection()
            this.StartAutoStartDetection()
            this.logger.Info("检测已重启以应用新间隔")
        }
    }
}

; ===================================================
; 热键定义（从配置读取）
; ===================================================

; 注册热键
RegisterHotkeys() {
    try {
        ; 读取热键配置
        hotkeyMonitor := g_ConfigManager.GetNested("hotkeys", "toggle_monitor")
        hotkeyTestTts := g_ConfigManager.GetNested("hotkeys", "test_tts")
        hotkeyWindow := g_ConfigManager.GetNested("hotkeys", "toggle_window")
        hotkeyReload := g_ConfigManager.GetNested("hotkeys", "reload")
        
        ; 使用默认值（如果配置不存在）
        if (!hotkeyMonitor) {
            hotkeyMonitor := "F5"
        }
        if (!hotkeyTestTts) {
            hotkeyTestTts := "F6"
        }
        if (!hotkeyWindow) {
            hotkeyWindow := "F7"
        }
        if (!hotkeyReload) {
            hotkeyReload := "F8"
        }
        
        ; 注册热键（全局热键）
        if (hotkeyMonitor) {
            try {
                Hotkey(hotkeyMonitor, (*) => ToggleMonitor(), "On")  ; "On"确保热键启用
                g_Logger.Info("✅ 全局热键已注册: " hotkeyMonitor " -> 统一监控")
            } catch as err {
                g_Logger.Error("热键注册失败 " hotkeyMonitor ": " err.Message)
            }
        }
        
        if (hotkeyTestTts) {
            try {
                Hotkey(hotkeyTestTts, (*) => TestTts(), "On")
                g_Logger.Info("✅ 全局热键已注册: " hotkeyTestTts " -> 测试 TTS")
            } catch as err {
                g_Logger.Error("热键注册失败 " hotkeyTestTts ": " err.Message)
            }
        }
        
        if (hotkeyWindow) {
            try {
                Hotkey(hotkeyWindow, (*) => ToggleWindow(), "On")
                g_Logger.Info("✅ 全局热键已注册: " hotkeyWindow " -> 窗口切换")
            } catch as err {
                g_Logger.Error("热键注册失败 " hotkeyWindow ": " err.Message)
            }
        }
        
        if (hotkeyReload) {
            try {
                Hotkey(hotkeyReload, (*) => ReloadProgram(), "On")
                g_Logger.Info("✅ 全局热键已注册: " hotkeyReload " -> 重启程序")
            } catch as err {
                g_Logger.Error("热键注册失败 " hotkeyReload ": " err.Message)
            }
        }
        
        g_Logger.Info("🔥 热键注册完成 - 全局生效（任何窗口都可用）")
        
    } catch as err {
        g_Logger.Error("热键注册失败: " err.Message)
    }
}

; 切换统一监控
ToggleMonitor() {
    ; 检查是否有任何监控在运行
    if (g_Timeline.running || g_OCRMonitor.running) {
        ; 停止所有正在运行的监控
        g_Logger.Info("停止监控（热键）")
        
        statusMsg := "停止监控...`n`n"
        
        if (g_Timeline.running) {
            if (g_Timeline.Stop()) {
                g_Logger.Info("TTS轴已停止")
                statusMsg .= "✓ TTS轴播报已停止`n"
            }
        }
        
    if (g_OCRMonitor.running) {
        if (g_OCRMonitor.Stop()) {
                g_Logger.Info("OCR 监控已停止")
                statusMsg .= "✓ OCR 监控已停止`n"
            }
        }
        
        statusMsg .= "`n停止时间: " FormatTime(, "yyyy-MM-dd HH:mm:ss")
        g_MainWindow.UpdateMonitorStatus(statusMsg)
        g_MainWindow.UpdateStatusBar("DBM 已停止")
        
        ; 恢复按钮状态
        g_MainWindow.startMonitorBtn.Enabled := true
        g_MainWindow.stopMonitorBtn.Enabled := false
        
        ; 不再语音播报停止信息
    } else {
        ; 启动监控（根据勾选的选项）
        dungeonFile := g_MainWindow.dungeonCombo.Text
        enableTimeline := g_MainWindow.enableTimelineCheck.Value
        enableOcr := g_MainWindow.enableOcrCheck.Value
        
        if (!enableTimeline && !enableOcr) {
            ; 不再语音播报提示信息
            return
        }
        
        if (dungeonFile = "") {
            ; 不再语音播报提示信息
            return
        }
        
        ; 调用启动监控方法
        g_App.OnStartMonitor(dungeonFile, enableTimeline, enableOcr)
    }
}

; 测试 TTS
TestTts() {
    g_TTS.Speak("这是一个测试播报", false)  ; 异步播报
}

; 切换窗口
ToggleWindow() {
    try {
        if (WinExist("DBM 播报系统")) {
            if (WinActive("DBM 播报系统")) {
                g_MainWindow.Hide()
            } else {
                g_MainWindow.Show()
            }
        } else {
            g_MainWindow.Show()
        }
    }
}

; ===========================================
; 全局函数
; ===========================================

; 重启程序
ReloadProgram() {
    try {
        g_Logger.Info("🔄 重启程序（热键）")
        Reload  ; 重启当前脚本
    } catch as err {
        g_Logger.Error("重启程序失败: " err.Message)
        MsgBox("重启程序失败:`n" err.Message, "错误", "Icon!")
    }
}

; ===================================================
; 启动程序
; ===================================================

; 创建应用实例
global g_App := DBMApp()
g_App.Init()

; 保存全局引用
global g_TTS := g_App.tts
global g_Timeline := g_App.timeline
global g_OCR := g_App.ocr
global g_OCRMonitor := g_App.ocrMonitor
global g_MainWindow := g_App.mainWindow

; 注册热键
RegisterHotkeys()

; 显示启动提示
hotkeyWindow := g_ConfigManager.GetNested("hotkeys", "toggle_window")
if (!hotkeyWindow) {
    hotkeyWindow := "F12"
}
hotkeyMonitor := g_ConfigManager.GetNested("hotkeys", "toggle_monitor")
if (!hotkeyMonitor) {
    hotkeyMonitor := "F10"
}
; TrayTip("✅ DBM 播报系统已启动", "按 " hotkeyMonitor " 启动/停止监控`n按 " hotkeyWindow " 显示/隐藏主窗口")


