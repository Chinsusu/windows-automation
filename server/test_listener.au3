; test_listener.au3 - Simple test for HTTP listener
#include "server_http_listener.au3"

ConsoleWrite("Starting HTTP listener test..." & @CRLF)

; Start listener
If _Listener_Start(8080) Then
    ConsoleWrite("Listener started on port 8080" & @CRLF)
    ConsoleWrite("Press Ctrl+C to stop..." & @CRLF)
    
    ; Keep running
    While 1
        Sleep(1000)
    WEnd
Else
    ConsoleWrite("Failed to start listener!" & @CRLF)
EndIf
