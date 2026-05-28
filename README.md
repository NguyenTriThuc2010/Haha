# Titans Hub

Chào mừng đến với Titans Hub!

## Hướng dẫn sử dụng

Copy đoạn script dưới đây và dán vào Executor của bạn (Krnl, Fluxus, Delta,...) để chạy:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NguyenTriThuc2010/Haha/main/MainLoader.lua"))()
```

---

> **Lưu ý dành cho Developer:** 
> Bộ mã này hiện đang được thiết kế dưới dạng sử dụng `script.Parent` và `require()`, phù hợp để build trong Roblox Studio. Nếu chạy trực tiếp qua Executor bằng đoạn script trên, bạn cần sửa lại logic nạp module trong `MainLoader.lua` thành các lệnh `loadstring(game:HttpGet(...))` tương ứng cho từng file con.
