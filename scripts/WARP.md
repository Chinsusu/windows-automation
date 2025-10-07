# WARP.md — Scripts (PowerShell + R2)

## Biến môi trường (bắt buộc)
- Worker: `R2_WORKER_URL`, `R2_AUTH_TOKEN`
- S3: `R2_ACCOUNT_ID`, `R2_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

## Quy tắc bảo mật
- Không echo token ra console/log; nếu cần debug, dùng placeholder.
- Script phải kiểm tra tồn tại file, trả mã lỗi rõ ràng, dừng khi lỗi (`$ErrorActionPreference = "Stop"`).

## Tác vụ sẵn có
- `compile_agent.ps1` — build Aut2Exe x64.
- `r2_upload.ps1` — upload qua S3 endpoint + cập nhật `manifests/manifest.json`.
- `r2_worker.ps1` — tiện ích **Upload/List/Download/Delete** qua Cloudflare Worker (Bearer).
