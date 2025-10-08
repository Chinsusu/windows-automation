; server_http_listener.au3 — fixed
; Minimal HTTP listener for Windows Automation (AutoIt)
; - Handles: /health, /cb, /tasks, /task_result, /agent/latest, /manifest
; - SQLite persistence: db/automation.db
; - GUI hooks: _Listener_AttachGui($edtLog, $lv)
; NOTE: keep <= 500 lines

#include-once
#include <Array.au3>
#include <Date.au3>
#include <String.au3>
#include <Inet.au3>
#include <File.au3>

; ---------- Globals ----------
Global $gSrvSock = -1, $gPort = 8080
Global $gClientsFile = @ScriptDir & "\..\db\clients.json"
Global $gTasksFile = @ScriptDir & "\..\db\tasks.json"
Global $gAttachedLog = -1, $gAttachedLV = -1
Global $gApiKey = EnvGet("X_API_KEY") ; optional auth header for /cb & /task_result
Global Const $MAX_BODY = 1048576 ; 1MB cap
Global $gLeftoverBody = "" ; Leftover data read with headers

; ---------- Public API ----------
Func _Listener_AttachGui($hEditLogCtrl, $hListViewCtrl)
    $gAttachedLog = $hEditLogCtrl
    $gAttachedLV  = $hListViewCtrl
EndFunc

Func _Listener_Start($port = 8080)
    $gPort = $port
    _EnsureDir(@ScriptDir & "\..\db")
    _EnsureDir(@ScriptDir & "\..\logs")

    TCPStartup()
    ; Bind tất cả giao diện để client máy khác kết nối được
    $gSrvSock = TCPListen("0.0.0.0", $gPort, 100)
    If $gSrvSock = -1 Then
        _LogUI("HTTP listener start FAILED on 0.0.0.0:" & $gPort)
        Return SetError(1, 0, 0)
    EndIf

    _DB_Startup()
    Local $lanIP = _GetLANIP()
    _LogUI("HTTP listener started at 0.0.0.0:" & $gPort & "  (local IP: " & $lanIP & ")")

    ; pump every 200ms (was 50ms - too fast, blocked GUI event loop)
    AdlibRegister("_Listener_Pump", 200)
    Return 1
EndFunc

Func _Listener_Stop()
    AdlibUnRegister("_Listener_Pump")
    If $gSrvSock <> -1 Then TCPCloseSocket($gSrvSock)
    $gSrvSock = -1
    _DB_Shutdown()
    TCPShutdown()
    _LogUI("HTTP listener stopped")
EndFunc

