; agent_config.au3
#include-once
; Simple config getters (no external file to keep 1-file agent deploy)
Global Const $CFG_SERVER = "http://192.168.2.101:8080"
Global Const $CFG_APIKEY = "changeme"
Global Const $CFG_VERSION = "0.2.3"

Func _Cfg_Server()
    Return $CFG_SERVER
EndFunc

Func _Cfg_ApiKey()
    Return $CFG_APIKEY
EndFunc

Func _Cfg_Version()
    Return $CFG_VERSION
EndFunc
