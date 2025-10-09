; Script để kích hoạt cửa sổ Earnapp và tìm nút Sign In bằng ImageSearchEx rồi click
#include <MsgBoxConstants.au3>

; Đường dẫn tương đối
#include "ImageSearchEx_UDF\ImageSearchEx_UDF.au3"

ConsoleWrite("[Click_Signin] Starting..." & @CRLF)

; Khởi tạo UDF
_ImageSearchEx_Startup()
If @error Then
    ConsoleWrite("[Click_Signin] ERROR: Cannot load ImageSearchEx DLL" & @CRLF)
    Exit 1  ; Thoát nếu không load được DLL
EndIf

ConsoleWrite("[Click_Signin] ImageSearchEx loaded successfully" & @CRLF)

; Kích hoạt cửa sổ
WinActivate("Earnapp")
WinWaitActive("Earnapp", "", 5)

If WinActive("Earnapp") Then
    ConsoleWrite("[Click_Signin] Earnapp window is active" & @CRLF)
    
    ; Lấy vị trí và kích thước cửa sổ
    Local $aPos = WinGetPos("Earnapp")
    If Not @error Then
        ConsoleWrite("[Click_Signin] Window position: X=" & $aPos[0] & " Y=" & $aPos[1] & " W=" & $aPos[2] & " H=" & $aPos[3] & @CRLF)
        
        ; Đường dẫn hình ảnh Sign In (relative path)
        Local $sImagePath = @ScriptDir & "\Image\Signin.bmp"
        
        If Not FileExists($sImagePath) Then
            ConsoleWrite("[Click_Signin] WARNING: Image file not found: " & $sImagePath & @CRLF)
        Else
            ConsoleWrite("[Click_Signin] Image file found: " & $sImagePath & @CRLF)
        EndIf

        ; Tìm hình ảnh trong vùng cửa sổ với tolerance 50
        ConsoleWrite("[Click_Signin] Searching for Sign In button image..." & @CRLF)
        Local $aResult = _ImageSearchEx_Area($sImagePath, $aPos[0], $aPos[1], $aPos[0] + $aPos[2], $aPos[1] + $aPos[3], 50)

        If $aResult[0][0] > 0 Then
            ; Lấy vị trí trung tâm của match đầu tiên
            Local $iX = $aResult[1][1]
            Local $iY = $aResult[1][2]

            ConsoleWrite("[Click_Signin] Found Sign In button at: X=" & $iX & " Y=" & $iY & @CRLF)
            
            ; Di chuyển chuột và click
            MouseMove($iX, $iY, 5)
            Sleep(500)
            MouseClick("left", $iX, $iY, 1, 5)
            ConsoleWrite("[Click_Signin] Clicked Sign In button (ImageSearch)" & @CRLF)
        Else
            ConsoleWrite("[Click_Signin] Image not found, using fallback position..." & @CRLF)
            
            ; Fallback: Click vị trí tương đối ở dưới cùng (dựa trên layout: Sign In ở phải dưới)
            Local $iX = $aPos[0] + $aPos[2] - 120  ; Cách mép phải 120px
            Local $iY = $aPos[1] + $aPos[3] - 60   ; Cách bottom 60px
            
            ConsoleWrite("[Click_Signin] Fallback position: X=" & $iX & " Y=" & $iY & @CRLF)
            MouseMove($iX, $iY, 5)
            Sleep(500)
            MouseClick("left", $iX, $iY, 1, 5)
            ConsoleWrite("[Click_Signin] Clicked Sign In button (Fallback)" & @CRLF)
        EndIf
    EndIf
Else
    ConsoleWrite("[Click_Signin] ERROR: Earnapp window is not active" & @CRLF)
EndIf

; Cleanup
_ImageSearchEx_Shutdown()
ConsoleWrite("[Click_Signin] Done" & @CRLF)