; ---------- Pump ----------
Func _Listener_Pump()
    If $gSrvSock = -1 Then Return
    Local $cSock = TCPAccept($gSrvSock)
    If $cSock = -1 Then Return

    _LogUI("[PUMP] Connection accepted")
    
    ; --- Read request (headers + leftover)
    Local $hr = _RecvHeaders($cSock)
    Local $raw = $hr[0]
    Local $preBody = $hr[1]
    
    If $raw = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Bad Request")
        TCPCloseSocket($cSock)
        Return
    EndIf
    
    Local $req = _ParseRequestHeaders($raw)
    If @error Then
        _SendHTTP($cSock, 400, "text/plain", "Malformed")
        TCPCloseSocket($cSock)
        Return
    EndIf
    
    ; --- 100-continue
    Local $hdrs = $req.Item("headers")
    Local $expect = _HeaderGet($hdrs, "Expect")
    If $expect <> "" And StringInStr(StringLower($expect), "100-continue") Then
        _LogUI("[PUMP] Sending '100 Continue' response")
        TCPSend($cSock, "HTTP/1.1 100 Continue" & @CRLF & @CRLF)
    EndIf
    
    ; --- Body reader: priority Transfer-Encoding: chunked, else Content-Length
    Local $body = ""
    Local $te = _HeaderGet($hdrs, "Transfer-Encoding")
    If $te <> "" And StringInStr(StringLower($te), "chunked") Then
        _LogUI("[PUMP] Reading chunked body (preBody: " & StringLen($preBody) & " bytes)")
        $body = _RecvChunked($cSock, $preBody)
        If @error Then
            _SendHTTP($cSock, 400, "text/plain", "Chunked read error")
            TCPCloseSocket($cSock)
            Return
        EndIf
        _LogUI("[PUMP] Chunked body complete: " & StringLen($body) & " bytes")
    Else
        Local $cl = Number(_HeaderGet($hdrs, "Content-Length"))
        If $cl > 0 Then
            ; Already have $preBody, append and only read remaining
            Local $pb = StringLen($preBody)
            _LogUI("[PUMP] Reading body: " & $cl & " bytes (preBody: " & $pb & " bytes)")
            If $pb >= $cl Then
                $body = StringLeft($preBody, $cl)
            Else
                $body = $preBody & _RecvExact($cSock, $cl - $pb)
                If @error Then
                    _SendHTTP($cSock, 400, "text/plain", "Body read error")
                    TCPCloseSocket($cSock)
                    Return
                EndIf
            EndIf
            _LogUI("[PUMP] Body complete: " & StringLen($body) & " bytes")
        Else
            ; No CL, no chunked → empty body
            $body = $preBody  ; In case client sends a few bytes without CL
        EndIf
    EndIf
    
    $req.Item("body") = $body

    ; Dispatch
    Local $path = $req.Item("path")
    Local $method = $req.Item("method")
    _LogUI("[REQ] " & $method & " " & $path & " (body: " & StringLen($body) & " bytes)")
    
    Switch $path
        Case "/health"
            _SendHTTP($cSock, 200, "text/plain", "ok")

        Case "/cb"
            _LogUI("[CB] Dispatch - method check")
            If StringUpper($method) <> "POST" Then
                _LogUI("[CB] ERROR: Wrong method - " & $method)
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                _LogUI("[CB] Dispatch - auth check")
                If Not _AuthOK($hdrs) Then
                    _LogUI("[CB] ERROR: Auth failed")
                    _SendHTTP($cSock, 401, "text/plain", "Unauthorized")
                Else
                    _LogUI("[CB] Dispatch - calling handler")
                    _HandleCB($req, $cSock)
                    _LogUI("[CB] Dispatch - handler returned")
                EndIf
            EndIf

        Case "/tasks"
            If StringUpper($req.Item("method")) <> "GET" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                _HandleTasks($req, $cSock)
            EndIf

        Case "/task_result"
            If StringUpper($req.Item("method")) <> "POST" Then
                _SendHTTP($cSock, 405, "text/plain", "Method Not Allowed")
            Else
                If Not _AuthOK($hdrs) Then
                    _SendHTTP($cSock, 401, "text/plain", "Unauthorized")
                Else
                    _HandleTaskResult($req, $cSock)
                EndIf
            EndIf

        Case "/agent/latest"
            _HandleLatest($cSock)

        Case "/manifest"
            _HandleManifest($cSock)

        Case Else
            _SendHTTP($cSock, 404, "text/plain", "Not Found")
    EndSwitch

    TCPCloseSocket($cSock)
EndFunc

; ---------- Handlers ----------
Func _HandleCB(ByRef $req, $cSock)
    _LogUI("[CB] Handler started")
    
    ; Step 1: Parse JSON body
    Local $body = $req.Item("body")
    _LogUI("[CB] Body length: " & StringLen($body))
    
    Local $cid = _JsonGetStr($body, "client_id")
    Local $status = _JsonGetStr($body, "status")
    Local $message = _JsonGetStr($body, "message")
    Local $ip_local = _JsonGetStr($body, "ip")  ; Client sends "ip" not "ip_local"
    If $ip_local = "" Then $ip_local = _JsonGetStr($body, "ip_local")  ; Fallback
    Local $hostname = _JsonGetStr($body, "computer")  ; Get computer name
    Local $ts = _JsonGetStr($body, "ts")
    If $ts = "" Then $ts = _NowTs()
    
    ; Convert long EarnApp URLs to short format
    $message = _ConvertEarnAppURL($message)
    
    _LogUI("[CB] Parsed - cid: " & $cid & ", status: " & $status)

    If $cid = "" Then
        _LogUI("[CB] ERROR: Missing client_id")
        _SendHTTP($cSock, 400, "text/plain", "Missing client_id")
        Return
    EndIf

    ; Step 2: DB Upsert with error handling
    Local $ip_public = ""
    _LogUI("[CB] Calling _DB_UpsertClient...")
    _LogUI("[CB] IP: " & $ip_local & ", Hostname: " & $hostname)
    
    _DB_UpsertClient($cid, $ip_public, $ip_local, $hostname, $status, $message, $ts)
    
    If @error Then
        _LogUI("[CB] ERROR: DB upsert failed - " & @error)
        _SendHTTP($cSock, 500, "text/plain", "Database error")
        Return
    EndIf
    
    _LogUI("[CB] SUCCESS: " & $cid & " [" & $status & "] " & $message)
    _SendHTTP($cSock, 200, "text/plain", "ok")
EndFunc

