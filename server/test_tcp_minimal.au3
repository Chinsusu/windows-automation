; test_tcp_minimal.au3 - Minimal TCP test
TCPStartup()
Local $sock = TCPListen("0.0.0.0", 8081, 10)
If $sock = -1 Then
    MsgBox(16, "Error", "Failed to listen on 8081")
    Exit
EndIf

MsgBox(64, "Listening", "TCP server on 0.0.0.0:8081" & @CRLF & "Test with: curl http://127.0.0.1:8081")

While 1
    Local $client = TCPAccept($sock)
    If $client <> -1 Then
        ; Read request
        Local $data = TCPRecv($client, 1024)
        If $data <> "" Then
            ; Send simple HTTP response
            Local $response = "HTTP/1.1 200 OK" & @CRLF & _
                            "Content-Type: text/plain" & @CRLF & _
                            "Content-Length: 2" & @CRLF & _
                            "Connection: close" & @CRLF & @CRLF & _
                            "ok"
            TCPSend($client, $response)
        EndIf
        TCPCloseSocket($client)
    EndIf
    Sleep(10)
WEnd

TCPCloseSocket($sock)
TCPShutdown()
