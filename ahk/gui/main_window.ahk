; ===================================================
; 主窗口 GUI
; DBM 播报系统的图形界面
; ===================================================

#Include ..\lib\json.ahk

class MainWindow {
    gui := ""
    
    ; 控件
    tabControl := ""
    
    ; 配置页面控件
    positionListView := ""
    positionSkillEdit := ""
    positionValueEdit := ""
    gameWindowEdit := ""
    ttsRateSlider := ""
    ttsVolumeSlider := ""
    ttsRateText := ""
    ttsVolumeText := ""
    ttsVoiceCombo := ""
    ocrIntervalEdit := ""
    debugModeCheck := ""
    
    ; 监控控制页面控件（合并TTS轴和OCR）
    dungeonCombo := ""
    roleCombo := ""  ; 职能选择
    broadcastAllCheck := ""  ; 全部播报
    enableTimelineCheck := ""
    enableOcrCheck := ""
    showOverlayCheck := ""
    startMonitorBtn := ""
    stopMonitorBtn := ""
    regionTypeCombo := ""
    ocrRegionList := ""
    monitorStatus := ""
    testOcrBtn := ""
    deleteOcrBtn := ""
    
    ; 兼容性：保留旧的引用，指向新控件
    startTimelineBtn := ""
    stopTimelineBtn := ""
    startOcrBtn := ""
    stopOcrBtn := ""
    timelineStatus := ""
    ocrStatus := ""
    timelineLogEdit := ""
    ocrLogEdit := ""
    
    ; 日志页面控件
    logEdit := ""
    
    ; 状态栏
    statusBar := ""
    
    ; 回调对象
    callbacks := Map()
    
    ; 初始化
    __New() {
        this.CreateGui()
    }
    
    ; 创建 GUI
    CreateGui() {
        ; 创建主窗口
        this.gui := Gui("+Resize", "DBM 播报系统")
        this.gui.SetFont("s10", "Microsoft YaHei UI")
        this.gui.BackColor := "0xF0F0F0"
        
        ; 设置最小尺寸
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        
        ; ✅ 点击关闭按钮时退出程序，而不是隐藏窗口
        this.gui.OnEvent("Close", (*) => ExitApp())
        
        ; 创建状态栏（必须先创建，才能自动停靠底部）
        this.statusBar := this.gui.Add("StatusBar")
        this.statusBar.SetText("  就绪")
        
        ; 创建标签页（填满整个客户区，StatusBar约占20像素）
        this.tabControl := this.gui.Add("Tab3", "x0 y0 w910 h695 +Background", 
            ["⚙️ 配置", "⌨️ 热键", "📊 监控控制", "📋 日志", "ℹ️ 关于"])
        
        ; 创建各个标签页
        this.CreateConfigTab()
        this.CreateHotkeyTab()
        this.CreateMonitorTab()
        this.CreateLogTab()
        this.CreateAboutTab()
        
        ; 设置窗口大小
        this.gui.Show("w900 h740 Center")
    }
    
    ; 创建配置标签页
    CreateConfigTab() {
        this.tabControl.UseTab("⚙️ 配置")
        
        ; 当前页面提示
        this.gui.SetFont("s10 bold", "Microsoft YaHei UI")
        this.gui.Add("Text", "x30 y40 w840 h25 Center Background0xE8F4FF c0x0066cc Border", "⚙️ 配置页面")
        this.gui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 游戏窗口设置
        this.gui.Add("GroupBox", "x30 y75 w840 h120", "游戏窗口设置")
        
        this.gui.Add("Text", "x50 y100", "游戏窗口标题:")
        this.gameWindowEdit := this.gui.Add("Edit", "x50 y120 w790", "")
        this.gui.Add("Text", "x50 y150", "(用于框选区域时激活窗口)")
        
        ; TTS 设置组
        this.gui.Add("GroupBox", "x30 y205 w840 h175", "TTS 设置")
        
        this.gui.Add("Text", "x50 y235", "语音选择:")
        this.ttsVoiceCombo := this.gui.Add("DropDownList", "x150 y230 w500", ["正在加载..."])
        this.ttsVoiceCombo.OnEvent("Change", ObjBindMethod(this, "OnTtsVoiceChange"))
        this.gui.Add("Button", "x660 y230 w80 h25", "🔄 刷新").OnEvent("Click", ObjBindMethod(this, "OnRefreshVoices"))
        
        this.gui.Add("Text", "x50 y270", "语速:")
        this.ttsRateSlider := this.gui.Add("Slider", "x150 y265 w500 Range-10-10 TickInterval5", 0)
        this.ttsRateText := this.gui.Add("Text", "x660 y270 w50", "0")
        this.ttsRateSlider.OnEvent("Change", ObjBindMethod(this, "OnTtsRateChange"))
        
        this.gui.Add("Text", "x50 y305", "音量:")
        this.ttsVolumeSlider := this.gui.Add("Slider", "x150 y300 w500 Range0-100 TickInterval10", 100)
        this.ttsVolumeText := this.gui.Add("Text", "x660 y305 w50", "100")
        this.ttsVolumeSlider.OnEvent("Change", ObjBindMethod(this, "OnTtsVolumeChange"))
        
        this.gui.Add("Button", "x50 y340 w150 h30", "🔊 测试 TTS").OnEvent("Click", ObjBindMethod(this, "OnTestTts"))
        
        ; OCR 设置组
        this.gui.Add("GroupBox", "x30 y390 w840 h70", "OCR 设置")
        
        this.gui.Add("Text", "x50 y420", "检查间隔(秒):")
        this.ocrIntervalEdit := this.gui.Add("Edit", "x160 y415 w100", "0.5")
        this.ocrIntervalEdit.OnEvent("Change", ObjBindMethod(this, "OnOcrIntervalChange"))
        this.gui.Add("Text", "x270 y420", "(建议 0.3 - 1.0)")
        
        ; 调试模式
        this.gui.Add("GroupBox", "x30 y475 w840 h60", "调试选项")
        
        this.debugModeCheck := this.gui.Add("Checkbox", "x50 y500", "启用 DEBUG 模式（输出详细日志）")
        this.debugModeCheck.OnEvent("Click", ObjBindMethod(this, "OnDebugModeChange"))
        
        ; 保存配置按钮（放到最后）
        this.gui.Add("Button", "x50 y550 w150 h35", "💾 保存配置").OnEvent("Click", ObjBindMethod(this, "OnSaveConfig"))
        this.gui.Add("Text", "x210 y560", "（保存所有配置项，包括勾选状态）")
        
        this.tabControl.UseTab()
    }
    
