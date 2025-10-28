; ===================================================
; JSON 解析库 for AutoHotkey v2
; 支持完整的 JSON 解析和生成
; ===================================================

class JSON {
    
    ; 解析 JSON 字符串为 AHK 对象
    static Parse(jsonText) {
        jsonText := Trim(jsonText)
        pos := {i: 1}
        return this._ParseValue(jsonText, pos)
    }
    
    ; 将 AHK 对象转换为 JSON 字符串
    static Stringify(obj, indent := "") {
        return this._StringifyValue(obj, indent, "")
    }
    
    ; 解析值
    static _ParseValue(jsonText, pos) {
        this._SkipWhitespace(jsonText, pos)
        
        if (pos.i > StrLen(jsonText)) {
            return ""
        }
        
        char := SubStr(jsonText, pos.i, 1)
        
        ; 对象
        if (char = "{") {
            return this._ParseObject(jsonText, pos)
        }
        ; 数组
        else if (char = "[") {
            return this._ParseArray(jsonText, pos)
        }
        ; 字符串
        else if (char = '"') {
            return this._ParseString(jsonText, pos)
        }
        ; 数字
        else if (char = "-" || (char >= "0" && char <= "9")) {
            return this._ParseNumber(jsonText, pos)
        }
        ; true
        else if (SubStr(jsonText, pos.i, 4) = "true") {
            pos.i += 4
            return true
        }
        ; false
        else if (SubStr(jsonText, pos.i, 5) = "false") {
            pos.i += 5
            return false
        }
        ; null
        else if (SubStr(jsonText, pos.i, 4) = "null") {
            pos.i += 4
            return ""
        }
        
        throw Error("JSON 解析错误：无效的值 at position " pos.i)
    }
    
    ; 解析对象
    static _ParseObject(jsonText, pos) {
        obj := Map()
        pos.i++  ; 跳过 '{'
        
        this._SkipWhitespace(jsonText, pos)
        
        ; 空对象
        if (SubStr(jsonText, pos.i, 1) = "}") {
            pos.i++
            return obj
        }
        
        loop {
            this._SkipWhitespace(jsonText, pos)
            
            ; 解析键
            if (SubStr(jsonText, pos.i, 1) != '"') {
                throw Error("JSON 解析错误：期望字符串键 at position " pos.i)
            }
            
            key := this._ParseString(jsonText, pos)
            
            this._SkipWhitespace(jsonText, pos)
            
            ; 期望 ':'
            if (SubStr(jsonText, pos.i, 1) != ":") {
                throw Error("JSON 解析错误：期望 ':' at position " pos.i)
            }
            pos.i++
            
            ; 解析值
            value := this._ParseValue(jsonText, pos)
            obj[key] := value
            
            this._SkipWhitespace(jsonText, pos)
            
            char := SubStr(jsonText, pos.i, 1)
            
            if (char = "}") {
                pos.i++
                break
            }
            else if (char = ",") {
                pos.i++
                continue
            }
            else {
                throw Error("JSON 解析错误：期望 ',' 或 '}' at position " pos.i)
            }
        }
        
        return obj
    }
    
    ; 解析数组
    static _ParseArray(jsonText, pos) {
        arr := []
        pos.i++  ; 跳过 '['
        
        this._SkipWhitespace(jsonText, pos)
        
        ; 空数组
        if (SubStr(jsonText, pos.i, 1) = "]") {
            pos.i++
            return arr
        }
        
        loop {
            value := this._ParseValue(jsonText, pos)
            arr.Push(value)
            
            this._SkipWhitespace(jsonText, pos)
            
            char := SubStr(jsonText, pos.i, 1)
            
            if (char = "]") {
                pos.i++
                break
            }
            else if (char = ",") {
                pos.i++
                continue
            }
            else {
                throw Error("JSON 解析错误：期望 ',' 或 ']' at position " pos.i)
            }
        }
        
        return arr
    }
    
    ; 解析字符串
    static _ParseString(jsonText, pos) {
        pos.i++  ; 跳过开始的 '"'
        
        str := ""
        
        loop {
            if (pos.i > StrLen(jsonText)) {
                throw Error("JSON 解析错误：未闭合的字符串")
            }
            
            char := SubStr(jsonText, pos.i, 1)
            
            if (char = '"') {
                pos.i++
                break
            }
            else if (char = "\") {
                pos.i++
                if (pos.i > StrLen(jsonText)) {
                    throw Error("JSON 解析错误：无效的转义序列")
                }
                
                escapeChar := SubStr(jsonText, pos.i, 1)
                
                switch escapeChar {
                    case '"':
                        str .= '"'
                    case '\':
                        str .= '\'
                    case '/':
                        str .= '/'
                    case 'b':
                        str .= '`b'
                    case 'f':
                        str .= '`f'
                    case 'n':
                        str .= '`n'
                    case 'r':
                        str .= '`r'
                    case 't':
                        str .= '`t'
                    case 'u':
                        ; Unicode 转义（简化处理）
                        str .= escapeChar
                    default:
                        str .= escapeChar
                }
                
                pos.i++
            }
            else {
                str .= char
                pos.i++
            }
        }
        
        return str
    }
    
