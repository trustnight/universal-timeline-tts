; ===================================================
; TTS 引擎模块
; 使用 Windows SAPI 进行文字转语音
; ===================================================

class TTSEngine {
    voice := ""
    enabled := true
    rate := 0
    volume := 100
    selectedVoiceId := ""  ; 选中的语音ID
    
    ; 初始化
    Init() {
        try {
            this.voice := ComObject("SAPI.SpVoice")
            this.voice.Rate := this.rate
            this.voice.Volume := this.volume
            
            ; 如果有指定语音，则切换
            if (this.selectedVoiceId != "") {
                this.SetVoiceById(this.selectedVoiceId)
            }
            
            ; 输出调试信息
            currentVoice := this.voice.Voice.GetDescription()
            OutputDebug("TTS 初始化: Rate=" this.voice.Rate " Volume=" this.voice.Volume " Voice=" currentVoice)
            
            return true
        } catch as err {
            MsgBox("❌ TTS 引擎初始化失败: " err.Message, "错误")
            return false
        }
    }
    
    ; 获取所有可用语音
    GetAvailableVoices() {
        if (!this.voice) {
            return []
        }
        
        try {
            voices := []
            voiceObjs := this.voice.GetVoices()
            
            ; 遍历所有语音
            loop voiceObjs.Count {
                voiceObj := voiceObjs.Item(A_Index - 1)
                voiceId := voiceObj.Id
                voiceName := voiceObj.GetDescription()
                
                ; 只保留中文语音（过滤掉英文等其他语音）
                if (InStr(voiceName, "Chinese") || InStr(voiceName, "中文") || 
                    InStr(voiceName, "Huihui") || InStr(voiceName, "Yaoyao") || 
                    InStr(voiceName, "Kangkang") || InStr(voiceName, "Xiaoxiao") || 
                    InStr(voiceName, "Yunxi") || InStr(voiceName, "Yunyang") || 
                    InStr(voiceName, "Xiaoyi") || InStr(voiceName, "Xiaochen") ||
                    InStr(voiceName, "晓晓") || InStr(voiceName, "云希") || 
                    InStr(voiceName, "云扬") || InStr(voiceName, "晓伊") || 
                    InStr(voiceName, "晓辰")) {
                    
                    voices.Push(Map(
                        "id", voiceId,
                        "name", voiceName
                    ))
                }
            }
            
            return voices
        } catch as err {
            OutputDebug("❌ 获取语音列表失败: " err.Message)
            return []
        }
    }
    
    ; 通过ID设置语音
    SetVoiceById(voiceId) {
        if (!this.voice) {
            return false
        }
        
        try {
            this.selectedVoiceId := voiceId
            voiceObjs := this.voice.GetVoices()
            
            ; 查找匹配的语音
            loop voiceObjs.Count {
                voiceObj := voiceObjs.Item(A_Index - 1)
                if (voiceObj.Id = voiceId) {
                    this.voice.Voice := voiceObj
                    OutputDebug("✅ 已切换语音: " voiceObj.GetDescription())
                    return true
                }
            }
            
            OutputDebug("❌ 未找到语音ID: " voiceId)
            return false
        } catch as err {
            OutputDebug("❌ 设置语音失败: " err.Message)
            return false
        }
    }
    
    ; 通过名称设置语音（模糊匹配）
    SetVoiceByName(voiceName) {
        if (!this.voice) {
            return false
        }
        
        try {
            voiceObjs := this.voice.GetVoices()
            
            ; 查找匹配的语音
            loop voiceObjs.Count {
                voiceObj := voiceObjs.Item(A_Index - 1)
                if (InStr(voiceObj.GetDescription(), voiceName)) {
                    this.voice.Voice := voiceObj
                    this.selectedVoiceId := voiceObj.Id
                    OutputDebug("✅ 已切换语音: " voiceObj.GetDescription())
                    return true
                }
            }
            
            OutputDebug("❌ 未找到语音: " voiceName)
            return false
        } catch as err {
            OutputDebug("❌ 设置语音失败: " err.Message)
            return false
        }
    }
    
    ; 获取当前语音名称
    GetCurrentVoiceName() {
        if (!this.voice) {
            return ""
        }
        
        try {
            return this.voice.Voice.GetDescription()
        } catch {
            return ""
        }
    }
    
    ; 获取当前语音ID
    GetCurrentVoiceId() {
        if (!this.voice) {
            return ""
        }
        
        try {
            return this.voice.Voice.Id
        } catch {
            return ""
        }
    }
    
    ; 设置语速 (-10 到 10)
    SetRate(rate) {
        this.rate := rate
        if (this.voice) {
            this.voice.Rate := rate
        }
    }
    
    ; 设置音量 (0 到 100)
    SetVolume(volume) {
        this.volume := volume
        if (this.voice) {
            this.voice.Volume := volume
            OutputDebug("TTS 音量已设置: " volume " (实际值: " this.voice.Volume ")")
        }
    }
    
    ; 获取当前音量
    GetVolume() {
        if (this.voice) {
            return this.voice.Volume
        }
        return 0
    }
    
    ; 启用/禁用 TTS
    SetEnabled(enabled) {
        this.enabled := enabled
    }
    
    ; 播报文字（异步，排队模式）
    Speak(text, waitForPrevious := false) {
        if (!this.enabled) {
            return false
        }
        
        if (!this.voice) {
            return false
        }
        
        try {
            ; ⚠️ 注意：默认异步播报，不等待上一次完成
            ; 如果上一次还在播报，新的播报会排队或覆盖
            if (waitForPrevious) {
                ; 只在特定场景（如测试TTS）使用同步等待
                timeout := A_TickCount + 3000
                while (this.voice.Status.RunningState = 2 && A_TickCount < timeout) {
                    Sleep(50)
                }
            }
            
            ; 异步播报（不阻塞主线程）
            ; SVSFlagsAsync = 1: 异步模式（排队）
            this.voice.Speak(text, 1)
            OutputDebug("🔊 [TTS排队] " text)
            return true
        } catch as err {
            OutputDebug("❌ TTS 播报失败: " err.Message)
            return false
        }
    }
    
    ; 优先播报（打断当前播报，立即播放）
    SpeakWithPriority(text) {
        if (!this.enabled) {
            return false
        }
        
        if (!this.voice) {
            return false
        }
        
        try {
            ; SVSFlagsAsync | SVSFPurgeBeforeSpeak = 1 | 2 = 3
            ; 打断当前播报并清空队列，立即播放新内容
            this.voice.Speak(text, 3)
            OutputDebug("🔊 [TTS优先] " text " ⚡")
            return true
        } catch as err {
            OutputDebug("❌ TTS 优先播报失败: " err.Message)
            return false
        }
    }
    
    ; 停止播报
    Stop() {
        if (this.voice) {
            try {
                this.voice.Speak("", 2)  ; 2 = SVSFPurgeBeforeSpeak
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    ; 等待播报完成
    Wait() {
        if (this.voice) {
            try {
                ; 等待当前播报完成
                while (this.voice.Status.RunningState = 2) {  ; 2 = SRSEIsSpeaking
                    Sleep(100)
                }
                return true
            } catch {
                return false
            }
        }
        return false
    }
}

