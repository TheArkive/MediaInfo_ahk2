; =========================================================================================
; MediaInfo class - Probes media files for lots of info.
;
;   This is a wrapper for MediaInfo.dll and most of its functions.  MediaInfo is a tool for
;   reporting detailed data on media files.  Most users who know the output format of this
;   tool remember it as a block of text with the details of the media file that was given
;   as input.
;
;   While you can do that with this lib (known as the "Inform" property) it is also possible
;   to query specific data fields, so there is no need to parse the full block of text.
;
;   For more detailed documentation, check the comments below the class lib, and the
;   MediaInfo documentation.
;
;   In this package, the dll folder contains examples of how to create language data, as
;   well as examples of how to control the formatting of the "Inform" property by using
;   the Options() method.  These examples were copied from the GUI distribution on the
;   MediaInfo site.
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;   For ease of use, it is highly recommended that you use a JSON serializer, as the output
;   objects in this class wrapper are quite big.
;
;   JSON Serializer - 2022/01/03 - beta.3 (by Coco - translated to v2 by TheArkive - included):
;       https://www.autohotkey.com/boards/viewtopic.php?f=83&t=74799
;
;   JSON library, write by cpp (by thqby):
;       https://www.autohotkey.com/boards/viewtopic.php?f=83&t=100602
;
;   MediaInfo download link:
;       https://mediaarea.net/en/MediaInfo/Download/Windows
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;   USAGE:  mi := MediaInfo(file_path := "", raw := true, drop_frame := "", lang_data := "")
;
;       Params:
;
;           file_path = The full path of the media file.
;
;           raw       = Choose whether to report raw data, or formatted data.  By default
;                       only formatted data is returned.  The data that is formatted is
;                       limited to the elements that I deemed the most helpful, such as
;                       formatting a byte amount into KB/MB/GB.
;
;          drop_frame = When this is set to true, a video property called DurationDropFrame
;                       is inserted and displays the video duration in the following format:
;
;                           HH:MM:SS;FF  (FF = drop frame value if available)
;
;           lang_data = Language data to use for translation.  The encoding should be
;                       UTF-8 for this parameter.  CR or CRLF is supported.  See the
;                       included "de.csv" file for the language data format.  You can
;                       find more info on the MediaInfo site, and through their 
;                       downloads that include the GUI.
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;   Properties:
;
;       Inform (string - READ ONLY)
;
;           Outputs a large foratted string that contains all the media info for the
;           specified file.  This is the simplest way to use this library.  If you want to
;           extract specific fields from a media file, see the "Output" property.
;
;       Output (Map)
;
;           A Map() containing all the MediaInfo data of the file.  By default, when you
;           create a new MediaInfo object with a file path specified, all the data is
;           automatically parsed and put into this property.
;
;           You can access the data like this:
;
;               field_data := mi.Output[ stream_type ][ stream_num ][ field_name ]
;
;                   stream_type = General, Video, Audio, Text, Other, Image, Menu (string)
;                   stream_num  = 1-based number of the stream.
;                   field_name  = See output of _Fields() method.
;
;           You can also loop through the values in a nested FOR loop.
;
;           You can check for the existence of a value like this:
;
;               field_value := ""
;               If ( mi.Output[stream_type][stream_num].Has(field_name) )
;                   field_value := mi.Output[stream_type][stream_num][field_name]
;
;       Version (string - READ ONLY)
;
;           The version of the library as a string, ie "22.03".
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;   Methods:
;
;       Open(sFile)
;
;           Reads the input file and preps for querying the DLL.  You can reuse a MediaInfo
;           object this way if you wish.  Note that the last specified language with
;           SetLang() is used to display the information when getting the "Inform" property.
;
;       SetLang(lang_data := " ")
;
;           Sets the language for all active objects.  The default langauge is English.
;
;           The lang_data param is a multi-line (`n or `r`n) formatted string:
;
;               field_name;new_name
;               field_name;new_name
;               lang_code:alias
;               ... and so on
;
;           See the dll\examples\Languages folder for more examples.  If lang_data is blank
;           then translation is disabled, and reverted back to English (the default).
;
; ==========================================================================================

class MediaInfo {
    Static module := "", mod_path := ""
         , cat  := ["General","Video","Audio","Text","Other","Image","Menu"] ; order defined by enum MediaInfo_stream_t below
         , cat2 := Map("General",1,"Video",2,"Audio",3,"Text",4,"Other",5,"Image",6,"Menu",7)
    
    ptr := 0, output := "", template := Map(), field_temp := ""
    all := false, raw := false, drop_frame := false
    s := ["\MediaInfo_","Complete","Complete_Get","Language","Language_Update"
         ,"ParseUnknownExtensions","ParseUnknownExtensions_Get","Info_Parameters_CSV"]
    
    fld_skip := " Inform Count StreamKind StreamKindID StreamCount StreamOrder StreamKindPos "
    fld_list := Map("Delay",3,"Delay_Original",3,"Duration",3,"Duration_FirstFrame",3,"Duration_LastFrame",3,"Source_Duration/String",3
                   ,"Source_Duration_FirstFrame",3,"Source_Duration_LastFrame",3,"UniqueID","","Language","","BitRate","","BitRate_Maximum",""
                   ,"BitDepth","","BitRate_Nominal","")
    
    __New(file_path := "", raw := false, drop_frame := false, lang_data := "") {
        If (MediaInfo.module="")
            MediaInfo.module := DllCall("LoadLibrary","Str",MediaInfo.mod_path := _lib_path())
        
        this.DefineProp("_CloseDelete",{Call:(o,typ:="Delete")=>DllCall(this.s[1] . typ,"UPtr",this.ptr)})
        this.DefineProp("_opt",{Call:(o,sOpt,param:="")=>DllCall(this.s[1] "Option","UPtr",this.ptr,"Str",sOpt,"Str",param,"UPtr")})
        this.DefineProp("_comp",{Call:(o,p*)=>StrGet(this._opt(!p.Length?this.s[3]:this.s[2],p.Length?String(p[1]):""))})
        this.DefineProp("_streams",{Call:(o,_sType,num:=0)=>DllCall(this.s[1] "Count_Get","UPtr",this.ptr,"Int",MediaInfo.cat2[_sType]-1,"Int",num-1)})
        this.DefineProp("Complete",{Get:this._comp,Set:this._comp})
        this.DefineProp("ParseUnknownExtensions",{Get:(o)=>StrGet(this._opt(this.s[7])),Set:(o,value)=>this._opt(this.s[6],value)})
        
        this.s[1] := MediaInfo.mod_path . this.s[1]
        this.raw := raw, this.drop_frame := drop_frame, this._Fields() ; prep field list
        For _sType in this.field_temp ; build field list template
            this.template[_sType] := ""
        
        this.ptr := DllCall(MediaInfo.mod_path "\MediaInfo_New","UPtr")
        
        If !InStr(lang_data,"`n") && FileExist(lang_data)
            lang_data := this._LoadFile(lang_data) ; load file if lang_data is a file
        
        (lang_data) ? this.SetLang(lang_data) : ""
        If (this.file := file_path)
            this.Open(file_path)
        
        _lib_path(f:="MediaInfo.dll") {
            Loop Files A_ScriptDir "\*.dll", "R"
                If (A_LoopFileName=f)
                    return A_LoopFileFullPath
        }
    }
    
    __Delete() => (this.ptr) ? this._CloseDelete() : ""
    
    Inform =>
        StrGet(DllCall(this.s[1] "Inform","UPtr",this.ptr,"UPtr",0,"UPtr"))
    
    Open(file_path := "") {
        If !file_path || !FileExist(file_path)
            throw Error("Invalid file specified.",-1)
        If !(DllCall(this.s[1] "Open","UPtr",this.ptr,"Str",this.file := file_path))
            throw Error("File not loaded.",-1)
        this._Parse() ; grab all data after successful "Open"
    }
    
    Option(name, value := "") => this._opt(name, value)
    
    SetLang(lang_data := "", self := false) => ; self=TRUE should only change the lang for the current obj
        this._opt(self?this.s[5]:this.s[4],lang_data) ; 5 = Language_Update /// 4 = Language
    
    Version =>
        StrReplace(StrGet(this._opt("Info_Version")),"MediaInfoLib - v")
    
    ; ================================================================
    ; Internal Methods
    ; ================================================================
    
    _div(x,y,dec:=3) => Round(x/y,dec)
    
    _perc(x,dec:=2) => Round(x*100,dec) "%"
    
    _drop_trail(z) => (Instr(z,".")) ? RTrim(z,"0.") : z
    
    _Fields() {
        txt := StrGet(this._opt(this.s[8])), curCat := "", curObj := "", output := Map()
        
        Loop Parse txt, "`n", "`r"
        {
            If A_LoopField && (data := StrSplit(A_LoopField,";"," ")).Length = 1 {
                curObj ? (output[curCat] := curObj) : ""
                curCat := A_LoopField, curObj := Map()
            } Else If !InStr(data[2],"Deprecated")
                curObj[data[1]] := data[2]
        }
        
        output[curCat] := curObj ; commit last obj
        this.field_temp := output
    }
    
    _GetField(_sType,_sField,_iStream:=1,info:=1) =>
        StrGet(DllCall(this.s[1] "Get" ,"UPtr",this.ptr,"Int",MediaInfo.cat2[_sType]-1,"Int",_iStream-1,"Str",_sField,"Int",info))
    
    _GetFieldI(_sType,_iStream,_iField,info:=0) =>
        StrGet(DllCall(this.s[1] "GetI","UPtr",this.ptr,"Int",MediaInfo.cat2[_sType]-1,"Int",_iStream-1,"Int",_iField ,"Int",info))
    
    _LoadFile(file_name, encoding:="UTF-8") => ; returns a string in the specified encoding
        StrReplace(StrGet(FileRead(file_name,"RAW"),encoding),"`r","")
    
    _Parse() {
        this.output := this.template.Clone()
        
        For i, _sType in MediaInfo.cat {
            this.output[_sType] := []
            Loop this._streams(_sType) { ; Stream loop (get stream count)
                _iStream := A_Index, stream_data := Map(), chapter_data := Map()
                
                If (_sType = "Menu") {
                    Loop (fields := this._GetField(_sType,"Count",_iStream)) {
                        fld_name:=this._GetFieldI(_sType,_iStream,A_Index-1,0)
                        If RegExMatch(fld_value:=this._GetFieldI(_sType,_iStream,A_Index-1,1),"Chapter +\d+")
                            chapter_data[fld_name] := fld_value
                    }
                }
                
                For field_name, desc in this.field_temp[_sType] { 
                    fld_value := (!this.raw && this.fld_list.Has(field_name)
                                            && (_v:=this._rep_fld(_sType,field_name,_iStream))!="")
                                             ? _v : this._GetField(_sType,field_name,_iStream,1)
                    
                    If !this.all && (InStr(field_name,"/String") || fld_value="" || InStr(this.fld_skip," " field_name " "))
                        Continue
                    
                    (_sType="Video" && this.drop_frame && "Duration" && !this.all)
                                     ? stream_data["DurationDropFrame"] := this._GetField(_sType,"Duration/String4",_iStream,1) : ""
                    stream_data[field_name] := IsFloat(fld_value) ? this._drop_trail(fld_value) : fld_value
                }
                
                this.output[_sType].Push(stream_data)
                (chapter_data.Count) ? this.output["Chapters"] := chapter_data : ""
            } ; Stream loop END
        } ; For loop END
    }
    
    _rep_fld(_t,f,_s) => ; type, field, stream (replace raw input field with formatted field)
        this._GetField(_t,f "/String" this.fld_list[f],_s)
    
    _size(x,units:="",dec:=2,bin:=true) {
        u := "KB MB GB TB", fac := (bin?1024:1000), res := x/fac, i := 1, L := (units?Integer((InStr(u,units)+2)/3):100)
        While (res >= fac && A_Index < L)
            res := res/fac, i++
        return Round(res,dec) " " SubStr(u,i*3-2,2)
    }
    
    _time(x,t:="") { ; t="" > 01:23:45.678 /// t="hmsm" > 1 h 23 m 45 s 678 ms /// t="hms" > 1 h 23 m 45 s /// t="hm" > 1 h 23 m
        ms := SubStr(x,-3), s := ((r:=SubStr(x,1,-3))="") ? "0" : r
        h := Integer((s//60)//60), m := Integer(( s-(h*60*60) ) // 60), s := Integer(s - (h*60*60) - (m*60))
        return (t="") ? Format("{1:02d}:{2:02d}:{3:02d}.{4:d}",h,m,s,ms) : (t="hmsm")
                      ? h " h " m " m " s " s " ms " ms" : (t="hms")
                      ? h " h " m " m " s " s" : (t="hm")
                      ? h " h " m " m" : ""
    }
}

; ==========================================================================================
; Additional Documentation
; ==========================================================================================
;
;   Properties:
;
;       all
;
;           Setting this property to true prior to calling the Open() method
;
;       Codecs (string - READ ONLY)
;
;           Returns a multi-line string list of known codec info.  Each line contains a
;           semi-colon (;) separated list of info pertaining to each codec.
;
;       Complete (boolean)
;
;           If set to true, then Inform property returns all fields and their string
;           variants.  The default value is FALSE on object creation.
;
;       Inform (string - READ ONLY)
;
;           Outputs a large foratted string that contains all the media info for the
;           specified file.  This is the simplest way to use this library.  If you want to
;           extract specific fields from a media file, see the "Output" property.
;
;       Output (Map)
;
;           A Map() containing all the MediaInfo data of the file.  By default, when you
;           create a new MediaInfo object with a file path specified, all the data is
;           automatically parsed and put into this property.
;
;           You can access the data like this:
;
;               field_data := mi.Output[ stream_type ][ stream_num ][ field_name ]
;
;                   stream_type = General, Video, Audio, Text, Other, Image, Menu (string)
;                   stream_num  = 1-based number of the stream.
;                   field_name  = See output of _Fields() method.
;
;           You can also loop through the values in a nested FOR loop.
;
;           You can check for the existence of a value like this:
;
;               field_value := ""
;               If ( mi.Output[stream_type][stream_num].Has(field_name) )
;                   field_value := mi.Output[stream_type][stream_num][field_name]
;
;       ParseUnknownExtensions (boolean)
;
;           Configure if MediaInfo parse files with unknown extension.  The default value
;           is TRUE on object creation.
;
;       Version (string - READ ONLY)
;
;           The version of the library as a string, ie "22.03".
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;   Methods:
;
;       _Fields()
;
;           This initiates the internal list of fields to check.  Note that some fields are
;           duplicated with "string variants".
;
;           For example, the "FileSize" field has a raw value and some text variants:
;
;               FileSize:         5982664375    <- the normal raw field
;               FileSize/String:  5,57 GiB      <- string variant one
;               FileSize/String1: 6 GiB         <- string variant two, etc...
;
;           The results of this internal configuration are stored in:
;
;               mi.field_temp
;
;           These internal results are not meant to be used directly, but may assist with
;           some debugging.
;
;           The output format of "field_temp" is as follows:
;
;               hint := mi.field_temp[stream_type][field_name]
;
;               * field_name = Note that field names with string variants are listed as
;                              "FieldName/String#" but when 
;
;               * stream_type = General, Video, Audio, Text, Other, Image, Menu
;
;           The hint value is not always populated.  When it is populated it contains info
;           explaining the purpose and use for the queried field.
;
;               Note that the output of this method does not contain any data
;               from the file.  This is just a list of fields per stream type
;               and a description of the field (sometimes), that's it.
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;       Type of info to get (info param - _GetFiled() and _GetFieldI() methods):
;   
;           Field Name      = 0
;           Field Value     = 1
;           Measure units   = 2
;           Options         = 3
;           Name_Text       = 4
;           Measure_Text    = 5
;           Info            = 6
;           HowTo           = 7
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;       _GetField(_iType,_sField,_iStream:=1,info:=1)
;
;           Returns the requested field's data.
;
;           Params:
;               _sType   = Stream Type (string)
;                          Values -> General, Video, Audio, Text, Other, Image, Menu
;               _sField  = Field name (string - see Fields() method)
;               _iStream = 1-based stream number of specified type.
;                   Default: 1 (first stream)
;               info     = Type of info to get (integer - see above)
;                   Default: 1 (Field data)
;
;       _GetFieldI(_iType,_iStream,_iField,info:=0)
;
;           Returns the requested field info in the order returned by the DLL.  This method
;           is meant for looping through the available fields in numerical order.  A specific
;           field will not always be in the same numerical position for every file, so don't
;           rely on this function to get an exhaustive list of fields, and don't rely on a
;           field's position to correspond to a specific number.
;
;           This method is used internally in the Parse() method.  To parse the fields
;           manually, use the CountStreams() method to determine how many streams need to be
;           parsed for each stream type.  Then use the CountFields() method to determine how
;           many loops are required to retrieve all the fields for a particular stream type
;           and number.
;
;           Params:
;               _sType   = Stream Type (string)
;                          Values -> General, Video, Audio, Text, Other, Image, Menu
;               _iStream = 1-based stream number of specified type.
;               _iField  = Zero-based number of field to check.
;               info     = Type of info to get (integer - see above)
;                   Default: 0 (Field name)
;
;       Open(sFile)
;
;           Reads the input file and preps for querying the DLL.  You can reuse a MediaInfo
;           object this way if you wish.
;
;       Option(name, value := "")
;
;           Sets or gets the specified option name.  An option name ending in "_Get" usually
;           will not require an input value.  See option names below.
;
;       SetLang(lang_data, self := true)
;
;           Sets the language for all active objects when self = TRUE, otherwise only the
;           current object is set.
;
;           The lang_data param is a multi-line (`n or `r`n) formatted string:
;
;               field_name;new_name
;               field_name;new_name
;               ... and so on
;
;           For a list of field names, see 
;
;           * It should be possible to set the language of just the current object on the
;           fly using the "Language_Update" option, but this has yet to function as
;           described in the MediaInfo documentation (according to my tests).
;
; =========================================================================================
; Utility Methods
;
;       If you wish to pull raw data from files and format the data yourslef, there are
;       a few tools included that you may find useful.
; =========================================================================================
;       
;       _div(x,y,dec:=3)
;
;           Performs x/y and rounds to the specified decimal place.
;
;       _perc(x,dec:=2)
;
;           Multiplies a decimal by 100, rounds to specified decimal place, and adds "%".
;
;       _drop_trail(z)
;
;           Removes trailing zeros from a decimal.  If a decimal is all zeros, then the
;           decimal is comletely remvoed and an integer is returned.
;
;       _size(x,units:="",dec:=2,bin:=true)
;
;           Input x is the size in bytes.  You can specify the units (KB, MB, GB, TB) or
;           just let the most logical units be used automatically.  The decimal place is
;           rounded as specified.  If bin=TRUE then a factor of 1024 is used.  If bin=FALSE
;           then a factor of 1000 is used.
;
;       _time(x,t:="")
;
;           Input x is milliseconds.  The following formating options are:
;
;               blank   = HH:MM:SS.mmm
;               hmsm    = 1 h 23 m 45 s 678 ms
;               hms     = 1 h 23 m 45 s
;               hm      = 1 h 23 m
;
; =========================================================================================
;                                     Option() List
; =========================================================================================
;
;   Method:  Option(sOption, sValue)
;
;       Complete            = speify true to get exhaustive data from Inform() func
;                    values = "1", "0"
;   
;       Complete_Get        = gets the value of "Complete" (false = "")
;                    values = none
;   
;       Language            = Sets the default lang of future objects, and current obj.
;                             These language settings affect most of the static field/
;                             category names and most of the data in each field.
;
;                    values = Column1;Column2[CRLF] ...
;
;                               Column1 is the default english name
;                               Column2 is the corresponding name in the new language
;                               
;                               * NOTE: This affects mostly the output of the Inform()
;                                 method, but also affects a few data elements in the
;                                 output data, but not all.  If a complete translation
;                                 is desired then one must simply pull the raw data and
;                                 and perform their own translations.
;
;                                 See dll\examples\Language for more lang examples.
;   
;       Language_Update     = sets lang of only current obj
;                    values = see "Language" above
;   
;       Info_Parameters     = vertical list of known/valid field names
;                    values = none
;   
;       Info_Parameters_CSV = csv list of known/valid field names
;                    values = none
;   
;       Info_Codecs         = list of known codecs
;                    values = none
;   
;       Info_Version        = Library version
;                    values = none
;   
;       Info_Url            = MediaInfo URL
;                    values = none
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;                           Slightly More Complicated Options
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;
;       Inform              = Configure custom text when getting the "Inform" property.
;                             (format: "Column1;Colum2[CRLF]...)
;
;                    values = Column1;Column2[CRLF] ...
;
;                               The entire value passed for the "Inform" option is a multi-
;                               line string.  Each line has 2 columns separated by a semi-
;                               colon.  Each line represents a single stream, and the format
;                               of the text that should be used when the coder gets the
;                               "Inform" property.
;
;                               Column1 is a category name.  Each category is either a
;                               stream name, a variant of a stream name, or a page header
;                               section.  The following list should help describe the options:
;
;                                   Streams     Variants         Page Headers
;                                   =========   ==============   ==============
;                                   General     Audio_Begin      Page_Begin
;                                   Video       Audio_Middle     Page_Middle
;                                   Audio       Audio_End        Page_End
;                                   Text        
;                                   Other       etc...
;                                   Image
;                                   Menu
; 
;                                   Chapters ?? (may be deprecated - replaced by Menu?)
;
;                               Column2 is the corresponding string that contains the
;                               formatting data (plain text and field names) to use for the
;                               specified stream (specified by Column1).
;
;                               Check the output of the Options() method using the Info_Parameters
;                               or Info_Parameters_CSV option for a list of field names.  Note that
;                               field names with string variants are listed as "FieldName/String#"
;                               but when using this option, you must replace the "/" with "_" in
;                               these field names.
;
;                                   Here is a short example:
;
; General;General : %FileName%\r\nFormat : %Format%$if(%OverallBitRate%, at %OverallBitRate_String%)\r\n
; Video;Video #%ID% : %Format_String%$if(%BitRate%, at %BitRate_String%)\r\nAspect : %Width% x %Height% (%AspectRatio%) at %FrameRate% fps\r\n\r\n
; Audio;Audio #%ID% : %Format_String%$if(%BitRate%, at %BitRate_String%)\r\nInfos : %Channels% channel(s), %SamplingRate_String%\r\n
; Text;Text #%ID% : %Format_String%\r\n$if(%Language%,Language : %Language%\r\n)\r\n
; Chapters;Chapters #%ID% : %Total% chapters\r\n\r\n
;
;                               As you can see in the example above, you can also use an $if() function
;                               in order to dynamically determine if certain values should be printed.
;
;                                   $if( %Field_Name% , value)
;
;                               And you can use "\r\n" to add line breaks.
;
;                               Check the dll\exmples\Formatting folder for some ideas on how
;                               to use this feature.
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Options that I'm not sure how to deal with yet
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;   
; * "ShowFiles": Configure if MediaInfo keep in memory files with specific kind of streams (or no streams)
; Value is Description of components (format: "Column1;Colum2 ...)
;
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; * "Language_Get": Get the language file in memory (this is a bit redundand, as AHK can manage this easily)
; * "Language_Update": Configure language of this object only (for optimisation) (doesn't work as described, or at all)
; Value is Description of language (format: "Column1;Column2[CRLF] ...)
; Column 1: Unique name ("Bytes", "Title")
; Column 2: translation ("Octets", "Titre") 
; ==========================================================================================

; =======================================================
; Notes
; =======================================================

; typedef (char / wchar_t) MediaInfo_Char;
; typedef unsigned char MediaInfo_int8u;
; typedef unsigned __int64   MediaInfo_int64u;

; /** @brief Kinds of Stream */
; typedef enum MediaInfo_stream_t {
    ; MediaInfo_Stream_General,
    ; MediaInfo_Stream_Video,
    ; MediaInfo_Stream_Audio,
    ; MediaInfo_Stream_Text,
    ; MediaInfo_Stream_Other,
    ; MediaInfo_Stream_Image,
    ; MediaInfo_Stream_Menu,
    ; MediaInfo_Stream_Max
; } MediaInfo_stream_C;

; /** @brief Kinds of Info */
; typedef enum MediaInfo_info_t { ; aka -> info_t
    ; MediaInfo_Info_Name,
    ; MediaInfo_Info_Text,
    ; MediaInfo_Info_Measure,
    ; MediaInfo_Info_Options,
    ; MediaInfo_Info_Name_Text,
    ; MediaInfo_Info_Measure_Text,
    ; MediaInfo_Info_Info,
    ; MediaInfo_Info_HowTo,
    ; MediaInfo_Info_Max
; } MediaInfo_info_C;

; /** @brief Option if InfoKind = Info_Options */
; typedef enum MediaInfo_infooptions_t {
    ; MediaInfo_InfoOption_ShowInInform,
    ; MediaInfo_InfoOption_Reserved,
    ; MediaInfo_InfoOption_ShowInSupported,
    ; MediaInfo_InfoOption_TypeOfValue,
    ; MediaInfo_InfoOption_Max
; } MediaInfo_infooptions_C;

; /** @brief File opening options */
; typedef enum MediaInfo_fileoptions_t {
    ; MediaInfo_FileOption_Nothing     = 0x00,
    ; MediaInfo_FileOption_NoRecursive = 0x01,
    ; MediaInfo_FileOption_CloseAll    = 0x02,
    ; MediaInfo_FileOption_Max         = 0x04
; } MediaInfo_fileoptions_C;


; ===============================================
; function list:
; ===============================================
; void*           MediaInfo_New()
; void            MediaInfo_Delete(void*)

; size_t          MediaInfo_Open(void*
;                              , const MediaInfo_Char*)

; void            MediaInfo_Close(void*)

; size_t          MediaInfo_Open_Buffer_Init(void*
;                                          , MediaInfo_int64u File_Size
;                                          , MediaInfo_int64u File_Offset)

; size_t          MediaInfo_Open_Buffer_Continue(void*
;                                              , MediaInfo_int8u* Buffer
;                                              , size_t Buffer_Size)

; int64u          MediaInfo_Open_Buffer_Continue_GoTo_Get(void*) ???
; size_t          MediaInfo_Open_Buffer_Finalize(void*)

; size_t          MediaInfo_Open_NextPacket(void*)

; const           MediaInfo_Inform(void*
;                                , size_t Reserved)

; const           MediaInfo_GetI(void*
;                              , MediaInfo_stream_C StreamKind
;                              , size_t StreamNumber
;                              , size_t Parameter
;                              , MediaInfo_info_C KindOfInfo)

; const           MediaInfo_Get(void*
;                             , MediaInfo_stream_C StreamKind
;                             , size_t StreamNumber
;                             , const MediaInfo_Char* Parameter
;                             , MediaInfo_info_C KindOfInfo
;                             , MediaInfo_info_C KindOfSearch)

; size_t          MediaInfo_Output_Buffer_Get(void*
;                                           , const MediaInfo_Char* Parameter)

; size_t          MediaInfo_Output_Buffer_GetI(void*
;                                            , size_t Pos)

; MediaInfo_Char* MediaInfo_Option(void*
;                                , const MediaInfo_Char* Parameter
;                                , const MediaInfo_Char* Value)

; size_t          MediaInfo_State_Get(void*)

; size_t          MediaInfo_Count_Get(void*
;                                   , MediaInfo_stream_C StreamKind
;                                   , size_t StreamNumber)

; size_t          MediaInfo_Count_Get_Files(void*)


