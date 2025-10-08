; test_server.au3 - Minimal HTTP server for testing URL conversion
#include "server\server_http_listener.au3"

ConsoleWrite("Starting minimal test server..." & @CRLF)

; Initialize and start listener
_DB_Startup()
_Listener_Start(8080)

ConsoleWrite("Server started at http://localhost:8080" & @CRLF)
ConsoleWrite("Press Ctrl+C to stop" & @CRLF)

; Simple message loop
While True
    Sleep(100)
WEnd