Func _HandleTasks(ByRef $req, $cSock)
    Local $query = $req.Item("query")
    _LogUI("[TASKS] Query string: '" & $query & "'")
    
    Local $cid = _QueryGet($query, "client_id")
    _LogUI("[TASKS] Parsed client_id: '" & $cid & "'")
    
    If $cid = "" Then
        _LogUI("[TASKS] ERROR: Missing client_id")
        _SendHTTP($cSock, 400, "application/json", '{"error":"missing client_id"}')
        Return
    EndIf

    Local $row = _DB_GetNextTask($cid)
    If @error Or UBound($row) = 0 Then
        _LogUI("[TASKS] No pending tasks for " & $cid)
        _SendEmpty($cSock, 204)
        Return
    EndIf

    ; row: [task_id, type, args]
    Local $task_id = $row[0]
    Local $type    = $row[1]
    Local $args    = $row[2]
    _DB_MarkTaskSent($task_id)

    Local $argsOut = "{}"
    If $args <> "" Then $argsOut = $args

    Local $json = '{"task_id":"' & $task_id & '","type":"' & $type & '","args":' & $argsOut & ',"timeout":30000}'
    _LogUI("[TASK] → " & $cid & " : " & $type)
    _SendHTTP($cSock, 200, "application/json", $json)
EndFunc

Func _HandleTaskResult(ByRef $req, $cSock)
    Local $cid = _JsonGetStr($req.Item("body"), "client_id")
    Local $task_id = _JsonGetStr($req.Item("body"), "task_id")
    Local $ok = _JsonGetBool($req.Item("body"), "ok")
    Local $result = _JsonGetStr($req.Item("body"), "result")
    Local $err = _JsonGetStr($req.Item("body"), "err")

    If $task_id = "" Then
        _SendHTTP($cSock, 400, "text/plain", "Missing task_id")
        Return
    EndIf

    _DB_SaveResult($task_id, $ok, $result, $err)
    Local $okText = "0"
    If $ok Then $okText = "1"
    _LogUI("[DONE] " & $cid & " #" & $task_id & " ok=" & $okText & " " & $result & " " & $err)
    _SendHTTP($cSock, 200, "text/plain", "ok")
EndFunc

Func _HandleLatest($cSock)
    Local $m = _ReadFile(@ScriptDir & "\..\manifests\manifest.json")
    If $m = "" Then
        _SendHTTP($cSock, 404, "text/plain", "manifest not found")
        Return
    EndIf
    Local $latest = _JsonGetStr($m, "latest")
    If $latest = "" Then $latest = "0.0.0"
    _SendHTTP($cSock, 200, "text/plain", $latest)
EndFunc

Func _HandleManifest($cSock)
    Local $m = _ReadFile(@ScriptDir & "\..\manifests\manifest.json")
    If $m = "" Then
        _SendHTTP($cSock, 404, "text/plain", "manifest not found")
        Return
    EndIf
    _SendHTTP($cSock, 200, "application/json", $m)
EndFunc

; ---------- JSON Storage ----------
Func _DB_Startup()
    _LogUI("[JSON] Initializing JSON storage")
    
    ; Create clients.json as empty array if not exists
    If Not FileExists($gClientsFile) Then
        Local $h = FileOpen($gClientsFile, 2)
        If $h <> -1 Then
            FileWrite($h, "[]")
            FileClose($h)
        EndIf
    EndIf
    
    ; Create tasks.json as empty array if not exists
    If Not FileExists($gTasksFile) Then
        Local $h = FileOpen($gTasksFile, 2)
        If $h <> -1 Then
            FileWrite($h, "[]")
            FileClose($h)
        EndIf
    EndIf
    
    _LogUI("[JSON] Storage initialized")
EndFunc

Func _DB_Shutdown()
    ; Nothing to cleanup for JSON
EndFunc

