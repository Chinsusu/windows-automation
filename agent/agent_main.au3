; agent_main.au3
#include "agent_config.au3"
#include "agent_util.au3"
#include "agent_http.au3"
#include "agent_commands.au3"
#include "agent_updater.au3"

Global Const $AGENT_VERSION = _Cfg_Version()
Global $gClientId = _ComputeClientId()

If $CmdLineRaw = "/service" Then
    _EnsureScheduledTask()
EndIf

_Log("Agent start v" & $AGENT_VERSION & ", id=" & $gClientId)

While 1
    ; Check update (non-blocking stub)
    _Updater_CheckAndMaybeUpdate()

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
