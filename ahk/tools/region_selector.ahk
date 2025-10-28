; ===================================================
; OCR 区域选择工具
; 让用户在屏幕上框选区域
; ===================================================

class RegionSelector {
    gui := ""
    startX := 0
    startY := 0
    endX := 0
    endY := 0
    isSelecting := false
    callback := ""
    overlayGui := ""
    tipGui := ""
    windowTitle := ""
    tooltipTimer := ""
    mouseMoveTimer := ""
    
    ; 开始选择区域
    Start(callback, windowTitle := "") {
        this.callback := callback
        this.windowTitle := windowTitle
        
        ; 如果指定了窗口标题，先激活窗口
        if (windowTitle != "") {
            try {
                if (WinExist(windowTitle)) {
                    WinActivate(windowTitle)
                    Sleep(500)  ; 等待窗口激活
                    
                    g_Logger.Info("已激活窗口: " windowTitle)
                } else {
                    g_Logger.Error("未找到窗口: " windowTitle)
                    MsgBox("未找到指定的游戏窗口: " windowTitle "`n`n请检查窗口标题是否正确", "错误", "Icon!")
                    return
                }
            } catch as err {
                g_Logger.Error("激活窗口失败: " err.Message)
            }
        }
        
        ; 创建全屏透明窗口
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.gui.BackColor := "0x000000"
        WinSetTransparent(1, this.gui)
        
        ; 获取屏幕尺寸
        MonitorGetWorkArea(, &left, &top, &right, &bottom)
        width := A_ScreenWidth
        height := A_ScreenHeight
        
        ; 显示全屏窗口
        this.gui.Show("x0 y0 w" width " h" height " NA")
        
        ; 创建提示窗口
        this.tipGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border")
        this.tipGui.SetFont("s12", "Microsoft YaHei UI")
        this.tipGui.BackColor := "0xFFFFE0"
        this.tipGui.Add("Text", "x10 y10 w350", "请在屏幕上拖动鼠标框选区域`n按 ESC 取消")
        this.tipGui.Show("NA")
        
        ; 等待一会儿再关闭提示（但Cleanup时会立即清除）
        SetTimer(() => this.CloseTipGui(), -2000)
        
        ; 设置鼠标钩子
        this.SetupHooks()
    }
    
    ; 关闭提示窗口（定时器调用）
    CloseTipGui() {
        if (this.tipGui) {
            try {
                this.tipGui.Destroy()
            }
            this.tipGui := ""
        }
    }
    
    ; 设置钩子
    SetupHooks() {
        ; 显示初始提示信息
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("左键拖动选择区域，ESC 取消", x + 20, y + 20)
        
        ; 持续更新提示位置（在选择前）- 使用命名函数便于停止
        this.tooltipTimer := ObjBindMethod(this, "UpdateInitialTooltip")
        SetTimer(this.tooltipTimer, 50)
        
        ; 等待用户操作
        Hotkey("LButton", ObjBindMethod(this, "OnMouseDown"), "On")
        Hotkey("Escape", ObjBindMethod(this, "OnCancel"), "On")
    }
    
    ; 更新初始提示
    UpdateInitialTooltip() {
        if (this.isSelecting) {
            ; 已经开始选择，停止更新初始提示
            if (this.tooltipTimer) {
                SetTimer(this.tooltipTimer, 0)
            }
            ToolTip()  ; 清除
            return
        }
        
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("左键拖动选择区域，ESC 取消", x + 20, y + 20)
    }
    
    ; 停止所有定时器
    StopAllTimers() {
        if (this.tooltipTimer) {
            SetTimer(this.tooltipTimer, 0)
        }
        if (this.mouseMoveTimer) {
            SetTimer(this.mouseMoveTimer, 0)
        }
    }
    
    ; 鼠标按下
    OnMouseDown(*) {
        ; 立即清除 ToolTip
        ToolTip()
        
        ; 停止所有定时器
        this.StopAllTimers()
        
        ; 禁用热键
        Hotkey("LButton", "Off")
        
        ; 获取鼠标位置
        x := 0, y := 0
        MouseGetPos(&x, &y)
        this.startX := x
        this.startY := y
        
        this.isSelecting := true
        
        ; 创建矩形覆盖层
        this.CreateOverlay()
        
        ; 等待鼠标释放
        Hotkey("LButton Up", ObjBindMethod(this, "OnMouseUp"), "On")
        
        ; 监听鼠标移动
        this.mouseMoveTimer := ObjBindMethod(this, "OnMouseMove")
        SetTimer(this.mouseMoveTimer, 10)
    }
    
    ; 鼠标移动
    OnMouseMove() {
        if (!this.isSelecting) {
            return
        }
        
        ; 获取当前鼠标位置
        currentX := 0, currentY := 0
        MouseGetPos(&currentX, &currentY)
        
        ; 更新覆盖层
        this.UpdateOverlay(this.startX, this.startY, currentX, currentY)
        
        ; 更新鼠标提示（跟随鼠标）
        width := Abs(currentX - this.startX)
        height := Abs(currentY - this.startY)
        ToolTip("区域大小: " width " x " height "`n松开鼠标完成选择", currentX + 20, currentY + 20)
    }
    
