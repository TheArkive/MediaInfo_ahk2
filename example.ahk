#Include mediainfo.ahk

lang := "de.csv" ; Load UTF8 without BOM and ensure UTF8 format

path := "sample-mp4-file.mp4" ; if you can, use larger video file

; ======================================================
; This is the most direct way to load the object, prep
; the data, and load an optional translation in a single
; line.
; ======================================================
mi := MediaInfo(path,,,lang) ; test German translation (provided by MediaInfo downloads)
; mi := MediaInfo(path,,,lang)
; mi.SetLang(), mi.Open(path)
; ======================================================
; The usual output format is easily accessible with the
; "inform" property.
; ======================================================
A_Clipboard := "Normal Inform output`n`n" mi.inform
msgbox "Check Clipboard`n`n" A_Clipboard

; ======================================================
; Next is the data collected in the Output property.
; ======================================================
A_Clipboard := "Comprehensive Field List per Stream`n`n     `"Field`": `"Value`"`n`n" StrReplace(jxon_dump(mi.output,4),"\/","/")
msgbox "Check Clipboard`n`n" A_Clipboard

; ======================================================
; This next example pulls raw data, and also pulls
; the DurationDropFrame from the video stream as well.
; ======================================================
mi := MediaInfo(path,true,true,lang)
A_Clipboard := "Complete Inform output`n`n" mi.inform
msgbox "Check Clipboard`n`n" A_Clipboard

; ======================================================
; Here is a small example of customizing the output of
; the "Inform" property.
; ======================================================

inform := "
(
General;General           : %FileName%\r\nFormat            : %Format%$if(%OverallBitRate%, at %OverallBitRate_String%)\r\nLength            : %FileSize_String% for %Duration_String1%\r\n\r\n
Video;Video #%ID%          : %Format_String%$if(%BitRate%, at %BitRate_String%)\r\nAspect            : %Width% x %Height% (%AspectRatio%) at %FrameRate% fps\r\n\r\n
Audio;Audio #%ID%          : %Format_String%$if(%BitRate%, at %BitRate_String%)\r\nInfos             : %Channel(s)_String%, %SamplingRate_String%\r\n$if(%Language%,Language          : %Language%\r\n)\r\n
Text;Text #%ID%           : %Format_String%\r\n$if(%Language%,Language          : %Language%\r\n)\r\n
Chapters;Chapters #%ID%       : %Total% chapters\r\n\r\n
)"

mi.Option("Inform",inform)
A_Clipboard := mi.Inform
msgbox A_Clipboard

; =====================================
; utility functions
; =====================================

Jxon_Dump(obj, indent:="", lvl:=1) {
	if IsObject(obj) {
		memType := Type(obj) ; Type.Call(obj)
		is_array := (memType = "Array") ? 1 : 0
		
		if (memType ? (memType != "Object" And memType != "Map" And memType != "Array") : (ObjGetCapacity(obj) == ""))
			throw Error("Object type not supported.", -1, Format("<Object at 0x{:p}>", ObjPtr(obj)))
		
		if IsInteger(indent)
		{
			if (indent < 0)
				throw Error("Indent parameter must be a postive integer.", -1, indent)
			spaces := indent, indent := ""
			
			Loop spaces ; ===> changed
				indent .= " "
		}
		indt := ""
		
		Loop indent ? lvl : 0
			indt .= indent

		lvl += 1, out := "" ; Make #Warn happy
		for k, v in obj {
			if IsObject(k) || (k == "")
				throw Error("Invalid object key.", -1, k ? Format("<Object at 0x{:p}>", ObjPtr(obj)) : "<blank>")
			
			if !is_array ;// key ; ObjGetCapacity([k], 1)
				out .= (ObjGetCapacity([k]) ? Jxon_Dump(k) : escape_str(k)) (indent ? ": " : ":") ; token + padding
			
			out .= Jxon_Dump(v, indent, lvl) ; value
				.  ( indent ? ",`n" . indt : "," ) ; token + indent
		}

		if (out != "") {
			out := Trim(out, ",`n" . indent)
			if (indent != "")
				out := "`n" . indt . out . "`n" . SubStr(indt, StrLen(indent)+1)
		}
		
		return is_array ? "[" . out . "]" : "{" . out . "}"
	} else { ; Number
		If (Type(obj) != "String")
			return obj
		Else
            return escape_str(obj)
	}
    
    escape_str(obj) {
        obj := StrReplace(obj,"\","\\")
        obj := StrReplace(obj,"`t","\t")
        obj := StrReplace(obj,"`r","\r")
        obj := StrReplace(obj,"`n","\n")
        obj := StrReplace(obj,"`b","\b")
        obj := StrReplace(obj,"`f","\f")
        obj := StrReplace(obj,"/","\/")
        obj := StrReplace(obj,'"','\"')
        
        return '"' obj '"'
    }
}

dbg(_in) { ; AHK v2
    Loop Parse _in, "`n", "`r"
        OutputDebug "AHK: " A_LoopField
}