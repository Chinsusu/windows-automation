# PROTOCOL

Client long-poll `GET /tasks?client_id=...` (timeout 10–25s). Callback `POST /cb`.
`/agent/latest` trả version mới nhất. Manifest tại `manifests/manifest.json`.

**Auth**: dạng header `X-Api-Key: <key>` trong mỗi request.

## Payload ví dụ
### /cb (POST)
```json
{
  "client_id": "ab12cd34ef56ab78",
  "ip_public": "27.79.50.55",
  "status": "live",
  "message": "Idle",
  "ts": "2025-10-07T12:01:34+07:00"
}
```

### /tasks (GET)
```json
{
  "task_id": "t-20251007-0001",
  "type": "OPEN_URL",
  "args": {"url": "https://example.com"},
  "timeout": 30000
}
```

