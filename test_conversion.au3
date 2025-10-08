#include "server\server_http_listener.au3"

; Test the URL conversion function directly
ConsoleWrite("Testing URL conversion..." & @CRLF)
Local $testURL = "https://earnapp.com/dashboard/signin?redirect=%2Fdashboard%2Flink%2Fsdk-win-testing123"
Local $converted = _ConvertEarnAppURL($testURL)
ConsoleWrite("Original: " & $testURL & @CRLF)
ConsoleWrite("Converted: " & $converted & @CRLF)

; Test with hex pattern
Local $testURL2 = "https://earnapp.com/dashboard/signin?redirect=%2Fdashboard%2Flink%2Fsdk-abc123"
Local $converted2 = _ConvertEarnAppURL($testURL2)
ConsoleWrite("Original: " & $testURL2 & @CRLF) 
ConsoleWrite("Converted: " & $converted2 & @CRLF)

Exit
