# Fhield Frontend

UI pages cho Fhield — privacy-preserving DeFi lending protocol trên Fhenix (FHE).

## Pages

| Page | File | Mô tả |
|------|------|-------|
| Dashboard | `pages/dashboard.html` | Tổng quan protocol: TVL, markets, APY |
| Deposit | `pages/deposit.html` | Supply ERC20 tokens vào TrustLendPool |
| Borrow | `pages/borrow.html` | Vay assets với encrypted amount (cofhejs) |
| Repay | `pages/repay.html` | Trả nợ cho TrustLendPool |
| Portfolio | `pages/portfolio.html` | Xem vị thế (encrypted), pending withdrawals |
| Markets | `pages/markets.html` | Chi tiết asset: interest rate model, FHERC20 wrapper |

## Smart Contract Interactions

### Deposit (Supply)
1. User approve ERC20 token cho TrustLendPool
2. Gọi `pool.deposit(asset, amount)` — amount là plaintext uint64
3. Contract encrypt balance qua FHE và lưu collateral

### Borrow
1. Encrypt amount qua `cofhejs.encrypt([Encryptable.uint64(amount)])`
2. Gọi `pool.borrow(asset, encryptedAmount)` — InEuint64
3. Contract kiểm tra collateral sufficiency bằng FHE mà không reveal positions

### Repay
1. Approve ERC20 token
2. Gọi `pool.repay(asset, amount)` — plaintext uint64
3. Contract tự động cap repay tại actual debt dùng FHE min

### Withdraw (2-step)
1. Encrypt amount, gọi `pool.withdraw(asset, encryptedAmount)`
2. Chờ FHE decrypt hoàn tất
3. Gọi `pool.claimWithdraw(asset)` để nhận tokens

### FHERC20 Wrapper
- `wrapper.wrap(amount)` — ERC20 → confidential FHERC20
- `wrapper.unwrap(encryptedAmount)` → decrypt → `claimUnwrapped(claimId)`

## Run Locally

```bash
# Serve static files
npx serve frontend/
# hoặc
python -m http.server 8080 -d frontend/
```

## Design System

- Dark theme (#0a0e17 base)
- Cyan accent (#06b6d4 / #4cd7f6)
- Fonts: Manrope (headlines), Inter (body/labels)
- Tailwind CSS via CDN
- Material Symbols Outlined icons
- Glassmorphism cards

## Stitch Project

Project ID: `17701927218531799858`
Screens được generate từ Google Stitch và download dưới dạng static HTML.