    ; 鼠标释放
    OnMouseUp(*) {
        ; 立即清除 ToolTip
        ToolTip()
        
        ; 停止所有定时器
        this.StopAllTimers()
        
        ; 获取结束位置
        x := 0, y := 0
        MouseGetPos(&x, &y)
        this.endX := x
        this.endY := y
        
        this.isSelecting := false
        
        ; 禁用热键
        Hotkey("LButton Up", "Off")
        Hotkey("Escape", "Off")
        
        ; 清理 UI
        this.Cleanup()
        
        ; 再次确保清除 ToolTip
        ToolTip()
        
        ; 计算区域
        x1 := Min(this.startX, this.endX)
        y1 := Min(this.startY, this.endY)
        x2 := Max(this.startX, this.endX)
        y2 := Max(this.startY, this.endY)
        
        ; 验证区域大小
        if (x2 - x1 < 10 || y2 - y1 < 10) {
            ; 多次确保 ToolTip 已清除
            ToolTip()
            Sleep(50)
            ToolTip()
            
            ; 显示主窗口（如果存在）
            this.ShowMainWindow()
            
            MsgBox("选择的区域太小（最小 10x10 像素），请重新框选", "提示", "Icon!")
            return
        }
        
        ; 调用回调
        if (this.callback) {
            this.callback.Call(x1, y1, x2, y2)
        }
        
        ; 多次确保 ToolTip 已清除
        ToolTip()
        Sleep(50)
        ToolTip()
        
        ; 显示主窗口（如果存在）
        this.ShowMainWindow()
    }
    
    ; 取消选择
    OnCancel(*) {
        ; 立即清除 ToolTip
        ToolTip()
        
        ; 停止所有定时器
        this.StopAllTimers()
        
        this.isSelecting := false
        
        ; 禁用热键
        try {
            Hotkey("LButton", "Off")
            Hotkey("LButton Up", "Off")
            Hotkey("Escape", "Off")
        }
        
        ; 清理 UI
        this.Cleanup()
        
        ; 多次确保 ToolTip 已清除
        ToolTip()
        Sleep(50)
        ToolTip()
        
        ; 显示主窗口（如果存在）
        this.ShowMainWindow()
        
        g_Logger.Info("用户取消了区域选择")
    }
    
    ; 创建覆盖层
    CreateOverlay() {
        this.overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.overlayGui.BackColor := "0xCCCCCC"  ; 白灰色
        WinSetTransparent(80, this.overlayGui)
        this.overlayGui.Show("x0 y0 w0 h0 NA")
    }
    
    ; 更新覆盖层
    UpdateOverlay(x1, y1, x2, y2) {
        if (!this.overlayGui) {
            return
        }
        
        ; 计算矩形
        left := Min(x1, x2)
        top := Min(y1, y2)
        width := Abs(x2 - x1)
        height := Abs(y2 - y1)
        
        ; 更新位置和大小
        try {
            this.overlayGui.Show("x" left " y" top " w" width " h" height " NA")
        }
    }
    
    ; 清理
    Cleanup() {
        ; 多次清除 ToolTip（确保清除）
        ToolTip()
        Sleep(10)
        ToolTip()
        
        ; 清理提示窗口
        if (this.tipGui) {
            try {
                this.tipGui.Destroy()
            }
            this.tipGui := ""
        }
        
        if (this.gui) {
            try {
                this.gui.Destroy()
            }
            this.gui := ""
        }
        
        if (this.overlayGui) {
            try {
                this.overlayGui.Destroy()
            }
            this.overlayGui := ""
        }
        
        ; 最后再次清除 ToolTip
        ToolTip()
    }
    
    ; 显示主窗口
    ShowMainWindow() {
        try {
            ; 方法1：直接使用全局变量
            global g_MainWindow
            if (g_MainWindow && g_MainWindow.gui) {
                g_MainWindow.Show()
                Sleep(100)  ; 等待窗口显示
                WinActivate("DBM 播报系统")
                g_Logger.Debug("已激活主窗口（通过全局变量）")
                return
            }
        } catch as err {
            g_Logger.Debug("通过全局变量激活失败: " err.Message)
        }
        
        ; 方法2：通过窗口标题查找
        try {
            if (WinExist("DBM 播报系统")) {
                WinShow("DBM 播报系统")
                WinActivate("DBM 播报系统")
                g_Logger.Debug("已激活主窗口（通过标题）")
                return
            }
        } catch as err {
            g_Logger.Debug("通过标题激活失败: " err.Message)
        }
        
        ; 方法3：通过类名查找
        try {
            if (WinExist("ahk_class AutoHotkeyGUI")) {
                WinShow("ahk_class AutoHotkeyGUI")
                WinActivate("ahk_class AutoHotkeyGUI")
                g_Logger.Debug("已激活主窗口（通过类名）")
                return
            }
        } catch as err {
            g_Logger.Debug("通过类名激活失败: " err.Message)
        }
        
        g_Logger.Debug("未找到主窗口")
    }
}

; 简化的区域选择函数
SelectRegion(callback, windowTitle := "") {
    selector := RegionSelector()
    selector.Start(callback, windowTitle)
}

