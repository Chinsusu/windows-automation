; agent_commands.au3
#include "agent_util.au3"
#include <Misc.au3>
#include <WinAPIFiles.au3>

Func _ExecuteTask(ByRef $task)
    ; $task stub: [$task_id]
    ; Expand to switch-case when JSON implemented
    Return _Ok("no-op")
EndFunc

Func _Cmd_OpenUrl($url)
    ShellExecute($url)
    Return _Ok("opened")
EndFunc

Func _Cmd_Run($path, $args, $wait)
    Local $pid = Run('"' & $path & '" ' & $args, "", @SW_HIDE, 6)
    If $wait Then ProcessWaitClose($pid, 30)
    Return _Ok("pid=" & $pid)
EndFunc

Func _Cmd_Click($x,$y,$button,$times)
    MouseClick($button, $x, $y, $times)
    Return _Ok("clicked")
EndFunc
