; agent_util.au3
#include-once
#include <File.au3>
#include <Date.au3>
#include <Crypt.au3>

; FIX: @ProgramDataDir không tồn tại, dùng đường dẫn cứng hoặc @AppDataCommonDir
Global Const $LOG_DIR = "C:\ProgramData\AutoAgent"
Global Const $LOG_PATH = $LOG_DIR & "\agent.log"

Func _EnsureDir($p)
    If Not FileExists($p) Then DirCreate($p)
EndFunc

Func _Log($s)
    _EnsureDir($LOG_DIR)
    Local $t = _NowCalc() & " - " & $s & @CRLF
    FileWrite($LOG_PATH, $t)
EndFunc

Func _ComputeClientId()
    _Crypt_Startup()
    ; FIX: dùng @OSArch (AutoIt có macro này), @CPUArch là macro không tồn tại
    Local $raw = @ComputerName & "|" & @OSVersion & "|" & @OSArch
    Local $bin = StringToBinary($raw, 4)
    Local $hash = _Crypt_HashData($bin, $CALG_SHA1)
    _Crypt_Shutdown()
    ; giữ logic cũ: cắt còn 16 ký tự hex
    Local $hex = StringTrimLeft($hash, 2) ; nếu là dạng "0x...." -> bỏ 0x
    Return StringLeft($hex, 16)
EndFunc

Func _RunCmd($cmd)
    Local $iPID = Run(@ComSpec & " /c " & $cmd, "", @SW_HIDE, 6) ; 6=STDOUT_CHILD+STDERR_CHILD
    Local $out = ""
    While 1
        $out &= StdoutRead($iPID)
        If @error Then ExitLoop
        Sleep(50)
    WEnd
    Return $out
EndFunc

; Create Scheduled Task on first run (idempotent best-effort)
Func _EnsureScheduledTask()
    Local $cmd = 'schtasks /Query /TN "AutoAgent"'
    Local $out = _RunCmd($cmd)
    If StringInStr($out, "ERROR:") Then
        _RunCmd('schtasks /Create /TN "AutoAgent" /TR "' & @ScriptFullPath & ' /service" /SC ONSTART /RU SYSTEM /RL HIGHEST /F')
        _RunCmd('schtasks /Create /TN "AutoAgent-Logon" /TR "' & @ScriptFullPath & ' /service" /SC ONLOGON /RU SYSTEM /RL HIGHEST /F')
    EndIf
EndFunc

Func _Ok($msg)
    Return $msg
EndFunc

Func _Err($msg)
    Return "ERR:" & $msg
EndFunc