    ; 解析数字
    static _ParseNumber(jsonText, pos) {
        startPos := pos.i
        
        ; 负号
        if (SubStr(jsonText, pos.i, 1) = "-") {
            pos.i++
        }
        
        ; 整数部分
        if (SubStr(jsonText, pos.i, 1) = "0") {
            pos.i++
        }
        else {
            loop {
                if (pos.i > StrLen(jsonText)) {
                    break
                }
                
                char := SubStr(jsonText, pos.i, 1)
                ; 检查是否是数字字符 (0-9)
                if (char != "" && InStr("0123456789", char)) {
                    pos.i++
                }
                else {
                    break
                }
            }
        }
        
        ; 小数部分
        if (SubStr(jsonText, pos.i, 1) = ".") {
            pos.i++
            
            loop {
                if (pos.i > StrLen(jsonText)) {
                    break
                }
                
                char := SubStr(jsonText, pos.i, 1)
                ; 检查是否是数字字符 (0-9)
                if (char != "" && InStr("0123456789", char)) {
                    pos.i++
                }
                else {
                    break
                }
            }
        }
        
        ; 指数部分
        char := SubStr(jsonText, pos.i, 1)
        if (char = "e" || char = "E") {
            pos.i++
            
            char := SubStr(jsonText, pos.i, 1)
            if (char = "+" || char = "-") {
                pos.i++
            }
            
            loop {
                if (pos.i > StrLen(jsonText)) {
                    break
                }
                
                char := SubStr(jsonText, pos.i, 1)
                ; 检查是否是数字字符 (0-9)
                if (char != "" && InStr("0123456789", char)) {
                    pos.i++
                }
                else {
                    break
                }
            }
        }
        
        numStr := SubStr(jsonText, startPos, pos.i - startPos)
        return Number(numStr)
    }
    
    ; 跳过空白字符
    static _SkipWhitespace(jsonText, pos) {
        loop {
            if (pos.i > StrLen(jsonText)) {
                break
            }
            
            char := SubStr(jsonText, pos.i, 1)
            if (char = " " || char = "`t" || char = "`n" || char = "`r") {
                pos.i++
            }
            else {
                break
            }
        }
    }
    
    ; 序列化值
    static _StringifyValue(value, indent, currentIndent) {
        valueType := Type(value)
        
        ; Map (对象)
        if (valueType = "Map") {
            return this._StringifyObject(value, indent, currentIndent)
        }
        ; Array
        else if (valueType = "Array") {
            return this._StringifyArray(value, indent, currentIndent)
        }
        ; String
        else if (valueType = "String") {
            return this._StringifyString(value)
        }
        ; Number/Integer/Float
        else if (valueType = "Integer" || valueType = "Float") {
            return String(value)
        }
        ; Boolean
        else if (value = true || value = false) {
            return value ? "true" : "false"
        }
        ; Null/Empty
        else {
            return "null"
        }
    }
    
    ; 序列化对象
    static _StringifyObject(obj, indent, currentIndent) {
        if (obj.Count = 0) {
            return "{}"
        }
        
        newIndent := currentIndent (indent ? indent : "")
        json := "{"
        
        if (indent) {
            json .= "`n"
        }
        
        isFirst := true
        for key, value in obj {
            if (!isFirst) {
                json .= ","
                if (indent) {
                    json .= "`n"
                }
            }
            
            if (indent) {
                json .= newIndent
            }
            
            json .= this._StringifyString(key) ":"
            
            if (indent) {
                json .= " "
            }
            
            json .= this._StringifyValue(value, indent, newIndent)
            
            isFirst := false
        }
        
        if (indent) {
            json .= "`n" currentIndent
        }
        
        json .= "}"
        
        return json
    }
    
    ; 序列化数组
    static _StringifyArray(arr, indent, currentIndent) {
        if (arr.Length = 0) {
            return "[]"
        }
        
        newIndent := currentIndent (indent ? indent : "")
        json := "["
        
        if (indent) {
            json .= "`n"
        }
        
        for index, value in arr {
            if (index > 1) {
                json .= ","
                if (indent) {
                    json .= "`n"
                }
            }
            
            if (indent) {
                json .= newIndent
            }
            
            json .= this._StringifyValue(value, indent, newIndent)
        }
        
        if (indent) {
            json .= "`n" currentIndent
        }
        
        json .= "]"
        
        return json
    }
    
    ; 序列化字符串
    static _StringifyString(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        str := StrReplace(str, "`b", "\b")
        str := StrReplace(str, "`f", "\f")
        
        return '"' str '"'
    }
}

; 便捷函数
Jxon_Load(jsonText) {
    return JSON.Parse(jsonText)
}

Jxon_Dump(obj, indent := "  ") {
    return JSON.Stringify(obj, indent)
}

