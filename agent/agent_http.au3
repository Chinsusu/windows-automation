; agent_http.au3
; Minimal HTTP stub via InetRead/InetGet. Replace by WinHttp.au3 for headers/long-poll.
#include "agent_config.au3"
#include "agent_util.au3"
#include <InetConstants.au3>

Func _HttpGet($path)
    Local $url = _Cfg_Server() & $path
    Local $data = InetRead($url, $INET_FORCERELOAD)
    If @error Then Return ""
    Return BinaryToString($data, 4)
EndFunc

Func _HttpPost($path, $body)
    ; Simplified: write to temp file and try PowerShell Invoke-WebRequest.
    Local $tmp = @TempDir & "\aa_post.json"
    FileDelete($tmp)
    FileWrite($tmp, $body)
    Local $ps = "Invoke-WebRequest -Uri " & Chr(34) & _Cfg_Server() & $path & Chr(34) & " -Method POST -ContentType application/json -InFile " & Chr(34) & $tmp & Chr(34) & " -Headers @{X-Api-Key=" & Chr(34) & _Cfg_ApiKey() & Chr(34) & "} -UseBasicParsing | Out-Null"
    Local $cmd = 'powershell -NoProfile -Command ' & Chr(34) & $ps & Chr(34)
    _RunCmd($cmd)
    Return 1
EndFunc

; Long-poll placeholder: return empty (you can implement WinHTTP long timeout)
Func _Api_LongPollTask($cid)
    Local $json = _HttpGet("/tasks?client_id=" & $cid)
    ; Skeleton: return as array of 1 string (task_id) if not empty
    If StringLen($json) > 0 And StringLeft($json,1) = "{" Then
        Local $ret[1]
        $ret[0] = "t-stub"
        Return $ret
    EndIf
    Local $empty[0]
    Return $empty
EndFunc

Func _Api_Callback($cid, $status, $message)
    Local $payload = '{"client_id":"' & $cid & '","status":"' & $status & '","message":"' & StringReplace($message, '"', '\"') & '"}'
    _HttpPost("/cb", $payload)
EndFunc

Func _Api_PostResult($cid, $task_id, $ok, $result, $err)
    Local $payload = '{"client_id":"' & $cid & '","task_id":"' & $task_id & '","ok":' & ($ok? "true":"false") & ',"result":"' & StringReplace($result, '"','\"') & '","err":"' & StringReplace($err, '"','\"') & '"}'
    _HttpPost("/task_result", $payload)
EndFunc

Func _Api_GetLatest()
    Return _HttpGet("/agent/latest")
EndFunc
