; server_db.au3
#include <SQLite.au3>
#include <SQLite.dll.au3>

Global $gDbPath = @ScriptDir & "\..\db\automation.db"

Func _DB_Init()
    _SQLite_Startup()
    Local $hDB
    _SQLite_Open($gDbPath, $hDB)
    Local $sql1 = "CREATE TABLE IF NOT EXISTS clients (client_id TEXT PRIMARY KEY, ip_public TEXT, ip_local TEXT, hostname TEXT, os TEXT, arch TEXT, version TEXT, status TEXT, last_message TEXT, last_seen TEXT);"
    Local $sql2 = "CREATE TABLE IF NOT EXISTS tasks (task_id TEXT PRIMARY KEY, client_id TEXT, type TEXT, args TEXT, status TEXT, result TEXT, created_at TEXT, executed_at TEXT);"
    _SQLite_Exec($hDB, $sql1)
    _SQLite_Exec($hDB, $sql2)
    _SQLite_Close($hDB)
EndFunc
