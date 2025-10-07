# OPERATIONS
## Thêm client
- Copy 1 file agent .exe vào `C:\ProgramData\AutoAgent\AutoAgent.exe`
- Tạo Scheduled Task (xem README)
- Quan sát callback trên GUI

## Cập nhật agent
- Build bản mới qua `scripts/compile_agent.ps1`
- Upload R2 + cập nhật `manifests/manifest.json`
- Force update qua GUI hoặc để agent auto-check 10 phút/lần

## Backup
- Sao lưu: `db/automation.db`, `manifests/manifest.json`, `dist/`

## Troubleshooting
- Task không chạy: kiểm tra Scheduled Tasks `Last Run Result`
- Không nhận task: check listener port & DB queue
- Update kẹt: xoá file `.new.exe` và task `AutoAgent-Update`, enqueue lại