Func _DB_UpsertClient($cid, $ip_public, $ip_local, $hostname, $status, $message, $ts)
    ; Read existing clients JSON
    Local $json = _ReadFile($gClientsFile)
    If $json = "" Or $json = "[]" Then $json = "[]"
    
    ; Build new client object
    Local $clientObj = '{"client_id":"' & _JsonEscStr($cid) & '",' & _
                       '"ip_public":"' & _JsonEscStr($ip_public) & '",' & _
                       '"ip_local":"' & _JsonEscStr($ip_local) & '",' & _
                       '"hostname":"' & _JsonEscStr($hostname) & '",' & _
                       '"os":"",' & _
                       '"version":"",' & _
                       '"status":"' & _JsonEscStr($status) & '",' & _
                       '"last_message":"' & _JsonEscStr($message) & '",' & _
                       '"last_seen":"' & _JsonEscStr($ts) & '"}'
    
    ; Find if client already exists
    Local $searchClient = '"client_id":"' & _JsonEscStr($cid) & '"'
    Local $pos = StringInStr($json, $searchClient)
    
    If $pos > 0 Then
        ; Update existing client - find the object boundaries
        Local $objStart = 0
        For $i = $pos To 1 Step -1
            If StringMid($json, $i, 1) = "{" Then
                $objStart = $i
                ExitLoop
            EndIf
        Next
        If $objStart = 0 Then $objStart = 1
        
        Local $objEnd = StringInStr($json, "}", 0, 1, $pos)
        If $objEnd = 0 Then Return  ; Malformed JSON
        
        ; Replace the old object with new one
        $json = StringLeft($json, $objStart - 1) & $clientObj & StringMid($json, $objEnd + 1)
    Else
        ; Add new client
        If $json = "[]" Then
            $json = "[" & $clientObj & "]"
        Else
            ; Insert before closing bracket
            $json = StringTrimRight($json, 1) & "," & $clientObj & "]"
        EndIf
    EndIf
    
    ; Write back
    Local $h = FileOpen($gClientsFile, 2)
    If $h <> -1 Then
        FileWrite($h, $json)
        FileClose($h)
    EndIf
EndFunc

Func _DB_GetNextTask($cid)
    ; Read tasks.json and find first pending task for this client
    Local $json = _ReadFile($gTasksFile)
    _LogUI("[DB] JSON content: " & StringLeft($json, 200))
    
    If $json = "" Or $json = "[]" Then
        _LogUI("[DB] Empty tasks file")
        Local $empty[0]
        SetError(1)
        Return $empty
    EndIf
    
    ; Parse JSON array manually - find first pending task
    ; Format: [{"task_id":"...","client_id":"...","type":"...","args":{...},"status":"...",...],...]
    Local $pattern = '\{"task_id":"([^"]+)","client_id":"([^"]+)","type":"([^"]+)","args":([^,]+),"status":"([^"]+)"'
    Local $matches = StringRegExp($json, $pattern, 3)  ; Global mode
    
    _LogUI("[DB] Regex matches: " & UBound($matches))
    
    If @error Or UBound($matches) = 0 Then
        Local $empty[0]
        SetError(1)
        Return $empty
    EndIf
    
    ; Matches array: [task_id, client_id, type, args, status, task_id2, client_id2, ...]
    For $i = 0 To UBound($matches) - 1 Step 5
        Local $task_id = $matches[$i]
        Local $task_cid = $matches[$i + 1]
        Local $task_type = $matches[$i + 2]
        Local $task_args = $matches[$i + 3]
        Local $task_status = $matches[$i + 4]
        
        If $task_cid = $cid And $task_status = "pending" Then
            Local $ret[3]
            $ret[0] = $task_id
            $ret[1] = $task_type
            $ret[2] = $task_args
            Return $ret
        EndIf
    Next
    
    Local $empty[0]
    SetError(1)
    Return $empty
EndFunc

Func _DB_MarkTaskSent($task_id)
    ; Update task status to 'sent' and mark executed_at
    Local $json = _ReadFile($gTasksFile)
    If $json = "" Then Return
    
    ; Find task by task_id and update fields
    Local $searchTask = '"task_id":"' & $task_id & '"'
    Local $pos = StringInStr($json, $searchTask)
    If $pos > 0 Then
        ; Update status from pending to sent
        Local $statusPos = StringInStr($json, '"status":"pending"', 0, 1, $pos)
        If $statusPos > 0 Then
            $json = StringLeft($json, $statusPos - 1) & '"status":"sent"' & StringMid($json, $statusPos + 18)
        EndIf
        
        ; Update executed_at timestamp
        Local $execPos = StringInStr($json, '"executed_at":""', 0, 1, $pos)
        If $execPos > 0 Then
            $json = StringLeft($json, $execPos - 1) & '"executed_at":"' & _NowTs() & '"' & StringMid($json, $execPos + 16)
        EndIf
    EndIf
    
    Local $h = FileOpen($gTasksFile, 2)
    If $h <> -1 Then
        FileWrite($h, $json)
        FileClose($h)
    EndIf
EndFunc

