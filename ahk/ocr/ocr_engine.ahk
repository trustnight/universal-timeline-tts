; ===================================================
; OCR 引擎模块 - 使用 RapidOCR DLL
; 纯AHK调用DLL进行文字识别
; ===================================================

class OCREngine {
    dllPath := ""
    modelDir := ""
    hModule := 0
    ocrPtr := 0  ; OCR引擎指针
    initialized := false
    
    ; 模型文件路径
    detModel := ""
    clsModel := ""
    recModel := ""
    keysDict := ""
    
    ; 初始化
    __New() {
        ; 检测系统架构
        if (A_PtrSize = 8) {
            this.dllPath := A_ScriptDir "\RapidOcr\64bit\RapidOcrOnnx.dll"
        } else {
            this.dllPath := A_ScriptDir "\RapidOcr\32bit\RapidOcrOnnx.dll"
        }
        
        this.modelDir := A_ScriptDir "\RapidOcr\models"
        
        ; 设置模型文件路径
        this.detModel := this.modelDir "\ch_PP-OCRv4_det_infer.onnx"
        this.clsModel := this.modelDir "\ch_ppocr_mobile_v2.0_cls_infer.onnx"
        this.recModel := this.modelDir "\ch_PP-OCRv4_rec_infer.onnx"
        this.keysDict := this.modelDir "\ppocr_keys_v1.txt"
    }
    
    ; 初始化 OCR 引擎
    Init() {
        ; 检查DLL文件
        if (!FileExist(this.dllPath)) {
            MsgBox("❌ DLL文件不存在: " this.dllPath, "错误")
            return false
        }
        
        ; 检查必需的模型文件（cls 模型是可选的）
        if (!FileExist(this.detModel)) {
            MsgBox("❌ 检测模型文件不存在: " this.detModel, "错误")
            return false
        }
        if (!FileExist(this.recModel)) {
            MsgBox("❌ 识别模型文件不存在: " this.recModel, "错误")
            return false
        }
        if (!FileExist(this.keysDict)) {
            MsgBox("❌ 字典文件不存在: " this.keysDict, "错误")
            return false
        }
        
        ; cls 模型是可选的，如果不存在就传空字符串
        clsModelToUse := FileExist(this.clsModel) ? this.clsModel : ""
        
        global g_Logger
        if (g_Logger) {
            g_Logger.Debug("Det模型: " this.detModel)
            g_Logger.Debug("Cls模型: " (clsModelToUse ? clsModelToUse : "未使用"))
            g_Logger.Debug("Rec模型: " this.recModel)
            g_Logger.Debug("Keys字典: " this.keysDict)
        }
        
        try {
            ; 使用静态变量确保 DLL 只加载一次（参考 RMT 实现）
            static dllLoaded := 0
            if (!dllLoaded) {
                this.hModule := DllCall("LoadLibrary", "Str", this.dllPath, "Ptr")
                if (!this.hModule) {
                    MsgBox("❌ 无法加载DLL: " this.dllPath, "错误")
                    return false
                }
                dllLoaded := this.hModule
            } else {
                this.hModule := dllLoaded
            }
            
            ; 初始化OCR引擎
            ; OcrInit(det_model, cls_model, rec_model, keys_dict, numThread)
            ; 完全按照 RMT 的方式调用（cls 模型可选）
            this.ocrPtr := DllCall("RapidOcrOnnx\OcrInit"
                , "Str", this.detModel       ; det模型
                , "Str", clsModelToUse       ; cls模型（可选，可以为空）
                , "Str", this.recModel       ; rec模型
                , "Str", this.keysDict       ; 字典文件
                , "Int", 4                   ; 线程数
                , "Cdecl Ptr")               ; 返回指针
            
            if (!this.ocrPtr) {
                global g_Logger
                errMsg := "OcrInit返回NULL，可能的原因：`n"
                errMsg .= "1. 模型文件损坏`n"
                errMsg .= "2. DLL版本不兼容`n"
                errMsg .= "3. 缺少运行时依赖（VC++ Redistributable）`n`n"
                errMsg .= "DLL: " this.dllPath "`n"
                errMsg .= "Det: " this.detModel "`n"
                errMsg .= "Rec: " this.recModel "`n"
                errMsg .= "Keys: " this.keysDict
                
                if (g_Logger) {
                    g_Logger.Error("OcrInit 返回 NULL")
                    g_Logger.Error("DLL路径: " this.dllPath)
                    g_Logger.Error("Det模型: " this.detModel)
                    g_Logger.Error("Rec模型: " this.recModel)
                    g_Logger.Error("Keys字典: " this.keysDict)
                }
                
                MsgBox(errMsg, "❌ OCR引擎初始化失败", "Icon!")
                return false
            }
            
            this.initialized := true
            OutputDebug("✅ OCR 引擎初始化成功 (OcrPtr: " this.ocrPtr ")")
            
            ; 记录到全局日志
            global g_Logger
            if (g_Logger) {
                g_Logger.Info("OCR引擎初始化成功 (Ptr: " this.ocrPtr ")")
            }
            
            return true
            
        } catch as err {
            global g_Logger
            if (g_Logger) {
                g_Logger.Error("OCR 引擎初始化异常: " err.Message)
                g_Logger.Error("异常位置: " err.File ":" err.Line)
            }
            MsgBox("❌ OCR 引擎初始化失败: " err.Message "`n`n位置: " err.File ":" err.Line, "错误")
            return false
        }
    }
    
