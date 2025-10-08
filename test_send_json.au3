; test_send_json.au3 - Test sending command with JSON DB
#include <File.au3>

; Configuration
Local $dbPath = @ScriptDir & "\db\tasks.json"
Local $clientID = "3078463243373330"
Local $cmdType = "SHELL"
Local $cmdArgs = '{"cmd":"ping google.com -n 3"}'

; Generate task_id
Local $task_id = "task_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & Random(1000, 9999, 1)

; Read existing tasks
Local $json = StringStripWS(FileRead($dbPath), 3)  ; Remove all whitespace
If $json = "" Or $json = "[]" Then $json = "[]"

; Build new task object
Local $timestamp = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
                   "T" & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

Local $taskObj = '{"task_id":"' & $task_id & '","client_id":"' & $clientID & '","type":"' & $cmdType & _
                 '","args":' & $cmdArgs & ',"status":"pending","result":"","created_at":"' & $timestamp & _
                 '","executed_at":""}'

; Insert into array
If $json = "[]" Then
    $json = "[" & $taskObj & "]"
Else
    ; Insert before closing bracket
    $json = StringTrimRight($json, 1) & "," & $taskObj & "]"
EndIf

; Write back
Local $h = FileOpen($dbPath, 2)  ; Overwrite mode
If $h <> -1 Then
    FileWrite($h, $json)
    FileClose($h)
EndIf

ConsoleWrite("Task queued successfully!" & @CRLF)
ConsoleWrite("Task ID: " & $task_id & @CRLF)
ConsoleWrite("Client ID: " & $clientID & @CRLF)
ConsoleWrite("Command: " & $cmdType & " " & $cmdArgs & @CRLF)
