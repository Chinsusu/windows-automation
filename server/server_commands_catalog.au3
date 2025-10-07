; server_commands_catalog.au3
#include-once
; Preset lệnh để GUI show dropdown
Func _CommandPresets()
    Local $arr[3]
    ; Use single quotes for JSON strings (no need to escape double quotes)
    $arr[0] = 'OPEN_URL {"url":"https://example.com"}'
    $arr[1] = 'SHELL {"cmd":"ipconfig"}'
    $arr[2] = 'CLICK {"x":100,"y":200,"button":"left","times":1}'
    Return $arr
EndFunc
