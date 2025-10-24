# Cloudflare R2 — Worker API for Releases

Tài liệu này hướng dẫn upload / list / download / delete file lên R2 qua Cloudflare Worker (Bearer token).

> Khuyến nghị: KHÔNG commit token vào Git. Đặt token trong biến môi trường.
>
> ```powershell
> $env:R2_WORKER_URL = "https://<your-worker>.<your-subdomain>.workers.dev"
> $env:R2_AUTH_TOKEN = "<paste-your-token-here>"
> ```

## cURL Examples

### Upload
```bash
curl -X PUT --data-binary @yourfile.txt   -H "Authorization: Bearer $R2_AUTH_TOKEN"   "$R2_WORKER_URL/upload/path/to/file.txt"
```

### List
```bash
curl "$R2_WORKER_URL/list"
```

### Download
```bash
curl "$R2_WORKER_URL/download/test.txt"
```

### Delete
```bash
curl -X DELETE -H "Authorization: Bearer $R2_AUTH_TOKEN"   "$R2_WORKER_URL/file/test.txt"
```

## PowerShell Examples (Windows-friendly)

> Yêu cầu: PowerShell 5+ (mặc định trên Windows 10/Server 2019/2022).

```powershell
$Worker = $env:R2_WORKER_URL
$Token  = $env:R2_AUTH_TOKEN

# Upload
$Local = "dist\AutoAgent-0.2.0.exe"
$Remote = "releases/AutoAgent-0.2.0.exe"
Invoke-RestMethod -Uri "$Worker/upload/$Remote" -Method Put `
  -Headers @{ Authorization = "Bearer $Token" } `
  -InFile $Local -ContentType "application/octet-stream"

# List
Invoke-RestMethod -Uri "$Worker/list" -Method Get

# Download
Invoke-RestMethod -Uri "$Worker/download/$Remote" -Method Get `
  -OutFile "dist\AutoAgent-0.2.0.exe"

# Delete
Invoke-RestMethod -Uri "$Worker/file/$Remote" -Method Delete `
  -Headers @{ Authorization = "Bearer $Token" }
```

## Tích hợp vào quy trình phát hành

1. Build agent: `scripts/compile_agent.ps1 0.2.0` → tạo `dist/AutoAgent-0.2.0.exe`  
2. Upload lên R2 qua Worker (PowerShell ở trên, hoặc dùng script `scripts/r2_worker.ps1`)  
3. Cập nhật manifest: sửa `manifests/manifest.json` (hoặc dùng `scripts/r2_upload.ps1` nếu bạn dùng endpoint S3 của R2)  
4. Agent gọi `GET /agent/latest` và tải bản mới theo `manifest.json`

> Dùng Worker R2 để che endpoint S3, áp hạn mức/rate-limit và kiểm soát truy cập bằng Bearer token.

