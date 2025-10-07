#include-once
#include "agent_config.au3"
#include "agent_util.au3"
#include "agent_http.au3"
#include "agent_commands.au3"
#include "agent_updater.au3"

Global $gCID = _ComputeClientId()
_Log("Agent " & $CFG_VERSION & " start id=" & $gCID & " server=" & _Cfg_Server())

Local $lastBeat = TimerInit()

While 1
    ; periodic heartbeat
    If TimerDiff($lastBeat) > $CFG_BEAT_MS Then
        _Api_Callback($gCID, "live", "heartbeat")
        $lastBeat = TimerInit()
    EndIf

    ; updater (cheap check)
    _Updater_CheckAndMaybeUpdate()

    ; long-poll a task
    Local $r = _Api_LongPollTask($gCID)
    If Not @error Then
        If $r[0] = 200 And $r[1] <> "" Then
            Local $tj = $r[1]
            Local $task_id = _JsonGetStr($tj, "task_id")
            Local $type    = _JsonGetStr($tj, "type")
            ; args block (non-greedy)
            Local $m = StringRegExp($tj, '"args"\s*:\s*(\{.*?\})(?:,|\})', 1)
            Local $args = (Not @error And UBound($m) > 0) ? $m[0] : "{}"

            _Api_Callback($gCID, "busy", "Task:" & $type)
            Local $res = _ExecTask($type, $args)
            Local $ok = (Not @error)
            Local $out = $ok ? $res : ""
            Local $err = $ok ? "" : $res
            _Api_PostResult($gCID, $task_id, $ok, $out, $err)
            _Api_Callback($gCID, "idle", "Done:" & $type)
        Else
            ; 204 or other → short sleep
            Sleep(400)
        EndIf
    Else
        Sleep(1000)
    EndIf
WEnd
