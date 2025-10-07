#include-once
#include "agent_http.au3"
#include "agent_util.au3"
#include "agent_config.au3"

Func _Updater_CheckAndMaybeUpdate()
    Local $r = _Api_Latest()
    If @error Or $r[0] <> 200 Then Return
    Local $latest = StringStripWS($r[1], 3)
    If $latest = "" Or $latest = $CFG_VERSION Then Return

    _Log("update available: " & $latest)
    Local $m = _Api_Manifest()
    If @error Or $m[0] <> 200 Then Return
    Local $mj = $m[1]
    Local $url = _JsonGetStr($mj, "url")
    Local $sha = _JsonGetStr($mj, "sha256")
    If $url = "" Then Return

    Local $dst = @TempDir & "\AutoAgent.new.exe"
    InetGet($url, $dst, 1, 0)
    If @error Then Return
    If $sha <> "" Then
        Local $calc = _Sha256File($dst)
        If StringLower($calc) <> StringLower($sha) Then
            _Log("sha256 mismatch")
            Return
        EndIf
    EndIf

    _Updater_SwapAndRestart($dst)
EndFunc

Func _Updater_SwapAndRestart($newPath)
    Local $bat = @TempDir & "\ag_update.bat"
    Local $self = @ScriptFullPath
    Local $fh = FileOpen($bat, 2)
    If $fh = -1 Then Return
    FileWrite($fh, "@echo off" & @CRLF & _
        "set t=\"" & $self & "\"" & @CRLF & _
        "set n=\"" & $newPath & "\"" & @CRLF & _
        ":wait" & @CRLF & _
        "(del %t% >nul 2>&1) && goto go || (ping -n 2 127.0.0.1 >nul & goto wait)" & @CRLF & _
        ":go" & @CRLF & _
        "copy /y %n% %t% >nul" & @CRLF & _
        "start \"\" %t%" & @CRLF & _
        "del /f /q %n%" & @CRLF & _
        "del /f /q \"%~f0\"" & @CRLF)
    FileClose($fh)
    Run(@ComSpec & " /c start \"\" \"" & $bat & "\"", "", @SW_HIDE)
    Exit ; terminate so batch can replace
EndFunc