    ; 创建热键标签页
    CreateHotkeyTab() {
        this.tabControl.UseTab("⌨️ 热键")
        
        ; 当前页面提示
        this.gui.SetFont("s10 bold", "Microsoft YaHei UI")
        this.gui.Add("Text", "x30 y40 w840 h25 Center Background0xFFF4E8 c0xFF8800 Border", "⌨️ 热键配置页面")
        this.gui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 说明文本
        this.gui.Add("Text", "x30 y75 w830", "配置全局热键（修改后需重启程序生效）:")
        
        ; 热键配置组
        this.gui.Add("GroupBox", "x30 y105 w830 h290", "热键设置")
        
        y := 135
        
        ; 监控热键（合并TTS轴和OCR）
        this.gui.Add("Text", "x50 y" y, "启动/停止监控:")
        this.hotkeyMonitor := this.gui.Add("Edit", "x250 y" (y-5) " w200", "F5")
        this.gui.Add("Text", "x460 y" y, "（启动勾选的监控功能）")
        
        y += 40
        
        ; 测试 TTS 热键
        this.gui.Add("Text", "x50 y" y, "测试 TTS 播报:")
        this.hotkeyTestTts := this.gui.Add("Edit", "x250 y" (y-5) " w200", "F6")
        this.gui.Add("Text", "x460 y" y, "（测试语音播报功能）")
        
        y += 40
        
        ; 窗口热键
        this.gui.Add("Text", "x50 y" y, "显示/隐藏主窗口:")
        this.hotkeyWindow := this.gui.Add("Edit", "x250 y" (y-5) " w200", "F7")
        this.gui.Add("Text", "x460 y" y, "（切换主窗口显示状态）")
        
        y += 40
        
        ; 重启程序热键
        this.gui.Add("Text", "x50 y" y, "重启程序:")
        this.hotkeyReload := this.gui.Add("Edit", "x250 y" (y-5) " w200", "F8")
        this.gui.Add("Text", "x460 y" y, "（关闭并重新启动程序）")
        
        ; 保存按钮
        this.gui.Add("Button", "x50 y415 w150 h35", "💾 保存热键配置").OnEvent("Click", ObjBindMethod(this, "OnSaveHotkeys"))
        this.gui.Add("Button", "x210 y415 w150 h35", "🔄 恢复默认").OnEvent("Click", ObjBindMethod(this, "OnResetHotkeys"))
        
        ; 提示信息
        this.gui.Add("Text", "x30 y465 w830", 
            "提示：`n" .
            "• 热键格式: 单个按键(如 F1)、组合键(如 ^!F1 表示 Ctrl+Alt+F1)`n" .
            "• 修饰符: ^ = Ctrl, ! = Alt, + = Shift, # = Win`n" .
            "• 鼠标侧键: XButton1 = 鼠标侧键1(后退), XButton2 = 鼠标侧键2(前进)`n" .
            "• 启动监控热键将根据监控选项启动TTS轴和/或OCR监控`n" .
            "• 保存后需要重启程序才能生效")
        
        this.tabControl.UseTab()
    }
    