Func _DB_SaveResult($task_id, $ok, $result, $err)
    ; Update task with result - simple string replace approach
    Local $json = _ReadFile($gTasksFile)
    If $json = "" Then Return
    
    Local $status = $ok ? "completed" : "failed"
    Local $resultText = $ok ? $result : $err
    Local $resultEsc = _JsonEscStr($resultText)
    
    _LogUI("[DB_SaveResult] task_id=" & $task_id & " status=" & $status & " result_len=" & StringLen($resultEsc))
    
    ; Find the task object and update status and result
    ; Use simpler string replace instead of complex regex
    ; First replace status for this specific task_id
    Local $searchStatus = '"task_id":"' & $task_id & '"'
    Local $pos = StringInStr($json, $searchStatus)
    If $pos > 0 Then
        ; Find status field after task_id
        Local $statusPos = StringInStr($json, '"status":"pending"', 0, 1, $pos)
        If $statusPos > 0 Then
            $json = StringLeft($json, $statusPos - 1) & '"status":"' & $status & '"' & StringMid($json, $statusPos + 18)
        EndIf
        
        ; Find result field after task_id
        Local $resultPos = StringInStr($json, '"result":""', 0, 1, $pos)
        If $resultPos > 0 Then
            $json = StringLeft($json, $resultPos - 1) & '"result":"' & $resultEsc & '"' & StringMid($json, $resultPos + 11)
        EndIf
    EndIf
    
    _LogUI("[DB_SaveResult] Updated JSON (first 200 chars): " & StringLeft($json, 200))
    
    Local $h = FileOpen($gTasksFile, 2)
    If $h <> -1 Then
        FileWrite($h, $json)
        FileClose($h)
    EndIf
EndFunc

; Queue a new task (called from GUI)
Func _DB_QueueTask($cid, $type, $args)
    ; Generate task_id
    Local $task_id = "task_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & Random(1000, 9999, 1)
    
    ; Read existing tasks
    Local $json = _ReadFile($gTasksFile)
    If $json = "" Or $json = "[]" Then $json = "[]"
    
    ; Build new task object
    Local $taskObj = '{"task_id":"' & $task_id & '","client_id":"' & $cid & '","type":"' & $type & _
                     '","args":' & $args & ',"status":"pending","result":"","created_at":"' & _NowTs() & _
                     '","executed_at":""}'
    
    ; Insert into array
    If $json = "[]" Then
        $json = "[" & $taskObj & "]"
    Else
        ; Insert before closing bracket
        $json = StringTrimRight($json, 1) & "," & $taskObj & "]"
    EndIf
    
    ; Write back
    Local $h = FileOpen($gTasksFile, 2)
    If $h <> -1 Then
        FileWrite($h, $json)
        FileClose($h)
    EndIf
EndFunc

; Helper to escape strings for JSON
Func _JsonEscStr($s)
    $s = StringReplace($s, "\\", "\\\\")
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CRLF, "\n")
    $s = StringReplace($s, @LF, "\n")
    $s = StringReplace($s, @CR, "\r")
    $s = StringReplace($s, @TAB, "\t")
    Return $s
EndFunc

; Get clients list for GUI ListView (returns 2D array)
Func _DB_GetClientsForUI(ByRef $out, ByRef $rows)
    Local $json = _ReadFile($gClientsFile)
    If $json = "" Or $json = "[]" Then
        $rows = 0
        Local $empty[0][0]
        $out = $empty
        Return 0
    EndIf
    
    ; Parse JSON array - regex for client objects
    ; Pattern: {"client_id":"...","ip_public":"...","ip_local":"...","hostname":"...","os":"...","version":"...","status":"...","last_message":"...","last_seen":"..."}
    Local $pattern = '\{"client_id":"([^"]*)","ip_public":"([^"]*)","ip_local":"([^"]*)","hostname":"([^"]*)","os":"([^"]*)","version":"([^"]*)","status":"([^"]*)","last_message":"([^"]*)","last_seen":"([^"]*)"\}'
    Local $matches = StringRegExp($json, $pattern, 3)  ; Global mode
    
    If @error Or UBound($matches) = 0 Then
        $rows = 0
        Local $empty[0][0]
        $out = $empty
        Return 0
    EndIf
    
    ; Matches array: [client_id, ip_public, ip_local, hostname, os, version, status, msg, ts, client_id2, ...]
    ; Each client has 9 fields
    Local $numClients = Int(UBound($matches) / 9)
    Local $data[$numClients + 1][8]
    
    ; Header row
    $data[0][0] = "client_id"
    $data[0][1] = "ip"
    $data[0][2] = "hostname"
    $data[0][3] = "os"
    $data[0][4] = "version"
    $data[0][5] = "status"
    $data[0][6] = "last_message"
    $data[0][7] = "last_seen"
    
    ; Data rows
    Local $outIdx = 1
    For $i = 0 To UBound($matches) - 1 Step 9
        $data[$outIdx][0] = $matches[$i]      ; client_id
        ; Prefer ip_local over ip_public
        $data[$outIdx][1] = $matches[$i + 2] <> "" ? $matches[$i + 2] : $matches[$i + 1]  ; ip
        $data[$outIdx][2] = $matches[$i + 3]  ; hostname
        $data[$outIdx][3] = $matches[$i + 4]  ; os
        $data[$outIdx][4] = $matches[$i + 5]  ; version
        $data[$outIdx][5] = $matches[$i + 6]  ; status
        $data[$outIdx][6] = $matches[$i + 7]  ; last_message
        $data[$outIdx][7] = $matches[$i + 8]  ; last_seen
        $outIdx += 1
    Next
    
    $out = $data
    $rows = $numClients
    Return $rows
