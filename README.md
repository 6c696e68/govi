# Govi

Bộ gõ tiếng Việt **Telex** cho macOS (Apple Silicon) — gọn nhẹ, chạy nền, chỉ hiện diện qua icon trên thanh trạng thái. Không Dock, không cửa sổ, không cấu hình rườm rà.

> [!NOTE]
> Govi là dự án cá nhân: viết một bộ gõ "theo ý mình" để chủ động đọc hiểu, tùy biến và tự fix bug.

## Tính năng

- Gõ tiếng Việt kiểu **Telex** với engine xử lý âm tiết, đặt dấu thanh theo luật chính tả tiếng Việt.
- **Tự khôi phục** từ tiếng Anh: chuỗi có dấu nhưng sai cấu trúc âm tiết (vd `function`, `kiro`) được trả về phím gốc, không bị Việt hóa nhầm.
- **Gõ dấu đôi để nhả dấu** (Telex thuần): gõ phím dấu hai lần để hủy dấu và ra ký tự thường — vd `gorri` → `gori`, `kirr` → `kir`.
- Bật/tắt nhanh bằng phím nóng **Control + Shift**, hoặc click icon trạng thái (`VI` / `EN`).
- **Nhận diện ứng dụng** để chọn chiến lược chèn ký tự phù hợp (Spotlight, trình duyệt, Terminal, Electron, Office...), tránh lỗi nhân đôi/mất ký tự.
- **Debug log gõ phím**: bật/tắt trong menu để ghi lại từng phím vào file, tiện soi lỗi.
- Tự khởi động cùng macOS, chặn chạy nhiều bản, dùng tài nguyên tối thiểu.

## Yêu cầu

- macOS 14.0 trở lên, máy **Apple Silicon (arm64)**.
- Swift toolchain (Xcode hoặc Command Line Tools).
- Quyền **Accessibility** cho ứng dụng (macOS sẽ nhắc khi chạy lần đầu).

## Tải về

Bản dựng sẵn (`.dmg`) có ở mục [Releases](../../releases). Tải về, mở `.dmg`, kéo `Govi.app` vào `Applications`.

> [!NOTE]
> Bản release từ CI được ký **ad-hoc** (chưa notarize). Lần đầu mở, nếu bị Gatekeeper chặn: chuột phải `Govi.app` → **Open** → **Open**, hoặc vào **System Settings → Privacy & Security** bấm **Open Anyway**.

## Build từ mã nguồn

Chữ ký code lấy từ biến môi trường `GOVI_SIGN_ID` (không hardcode trong repo):

```bash
# Xem danh sách chứng chỉ ký
security find-identity -v -p codesigning

# Đặt chứng chỉ và build
export GOVI_SIGN_ID="<hash hoặc tên cert>"
./build.sh
```

`build.sh` sẽ tạo `build/Govi.app` và `build/Govi.dmg`. Mở file `.dmg` rồi kéo `Govi.app` vào thư mục `Applications` để cài.

> [!IMPORTANT]
> Lần chạy đầu, cấp quyền tại **System Settings → Privacy & Security → Accessibility**. Khi chưa có quyền, Govi **không hiện** icon trên thanh trạng thái mà chỉ hiện hộp thoại xin quyền; icon `VI`/`EN` chỉ xuất hiện sau khi quyền đã được cấp.

## Sử dụng

- Icon trên thanh trạng thái cho biết chế độ: `VI` (đang gõ tiếng Việt) hoặc `EN` (tắt). Icon chỉ xuất hiện sau khi đã cấp quyền Accessibility.
- **Control + Shift** hoặc **click trái** vào icon để chuyển VI/EN.
- **Click phải** vào icon để mở menu (chuyển chế độ, bật/tắt debug log, thoát).
- **Debug log gõ phím**: bật trong menu để ghi từng phím vào `~/Library/Logs/Govi/typing.log`; khi tắt sẽ tự mở file log. Xem realtime: `tail -f ~/Library/Logs/Govi/typing.log`.

## Kiến trúc

Govi tách bạch phần engine thuần logic và phần platform tương tác với macOS:

- **Engine** (`Sources/Engine`) — `VietTelex` xử lý theo mô hình buffer phím thô + chuỗi hiển thị + chỉ số thanh. Mỗi phím được replay để áp dụng dấu đôi (aa/ee/oo/dd), móc/trăng (`w`), dấu thanh (s/f/r/x/j/z), kiểm tra âm tiết hợp lệ rồi tính `diff` thành lệnh `(số ký tự xóa, chuỗi chèn)`.
- **Platform** (`Sources/Platform`):
  - `KeyTap` — `CGEventTap` chạy trên thread riêng, bắt sự kiện bàn phím/chuột.
  - `Injector` + `Strategies` — registry nhận diện app theo `bundleId`/role, chọn chiến lược chèn ký tự (Fast, Slow, Selection, EmptyCharPrefix, SyncProxy, AXDirect, Passthrough).
  - `Hotkey` — phím nóng Control + Shift.
  - `StatusBar`, `LoginItem`, `Accessibility` — icon trạng thái, khởi động cùng OS, kiểm tra quyền.
  - `DebugLog` — ghi log gõ phím ra file khi bật debug.

## Cấu trúc dự án

```
govi/
├── Sources/
│   ├── Engine/        # VietTelex, bảng ký tự tiếng Việt (logic thuần)
│   ├── Platform/      # KeyTap, Injector, Strategies, Hotkey, StatusBar, ...
│   └── main.swift     # AppController: kết nối engine + platform
├── Resources/         # Info.plist, AppIcon.icns
├── test/              # Test engine theo golden file
├── tools/             # Tiện ích (tạo icon)
├── build.sh           # Build .app + .dmg, codesign
└── docs/              # Tài liệu, kế hoạch triển khai
```

## Kiểm thử

Engine được kiểm thử bằng bảng `phím gõ → kết quả mong đợi` so với golden file:

```bash
./test/run.sh
```

Script biên dịch engine cùng test runner và đối chiếu với `test/golden.tsv`.

---

### Ghi chú & tham khảo

Govi được **lấy cảm hứng và tham khảo** từ dự án mã nguồn mở [tctvn/cay](https://github.com/tctvn/cay). Mình tham khảo để hiểu cách một bộ gõ tiếng Việt trên macOS vận hành, rồi tự xây dựng lại theo hướng riêng nhằm chủ động tùy biến và tự fix bug theo ý mình. Cảm ơn tác giả `cay` vì nguồn tham khảo quý giá.