    ; 创建监控控制标签页（合并TTS轴和OCR）
    CreateMonitorTab() {
        this.tabControl.UseTab("📊 监控控制")
        
        ; 当前页面提示
        this.gui.SetFont("s10 bold", "Microsoft YaHei UI")
        this.gui.Add("Text", "x30 y40 w840 h25 Center Background0xE8FFE8 c0x00AA00 Border", "📊 监控控制页面")
        this.gui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 副本选择组
        this.gui.Add("GroupBox", "x30 y75 w860 h110", "副本管理")
        
        this.gui.Add("Text", "x50 y100", "副本:")
        this.dungeonCombo := this.gui.Add("DropDownList", "x110 y95 w480")
        this.dungeonCombo.OnEvent("Change", ObjBindMethod(this, "OnDungeonChange"))
        
        this.gui.Add("Button", "x600 y95 w60 h28", "➕ 新建").OnEvent("Click", ObjBindMethod(this, "OnNewDungeon"))
        this.gui.Add("Button", "x670 y95 w60 h28", "📝 编辑").OnEvent("Click", ObjBindMethod(this, "OnEditDungeon"))
        this.gui.Add("Button", "x740 y95 w60 h28", "🗑️ 删除").OnEvent("Click", ObjBindMethod(this, "OnDeleteDungeon"))
        this.gui.Add("Button", "x810 y95 w60 h28", "🔄 刷新").OnEvent("Click", ObjBindMethod(this, "OnRefreshDungeons"))
        
        ; 队伍和职业选择
        this.gui.Add("Text", "x50 y130", "队伍:")
        this.partyCombo := this.gui.Add("DropDownList", "x110 y125 w100", ["全部", "1队", "2队"])
        this.partyCombo.Choose(1)  ; 默认选择"全部"
        this.partyCombo.OnEvent("Change", ObjBindMethod(this, "OnPartyChange"))
        
        this.gui.Add("Text", "x230 y130", "职能:")
        this.roleCombo := this.gui.Add("DropDownList", "x280 y125 w150", ["全部", "T", "N", "D", "MT", "H1", "D1", "D2", "ST", "H2", "D3", "D4"])
        this.roleCombo.Choose(1)  ; 默认选择"全部"
        this.roleCombo.OnEvent("Change", ObjBindMethod(this, "OnRoleChange"))
        
        this.broadcastAllCheck := this.gui.Add("Checkbox", "x450 y125 w150", "全部播报")
        this.broadcastAllCheck.OnEvent("Click", ObjBindMethod(this, "OnBroadcastAllChange"))
        
        this.gui.Add("Text", "x50 y160", "说明：选择你的队伍和职能后，只会播报相关内容。勾选全部播报将忽略职能限制。")
        
        ; 监控选项组
        this.gui.Add("GroupBox", "x30 y195 w860 h110", "监控选项")
        
        this.enableTimelineCheck := this.gui.Add("Checkbox", "x50 y220 w200", "✓ 启用TTS轴播报")
        this.enableTimelineCheck.Value := 1  ; 默认勾选
        this.enableTimelineCheck.OnEvent("Click", ObjBindMethod(this, "OnMonitorOptionChange"))
        
        this.enableOcrCheck := this.gui.Add("Checkbox", "x50 y245 w200", "✓ 启用OCR监控")
        this.enableOcrCheck.Value := 1  ; 默认勾选
        this.enableOcrCheck.OnEvent("Click", ObjBindMethod(this, "OnMonitorOptionChange"))
        
        this.showOverlayCheck := this.gui.Add("Checkbox", "x50 y270 w200", "✓ 显示技能倒计时")
        this.showOverlayCheck.Value := 1  ; 默认勾选
        this.showOverlayCheck.OnEvent("Click", ObjBindMethod(this, "OnMonitorOptionChange"))
        
        this.gui.Add("Button", "x260 y267 w120 h26", "📍 悬浮窗设置").OnEvent("Click", ObjBindMethod(this, "OnSetOverlayPosition"))
        
        this.gui.Add("Text", "x400 y220", "（根据副本规则，在指定时间点播报技能）")
        this.gui.Add("Text", "x400 y245", "（实时识别屏幕文字，触发相应播报）")
        this.gui.Add("Text", "x400 y270", "（屏幕上显示悬浮倒计时窗口）")
        
        ; 统一控制按钮
        this.gui.Add("GroupBox", "x30 y315 w860 h100", "监控控制")
        
        this.startMonitorBtn := this.gui.Add("Button", "x50 y340 w120 h28", "▶️ 启动监控")
        this.startMonitorBtn.OnEvent("Click", ObjBindMethod(this, "OnStartMonitor"))
        
        this.stopMonitorBtn := this.gui.Add("Button", "x180 y340 w120 h28", "⏹️ 停止监控")
        this.stopMonitorBtn.OnEvent("Click", ObjBindMethod(this, "OnStopMonitor"))
        this.stopMonitorBtn.Enabled := false  ; 初始禁用
        
        this.gui.Add("Button", "x310 y340 w120 h28", "🔄 重载配置").OnEvent("Click", ObjBindMethod(this, "OnReloadOcrConfig"))
        
        ; 自动启动功能
        this.gui.Add("Text", "x50 y377", "🎯 自动启动:")
        this.autoStartCheck := this.gui.Add("Checkbox", "x140 y377 w80", "启用")
        this.autoStartCheck.OnEvent("Click", ObjBindMethod(this, "OnAutoStartToggle"))
        
        this.gui.Add("Button", "x230 y372 w100 h28", "📐 框选区域").OnEvent("Click", ObjBindMethod(this, "OnSelectAutoStartRegion"))
        this.gui.Add("Button", "x340 y372 w100 h28", "🎨 取色设置").OnEvent("Click", ObjBindMethod(this, "OnSetAutoStartColor"))
        
        this.gui.Add("Text", "x450 y377", "检测间隔:")
        this.autoStartInterval := this.gui.Add("Edit", "x515 y372 w50 h28 Number", "200")
        this.gui.Add("Text", "x570 y377", "ms")
        this.autoStartInterval.OnEvent("Change", ObjBindMethod(this, "OnAutoStartIntervalChange"))
        
        this.autoStartStatus := this.gui.Add("Text", "x610 y377 w240", "未配置")
        this.autoStartStatus.SetFont("c808080")
        
        ; OCR 区域配置
        this.gui.Add("GroupBox", "x30 y420 w860 h165", "OCR 区域配置")
        
        this.gui.Add("Text", "x50 y445", "选择区域类型:")
        this.regionTypeCombo := this.gui.Add("DropDownList", "x150 y440 w150", 
            ["BOSS台词区", "BOSS血条区", "BOSS技能区"])
        this.regionTypeCombo.Choose(1)
        this.gui.Add("Button", "x320 y440 w100 h28", "📐 框选区域").OnEvent("Click", ObjBindMethod(this, "OnSelectRegion"))
        
        this.gui.Add("Text", "x50 y480", "已配置的 OCR 区域:")
        this.ocrRegionList := this.gui.Add("ListView", "x50 y505 w720 h65 -Multi", 
            ["区域名称", "X1", "Y1", "X2", "Y2", "状态"])
        this.ocrRegionList.ModifyCol(1, 130)
        this.ocrRegionList.ModifyCol(2, 100)
        this.ocrRegionList.ModifyCol(3, 100)
        this.ocrRegionList.ModifyCol(4, 100)
        this.ocrRegionList.ModifyCol(5, 100)
        this.ocrRegionList.ModifyCol(6, 90)
        
        ; 添加操作按钮
        this.testOcrBtn := this.gui.Add("Button", "x780 y505 w90 h30", "🔍 测试")
        this.testOcrBtn.OnEvent("Click", ObjBindMethod(this, "OnTestOcrRegion"))
        
        this.deleteOcrBtn := this.gui.Add("Button", "x780 y540 w90 h30", "🗑️ 删除")
        this.deleteOcrBtn.OnEvent("Click", ObjBindMethod(this, "OnDeleteOcrRegion"))
        
        ; 监控状态显示
        this.gui.Add("GroupBox", "x30 y590 w860 h105", "监控状态")
        
        this.monitorStatus := this.gui.Add("Edit", "x50 y615 w800 h70 +Multi ReadOnly -WantReturn", 
            "监控未启动 - 请选择副本，勾选监控选项，然后点击 启动监控")
        
        ; 初始化职能选项（根据默认队伍"全部"）
        this.UpdateRoleOptions()
        
        this.tabControl.UseTab()
    }
    