    ; 识别文字
    RecognizeRegion(x1, y1, x2, y2) {
        if (!this.initialized) {
            return []
        }
        
        try {
            ; 保存临时截图
            tempFile := A_Temp "\ocr_temp_" A_TickCount ".bmp"
            
            ; 使用内置的截图功能
            this.SaveScreenshot(x1, y1, x2, y2, tempFile)
            
            ; 调用 OCR 识别
            results := this.RecognizeImage(tempFile)
            
            ; 删除临时文件
            if (FileExist(tempFile)) {
                try {
                    FileDelete(tempFile)
                }
            }
            
            return results
            
        } catch as err {
            OutputDebug("❌ OCR 识别失败: " err.Message)
            return []
        }
    }
    
    ; 保存截图（使用BMP格式）
    SaveScreenshot(x1, y1, x2, y2, filePath) {
        try {
            ; 计算宽高
            width := x2 - x1
            height := y2 - y1
            
            ; 截图到位图
            pBitmap := this.CaptureScreenToBitmap(x1, y1, width, height)
            
            if (pBitmap) {
                ; 保存为BMP
                this.SaveBitmapToFile(pBitmap, filePath)
                DllCall("DeleteObject", "Ptr", pBitmap)
            }
            
        } catch as err {
            OutputDebug("❌ 保存截图失败: " err.Message)
            throw err
        }
    }
    
    ; 截图到位图
    CaptureScreenToBitmap(x, y, width, height) {
        ; 获取屏幕DC
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
        hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
        
        ; 选择位图
        hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")
        
        ; 复制屏幕
        DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", width, "Int", height,
                "Ptr", hdcScreen, "Int", x, "Int", y, "UInt", 0x00CC0020)
        
        ; 恢复并清理
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
        