EndFunc

Func _CSVEscape($s)
    ; Simple CSV escape: if contains comma or quote, wrap in quotes and escape quotes
    If StringInStr($s, ",") Or StringInStr($s, '"') Then
        Return '"' & StringReplace($s, '"', '""') & '"'
    EndIf
    Return $s
EndFunc

; ---------- Helpers ----------
Func _GetLANIP()
    ; Try to find 192.168.x.x IP address
    For $i = 1 To 4
        Local $ip = Execute("@IPAddress" & $i)
        If StringLeft($ip, 8) = "192.168." Then Return $ip
    Next
    ; Fallback to first adapter
    Return @IPAddress1
EndFunc

Func _EnsureDir($p)
    If Not FileExists($p) Then DirCreate($p)
EndFunc

Func _LogUI($s)
    ; Only write to file to avoid blocking GUI
    Local $line = _NowTs() & "  " & $s & @CRLF
    Local $logFile = @ScriptDir & "\..\logs\listener.log"
    FileWrite($logFile, $line)
    ; Skip GUI update - it blocks event loop
    ; If $gAttachedLog <> -1 Then GUICtrlSetData($gAttachedLog, GUICtrlRead($gAttachedLog) & $line)
EndFunc

Func _Q($s) ; simple SQL quote
    If $s = "" Then Return "NULL"
    Return "'" & StringReplace($s, "'", "''") & "'"
EndFunc

Func _ReadFile($p)
    If Not FileExists($p) Then Return ""
    Local $h = FileOpen($p, 0)
    If $h = -1 Then Return ""
    Local $d = FileRead($h)
    FileClose($h)
    Return $d
EndFunc

Func _AuthOK($hdrs)
    If $gApiKey = "" Then Return True
    Local $key = _HeaderGet($hdrs, "X-Api-Key")
    Return ($key = $gApiKey)
EndFunc

; ----- HTTP parsing/sending -----
; Returns: [0]=raw headers (string), [1]=leftover body already read (string)
Func _RecvHeaders($sock)
    Local $buf = ""
    Local $stamp = TimerInit()
    While 1
        Local $chunk = TCPRecv($sock, 4096)
        If @error Then ExitLoop
        If $chunk = "" Then
            If TimerDiff($stamp) > 5000 Then ExitLoop
            Sleep(10)
            ContinueLoop
        EndIf
        $buf &= BinaryToString($chunk)
        Local $p = StringInStr($buf, @CRLF & @CRLF, 0, 1)
        If $p > 0 Then
            Local $hdr = StringLeft($buf, $p + 3)  ; headers including \r\n\r\n
            Local $left = StringMid($buf, $p + 4)  ; leftover body
            Local $ret[2]
            $ret[0] = $hdr
            $ret[1] = $left
            Return $ret
        EndIf
        If StringLen($buf) > 16384 Then ExitLoop  ; prevent overly long headers
    WEnd
    Local $ret2[2]
    $ret2[0] = ""
    $ret2[1] = ""
    Return $ret2
EndFunc

Func _RecvToDoubleCRLF($sock)
    Local $buf = ""
    Local $stamp = TimerInit()
    While 1
        Local $chunk = TCPRecv($sock, 4096)
        If @error Then ExitLoop
        If $chunk = "" Then
            If TimerDiff($stamp) > 5000 Then ExitLoop
            Sleep(10)
            ContinueLoop
        EndIf
        $buf &= BinaryToString($chunk)
        If StringInStr($buf, @CRLF & @CRLF) Then ExitLoop
        If StringLen($buf) > 8192 Then ExitLoop
    WEnd
    
    ; Separate headers and leftover body
    $gLeftoverBody = ""
    Local $pos = StringInStr($buf, @CRLF & @CRLF)
    If $pos > 0 Then
        Local $headers = StringLeft($buf, $pos + 3)  ; Include @CRLF@CRLF
        $gLeftoverBody = StringMid($buf, $pos + 4)  ; Body data after @CRLF@CRLF
        _LogUI("[RECV] Leftover body from header read: " & StringLen($gLeftoverBody) & " bytes")
        Return $headers
    EndIf
    Return $buf
