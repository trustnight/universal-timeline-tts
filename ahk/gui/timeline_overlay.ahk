; TTS轴悬浮窗 - 显示技能倒计时
class TimelineOverlay {
    gui := ""
    eventBars := []  ; 存储3个技能条的控件
    isVisible := false
    isPreviewMode := false  ; 预览模式（可拖动）
    
    ; 配置
    x := 100
    y := 100
    width := 400
    height := 120  ; 3个技能条，每个40px高
    opacity := 220  ; 窗口透明度 (0-255)
    bgColor := "0x010101"  ; 背景颜色
    barBgColor := "0x333333"  ; 进度条背景颜色
    barColor := "0xFFFFFF"  ; 进度条前景颜色
    skillTextColor := "0xFFFFFF"  ; 技能文字颜色
    timeTextColor := "0xFFFF00"  ; 倒计时文字颜色
    
    configManager := ""
    resizeTimer := ""  ; 防抖定时器
    saveTimer := ""  ; 保存定时器
    
    __New(configManager) {
        this.configManager := configManager
        this.LoadPosition()
        this.CreateGui()
    }
    
    ; 创建GUI（游戏风格）- 预创建最多5个技能条
    CreateGui() {
        ; 创建无边框置顶窗口（支持调整大小）- 移除边框和白边
        this.gui := Gui("+AlwaysOnTop +ToolWindow -Caption +Resize -DPIScale")
        this.gui.BackColor := "0x010101"  ; 设置为接近黑色，用于透明
        this.gui.SetFont("s10 Bold", "Microsoft YaHei UI")
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        
        ; 预创建最多5个技能条（根据需要显示）
        this.maxBars := 5
        this.barHeight := 40  ; 每个技能条固定高度
        this.eventBars := []
        
        Loop this.maxBars {
            yPos := (A_Index - 1) * this.barHeight
            
            ; ✅ 进度条（从右往左消失，默认隐藏）
            progressBar := this.gui.Add("Progress", "x0 y" yPos " w" this.width " h" this.barHeight " Background" this.barBgColor " c" this.barColor " -Smooth Hidden", 100)
            
            ; 左侧图标（圆形，默认隐藏）
            iconText := this.gui.Add("Text", "x10 y" (yPos + this.barHeight//2 - 15) " w30 h30 Center BackgroundTrans c" this.skillTextColor " Hidden", "●")
            iconText.SetFont("s16")
            ; ✅ 图标也能拖动
            iconText.OnEvent("Click", (*) => this.StartDrag())
            
            ; 技能名称文本（中间偏左，默认隐藏）
            skillText := this.gui.Add("Text", "x45 y" (yPos + this.barHeight//2 - 10) " w200 h20 BackgroundTrans c" this.skillTextColor " Hidden", "")
            skillText.SetFont("s10 Bold")
            ; ✅ 技能名称也能拖动
            skillText.OnEvent("Click", (*) => this.StartDrag())
            
            ; 倒计时文本（右侧，更大更醒目，默认隐藏）
            timeText := this.gui.Add("Text", "x250 y" (yPos + this.barHeight//2 - 12) " w50 h25 Right BackgroundTrans c" this.timeTextColor " Hidden", "")
            timeText.SetFont("s12 Bold")
            ; ✅ 倒计时也能拖动
            timeText.OnEvent("Click", (*) => this.StartDrag())
            
            ; 存储控件
            this.eventBars.Push(Map(
                "progress", progressBar,
                "icon", iconText,
                "skillText", skillText,
                "timeText", timeText,
                "yPos", yPos,
                "visible", false,
                "warningState", ""  ; 用于跟踪警告状态，避免重复设置颜色
            ))
        }
        
        ; 设置背景色透明，移除窗口边框
        WinSetTransColor("0xffffff", this.gui)
        
        ; 监听窗口大小改变事件
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        
        ; 右键菜单
        this.gui.OnEvent("ContextMenu", (*) => this.ShowContextMenu())
    }
    
    ; 窗口大小改变事件 - 不重新创建GUI，只调整控件
    OnResize(guiObj, minMax, width, height) {
        if (minMax = -1 || !this.isPreviewMode) {  ; 最小化或非预览模式
            return
        }
        
        ; 更新尺寸
        this.width := width
        this.height := height
        
        ; ⚠️ 防抖：减少延迟提高响应速度
        ; 取消之前的定时器
        if (this.resizeTimer) {
            SetTimer(this.resizeTimer, 0)
        }
        
        ; 延迟30ms后才调整控件，快速响应拉伸
        this.resizeTimer := () => this.ApplyResize(width, height)
        SetTimer(this.resizeTimer, -30)
        
        ; 延迟保存大小（拉伸停止后1秒保存）
        if (this.saveTimer) {
            SetTimer(this.saveTimer, 0)
        }
        this.saveTimer := () => this.SavePosition()
        SetTimer(this.saveTimer, -1000)
    }
    
    ; 应用窗口尺寸调整（防抖后执行）
    ApplyResize(width, height) {
        if (!this.isPreviewMode) {
            return
        }
        
        ; 计算显示的条数
        visibleCount := 0
        for bar in this.eventBars {
            if (bar["visible"]) {
                visibleCount++
            }
        }
        
        ; 如果是预览模式，至少3个条
        if (this.isPreviewMode && visibleCount < 3) {
            visibleCount := 3
        }
        
        ; 动态调整控件位置和大小
        barHeight := (visibleCount > 0) ? (height // visibleCount) : this.barHeight
        
        try {
            visibleIndex := 0
            for index, bar in this.eventBars {
                ; 只处理可见的条
                if (!bar["visible"]) {
                    continue
                }
                
                ; 只调整前visibleCount个
                if (visibleIndex >= visibleCount) {
                    break
                }
                
                yPos := visibleIndex * barHeight
                visibleIndex++
                
                ; ✅ 最后一个可见条填满剩余空间
                actualBarHeight := barHeight
                if (visibleIndex = visibleCount) {
                    actualBarHeight := height - yPos
                }
                
                ; ✅ 调整进度条（填满整个窗口宽度）
                bar["progress"].Move(0, yPos, width, actualBarHeight)
                
                ; 调整图标位置（垂直居中）
                bar["icon"].Move(10, yPos + actualBarHeight//2 - 15)
                
                ; ⚠️ 关键修复：技能名称宽度跟随窗口宽度变化
                skillTextWidth := width - 120  ; 窗口宽度 - 左边距(45) - 右侧倒计时区域(65) - 间隙(10)
                bar["skillText"].Move(45, yPos + actualBarHeight//2 - 10, skillTextWidth)
                
                ; ⚠️ 关键修复：倒计时文本位置跟随窗口宽度变化
                bar["timeText"].Move(width - 65, yPos + actualBarHeight//2 - 12)
            }
        }
    }
    
    ; 进入预览模式（可拖动）
    EnterPreviewMode() {
        this.isPreviewMode := true
        
        ; ✅ 先隐藏所有条（清除之前的状态）
        for bar in this.eventBars {
            bar["progress"].Visible := false
            bar["icon"].Visible := false
            bar["skillText"].Visible := false
            bar["timeText"].Visible := false
            bar["visible"] := false
        }
        
        ; 准备示例数据（按时间从近到远排序）
        previewSkills := [
            Map("name", "钢铁+分摊", "time", 8, "progress", 27),
            Map("name", "凶鸟尖啸", "time", 19, "progress", 63),
            Map("name", "月华冲", "time", 28, "progress", 93)
        ]
        
        previewCount := previewSkills.Length
        
        ; ✅ 使用保存的窗口宽度，不重新计算！
        previewWidth := (this.width > 0) ? this.width : 400
        previewHeight := (this.height > 0) ? this.height : (previewCount * this.barHeight)
        
        ; 调试输出
        if (IsSet(g_Logger)) {
            g_Logger.Debug("倒计时条预览: 窗口尺寸 w=" previewWidth ", h=" previewHeight)
        }
        
        ; 计算每个条的高度
        barHeight := previewHeight // previewCount
        
        ; 显示3个示例技能条
        Loop previewCount {
            bar := this.eventBars[A_Index]
            skillData := previewSkills[A_Index]
            yPos := (A_Index - 1) * barHeight
            
            ; ✅ 最后一个条填满剩余空间
            actualBarHeight := barHeight
            if (A_Index = previewCount) {
                actualBarHeight := previewHeight - yPos
            }
            
            ; 设置技能名称
            skillName := skillData["name"]
            bar["skillText"].Value := skillName
            
            ; 设置倒计时（显示整数秒）
            timeValue := skillData["time"]
            bar["timeText"].Value := (timeValue >= 60) ? Format("{:01}:{:02}", timeValue // 60, Mod(timeValue, 60)) : Integer(timeValue)
            
            ; ✅ 进度条填满整个窗口宽度，设置进度值（时间越长，进度越长）
            bar["progress"].Move(0, yPos, previewWidth, actualBarHeight)
            bar["progress"].Value := skillData["progress"]  ; 使用预设的进度值
            
            ; ✅ 控件位置和宽度跟随窗口宽度
            bar["icon"].Move(10, yPos + actualBarHeight//2 - 15)
            skillTextWidth := previewWidth - 120  ; 窗口宽度 - 左边距(45) - 右侧倒计时区域(65) - 间隙(10)
            bar["skillText"].Move(45, yPos + actualBarHeight//2 - 10, skillTextWidth)
            bar["timeText"].Move(previewWidth - 65, yPos + actualBarHeight//2 - 12)
            
            ; 设置倒计时颜色
            bar["timeText"].SetFont("c" this.timeTextColor " s12 Bold")
            bar["progress"].Opt("Background" this.barBgColor " c" this.barColor)
            
            ; 显示所有控件
            bar["progress"].Visible := true
            bar["icon"].Visible := true
            bar["skillText"].Visible := true
            bar["timeText"].Visible := true
            bar["visible"] := true
        }
        
        ; 设置透明度
        WinSetTransparent(this.opacity, this.gui)
        
        ; ✅ 显示窗口（使用保存的宽度和高度）
        this.gui.Show("x" this.x " y" this.y " w" previewWidth " h" previewHeight)
        this.isVisible := true
        
        ; ⚠️ 删除了 GetPos 验证修正逻辑
        ; 因为 GetPos 返回的是包含边框的尺寸，会导致 Progress 超出客户区
        ; Progress 的宽度已经在上面的 Loop 中设置为 previewWidth（客户区尺寸）
        
        ; 确保移除鼠标穿透
        try {
            WinSetExStyle("-0x20", this.gui)
        }
        
        ; 注册全局鼠标按下消息监听（用于拖动）
        OnMessage(0x201, ObjBindMethod(this, "WM_LBUTTONDOWN"))
    }
    
    ; 处理鼠标左键按下消息（实现拖动）
    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        ; 只在预览模式时处理
        if (!this.isPreviewMode) {
            return
        }
        
        ; 检查点击的窗口是否属于我们的 GUI（包括子控件）
        try {
            clickedGuiHwnd := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")  ; GA_ROOT = 2
            if (clickedGuiHwnd != this.gui.Hwnd) {
                return
            }
        } catch {
            return
        }
        
        ; ✅ 发送拖动消息到主窗口
        PostMessage(0xA1, 2, 0,, "ahk_id " this.gui.Hwnd)
        
        ; 延迟保存位置
        SetTimer(() => this.SavePosition(), -500)
    }
    
    ; 开始拖动窗口
    StartDrag() {
        if (!this.isPreviewMode) {
            return
        }
        
        ; 使用PostMessage发送拖动消息
        PostMessage(0xA1, 2, 0,, "ahk_id " this.gui.Hwnd)
        
        ; 延迟保存位置
        SetTimer(() => this.SavePosition(), -500)
    }
    
    ; 退出预览模式
    ExitPreviewMode() {
        ; ⚠️ 只保存位置，不保存尺寸！
        ; 尺寸已经在用户拉伸时通过 OnResize -> SavePosition 保存了
        ; 如果这里再保存 GetPos 的结果，会保存包含边框的尺寸，导致越来越大！
        try {
            this.gui.GetPos(&currentX, &currentY, &currentW, &currentH)
            this.x := currentX
            this.y := currentY
            ; this.width := currentW   // ❌ 不保存！这是带边框的尺寸
            ; this.height := currentH  // ❌ 不保存！这是带边框的尺寸
            
            if (IsSet(g_Logger)) {
                g_Logger.Debug("倒计时条-退出预览: 保存位置 x=" currentX ", y=" currentY " (尺寸已在拉伸时保存 w=" this.width ", h=" this.height ")")
            }
        }
        
        this.isPreviewMode := false
        
        ; 注销消息监听
        OnMessage(0x201, ObjBindMethod(this, "WM_LBUTTONDOWN"), 0)
        
        ; 保存配置到文件
        this.SaveSettings()
        
        ; 隐藏窗口
        this.Hide()
    }
    
    ; 重新创建GUI（用于应用颜色更改）
    RecreateGui() {
        ; 保存当前状态
        wasVisible := this.isVisible
        wasPreviewMode := this.isPreviewMode
        
        ; 获取当前位置
        if (this.gui) {
            try {
                this.gui.GetPos(&currentX, &currentY, &currentW, &currentH)
                this.x := currentX
                this.y := currentY
                this.width := currentW
                this.height := currentH
            }
            
            ; 销毁旧GUI
            this.gui.Destroy()
        }
        
        ; 重新创建
        this.CreateGui()
        
        ; 恢复状态
        if (wasPreviewMode) {
            this.EnterPreviewMode()
        } else if (wasVisible) {
            this.Show()
        }
    }
    
    ; 显示右键菜单
    ShowContextMenu() {
        if (!this.isPreviewMode) {
            return
        }
        
        try {
            contextMenu := Menu()
            contextMenu.Add("✅ 完成设置", (*) => this.ExitPreviewMode())
            contextMenu.Add()
            contextMenu.Add("⚙️ 设置透明度", (*) => this.ShowOpacitySettings())
            contextMenu.Add("🎨 设置颜色", (*) => this.ShowColorSettings())
            contextMenu.Show()
        } catch as err {
            MsgBox("菜单错误: " err.Message, "错误", "IconX")
        }
    }
    
    ; 显示透明度设置
    ShowOpacitySettings() {
        result := InputBox("请输入倒计时条透明度 (0-255):`n(0=完全透明, 255=完全不透明)`n`n建议值: 180-255", "设置透明度", "w300 h140", String(this.opacity))
        if (result.Result = "OK") {
            newOpacity := Integer(result.Value)
            if (newOpacity >= 0 && newOpacity <= 255) {
                this.opacity := newOpacity
                WinSetTransparent(this.opacity, this.gui)
                this.SaveSettings()
            }
        }
    }
    
    ; 显示颜色设置
    ShowColorSettings() {
        colorGui := Gui("+Owner" this.gui.Hwnd, "颜色设置")
        colorGui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 进度条背景颜色
        colorGui.Add("Text", "x20 y15", "进度条背景颜色:")
        barBgColorEdit := colorGui.Add("Edit", "x140 y10 w150 ReadOnly", this.barBgColor)
        colorGui.Add("Button", "x300 y10 w60 h25", "🎨 选择").OnEvent("Click", (*) => this.ShowColorPicker(barBgColorEdit, "进度条背景颜色"))
        
        ; 进度条前景颜色
        colorGui.Add("Text", "x20 y45", "进度条前景颜色:")
        barColorEdit := colorGui.Add("Edit", "x140 y40 w150 ReadOnly", this.barColor)
        colorGui.Add("Button", "x300 y40 w60 h25", "🎨 选择").OnEvent("Click", (*) => this.ShowColorPicker(barColorEdit, "进度条前景颜色"))
        
        ; 技能文字颜色
        colorGui.Add("Text", "x20 y75", "技能文字颜色:")
        skillColorEdit := colorGui.Add("Edit", "x140 y70 w150 ReadOnly", this.skillTextColor)
        colorGui.Add("Button", "x300 y70 w60 h25", "🎨 选择").OnEvent("Click", (*) => this.ShowColorPicker(skillColorEdit, "技能文字颜色"))
        
        ; 倒计时文字颜色
        colorGui.Add("Text", "x20 y105", "倒计时文字颜色:")
        timeColorEdit := colorGui.Add("Edit", "x140 y100 w150 ReadOnly", this.timeTextColor)
        colorGui.Add("Button", "x300 y100 w60 h25", "🎨 选择").OnEvent("Click", (*) => this.ShowColorPicker(timeColorEdit, "倒计时文字颜色"))
        
        ; 预设方案
        colorGui.Add("GroupBox", "x20 y140 w450 h75", "快速预设方案")
        colorGui.Add("Button", "x30 y160 w100 h40", "🌙 暗黑").OnEvent("Click", (*) => this.ApplyPresetDark(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit))
        colorGui.Add("Button", "x140 y160 w100 h40", "🌞 明亮").OnEvent("Click", (*) => this.ApplyPresetLight(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit))
        colorGui.Add("Button", "x250 y160 w100 h40", "🎮 游戏").OnEvent("Click", (*) => this.ApplyPresetGame(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit))
        colorGui.Add("Button", "x360 y160 w100 h40", "🔥 警告").OnEvent("Click", (*) => this.ApplyPresetAlert(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit))
        
        saveBtn := colorGui.Add("Button", "x250 y230 w100 h35", "💾 保存")
        cancelBtn := colorGui.Add("Button", "x360 y230 w100 h35", "❌ 取消")
        
        saveBtn.OnEvent("Click", (*) => this.ApplyColorSettingsFromEdit(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit, colorGui))
        cancelBtn.OnEvent("Click", (*) => colorGui.Destroy())
        
        colorGui.Show("w490 h280 Center")
    }
    
    ; 显示颜色选择器（色盘）
    ShowColorPicker(editCtrl, title) {
        ; 将0x开头的颜色值转换为BGR格式的整数
        currentColor := editCtrl.Value
        
        ; 去掉0x前缀并转换为BGR
        if (SubStr(currentColor, 1, 2) = "0x") {
            hexColor := SubStr(currentColor, 3)
            r := Integer("0x" SubStr(hexColor, 1, 2))
            g := Integer("0x" SubStr(hexColor, 3, 2))
            b := Integer("0x" SubStr(hexColor, 5, 2))
            bgrColor := (b << 16) | (g << 8) | r
        } else {
            bgrColor := 0x333333  ; 默认灰色
        }
        
        ; 创建颜色选择对话框（64位系统结构）
        try {
            ; CHOOSECOLOR结构体 (64位：9*8 = 72字节)
            CHOOSECOLOR := Buffer(72, 0)
            customColors := Buffer(16 * 4, 0)
            
            NumPut("UInt", 72, CHOOSECOLOR, 0)                     ; lStructSize
            NumPut("Ptr", this.gui.Hwnd, CHOOSECOLOR, 8)           ; hwndOwner (偏移8)
            NumPut("Ptr", 0, CHOOSECOLOR, 16)                      ; hInstance
            NumPut("UInt", bgrColor, CHOOSECOLOR, 24)              ; rgbResult (偏移24)
            NumPut("Ptr", customColors.Ptr, CHOOSECOLOR, 32)       ; lpCustColors (偏移32)
            NumPut("UInt", 0x00000103, CHOOSECOLOR, 40)            ; Flags (CC_RGBINIT | CC_FULLOPEN)
            
            ; 调用颜色选择对话框
            result := DllCall("comdlg32\ChooseColor", "Ptr", CHOOSECOLOR, "Int")
            
            if (result) {
                ; 获取选择的颜色（BGR格式）
                selectedBGR := NumGet(CHOOSECOLOR, 24, "UInt")
                
                ; 转换回RGB（0xRRGGBB格式）
                r := selectedBGR & 0xFF
                g := (selectedBGR >> 8) & 0xFF
                b := (selectedBGR >> 16) & 0xFF
                
                ; 格式化为0xRRGGBB字符串
                rgbHex := Format("0x{:02X}{:02X}{:02X}", r, g, b)
                editCtrl.Value := rgbHex
            }
        } catch as err {
            MsgBox("颜色选择器错误: " err.Message, "错误", "IconX")
        }
    }
    
    ; 从下拉框文本提取颜色值
    ExtractColorFromText(text) {
        ; 提取括号中的颜色值 "白色 (0xFFFFFF)" -> "0xFFFFFF"
        if (RegExMatch(text, "\((0x[0-9A-Fa-f]+)\)", &match)) {
            return match[1]
        }
        return "0xFFFFFF"
    }
    
    ; 应用预设 - 暗黑
    ApplyPresetDark(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit) {
        barBgColorEdit.Value := "0x333333"   ; 深灰色
        barColorEdit.Value := "0xFFFFFF"     ; 白色
        skillColorEdit.Value := "0xFFFFFF"   ; 白色
        timeColorEdit.Value := "0xFFFF00"    ; 黄色
    }
    
    ; 应用预设 - 明亮
    ApplyPresetLight(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit) {
        barBgColorEdit.Value := "0x666666"   ; 浅灰色
        barColorEdit.Value := "0xFFFFFF"     ; 白色
        skillColorEdit.Value := "0xFFFFFF"   ; 白色
        timeColorEdit.Value := "0xFFFF00"    ; 黄色
    }
    
    ; 应用预设 - 游戏
    ApplyPresetGame(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit) {
        barBgColorEdit.Value := "0x1a1a4d"   ; 深蓝色
        barColorEdit.Value := "0x00AAFF"     ; 蓝色
        skillColorEdit.Value := "0xFFFFFF"   ; 白色
        timeColorEdit.Value := "0x00FF00"    ; 绿色
    }
    
    ; 应用预设 - 警告
    ApplyPresetAlert(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit) {
        barBgColorEdit.Value := "0x333333"   ; 深灰色
        barColorEdit.Value := "0xFF0000"     ; 红色
        skillColorEdit.Value := "0xFFFF00"   ; 黄色
        timeColorEdit.Value := "0xFF0000"    ; 红色
    }
    
    ; 从编辑框应用颜色设置
    ApplyColorSettingsFromEdit(barBgColorEdit, barColorEdit, skillColorEdit, timeColorEdit, colorGui) {
        try {
            this.barBgColor := barBgColorEdit.Value
            this.barColor := barColorEdit.Value
            this.skillTextColor := skillColorEdit.Value
            this.timeTextColor := timeColorEdit.Value
            
            ; 重新创建GUI以应用新颜色
            this.RecreateGui()
            
            this.SaveSettings()
            colorGui.Destroy()
            
            MsgBox("颜色设置已保存并应用", "成功", "Icon!")
        } catch as err {
            MsgBox("颜色设置失败: " err.Message, "错误", "IconX")
        }
    }
    
    ; 显示窗口（监控模式，鼠标穿透）
    Show() {
        if (!this.isVisible && !this.isPreviewMode) {
            
            ; 设置窗口透明度
            WinSetTransparent(this.opacity, this.gui)
            
            ; 启用鼠标穿透
            WinSetExStyle("+0x20", this.gui)
            
            ; 显示窗口（使用保存的尺寸，如果没有则使用默认值）
            ; 窗口大小完全由用户在预览模式设置，不会自动调整
            initialWidth := (this.width > 0) ? this.width : 400
            initialHeight := (this.height > 0) ? this.height : (3 * this.barHeight)  ; 默认3个技能条的高度
            
            if (IsSet(g_Logger)) {
                g_Logger.Debug("倒计时条-显示: 预期尺寸 x=" this.x ", y=" this.y ", w=" initialWidth ", h=" initialHeight)
            }
            
            this.gui.Show("x" this.x " y" this.y " w" initialWidth " h" initialHeight " NoActivate")
            this.isVisible := true
            
            ; ⚠️ 删除了 GetPos 验证逻辑
            ; 因为 GetPos 返回的是包含边框的尺寸，会导致 Progress 超出客户区
            ; 应该始终使用 this.width 和 this.height（客户区尺寸）
        }
    }
    
    ; 隐藏窗口
    Hide() {
        if (this.isVisible) {
            this.gui.Hide()
            this.isVisible := false
            this.isPreviewMode := false
        }
    }
    
    ; 更新显示内容（动态显示技能数量，游戏UI风格）
    UpdateMultiple(upcomingEvents) {
        if (!this.isVisible || this.isPreviewMode) {
            return
        }
        
        ; 隐藏所有条
        for bar in this.eventBars {
            bar["progress"].Visible := false
            bar["icon"].Visible := false
            bar["skillText"].Visible := false
            bar["timeText"].Visible := false
            bar["visible"] := false
            bar["warningState"] := ""  ; 重置警告状态
        }
        
        ; 填充技能信息（最多显示maxBars个）
        eventCount := Min(upcomingEvents.Length, this.maxBars)
        
        ; ⚠️ 使用保存的客户区尺寸，而不是 GetPos（GetPos 包含边框！）
        currentWidth := this.width
        currentHeight := this.height
        
        ; 调试输出
        if (IsSet(g_Logger)) {
            g_Logger.Debug("倒计时条-更新: 使用客户区尺寸 w=" currentWidth ", h=" currentHeight ", 事件数=" eventCount)
        }
        
        ; 计算每个条的高度
        barHeight := (eventCount > 0) ? (currentHeight // eventCount) : this.barHeight
        
        Loop eventCount {
            event := upcomingEvents[A_Index]
            bar := this.eventBars[A_Index]
            yPos := (A_Index - 1) * barHeight
            
            ; ✅ 最后一个条填满剩余空间（解决整除余数问题）
            actualBarHeight := barHeight
            if (A_Index = eventCount) {
                actualBarHeight := currentHeight - yPos  ; 填满到底部
            }
            
            ; 设置技能名称
            skillName := event["skillName"]
            bar["skillText"].Value := skillName
            
            ; 设置倒计时
            remainingSeconds := event["remainingSeconds"]
            
            ; 根据剩余时间格式化显示
            if (remainingSeconds >= 60) {
                minutes := remainingSeconds // 60
                seconds := Mod(remainingSeconds, 60)
                timeStr := Format("{:01}:{:02}", minutes, seconds)
            } else {
                ; 显示整数秒（不显示小数）
                timeStr := Integer(remainingSeconds)
            }
            bar["timeText"].Value := timeStr
            
            ; ✅ 计算进度条值（剩余时间越少，进度条越短）
            ; 假设显示窗口为30秒，超过30秒显示100%，0秒显示0%
            displayWindow := 30.0
            if (remainingSeconds >= displayWindow) {
                progressValue := 100
            } else {
                progressValue := Integer((remainingSeconds / displayWindow) * 100)
                progressValue := Max(0, Min(100, progressValue))
            }
            bar["progress"].Value := progressValue
            
            ; ⚠️ 防闪烁优化：只在首次显示或位置改变时才 Move
            if (!bar["visible"]) {
                bar["progress"].Move(0, yPos, currentWidth, actualBarHeight)
                bar["icon"].Move(10, yPos + actualBarHeight//2 - 15)
                skillTextWidth := currentWidth - 120
                bar["skillText"].Move(45, yPos + actualBarHeight//2 - 10, skillTextWidth)
                bar["timeText"].Move(currentWidth - 65, yPos + actualBarHeight//2 - 12)
            }
            
            ; ⚠️ 防闪烁优化：只在警告状态改变时才更新颜色
            currentWarningState := (remainingSeconds <= 5) ? "danger" : (remainingSeconds <= 10) ? "warning" : "normal"
            if (!bar.Has("warningState") || bar["warningState"] != currentWarningState) {
                if (remainingSeconds <= 5) {
                    bar["timeText"].SetFont("c0xFF0000 s12 Bold")
                    bar["progress"].Opt("Background0x4d1a1a c0xFF0000")
                } else if (remainingSeconds <= 10) {
                    bar["timeText"].SetFont("c0xFFAA00 s12 Bold")
                    bar["progress"].Opt("Background0x4d3a1a c0xFFAA00")
                } else {
                    bar["timeText"].SetFont("c" this.timeTextColor " s12 Bold")
                    bar["progress"].Opt("Background" this.barBgColor " c" this.barColor)
                }
                bar["warningState"] := currentWarningState
            }
            
            ; ⚠️ 防闪烁优化：只在首次显示时设置 Visible
            if (!bar["visible"]) {
                bar["progress"].Visible := true
                bar["icon"].Visible := true
                bar["skillText"].Visible := true
                bar["timeText"].Visible := true
                bar["visible"] := true
            }
        }
        
        ; ✅ 不再自动调整窗口大小，完全尊重用户设置的大小
        ; 用户可以在预览模式手动调整窗口大小，保存后会被保留
    }
    
    ; 显示等待状态
    ShowWaiting(message := "⏱️ 等待开始...") {
        if (!this.isVisible || this.isPreviewMode) {
            return
        }
        
        ; 隐藏所有条
        for bar in this.eventBars {
            bar["progress"].Visible := false
            bar["icon"].Visible := false
            bar["skillText"].Visible := false
            bar["timeText"].Visible := false
            bar["visible"] := false
            bar["warningState"] := ""  ; 重置警告状态
        }
        
        ; 只显示第一个条
        this.eventBars[1]["progress"].Visible := true
        this.eventBars[1]["progress"].Value := 100  ; 满进度
        this.eventBars[1]["icon"].Visible := false  ; 等待状态不显示圆点
        this.eventBars[1]["skillText"].Visible := true
        this.eventBars[1]["skillText"].Value := message
        this.eventBars[1]["timeText"].Value := ""
        this.eventBars[1]["visible"] := true
        
        ; 不再自动调整窗口高度，保持用户设置的大小
    }
    
    ; 加载窗口配置
    LoadPosition() {
        try {
            config := this.configManager.config
            
            if (config.Has("timeline_overlay")) {
                overlay := config["timeline_overlay"]
                
                if (overlay.Has("x"))
                    this.x := overlay["x"]
                if (overlay.Has("y"))
                    this.y := overlay["y"]
                if (overlay.Has("width"))
                    this.width := overlay["width"]
                if (overlay.Has("height"))
                    this.height := overlay["height"]
                if (overlay.Has("opacity"))
                    this.opacity := overlay["opacity"]
                if (overlay.Has("bg_color"))
                    this.bgColor := overlay["bg_color"]
                if (overlay.Has("bar_bg_color"))
                    this.barBgColor := overlay["bar_bg_color"]
                if (overlay.Has("bar_color"))
                    this.barColor := overlay["bar_color"]
                if (overlay.Has("skill_text_color"))
                    this.skillTextColor := overlay["skill_text_color"]
                if (overlay.Has("time_text_color"))
                    this.timeTextColor := overlay["time_text_color"]
                
                ; 调试输出
                if (IsSet(g_Logger)) {
                    g_Logger.Debug("倒计时条-加载配置: x=" this.x ", y=" this.y ", w=" this.width ", h=" this.height)
                }
            }
        } catch as err {
            if (IsSet(g_Logger)) {
                g_Logger.Error("加载倒计时条配置失败: " err.Message)
            }
        }
    }
    
    ; 保存窗口位置和大小
    SavePosition() {
        try {
            ; ⚠️ 只获取位置，不获取尺寸！
            ; GetPos() 返回的是包含边框的窗口尺寸
            ; 而 Show("w... h...") 使用的是客户区尺寸（不含边框）
            ; 如果保存 GetPos 的尺寸，会导致循环放大！
            this.gui.GetPos(&currentX, &currentY, , )
            this.x := currentX
            this.y := currentY
            ; this.width 和 this.height 应该只在 OnResize 中更新！
            
            this.SaveSettings()
        } catch as err {
            if (IsSet(g_Logger)) {
                g_Logger.Error("保存倒计时条位置失败: " err.Message)
            }
        }
    }
    
    ; 保存所有设置
    SaveSettings() {
        try {
            config := this.configManager.config
            
            if (!config.Has("timeline_overlay")) {
                config["timeline_overlay"] := Map()
            }
            
            config["timeline_overlay"]["x"] := this.x
            config["timeline_overlay"]["y"] := this.y
            config["timeline_overlay"]["width"] := this.width
            config["timeline_overlay"]["height"] := this.height
            config["timeline_overlay"]["opacity"] := this.opacity
            config["timeline_overlay"]["bg_color"] := this.bgColor
            config["timeline_overlay"]["bar_bg_color"] := this.barBgColor
            config["timeline_overlay"]["bar_color"] := this.barColor
            config["timeline_overlay"]["skill_text_color"] := this.skillTextColor
            config["timeline_overlay"]["time_text_color"] := this.timeTextColor
            
            ; ✅ 方法名是Save()不是SaveConfig()！
            result := this.configManager.Save()
            
            ; 调试输出
            if (IsSet(g_Logger)) {
                if (result) {
                    g_Logger.Debug("倒计时条-保存配置成功: x=" this.x ", y=" this.y ", w=" this.width ", h=" this.height)
                } else {
                    g_Logger.Error("倒计时条-保存配置失败！")
                }
            }
        } catch as err {
            if (IsSet(g_Logger)) {
                g_Logger.Error("保存倒计时条配置异常: " err.Message)
            }
            MsgBox("保存倒计时条配置失败: " err.Message, "错误", "IconX")
        }
    }
    
    ; 销毁窗口
    Destroy() {
        if (this.gui) {
            this.Hide()
            this.gui.Destroy()
            this.gui := ""
        }
    }
}

