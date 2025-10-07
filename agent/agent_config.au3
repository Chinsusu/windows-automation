#include-once

; ===== Agent Config (edit SERVER before build) =====
Global Const $CFG_SERVER  = "http://192.168.2.101:8080" ; <-- CHANGE to your server
Global Const $CFG_VERSION = "0.3.0"                       ; agent version
Global Const $CFG_BEAT_MS = 60000                          ; heartbeat every 60s
Global Const $CFG_LPOLL_MS = 25000                         ; long-poll timeout

Func _Cfg_Server()
    Return $CFG_SERVER
EndFunc

Func _Cfg_ApiKey()
    Local $k = EnvGet("X_API_KEY")
    If $k = "" Then $k = "" ; leave blank if not used
    Return $k
EndFunc
