; ===================================================
; 日志系统
; 支持多级别日志（DEBUG/INFO/ERROR）
; 支持 GUI 显示和文件写入
; ===================================================

class Logger {
    ; 日志级别（静态常量）
    static LEVEL_DEBUG := 0
    static LEVEL_INFO := 1
    static LEVEL_ERROR := 2
    
    ; 实例属性
    currentLevel := 0
    logFile := ""
    logDir := ""
    guiLogControl := ""
    logBuffer := 0
    maxBufferSize := 0
    enableWriteToFile := false
    enableShowInGui := false
    
    ; 初始化
    __New(logDir := "logs") {
        ; 初始化属性
        this.currentLevel := 1  ; 默认 INFO
        this.logBuffer := []
        this.maxBufferSize := 1000
        this.enableWriteToFile := true
        this.enableShowInGui := true
        this.logDir := logDir
        
        ; 确保日志目录存在
        if (!DirExist(logDir)) {
            DirCreate(logDir)
        }
        
        ; 创建日志文件（按日期）
        dateStr := FormatTime(, "yyyy-MM-dd")
        this.logFile := logDir "\" dateStr ".log"
        
        ; 写入启动标记
        this.WriteToFile("`n" this.GetTimestamp() " ========== 程序启动 ==========`n")
    }
    
    ; 设置日志级别
    SetLevel(level) {
        this.currentLevel := level
    }
    
    ; 设置 DEBUG 模式
    SetDebugMode(enabled) {
        if (enabled) {
            this.currentLevel := Logger.LEVEL_DEBUG
        } else {
            this.currentLevel := Logger.LEVEL_INFO
        }
    }
    
    ; 设置 GUI 控件
    SetGuiControl(control) {
        this.guiLogControl := control
    }
    
    ; DEBUG 日志
    Debug(message) {
        this.Log(message, Logger.LEVEL_DEBUG, "DEBUG")
    }
    
    ; INFO 日志
    Info(message) {
        this.Log(message, Logger.LEVEL_INFO, "INFO")
    }
    
    ; ERROR 日志
    Error(message) {
        this.Log(message, Logger.LEVEL_ERROR, "ERROR")
    }
    
    ; 核心日志方法
    Log(message, level, levelName) {
        ; 检查日志级别
        if (level < this.currentLevel) {
            return
        }
        
        ; 格式化日志
        timestamp := this.GetTimestamp()
        logLine := timestamp " [" levelName "] " message
        
        ; 添加到缓冲
        this.logBuffer.Push(logLine)
        
        ; 限制缓冲大小
        if (this.logBuffer.Length > this.maxBufferSize) {
            this.logBuffer.RemoveAt(1)
        }
        
        ; 写入文件
        if (this.enableWriteToFile) {
            this.WriteToFile(logLine "`n")
        }
        
        ; 显示在 GUI
        if (this.enableShowInGui && this.guiLogControl) {
            this.UpdateGui(logLine)
        }
        
        ; 输出到 OutputDebug
        OutputDebug(logLine)
    }
    
    ; 获取时间戳
    GetTimestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }
    
    ; 写入文件
    WriteToFile(content) {
        try {
            FileAppend(content, this.logFile, "UTF-8")
        } catch as err {
            OutputDebug("写入日志文件失败: " err.Message)
        }
    }
    
    ; 更新 GUI
    UpdateGui(logLine) {
        try {
            ; 获取当前内容
            currentText := this.guiLogControl.Value
            
            ; 添加新日志
            newText := currentText (currentText ? "`n" : "") logLine
            
            ; 限制显示行数
            lines := StrSplit(newText, "`n")
            if (lines.Length > 500) {
                ; 只保留最后 500 行
                lines := lines.Clone()
                loop (lines.Length - 500) {
                    lines.RemoveAt(1)
                }
                newText := ""
                for index, line in lines {
                    newText .= (index > 1 ? "`n" : "") line
                }
            }
            
            ; 更新控件
            this.guiLogControl.Value := newText
            
            ; 滚动到底部
            this.guiLogControl.Value := newText
        } catch as err {
            OutputDebug("更新 GUI 日志失败: " err.Message)
        }
    }
    
    ; 清空 GUI 日志
    ClearGui() {
        if (this.guiLogControl) {
            this.guiLogControl.Value := ""
        }
    }
    
    ; 获取所有日志
    GetAllLogs() {
        result := ""
        for index, line in this.logBuffer {
            result .= (index > 1 ? "`n" : "") line
        }
        return result
    }
    
    ; 导出日志到文件
    ExportLogs(filePath) {
        try {
            content := this.GetAllLogs()
            
            if (FileExist(filePath)) {
                FileDelete(filePath)
            }
            
            FileAppend(content, filePath, "UTF-8")
            return true
        } catch as err {
            this.Error("导出日志失败: " err.Message)
            return false
        }
    }
}

; 全局日志实例
global g_Logger := ""

