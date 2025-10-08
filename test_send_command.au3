; test_send_command.au3 - Test sending command to client
#include <File.au3>

; Configuration
Local $dbPath = @ScriptDir & "\db\tasks.csv"
Local $clientID = "3078463243373330"  ; From clients.csv
Local $cmdType = "SHELL"
Local $cmdArgs = "{""cmd"":""ipconfig""}"

; Generate task_id
Local $task_id = "task_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & Random(1000, 9999, 1)

; Build CSV line: task_id,client_id,type,args,status,result,created_at,executed_at
Local $timestamp = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
                   "T" & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

Local $line = $task_id & "," & $clientID & "," & $cmdType & ",""" & $cmdArgs & """,pending,," & $timestamp & ","

ConsoleWrite("Queueing task: " & $line & @CRLF)

; Append to tasks.csv
FileWrite($dbPath, $line & @CRLF)

ConsoleWrite("Task queued successfully!" & @CRLF)
ConsoleWrite("Task ID: " & $task_id & @CRLF)
ConsoleWrite("Client ID: " & $clientID & @CRLF)
ConsoleWrite("Command: " & $cmdType & " " & $cmdArgs & @CRLF)
