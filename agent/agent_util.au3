#include-once
#include <File.au3>
#include <Crypt.au3>
#include <Date.au3>

Global Const $AG_LOG_DIR  = @ProgramDataDir & "\AutoAgent"
Global Const $AG_LOG_FILE = $AG_LOG_DIR & "\agent.log"

Func _EnsureDir($p)
    If Not FileExists($p) Then DirCreate($p)
EndFunc

Func _NowTs()
    Return @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
           "T" & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)
EndFunc

Func _Log($s)
    _EnsureDir($AG_LOG_DIR)
    Local $line = _NowTs() & "  " & $s & @CRLF
    FileWrite($AG_LOG_FILE, $line)
EndFunc

Func _ComputeClientId()
    _Crypt_Startup()
    Local $raw = @ComputerName & "|" & @OSVersion & "|" & @OSArch
    Local $hbin = _Crypt_HashData(StringToBinary($raw, 4), $CALG_SHA1)
    _Crypt_Shutdown()
    ; to hex short 16 chars
    Local $hex = ""
    For $i = 1 To StringLen($hbin)
        $hex &= Hex(Asc(StringMid($hbin, $i, 1)), 2)
    Next
    Return StringLeft($hex, 16)
EndFunc

Func _RunCmdCapture($cmd)
    Local $pid = Run(@ComSpec & " /c " & $cmd, "", @SW_HIDE, 6)
    Local $out = ""
    While 1
        $out &= StdoutRead($pid)
        If @error Then ExitLoop
        Sleep(30)
    WEnd
    Return StringStripWS($out, 3)
EndFunc

Func _Sha256File($p)
    _Crypt_Startup()
    Local $bin = _Crypt_HashFile($p, $CALG_SHA_256)
    _Crypt_Shutdown()
    If @error Or $bin = "" Then Return ""
    Local $hex = ""
    For $i = 1 To StringLen($bin)
        $hex &= Hex(Asc(StringMid($bin, $i, 1)), 2)
    Next
    Return StringLower($hex)
EndFunc

Func _JsonEsc($s)
    $s = StringReplace($s, "\\", "\\\\")
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CRLF, "\\n")
    $s = StringReplace($s, @LF, "\\n")
    $s = StringReplace($s, @CR, "\\r")
    Return $s
EndFunc

Func _JsonGetStr($json, $key)
    Local $m = StringRegExp($json, '"' & $key & '"\s*:\s*"(.*?)"', 1)
    If @error Or UBound($m) = 0 Then Return ""
    Return $m[0]
EndFunc

Func _JsonGetNum($json, $key)
    Local $m = StringRegExp($json, '"' & $key & '"\s*:\s*([-0-9\.]+)', 1)
    If @error Or UBound($m) = 0 Then Return 0
    Return Number($m[0])
EndFunc
