---
description: "Dùng khi viết, review, hoặc sửa code. Áp dụng quy tắc nghiêm ngặt về comment — không được thêm comment thừa hoặc hiển nhiên."
applyTo: "**"
---
# Chính sách Comment Code

- **KHÔNG thêm comment** trừ khi giải thích điều phức tạp hoặc không hiển nhiên
- Không thêm comment chỉ nhắc lại những gì code đã nói (vd: `// increment counter` trên `counter++`)
- Không thêm comment boilerplate như `// constructor`, `// imports`, `// state variables`
- Không thêm JSDoc/NatSpec cho mọi function — chỉ thêm khi mục đích, tham số, hoặc hành vi thực sự không rõ từ tên và signature
- Nếu cần comment, phải trả lời **tại sao** chứ không phải **cái gì**
- Comment tốt: `// FHE.allowThis bắt buộc sau mỗi mutation, nếu không contract mất quyền truy cập ciphertext`
- Comment xấu: `// Cộng a với b` trên `FHE.add(a, b)`
