#include-once
#include <WinHttp.au3>
#include "agent_config.au3"
#include "agent_util.au3"

; Parse base URL like http://host:port
Func _ParseServer(ByRef $scheme, ByRef $host, ByRef $port)
    Local $u = _Cfg_Server()
    Local $m = StringRegExp($u, '^(https?)://([^/:]+)(?::([0-9]+))?/?$', 1)
    If @error Or UBound($m) < 2 Then
        $scheme = "http" : $host = "127.0.0.1" : $port = 8080
    Else
        $scheme = $m[0]
        $host = $m[1]
        $port = (UBound($m) >= 3 And $m[2] <> "") ? Number($m[2]) : (StringLower($scheme) = "https" ? 443 : 80)
    EndIf
EndFunc

Func _HttpReq($method, $path, $payload, $timeout)
    Local $scheme, $host, $port
    _ParseServer($scheme, $host, $port)

    Local $hOpen = _WinHttpOpen("AutoAgent/" & $CFG_VERSION)
    If $hOpen = 0 Then Return SetError(1,0,[0,""])
    Local $hConn = _WinHttpConnect($hOpen, $host, $port)
    If $hConn = 0 Then
        _WinHttpCloseHandle($hOpen)
        Return SetError(1,0,[0,""])
    EndIf
    Local $flags = (StringLower($scheme) = "https") ? $WINHTTP_FLAG_SECURE : 0
    Local $hReq = _WinHttpOpenRequest($hConn, $method, $path, "HTTP/1.1", "", "", $flags)
    _WinHttpSetTimeouts($hReq, $timeout, $timeout, $timeout, $timeout)

    Local $hdr = "User-Agent: AutoAgent/" & $CFG_VERSION & @CRLF & _
                 "Content-Type: application/json" & @CRLF & _
                 "Expect:" & @CRLF
    Local $k = _Cfg_ApiKey()
    If $k <> "" Then $hdr &= "X-Api-Key: " & $k & @CRLF
    _WinHttpAddRequestHeaders($hReq, $hdr, $WINHTTP_ADDREQ_FLAG_ADD)

    Local $bin = Binary($payload)
    _WinHttpSendRequest($hReq, "", 0, $bin, BinaryLen($bin))
    _WinHttpReceiveResponse($hReq)

    Local $status = Number(_WinHttpQueryInfo($hReq, $WINHTTP_QUERY_STATUS_CODE))
    Local $data = ""
    While 1
        Local $chunk = _WinHttpReadData($hReq, 8192)
        If @error Or $chunk = "" Then ExitLoop
        $data &= $chunk
    WEnd

    _WinHttpCloseHandle($hReq)
    _WinHttpCloseHandle($hConn)
    _WinHttpCloseHandle($hOpen)
    Local $r[2]
    $r[0] = $status
    $r[1] = $data
    Return $r
EndFunc

Func _HttpGet($path, $timeout)
    Return _HttpReq("GET", $path, "", $timeout)
EndFunc

Func _HttpPost($path, $json, $timeout)
    Return _HttpReq("POST", $path, $json, $timeout)
EndFunc

; ---- API wrappers ----
Func _Api_Callback($cid, $status, $message)
    Local $payload = '{"client_id":"' & $cid & '","status":"' & $status & '","message":"' & _JsonEsc($message) & _
                     '","ip_local":"' & @IPAddress1 & '","ts":"' & _NowTs() & '"}'
    Return _HttpPost("/cb", $payload, 10000)
EndFunc

Func _Api_LongPollTask($cid)
    Return _HttpGet("/tasks?client_id=" & $cid, $CFG_LPOLL_MS)
EndFunc

Func _Api_PostResult($cid, $task_id, $ok, $result, $err)
    Local $okstr = $ok ? "true" : "false"
    Local $payload = '{"client_id":"' & $cid & '","task_id":"' & $task_id & '","ok":' & $okstr & _
                     ',"result":"' & _JsonEsc($result) & '","err":"' & _JsonEsc($err) & '"}'
    Return _HttpPost("/task_result", $payload, 15000)
EndFunc

Func _Api_Latest()
    Return _HttpGet("/agent/latest", 8000)
EndFunc

Func _Api_Manifest()
    Return _HttpGet("/manifest", 8000)
EndFunc
