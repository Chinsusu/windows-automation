# WARP.md — Server (AutoIt GUI + HTTP + SQLite)

## Thành phần
- GUI: ListView clients + panel Logs + Preset Commands.
- HTTP listener endpoints: `/cb`, `/tasks`, `/task_result`, `/agent/latest`, `/manifest`.
- DB: `db/automation.db` với bảng `clients`, `tasks` (trạng thái: queued|sent|done|error).

## Yêu cầu thực thi
- Endpoints phải **idempotent**; validate `client_id`, sanitize JSON.
- Giao nhiệm vụ: FIFO theo `created_at` cho từng `client_id`.
- Bảo mật: bắt buộc `X-Api-Key` cho `/cb` và `/task_result`; để listener phía sau proxy TLS khi xuất Internet.

## R2/Manifest
- Build & publish: có action gọi PowerShell `scripts/compile_agent.ps1` và `scripts/r2_upload.ps1` hoặc Worker `scripts/r2_worker.ps1`.
- `manifest.json` luôn cập nhật: `version`, `sha256`, `size`, `url`, `released_at`, `notes`.