    ; 创建日志标签页
    CreateLogTab() {
        this.tabControl.UseTab("📋 日志")
        
        ; 当前页面提示
        this.gui.SetFont("s10 bold", "Microsoft YaHei UI")
        this.gui.Add("Text", "x30 y40 w840 h25 Center Background0xFFF0F0 c0xDD0000 Border", "📋 日志查看页面")
        this.gui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 日志显示区域
        this.gui.Add("Text", "x30 y75", "系统日志（自动更新）:")
        
        this.logEdit := this.gui.Add("Edit", "x30 y100 w830 h450 ReadOnly +VScroll", "")
        
        ; 按钮组
        btnY := 580
        this.gui.Add("Button", "x30 y" btnY " w100", "清空日志").OnEvent("Click", ObjBindMethod(this, "OnClearLog"))
        this.gui.Add("Button", "x140 y" btnY " w100", "导出日志").OnEvent("Click", ObjBindMethod(this, "OnExportLog"))
        this.gui.Add("Button", "x250 y" btnY " w100", "刷新").OnEvent("Click", ObjBindMethod(this, "OnRefreshLog"))
        
        this.tabControl.UseTab()
    }
    
    ; 创建关于标签页
    CreateAboutTab() {
        this.tabControl.UseTab("ℹ️ 关于")
        
        aboutText := "
        (
        ╔════════════════════════════════════════╗
                                                
                                        DBM 播报系统 v1.0.0              
                                                
                                    基于 AutoHotkey v2 开发             
                                                
        ╚════════════════════════════════════════╝
        
        
        【主要功能】
        
        • 副本TTS轴自动播报
        • OCR 文字识别触发器
        • TTS 实时语音播报
        • 技能倒计时悬浮窗
        • 技能站位自动提示
        • 职能过滤播报
        
        
        【使用说明】
        
        1. 在"监控控制"页面选择副本
        2. 勾选需要的监控功能（TTS轴/OCR/倒计时）
        3. 点击副本的"编辑"按钮配置TTS轴和触发器
        4. 按热键启动监控
        
        
        【热键说明】
        
        F5 - 启动/停止监控（TTS轴+OCR）
        F6 - 测试 TTS 播报
        F7 - 显示/隐藏主窗口
        F8 - 重启程序
        
        （可在"热键"页面自定义修改）
        
        
        【核心特性】
        
        • TTS轴与倒计时条独立配置
        • 支持技能站位占位符 {position}
        • 职能过滤：MT/ST/H/D 分别播报
        • 倒计时悬浮窗可拖动调整大小
        • 支持 BOSS 台词/血条/技能三种 OCR 触发
        
        
        【技术支持】
        
        • OCR 识别：RapidOCR
        • 语音播报：Windows SAPI
        • 开发语言：AutoHotkey v2
        )"
        
        this.gui.Add("Edit", "x30 y50 w730 h490 ReadOnly -Wrap +VScroll", aboutText)
        
        this.tabControl.UseTab()
    }
    
