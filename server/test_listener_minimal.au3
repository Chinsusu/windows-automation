; test_listener_minimal.au3 - Debug listener startup
#include "server_http_listener.au3"

ConsoleWrite("=== Testing Listener Startup ===" & @CRLF)

; Test 1: DB startup
ConsoleWrite("1. Testing DB startup..." & @CRLF)
_DB_Startup()
ConsoleWrite("   DB OK" & @CRLF)

; Test 2: Start listener
ConsoleWrite("2. Testing listener start..." & @CRLF)
Local $result = _Listener_Start(8080)
If @error Then
    ConsoleWrite("   FAILED: " & @error & @CRLF)
    Exit
EndIf
ConsoleWrite("   Listener OK" & @CRLF)

; Test 3: Keep running
ConsoleWrite("3. Listening on 0.0.0.0:8080..." & @CRLF)
ConsoleWrite("   Press Ctrl+C to stop" & @CRLF)

While 1
    Sleep(1000)
WEnd