EndFunc

Func _RecvExact($sock, $len)
    If $len > $MAX_BODY Then Return SetError(1, 0, "") ; cap
    Local $buf = ""
    Local $got = 0
    Local $stamp = TimerInit()
    Local $loopCount = 0
    While $got < $len
        Local $need = $len - $got
        Local $chunk = TCPRecv($sock, $need)
        If @error Then
            _LogUI("[RECV] TCPRecv error: " & @error)
            Return SetError(1, 0, "")
        EndIf
        If $chunk = "" Then
            $loopCount += 1
            If Mod($loopCount, 100) = 0 Then
                _LogUI("[RECV] Waiting for data... got=" & $got & " need=" & ($len - $got) & " elapsed=" & Int(TimerDiff($stamp)/1000) & "s")
            EndIf
            If TimerDiff($stamp) > 5000 Then
                _LogUI("[RECV] Timeout after 5s - got " & $got & "/" & $len & " bytes")
                Return SetError(1, 0, "")
            EndIf
            Sleep(10)
            ContinueLoop
        EndIf
        $buf &= BinaryToString($chunk)
        $got = StringLen($buf)
        _LogUI("[RECV] Received chunk: " & StringLen(BinaryToString($chunk)) & " bytes, total: " & $got & "/" & $len)
    WEnd
    _LogUI("[RECV] Complete - received " & $got & " bytes")
    Return $buf
EndFunc

; Read chunked transfer encoding; $pre contains data already read with headers
Func _RecvChunked($sock, $pre)
    Local $buf = $pre
    Local $out = ""
    
    While 1
        ; Ensure we have a chunk size line
        Local $lineEnd = StringInStr($buf, @CRLF, 0, 1)
        While $lineEnd = 0
            Local $t = TCPRecv($sock, 4096)
            If @error Then Return SetError(1, 0, "")
            If $t = "" Then Sleep(10)
            $buf &= BinaryToString($t)
            $lineEnd = StringInStr($buf, @CRLF, 0, 1)
        WEnd
        
        Local $sizeHex = StringLeft($buf, $lineEnd - 1)
        $buf = StringMid($buf, $lineEnd + 2)
        Local $size = Dec("0x" & StringStripWS($sizeHex, 3))
        If $size <= 0 Then ExitLoop  ; chunk 0 => end
        
        ; Ensure we have $size bytes + CRLF
        While StringLen($buf) < $size + 2
            Local $t2 = TCPRecv($sock, ($size + 2) - StringLen($buf))
            If @error Then Return SetError(1, 0, "")
            If $t2 = "" Then Sleep(10)
            $buf &= BinaryToString($t2)
        WEnd
        
        $out &= StringLeft($buf, $size)
        ; Skip CRLF after chunk
        $buf = StringMid($buf, $size + 3)
    WEnd
    
    Return $out
EndFunc

Func _ParseRequestHeaders($raw)
    Local $lines = StringSplit(StringStripCR($raw), @LF, 3)
    If UBound($lines) < 2 Then Return SetError(1, 0, 0)
    Local $first = $lines[0]
    Local $sp = StringSplit($first, " ", 3)
    If UBound($sp) < 2 Then Return SetError(1, 0, 0)

    Local $method = $sp[0]
    Local $full   = $sp[1]
    Local $path = $full, $query = ""
    Local $qpos = StringInStr($full, "?", 0, 1)
    If $qpos > 0 Then
        $path = StringLeft($full, $qpos - 1)
        $query = StringMid($full, $qpos + 1)
    EndIf

    ; headers -> 2D array [n][2]
    Local $hdrs[0][2]
    For $i = 1 To UBound($lines) - 1
        Local $ln = $lines[$i]
        If $ln = "" Then ExitLoop
        Local $p = StringInStr($ln, ":", 0, 1)
        If $p > 0 Then
            Local $k = StringStripWS(StringLeft($ln, $p - 1), 3)
            Local $v = StringStripWS(StringMid($ln, $p + 1), 3)
            ReDim $hdrs[UBound($hdrs) + 1][2]
            $hdrs[UBound($hdrs) - 1][0] = $k
            $hdrs[UBound($hdrs) - 1][1] = $v
        EndIf
    Next

    ; Use COM dictionary via Add/Item (không dùng property chấm)
    Local $req = ObjCreate("Scripting.Dictionary")
    $req.Add("method",  $method)
    $req.Add("path",    $path)
    $req.Add("query",   $query)
    $req.Add("headers", $hdrs)
    $req.Add("body",    "")
    Return $req