    ; 窗口大小改变事件
    OnResize(guiObj, minMax, width, height) {
        if (minMax = -1) {  ; 最小化
            return
        }
        
        ; 调整标签页大小（填满整个客户区，StatusBar自动停靠底部占约20像素）
        if (this.tabControl) {
            this.tabControl.Move(0, 0, width, height - 20)
        }
    }
    
    ; TTS 语速改变事件
    OnTtsRateChange(ctrl, info) {
        value := ctrl.Value
        this.ttsRateText.Value := value
        
        ; 调用回调
        if (this.callbacks.Has("OnTtsRateChange")) {
            this.callbacks["OnTtsRateChange"](value)
        }
    }
    
    ; TTS 音量改变事件
    OnTtsVolumeChange(ctrl, info) {
        value := ctrl.Value
        this.ttsVolumeText.Value := value
        
        ; 调用回调
        if (this.callbacks.Has("OnTtsVolumeChange")) {
            this.callbacks["OnTtsVolumeChange"](value)
        }
    }
    
    ; TTS 语音改变事件
    OnTtsVoiceChange(ctrl, info) {
        voiceText := ctrl.Text
        
        ; 调用回调
        if (this.callbacks.Has("OnTtsVoiceChange")) {
            this.callbacks["OnTtsVoiceChange"](voiceText)
        }
    }
    
