; agent_config.au3
#include-once
; Simple config getters (no external file to keep 1-file agent deploy)
Global Const $CFG_SERVER = "http://127.0.0.1:8080"
Global Const $CFG_APIKEY = "changeme"
Global Const $CFG_VERSION = "0.2.0"

Func _Cfg_Server()
    Return $CFG_SERVER
EndFunc

Func _Cfg_ApiKey()
    Return $CFG_APIKEY
EndFunc

Func _Cfg_Version()
    Return $CFG_VERSION
EndFunc
