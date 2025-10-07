; agent_updater.au3
#include "agent_config.au3"
#include "agent_http.au3"
#include "agent_util.au3"

Global $gLastUpdateCheck = TimerInit()

Func _Updater_CheckAndMaybeUpdate()
    If TimerDiff($gLastUpdateCheck) < 600000 Then Return ; 10 phút
    $gLastUpdateCheck = TimerInit()

    Local $latest = _Api_GetLatest()
    If StringLen($latest) = 0 Then Return
    If $latest <> _Cfg_Version() Then
        _Log("New version available: " & $latest & " (current " & _Cfg_Version() & ")")
        ; TODO: download from R2 and swap via run-once Scheduled Task
    EndIf
EndFunc

Func _Updater_Force($ver)
    ; TODO: same as above but immediate
    _Log("Force update to " & $ver)
EndFunc