    ; 刷新语音列表
    OnRefreshVoices(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnRefreshVoices")) {
            this.callbacks["OnRefreshVoices"]()
        }
    }
    
    ; 保存配置按钮
    OnSaveConfig(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnSaveConfig")) {
            this.callbacks["OnSaveConfig"]()
        }
    }
    
    ; 测试 TTS 按钮
    OnTestTts(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnTestTts")) {
            this.callbacks["OnTestTts"]()
        }
    }
    
    ; 刷新副本列表按钮
    OnRefreshDungeons(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnRefreshDungeons")) {
            this.callbacks["OnRefreshDungeons"]()
        }
    }
    
    ; 副本切换事件
    OnDungeonChange(ctrl, info) {
        ; 调用回调立即保存配置
        if (this.callbacks.Has("OnDungeonChange")) {
            this.callbacks["OnDungeonChange"](ctrl.Text)
        }
    }
    
    ; 监控选项改变时自动保存
    OnMonitorOptionChange(ctrl, info) {
        ; 调用回调立即保存配置
        if (this.callbacks.Has("OnMonitorOptionChange")) {
            this.callbacks["OnMonitorOptionChange"]()
        }
    }
    
    ; 队伍选择改变时自动保存
    OnPartyChange(ctrl, info) {
        ; 根据队伍更新职业选项
        this.UpdateRoleOptions()
        
        ; 调用回调立即保存配置
        if (this.callbacks.Has("OnPartyChange")) {
            this.callbacks["OnPartyChange"]()
        }
    }
    
    ; 根据队伍选择更新职业选项
    UpdateRoleOptions() {
        partyText := this.partyCombo.Text
        currentRole := this.roleCombo.Text
        
        if (partyText = "1队") {
            ; 1队：MT、H1、D1、D2 + T/N/D角色组
            this.roleCombo.Delete()
            this.roleCombo.Add(["全部", "T", "N", "D", "MT", "H1", "D1", "D2"])
            ; 尝试保持选择，如果当前选择不在新列表中，则选择"全部"
            if (currentRole = "全部" || currentRole = "T" || currentRole = "N" || currentRole = "D" || currentRole = "MT" || currentRole = "H1" || currentRole = "D1" || currentRole = "D2") {
                roleMap := Map("全部", 1, "T", 2, "N", 3, "D", 4, "MT", 5, "H1", 6, "D1", 7, "D2", 8)
                if (roleMap.Has(currentRole)) {
                    this.roleCombo.Choose(roleMap[currentRole])
                } else {
                    this.roleCombo.Choose(1)
                }
            } else {
                this.roleCombo.Choose(1)
            }
        } else if (partyText = "2队") {
            ; 2队：ST、H2、D3、D4 + T/N/D角色组
            this.roleCombo.Delete()
            this.roleCombo.Add(["全部", "T", "N", "D", "ST", "H2", "D3", "D4"])
            ; 尝试保持选择
            if (currentRole = "全部" || currentRole = "T" || currentRole = "N" || currentRole = "D" || currentRole = "ST" || currentRole = "H2" || currentRole = "D3" || currentRole = "D4") {
                roleMap := Map("全部", 1, "T", 2, "N", 3, "D", 4, "ST", 5, "H2", 6, "D3", 7, "D4", 8)
                if (roleMap.Has(currentRole)) {
                    this.roleCombo.Choose(roleMap[currentRole])
                } else {
                    this.roleCombo.Choose(1)
                }
            } else {
                this.roleCombo.Choose(1)
            }
        } else {
            ; 全部：显示所有职业 + T/N/D角色组
            this.roleCombo.Delete()
            this.roleCombo.Add(["全部", "T", "N", "D", "MT", "H1", "D1", "D2", "ST", "H2", "D3", "D4"])
            ; 尝试保持选择
            roleMap := Map("全部", 1, "T", 2, "N", 3, "D", 4, "MT", 5, "H1", 6, "D1", 7, "D2", 8, "ST", 9, "H2", 10, "D3", 11, "D4", 12)
            if (roleMap.Has(currentRole)) {
                this.roleCombo.Choose(roleMap[currentRole])
            } else {
                this.roleCombo.Choose(1)
            }
        }
    }
    
    ; 职业选择改变时自动保存
    OnRoleChange(ctrl, info) {
        ; 调用回调立即保存配置
        if (this.callbacks.Has("OnRoleChange")) {
            this.callbacks["OnRoleChange"]()
        }
    }
    
    ; 全部播报复选框变化
    OnBroadcastAllChange(ctrl, info) {
        ; 调用回调立即保存配置
        if (this.callbacks.Has("OnBroadcastAllChange")) {
            this.callbacks["OnBroadcastAllChange"]()
        }
    }
    
    ; 启动统一监控按钮
    OnStartMonitor(ctrl, info) {
        dungeonFile := this.dungeonCombo.Text
        enableTimeline := this.enableTimelineCheck.Value
        enableOcr := this.enableOcrCheck.Value
        
        ; 调用回调
        if (this.callbacks.Has("OnStartMonitor")) {
            this.callbacks["OnStartMonitor"](dungeonFile, enableTimeline, enableOcr)
        }
    }
    
    ; 设置倒计时条位置
    OnSetOverlayPosition(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnSetOverlayPosition")) {
            this.callbacks["OnSetOverlayPosition"]()
        }
    }
    
    ; 停止统一监控按钮
    OnStopMonitor(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnStopMonitor")) {
            this.callbacks["OnStopMonitor"]()
        }
    }
    
    ; 兼容性：保留旧的方法名，重定向到新方法
    OnStartTimeline(ctrl, info) {
        this.OnStartMonitor(ctrl, info)
    }
    
    OnStopTimeline(ctrl, info) {
        this.OnStopMonitor(ctrl, info)
    }
    
    OnStartOcr(ctrl, info) {
        this.OnStartMonitor(ctrl, info)
    }
    
    OnStopOcr(ctrl, info) {
        this.OnStopMonitor(ctrl, info)
    }
    
    ; 重新加载 OCR 配置按钮
    OnReloadOcrConfig(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnReloadOcrConfig")) {
            this.callbacks["OnReloadOcrConfig"]()
        }
    }
    
    ; 框选区域按钮
    OnSelectRegion(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnSelectRegion")) {
            this.callbacks["OnSelectRegion"]()
        }
    }
    
    ; 测试OCR区域按钮
    OnTestOcrRegion(ctrl, info) {
        ; 获取选中的行
        selectedRow := this.ocrRegionList.GetNext(0, "Focused")
        
        if (selectedRow = 0) {
            MsgBox("请先选择一个OCR区域", "提示", "Icon!")
            return
        }
        
        ; 调用回调
        if (this.callbacks.Has("OnTestOcrRegion")) {
            this.callbacks["OnTestOcrRegion"](selectedRow)
        }
    }
    
    ; 新建副本按钮
    OnNewDungeon(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnNewDungeon")) {
            this.callbacks["OnNewDungeon"]()
        }
    }
    
    ; 编辑副本按钮
    OnEditDungeon(ctrl, info) {
        dungeonFile := this.dungeonCombo.Text
        
        if (dungeonFile = "") {
            MsgBox("请先选择副本", "提示", "Icon!")
            return
        }
        
        ; 调用回调
        if (this.callbacks.Has("OnEditDungeon")) {
            this.callbacks["OnEditDungeon"](dungeonFile)
        }
    }
    
    ; 删除副本按钮
    OnDeleteDungeon(ctrl, info) {
        dungeonFile := this.dungeonCombo.Text
        
        if (dungeonFile = "") {
            MsgBox("请先选择副本", "提示", "Icon!")
            return
        }
        
        ; 调用回调
        if (this.callbacks.Has("OnDeleteDungeon")) {
            this.callbacks["OnDeleteDungeon"](dungeonFile)
        }
    }
    
    ; 删除OCR区域按钮
    OnDeleteOcrRegion(ctrl, info) {
        ; 获取选中的行
        selectedRow := this.ocrRegionList.GetNext(0, "Focused")
        
        if (selectedRow = 0) {
            MsgBox("请先选择一个OCR区域", "提示", "Icon!")
            return
        }
        
        ; 调用回调
        if (this.callbacks.Has("OnDeleteOcrRegion")) {
            this.callbacks["OnDeleteOcrRegion"](selectedRow)
        }
    }
    
    ; DEBUG 模式改变
    OnDebugModeChange(ctrl, info) {
        enabled := ctrl.Value
        
        ; 调用回调
        if (this.callbacks.Has("OnDebugModeChange")) {
            this.callbacks["OnDebugModeChange"](enabled)
        }
    }
    
    ; 清空日志
    OnClearLog(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnClearLog")) {
            this.callbacks["OnClearLog"]()
        }
    }
    
    ; 导出日志
    OnExportLog(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnExportLog")) {
            this.callbacks["OnExportLog"]()
        }
    }
    
    ; 刷新日志
    OnRefreshLog(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnRefreshLog")) {
            this.callbacks["OnRefreshLog"]()
        }
    }
    
    ; 保存热键配置
    OnSaveHotkeys(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnSaveHotkeys")) {
            this.callbacks["OnSaveHotkeys"]()
        }
    }
    
    ; 恢复默认热键
    OnResetHotkeys(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnResetHotkeys")) {
            this.callbacks["OnResetHotkeys"]()
        }
    }
    
    ; OCR 间隔改变
    OnOcrIntervalChange(ctrl, info) {
        ; 调用回调
        if (this.callbacks.Has("OnOcrIntervalChange")) {
            this.callbacks["OnOcrIntervalChange"](ctrl.Value)
        }
    }
    
    ; 设置回调
    SetCallback(name, func) {
        this.callbacks[name] := func
    }
    
    ; 更新副本列表
    UpdateDungeonList(dungeons) {
        this.dungeonCombo.Delete()
        
        for dungeon in dungeons {
            this.dungeonCombo.Add([dungeon])
        }
    }
    
    ; 更新监控状态
    UpdateMonitorStatus(status) {
        this.monitorStatus.Value := status
    }
    
    ; 兼容性：保留旧方法，重定向到新方法
    UpdateTimelineStatus(status) {
        this.UpdateMonitorStatus(status)
    }
    
    UpdateOcrStatus(status) {
        this.UpdateMonitorStatus(status)
    }
    
    ; 更新 OCR 区域列表
    UpdateOcrRegions(regions) {
        this.ocrRegionList.Delete()
        
        for name, config in regions {
            status := config.Has("enabled") && config["enabled"] ? "✓ 启用" : "✗ 禁用"
            displayName := config.Has("name") ? config["name"] : name
            
            this.ocrRegionList.Add("", displayName, 
                config.Has("x1") ? config["x1"] : "", 
                config.Has("y1") ? config["y1"] : "",
                config.Has("x2") ? config["x2"] : "",
                config.Has("y2") ? config["y2"] : "",
                status)
        }
    }
    
    ; 更新状态栏
    UpdateStatusBar(text) {
        this.statusBar.SetText("  " text)
    }
    
    ; 显示消息框
    ShowMessage(title, message, type := "Info") {
        switch type {
            case "Info":
                MsgBox(message, title, "Icon!")
            case "Success":
                MsgBox(message, title, "Iconi")
            case "Warning":
                MsgBox(message, title, "Icon!")
            case "Error":
                MsgBox(message, title, "IconX")
        }
    }
    
    ; 加载配置
    LoadConfig(config) {
        ; 加载游戏窗口设置
        if (config.Has("game")) {
            game := config["game"]
            
            if (game.Has("window_title")) {
                this.gameWindowEdit.Value := game["window_title"]
            }
        }
        
        ; 加载玩家队伍和职业
        if (config.Has("player")) {
            player := config["player"]
            
            ; 加载队伍
            if (player.Has("party")) {
                partyMap := Map("all", 1, "1", 2, "2", 3)
                party := player["party"]
                if (partyMap.Has(party)) {
                    this.partyCombo.Choose(partyMap[party])
                }
            }
            
            ; 更新职能选项（根据队伍）
            this.UpdateRoleOptions()
            
            ; 加载职业（在更新职能选项后）
            if (player.Has("role")) {
                ; 根据当前队伍选择，使用正确的映射
                partyText := this.partyCombo.Text
                role := player["role"]
                
                if (partyText = "1队") {
                    ; 1队的职能映射
                    roleMap := Map("all", 1, "T", 2, "N", 3, "D", 4, "MT", 5, "H1", 6, "D1", 7, "D2", 8)
                } else if (partyText = "2队") {
                    ; 2队的职能映射
                    roleMap := Map("all", 1, "T", 2, "N", 3, "D", 4, "ST", 5, "H2", 6, "D3", 7, "D4", 8)
                } else {
                    ; 全部的职能映射
                    roleMap := Map("all", 1, "T", 2, "N", 3, "D", 4, "MT", 5, "H1", 6, "D1", 7, "D2", 8, "ST", 9, "H2", 10, "D3", 11, "D4", 12)
                }
                
                if (roleMap.Has(role)) {
                    this.roleCombo.Choose(roleMap[role])
                }
            }
            
            ; 加载全部播报设置
            if (player.Has("broadcast_all")) {
                this.broadcastAllCheck.Value := player["broadcast_all"]
            }
        }
        
        ; 加载 TTS 设置
        if (config.Has("tts")) {
            tts := config["tts"]
            
            if (tts.Has("rate")) {
                this.ttsRateSlider.Value := tts["rate"]
                this.ttsRateText.Value := tts["rate"]
            }
            
            if (tts.Has("volume")) {
                this.ttsVolumeSlider.Value := tts["volume"]
                this.ttsVolumeText.Value := tts["volume"]
            }
            
            ; 语音设置会在加载语音列表时处理
        }
        
        ; 加载 OCR 设置
        if (config.Has("ocr")) {
            ocr := config["ocr"]
            
            if (ocr.Has("check_interval")) {
                ; 格式化浮点数，保留2位小数
                interval := Round(Float(ocr["check_interval"]), 2)
                this.ocrIntervalEdit.Value := Format("{:.2f}", interval)
            }
        }
        
        ; 加载监控选项（勾选状态）
        if (config.Has("monitor")) {
            monitor := config["monitor"]
            
            if (monitor.Has("enable_timeline")) {
                this.enableTimelineCheck.Value := monitor["enable_timeline"]
            }
            
            if (monitor.Has("enable_ocr")) {
                this.enableOcrCheck.Value := monitor["enable_ocr"]
            }
            
            if (monitor.Has("show_timeline_overlay")) {
                this.showOverlayCheck.Value := monitor["show_timeline_overlay"]
            }
        }
        
        ; 加载日志设置
        if (config.Has("logging")) {
            logging := config["logging"]
            
            if (logging.Has("debug_mode")) {
                this.debugModeCheck.Value := logging["debug_mode"]
            }
        }
        
        ; 加载热键设置
        if (config.Has("hotkeys")) {
            this.LoadHotkeys(config["hotkeys"])
        }
    }
    
    ; 获取配置值
    GetConfigValues() {
        config := Map()
        
        ; 游戏窗口设置
        config["game"] := Map(
            "window_title", this.gameWindowEdit.Value
        )
        
        ; 玩家队伍和职业
        partyText := this.partyCombo.Text
        partyValue := "all"
        if (partyText = "1队") {
            partyValue := "1"
        } else if (partyText = "2队") {
            partyValue := "2"
        }
        
        roleText := this.roleCombo.Text
        roleValue := "all"
        if (roleText = "MT" || roleText = "H1" || roleText = "D1" || roleText = "D2" || roleText = "ST" || roleText = "H2" || roleText = "D3" || roleText = "D4") {
            roleValue := roleText
        }
        
        config["player"] := Map("party", partyValue, "role", roleValue)
        
        ; 监控选项（勾选状态）
        config["monitor"] := Map(
            "enable_timeline", this.enableTimelineCheck.Value,
            "enable_ocr", this.enableOcrCheck.Value,
            "show_timeline_overlay", this.showOverlayCheck.Value
        )
        
        ; TTS 设置
        config["tts"] := Map(
            "rate", this.ttsRateSlider.Value,
            "volume", this.ttsVolumeSlider.Value,
            "voice", this.ttsVoiceCombo.Text
        )
        
        ; OCR 设置
        config["ocr"] := Map(
            "check_interval", Round(Float(this.ocrIntervalEdit.Value), 2)
        )
        
        ; 日志设置
        config["logging"] := Map(
            "debug_mode", this.debugModeCheck.Value
        )
        
        ; 热键设置
        config["hotkeys"] := Map(
            "toggle_monitor", this.hotkeyMonitor.Value,
            "test_tts", this.hotkeyTestTts.Value,
            "toggle_window", this.hotkeyWindow.Value,
            "reload", this.hotkeyReload.Value
        )
        
        return config
    }
    
    ; 加载热键配置
    LoadHotkeys(hotkeys) {
        if (hotkeys.Has("toggle_monitor")) {
            this.hotkeyMonitor.Value := hotkeys["toggle_monitor"]
        } else if (hotkeys.Has("start_timeline")) {
            ; 兼容旧配置
            this.hotkeyMonitor.Value := hotkeys["start_timeline"]
        }
        if (hotkeys.Has("test_tts")) {
            this.hotkeyTestTts.Value := hotkeys["test_tts"]
        }
        if (hotkeys.Has("toggle_window")) {
            this.hotkeyWindow.Value := hotkeys["toggle_window"]
        }
        if (hotkeys.Has("reload")) {
            this.hotkeyReload.Value := hotkeys["reload"]
        }
    }
    
    ; 重置热键为默认值
    ResetHotkeys() {
        this.hotkeyMonitor.Value := "F5"
        this.hotkeyTestTts.Value := "F6"
        this.hotkeyWindow.Value := "F7"
        this.hotkeyReload.Value := "F8"
    }
    
    ; 获取主日志控件
    GetLogControl() {
        return this.logEdit
    }
    
    ; 获取TTS轴日志控件（兼容性）
    GetTimelineLogControl() {
        return this.logEdit
    }
    
    ; 获取 OCR 日志控件（兼容性）
    GetOcrLogControl() {
        return this.logEdit
    }
    
    ; 显示窗口
    Show() {
        this.gui.Show()
    }
    
    ; 隐藏窗口
    Hide() {
        this.gui.Hide()
    }
    
    ; 销毁窗口
    Destroy() {
        this.gui.Destroy()
    }
    
    ; ===========================================
    ; 自动启动功能事件处理
    ; ===========================================
    
    ; 框选自动启动区域
    OnSelectAutoStartRegion(*) {
        global g_App
        g_App.OnSelectAutoStartRegion()
    }
    
    ; 取色设置
    OnSetAutoStartColor(*) {
        global g_App
        g_App.OnSetAutoStartColor()
    }
    
    ; 启用/禁用自动启动
    OnAutoStartToggle(*) {
        global g_App
        g_App.OnAutoStartToggle()
    }
    
    ; 修改检测间隔
    OnAutoStartIntervalChange(*) {
        global g_App
        g_App.OnAutoStartIntervalChange()
    }
}


