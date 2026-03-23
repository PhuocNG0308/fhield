---
description: "Dùng khi cần hiểu sâu về quy tắc dự án, kiến trúc Fhenix CoFHE, sử dụng thư viện FHE, kiểu mã hóa, access control, luồng giải mã, FHERC20, client SDK, hoặc best practices. Tham khảo thư mục docs/ cho tài liệu chính thức."
applyTo: "**"
---
# Tham chiếu tài liệu dự án

Khi cần hiểu quy tắc kỹ thuật, conventions, hoặc cách Fhenix CoFHE hoạt động:

1. **Luôn tham khảo thư mục `docs/` trước** khi giả định về FHE patterns, kiểu mã hóa, access control, hoặc luồng giải mã
2. Thư mục `docs/` chứa tài liệu toàn diện từ CoFHE docs chính thức:
   - `docs/getting-started.md` — Cài đặt, tương thích, bắt đầu nhanh
   - `docs/fhe-library.md` — FHE.sol kiểu mã hóa và phép toán + errors reference
   - `docs/core-concepts.md` — Inputs, trivial encryption, ACL, conditions (select), giải mã, randomness, data evaluation
   - `docs/client-sdk.md` — @cofhe/sdk lifecycle, mã hóa, giải mã, permits, Hardhat plugin, quick-start, migration guide
   - `docs/fherc20.md` — Chuẩn token bảo mật FHERC20, operators, permits, wrapper
   - `docs/architecture.md` — Thành phần CoFHE, threshold network, luồng dữ liệu
   - `docs/best-practices.md` — Bảo mật, hiệu năng, quy trình phát triển
   - `docs/tutorials.md` — Hướng dẫn từng bước: counter, voting migration, decrypt migration, ACL examples, auction
3. Khi viết hoặc sửa Solidity contracts dùng FHE, verify patterns với `docs/core-concepts.md` và `docs/best-practices.md`
4. Khi làm việc với client SDK, tham khảo `docs/client-sdk.md` cho đúng lifecycle và API usage