EndFunc

Func _HeaderGet($hdrs, $key)
    For $i = 0 To UBound($hdrs) - 1
        If StringLower($hdrs[$i][0]) = StringLower($key) Then Return $hdrs[$i][1]
    Next
    Return ""
EndFunc

Func _QueryGet($q, $key)
    If $q = "" Then Return ""
    Local $parts = StringSplit($q, "&", 3)
    For $i = 0 To UBound($parts) - 1
        Local $kv = StringSplit($parts[$i], "=", 3)
        If UBound($kv) >= 1 Then
            If $kv[0] = $key Then
                If UBound($kv) = 1 Then Return ""
                Return _URLDecode($kv[1])
            EndIf
        EndIf
    Next
    Return ""
EndFunc

Func _URLDecode($s)
    $s = StringReplace($s, "+", " ")
    Local $i = 1
    While $i <= StringLen($s)
        If StringMid($s, $i, 1) = "%" And $i + 2 <= StringLen($s) Then
            Local $hex = StringMid($s, $i + 1, 2)
            $s = StringLeft($s, $i - 1) & Chr(Dec($hex)) & StringMid($s, $i + 3)
        EndIf
        $i += 1
    WEnd
    Return $s
EndFunc

Func _SendHTTP($sock, $code, $ctype, $body)
    Local $status = "200 OK"
    Switch $code
        Case 200
            $status = "200 OK"
        Case 204
            $status = "204 No Content"
        Case 400
            $status = "400 Bad Request"
        Case 401
            $status = "401 Unauthorized"
        Case 404
            $status = "404 Not Found"
        Case 405
            $status = "405 Method Not Allowed"
        Case Else
            $status = $code & " OK"
    EndSwitch
    Local $hdr = "HTTP/1.1 " & $status & @CRLF & _
                 "Content-Type: " & $ctype & @CRLF & _
                 "Content-Length: " & StringLen($body) & @CRLF & _
                 "Connection: close" & @CRLF & @CRLF
    TCPSend($sock, $hdr & $body)
EndFunc

Func _SendEmpty($sock, $code)
    Local $hdr = "HTTP/1.1 " & $code & " No Content" & @CRLF & _
                 "Content-Length: 0" & @CRLF & _
                 "Connection: close" & @CRLF & @CRLF
    TCPSend($sock, $hdr)
EndFunc

; --- Timestamp helper to avoid name clash with Date.au3's _NowCalc()
Func _NowTs()
    ; ISO-like timestamp: YYYY-MM-DDTHH:MM:SS
    Return @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
           "T" & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)
EndFunc

; Convert EarnApp URL from long to short format
; Input: https://earnapp.com/dashboard/signin?redirect=%2Fdashboard%2Flink%2Fsdk-win-XXXXX
; Output: https://earnapp.com/dashboard/r/sdk-win-XXXXX  
Func _ConvertEarnAppURL($url)
    ; Check if URL contains earnapp.com and has sdk- pattern
    If StringInStr($url, "earnapp.com") And StringInStr($url, "sdk-") Then
        ; Extract everything after "sdk-" (including "sdk-")
        Local $sdkPattern = "(sdk-[a-f0-9]+)"
        Local $sdkMatches = StringRegExp($url, $sdkPattern, 1)
        
        If Not @error And UBound($sdkMatches) > 0 Then
            Local $sdkCode = $sdkMatches[0]
            
            ; Build new URL: keep https://earnapp.com/dashboard/ + r/ + sdk-code
            Local $shortURL = "https://earnapp.com/dashboard/r/" & $sdkCode
            _LogUI("[ConvertURL] " & $url & " -> " & $shortURL)
            Return $shortURL
        EndIf
    EndIf
    
    ; If conversion fails or URL is already short, return original
    Return $url
EndFunc

; ----- Tiny JSON helpers (string-only + bool) -----
Func _JsonGetStr($json, $key)
    Local $pat = '"' & $key & '"\s*:\s*"(.*?)"'
    Local $m = StringRegExp($json, $pat, 1)
    If @error Or UBound($m) = 0 Then Return ""
    Return $m[0]
EndFunc

Func _JsonGetBool($json, $key)
    Local $pat = '"' & $key & '"\s*:\s*(true|false)'
    Local $m = StringRegExp($json, $pat, 1)
    If @error Or UBound($m) = 0 Then Return False
    Return (StringLower($m[0]) = "true")
EndFunc