        return hBitmap
    }
    
    ; 保存位图到文件（BMP格式）
    SaveBitmapToFile(hBitmap, filePath) {
        ; 获取位图信息
        bi := Buffer(40, 0)  ; BITMAPINFOHEADER
        NumPut("UInt", 40, bi, 0)  ; biSize
        
        hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
        DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", 0, "Ptr", 0, "Ptr", bi, "UInt", 0)
        
        width := NumGet(bi, 4, "Int")
        height := NumGet(bi, 8, "Int")
        bpp := NumGet(bi, 14, "UShort")
        
        ; 计算图像大小
        imageSize := ((width * bpp + 31) // 32) * 4 * Abs(height)
        
        ; 创建位图数据缓冲
        bmpData := Buffer(imageSize)
        NumPut("UShort", bpp, bi, 14)
        NumPut("UInt", 0, bi, 16)  ; biCompression = BI_RGB
        NumPut("UInt", imageSize, bi, 20)
        
        ; 获取位图数据
        DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", Abs(height),
                "Ptr", bmpData, "Ptr", bi, "UInt", 0)
        
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
        
        ; 写入BMP文件
        file := FileOpen(filePath, "w")
        if (file) {
            ; BMP文件头
            file.WriteUShort(0x4D42)  ; "BM"
            file.WriteUInt(54 + imageSize)  ; 文件大小
            file.WriteUInt(0)  ; 保留
            file.WriteUInt(54)  ; 数据偏移
            
            ; 写入BITMAPINFOHEADER
            file.RawWrite(bi)
            
            ; 写入图像数据
            file.RawWrite(bmpData)
            file.Close()
        }
    }
    
    ; 识别图像文件（直接调用RapidOCR DLL）
    RecognizeImage(imagePath) {
        if (!this.initialized || !this.ocrPtr) {
            OutputDebug("❌ OCR引擎未初始化")
            return []
        }
        
        try {
            ; 记录到全局日志
            global g_Logger
            if (g_Logger) {
                g_Logger.Debug("开始OCR识别: " imagePath)
            }
            
            ; 使用静态回调获取文本
            resultText := ""
            
            ; 调用 OcrDetectFile
            ; int OcrDetectFile(void* ocrPtr, const char* imagePath, void* param, void* callback, void* userdata)
            ret := DllCall("RapidOcrOnnx\OcrDetectFile"
                , "Ptr", this.ocrPtr                      ; OCR引擎指针
                , "AStr", imagePath                       ; 图片路径
                , "Ptr", 0                                ; 参数（0使用默认参数）
                , "Ptr", OCREngine.GetTextCallback().ptr  ; 回调函数
                , "Ptr", ObjPtr(&resultText)              ; 用户数据（接收结果）
                , "Cdecl")
            
            if (!ret) {
                if (g_Logger)
                    g_Logger.Error("❌ OcrDetectFile 调用失败")
                OutputDebug("❌ OcrDetectFile 调用失败")
                return []
            }
            
            if (g_Logger)
                g_Logger.Debug("OCR结果: " resultText)
            OutputDebug("OCR结果: " resultText)
            
            ; 解析结果 - RapidOCR直接返回文本，多行用换行符分隔
            results := []
            if (resultText && resultText != "") {
                ; 按行分割
                lines := StrSplit(resultText, "`n", "`r")
                for line in lines {
                    line := Trim(line)
                    if (line != "") {
                        results.Push(Map("text", line, "confidence", 1.0))
                    }
                }
            }
            
            if (g_Logger)
                g_Logger.Info("✅ OCR识别成功，找到 " results.Length " 行文本")
            OutputDebug("✅ OCR识别成功，找到 " results.Length " 行文本")
            
            return results
            
        } catch as err {
            if (g_Logger)
                g_Logger.Error("❌ OCR识别异常: " err.Message)
            OutputDebug("❌ OCR识别异常: " err.Message)
            return []
        }
    }
    
    ; 静态回调函数（接收OCR文本结果）
    static GetTextCallback() {
        static cb := ""
        if (!cb) {
            cb := {
                ptr: CallbackCreate(GetText),
                __Delete: (self) => CallbackFree(self.ptr)
            }
        }
        return cb
        
        GetText(userdata, ptext, presult) {
            if (ptext) {
                text := StrGet(ptext, "UTF-8")
                %ObjFromPtrAddRef(userdata)% := text
            }
            return 0
        }
    }
    
    ; 获取文字（拼接所有识别结果）
    GetTextOnly(x1, y1, x2, y2) {
        results := this.RecognizeRegion(x1, y1, x2, y2)
        
        text := ""
        for result in results {
            if (result.Has("text")) {
                text .= result["text"] " "
            }
        }
        
        return Trim(text)
    }
    
    ; 清理
    Cleanup() {
        ; 销毁OCR引擎
        if (this.ocrPtr) {
            try {
                DllCall("RapidOcrOnnx\OcrDestroy", "Ptr", this.ocrPtr, "Cdecl")
            }
            this.ocrPtr := 0
        }
        
        ; 卸载DLL
        if (this.hModule) {
            DllCall("FreeLibrary", "Ptr", this.hModule)
            this.hModule := 0
        }
        
        this.initialized := false
        OutputDebug("✅ OCR引擎已清理")
    }
}
