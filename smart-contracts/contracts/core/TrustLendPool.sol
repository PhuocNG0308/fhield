// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/RayMath.sol";
import "../libraries/FHELendingMath.sol";
import "../interfaces/IInterestRateStrategy.sol";
import "../interfaces/ICreditScore.sol";
import "../interfaces/IPhoenixProgram.sol";
import "./ReserveLogic.sol";
import "./PriceOracle.sol";
import "./AssetConfig.sol";

contract TrustLendPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using RayMath for uint256;
    using ReserveLogic for ReserveLogic.ReserveData;

    AssetConfig public assetConfig;
    PriceOracle public oracle;
    IInterestRateStrategy public interestRateStrategy;
    ICreditScore public creditScore;
    IPhoenixProgram public phoenixProgram;

    mapping(address => ReserveLogic.ReserveData) internal _reserves;

    mapping(address => mapping(address => euint64)) private _collateralBalances;
    mapping(address => mapping(address => euint64)) private _debtBalances;

    mapping(address => uint256) public totalDeposits;
    mapping(address => uint256) public totalBorrows;

    mapping(address => mapping(address => uint256)) public userLiquidityIndex;
    mapping(address => mapping(address => uint256)) public userBorrowIndex;

    mapping(address => mapping(address => euint64)) private _pendingWithdrawals;
    mapping(address => mapping(address => euint64)) private _pendingBorrows;

    uint256 private constant NORMALIZATION_FACTOR = 1e6;
    uint256 public constant CLOSE_FACTOR = 5000;
    uint256 public constant CLOSE_FACTOR_PRECISION = 10000;

    struct LiquidationRequest {
        address liquidator;
        address borrower;
        address debtAsset;
        address collateralAsset;
        ebool isUndercollateralized;
        bool executed;
    }

    mapping(bytes32 => LiquidationRequest) public liquidationRequests;
    uint256 private _liquidationNonce;

    // ─── FHIELD BUFFER MODEL STATE ──────────────────────────────────────

    uint256 public maxSweepBatchSize = 3;
    uint256 public keeperBountyPerUser;
    mapping(address => uint256) public keeperBountyReserve;

    uint256 public constant SWEEP_COOLDOWN = 600;
    mapping(address => uint256) public lastSweptTimestamp;
    mapping(address => bool) public hasBorrowed;

    struct BufferPool {
        euint64 encCollateral;
        euint64 encDebt;
    }
    mapping(bytes32 => BufferPool) internal _bufferPools;

    struct PendingAuction {
        euint64 encCollateral;
        euint64 encDebt;
        bool pending;
    }
    mapping(bytes32 => PendingAuction) internal _pendingAuctions;

    uint256 public constant AUCTION_DURATION = 3600;
    uint256 public constant AUCTION_START_PREMIUM = 10500;
    uint256 public constant AUCTION_FLOOR = 8000;
    uint256 private constant PRICE_PRECISION = 1e18;

    struct Auction {
        address collateralAsset;
        address debtAsset;
        uint64 collateralRemaining;
        uint64 debtToRecover;
        uint64 debtRecovered;
        uint256 startTime;
        bool active;
    }
    mapping(bytes32 => Auction) public auctions;

    mapping(address => uint256) public insuranceFund;

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset);
    event BorrowClaimed(address indexed user, address indexed asset, uint64 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset);
    event WithdrawClaimed(address indexed user, address indexed asset, uint64 amount);
    event LiquidationRequested(bytes32 indexed requestId, address indexed borrower, address liquidator);
    event LiquidationExecuted(bytes32 indexed requestId, address indexed borrower, uint64 debtRepaid);
    event Swept(address indexed keeper, address collateralAsset, address debtAsset, uint256 usersCount);
    event KeeperBountyPaid(address indexed keeper, address asset, uint256 amount);
    event BufferDecryptRequested(bytes32 indexed pairKey);
    event AuctionStarted(bytes32 indexed pairKey, uint64 collateral, uint64 debt);
    event AuctionBid(bytes32 indexed pairKey, address indexed bidder, uint64 colBought, uint64 debtPaid);
    event AuctionSettled(bytes32 indexed pairKey, uint64 debtRecovered, int256 surplus);
    event BadDebtCovered(address indexed asset, uint256 shortfall, uint256 covered);
    event InsuranceDeposited(address indexed asset, uint256 amount);

    constructor(
        address _assetConfig,
        address _oracle,
        address _interestRateStrategy,
        address _creditScore,
        address _phoenixProgram
    ) Ownable(msg.sender) {
        assetConfig = AssetConfig(_assetConfig);
        oracle = PriceOracle(_oracle);
        interestRateStrategy = IInterestRateStrategy(_interestRateStrategy);
        creditScore = ICreditScore(_creditScore);
        phoenixProgram = IPhoenixProgram(_phoenixProgram);
    }

    // ─── DEPOSIT (Supply) ────────────────────────────────────────────────

    function deposit(address asset, uint64 amount) external nonReentrant {
        require(assetConfig.isSupported(asset), "Unsupported asset");
        require(amount > 0, "Amount must be > 0");

        ReserveLogic.ReserveData storage reserve = _reserves[asset];
        reserve.accrueInterest();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        euint64 encAmount = FHE.asEuint64(amount);
        euint64 normalized = _safeCollateral(msg.sender, asset);
        _collateralBalances[msg.sender][asset] = FHE.add(normalized, encAmount);
        userLiquidityIndex[msg.sender][asset] = reserve.liquidityIndex;

        FHE.allowThis(_collateralBalances[msg.sender][asset]);
        FHE.allow(_collateralBalances[msg.sender][asset], msg.sender);

        totalDeposits[asset] += amount;

        uint256 rfRay = _getReserveFactorRay(asset);
        reserve.updateRates(totalDeposits[asset], totalBorrows[asset], interestRateStrategy, rfRay);

        emit Deposit(msg.sender, asset, amount);
    }

    // ─── BORROW ──────────────────────────────────────────────────────────
    //  DCS Hook: getBorrowRateDiscount (→ 0%) + getLTVBoost (→ 0%)

    function borrow(address asset, InEuint64 memory amount) external nonReentrant {
        require(assetConfig.isSupported(asset), "Unsupported asset");

        ReserveLogic.ReserveData storage reserve = _reserves[asset];
        reserve.accrueInterest();

        euint64 encAmount = FHE.asEuint64(amount);

        // ══════ DCS HOOK: Borrow Rate Discount (currently 0%) ══════
        // uint256 rateDiscount = creditScore.getBorrowRateDiscount(msg.sender);
        // Future: effective rate = borrowRate * (RAY - rateDiscount) / RAY

        // ══════ DCS HOOK: LTV Boost (currently 0%) ══════
        uint256 ltvBoost = creditScore.getLTVBoost(msg.sender);

        euint64 totalCollateralValue = _computeEncryptedCollateralValue(msg.sender, ltvBoost);
        euint64 totalDebtValue = _computeEncryptedDebtValue(msg.sender);

        uint256 assetPrice = oracle.getPrice(asset);
        euint64 newDebtValue = FHE.add(
            totalDebtValue,
            FHELendingMath.mulByPlaintext(encAmount, assetPrice)
        );

        ebool healthy = FHE.gte(totalCollateralValue, newDebtValue);
        euint64 actualAmount = FHE.select(healthy, encAmount, FHELendingMath.encryptedZero());

        hasBorrowed[msg.sender] = true;

        euint64 normalizedDebt = _safeDebt(msg.sender, asset);
        _debtBalances[msg.sender][asset] = FHE.add(normalizedDebt, actualAmount);
        userBorrowIndex[msg.sender][asset] = reserve.variableBorrowIndex;

        FHE.allowThis(_debtBalances[msg.sender][asset]);
        FHE.allow(_debtBalances[msg.sender][asset], msg.sender);

        _pendingBorrows[msg.sender][asset] = actualAmount;
        FHE.allowThis(actualAmount);
        FHE.allow(actualAmount, msg.sender);
        FHE.decrypt(actualAmount);

        emit Borrow(msg.sender, asset);
    }

    function claimBorrow(address asset) external nonReentrant {
        euint64 pending = _pendingBorrows[msg.sender][asset];
        require(euint64.unwrap(pending) != 0, "No pending borrow");

        (uint64 amount, bool ready) = FHE.getDecryptResultSafe(pending);
        require(ready, "Decrypt not ready");

        _pendingBorrows[msg.sender][asset] = euint64.wrap(0);

        if (amount > 0) {
            totalBorrows[asset] += amount;

            uint256 rfRay = _getReserveFactorRay(asset);
            _reserves[asset].updateRates(totalDeposits[asset], totalBorrows[asset], interestRateStrategy, rfRay);

            IERC20(asset).safeTransfer(msg.sender, amount);
        }

        emit BorrowClaimed(msg.sender, asset, amount);
    }

    // ─── REPAY ───────────────────────────────────────────────────────────

    function repay(address asset, uint64 amount) external nonReentrant {
        require(assetConfig.isSupported(asset), "Unsupported asset");
        require(amount > 0, "Amount must be > 0");

        ReserveLogic.ReserveData storage reserve = _reserves[asset];
        reserve.accrueInterest();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        euint64 encAmount = FHE.asEuint64(amount);
        euint64 normalizedDebt = _safeDebt(msg.sender, asset);
        euint64 actualRepay = FHELendingMath.encryptedMin(encAmount, normalizedDebt);
        _debtBalances[msg.sender][asset] = FHE.sub(normalizedDebt, actualRepay);
        userBorrowIndex[msg.sender][asset] = reserve.variableBorrowIndex;

        FHE.allowThis(_debtBalances[msg.sender][asset]);
        FHE.allow(_debtBalances[msg.sender][asset], msg.sender);

        totalBorrows[asset] = totalBorrows[asset] > amount
            ? totalBorrows[asset] - amount
            : 0;

        uint256 rfRay = _getReserveFactorRay(asset);
        reserve.updateRates(totalDeposits[asset], totalBorrows[asset], interestRateStrategy, rfRay);

        emit Repay(msg.sender, asset, amount);
    }

    // ─── WITHDRAW (2-step: request + claim after decrypt) ────────────────

    function withdraw(address asset, InEuint64 memory amount) external nonReentrant {
        require(assetConfig.isSupported(asset), "Unsupported asset");

        ReserveLogic.ReserveData storage reserve = _reserves[asset];
        reserve.accrueInterest();

        euint64 encAmount = FHE.asEuint64(amount);
        euint64 currentCollateral = _collateralBalances[msg.sender][asset];

        euint64 normalizedCollateral = _normalizeCollateral(currentCollateral, msg.sender, asset);
        euint64 actualWithdraw = FHELendingMath.encryptedMin(encAmount, normalizedCollateral);

        euint64 newCollateralValue = _computeEncryptedCollateralValueAfterWithdraw(
            msg.sender, asset, actualWithdraw
        );
        euint64 debtValue = _computeEncryptedDebtValue(msg.sender);

        ebool stillHealthy = FHE.gte(newCollateralValue, debtValue);
        euint64 finalWithdraw = FHE.select(stillHealthy, actualWithdraw, FHELendingMath.encryptedZero());

        _collateralBalances[msg.sender][asset] = FHE.sub(normalizedCollateral, finalWithdraw);
        userLiquidityIndex[msg.sender][asset] = reserve.liquidityIndex;
        FHE.allowThis(_collateralBalances[msg.sender][asset]);
        FHE.allow(_collateralBalances[msg.sender][asset], msg.sender);

        _pendingWithdrawals[msg.sender][asset] = finalWithdraw;
        FHE.allowThis(finalWithdraw);
        FHE.allow(finalWithdraw, msg.sender);
        FHE.decrypt(finalWithdraw);

        emit Withdraw(msg.sender, asset);
    }

    function claimWithdraw(address asset) external nonReentrant {
        euint64 pending = _pendingWithdrawals[msg.sender][asset];
        require(euint64.unwrap(pending) != 0, "No pending withdrawal");

        (uint64 amount, bool ready) = FHE.getDecryptResultSafe(pending);
        require(ready, "Decrypt not ready");

        _pendingWithdrawals[msg.sender][asset] = euint64.wrap(0);

        if (amount > 0) {
            totalDeposits[asset] = totalDeposits[asset] > amount
                ? totalDeposits[asset] - amount
                : 0;

            uint256 rfRay = _getReserveFactorRay(asset);
            _reserves[asset].updateRates(totalDeposits[asset], totalBorrows[asset], interestRateStrategy, rfRay);

            IERC20(asset).safeTransfer(msg.sender, amount);
        }

        emit WithdrawClaimed(msg.sender, asset, amount);
    }

    // ─── LIQUIDATION (2-step async) ──────────────────────────────────────
    //  Phoenix Hook: _triggerPhoenixRelief (→ 0% relief share)

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address borrower
    ) external nonReentrant returns (bytes32) {
        require(assetConfig.isSupported(debtAsset), "Unsupported debt asset");
        require(assetConfig.isSupported(collateralAsset), "Unsupported collateral");

        _reserves[debtAsset].accrueInterest();

        euint64 collateralValue = _computeEncryptedLiquidationCollateralValue(borrower);
        euint64 debtValue = _computeEncryptedDebtValue(borrower);

        ebool isUndercollateralized = FHE.lt(collateralValue, debtValue);
        FHE.allowThis(isUndercollateralized);
        FHE.decrypt(isUndercollateralized);

        bytes32 requestId = keccak256(
            abi.encodePacked(msg.sender, borrower, debtAsset, collateralAsset, _liquidationNonce++)
        );

        liquidationRequests[requestId] = LiquidationRequest({
            liquidator: msg.sender,
            borrower: borrower,
            debtAsset: debtAsset,
            collateralAsset: collateralAsset,
            isUndercollateralized: isUndercollateralized,
            executed: false
        });

        emit LiquidationRequested(requestId, borrower, msg.sender);
        return requestId;
    }

    function executeLiquidation(
        bytes32 requestId,
        uint64 debtToCover
    ) external nonReentrant {
        LiquidationRequest storage req = liquidationRequests[requestId];
        require(req.liquidator == msg.sender, "Not liquidator");
        require(!req.executed, "Already executed");

        {
            (bool isUnder, bool ready) = FHE.getDecryptResultSafe(req.isUndercollateralized);
            require(ready, "Decrypt not ready");
            require(isUnder, "Position is healthy");
        }

        req.executed = true;

        _reserves[req.debtAsset].accrueInterest();

        IERC20(req.debtAsset).safeTransferFrom(msg.sender, address(this), debtToCover);
        _repayDebtOnLiquidation(req.borrower, req.debtAsset, debtToCover);

        (uint256 collateralAmount, uint256 penaltyAmount) = _calculateLiquidationAmounts(
            req.debtAsset, req.collateralAsset, debtToCover
        );

        // ══════ PHOENIX PROGRAM HOOK (currently 0% relief) ══════
        _triggerPhoenixRelief(req.borrower, penaltyAmount);

        _seizeCollateral(req.borrower, req.collateralAsset, collateralAmount);
        IERC20(req.collateralAsset).safeTransfer(msg.sender, collateralAmount);

        _updateTotalsAfterLiquidation(req.debtAsset, req.collateralAsset, debtToCover, collateralAmount);

        emit LiquidationExecuted(requestId, req.borrower, debtToCover);
    }

    function _repayDebtOnLiquidation(address borrower, address debtAsset, uint64 debtToCover) internal {
        euint64 encRepay = FHE.asEuint64(debtToCover);
        euint64 normalizedDebt = _safeDebt(borrower, debtAsset);
        euint64 actualRepay = FHELendingMath.encryptedMin(encRepay, normalizedDebt);
        _debtBalances[borrower][debtAsset] = FHE.sub(normalizedDebt, actualRepay);
        userBorrowIndex[borrower][debtAsset] = _reserves[debtAsset].variableBorrowIndex;

        FHE.allowThis(_debtBalances[borrower][debtAsset]);
        FHE.allow(_debtBalances[borrower][debtAsset], borrower);
    }

    function _calculateLiquidationAmounts(
        address debtAsset,
        address collateralAsset,
        uint64 debtToCover
    ) internal view returns (uint256 collateralAmount, uint256 penaltyAmount) {
        uint256 bonus = assetConfig.getAsset(collateralAsset).liquidationBonus;
        uint256 debtPrice = oracle.getPrice(debtAsset);
        uint256 colPrice = oracle.getPrice(collateralAsset);
        uint256 pctPrec = assetConfig.PERCENTAGE_PRECISION();

        collateralAmount = (uint256(debtToCover) * debtPrice * (pctPrec + bonus))
            / (colPrice * pctPrec);
        penaltyAmount = (uint256(debtToCover) * debtPrice * bonus)
            / (colPrice * pctPrec);
    }

    function _seizeCollateral(address borrower, address collateralAsset, uint256 amount) internal {
        euint64 encSeize = FHE.asEuint64(uint64(amount));
        euint64 normalized = _safeCollateral(borrower, collateralAsset);
        euint64 actualSeize = FHELendingMath.encryptedMin(encSeize, normalized);
        _collateralBalances[borrower][collateralAsset] = FHE.sub(normalized, actualSeize);
        userLiquidityIndex[borrower][collateralAsset] = _reserves[collateralAsset].liquidityIndex;

        FHE.allowThis(_collateralBalances[borrower][collateralAsset]);
        FHE.allow(_collateralBalances[borrower][collateralAsset], borrower);
    }

    function _updateTotalsAfterLiquidation(
        address debtAsset,
        address collateralAsset,
        uint64 debtToCover,
        uint256 collateralAmount
    ) internal {
        totalBorrows[debtAsset] = totalBorrows[debtAsset] > debtToCover
            ? totalBorrows[debtAsset] - debtToCover
            : 0;
        totalDeposits[collateralAsset] = totalDeposits[collateralAsset] > collateralAmount
            ? totalDeposits[collateralAsset] - collateralAmount
            : 0;

        uint256 rfDebt = _getReserveFactorRay(debtAsset);
        _reserves[debtAsset].updateRates(totalDeposits[debtAsset], totalBorrows[debtAsset], interestRateStrategy, rfDebt);

        if (collateralAsset != debtAsset) {
            uint256 rfCol = _getReserveFactorRay(collateralAsset);
            _reserves[collateralAsset].updateRates(totalDeposits[collateralAsset], totalBorrows[collateralAsset], interestRateStrategy, rfCol);
        }
    }

    // ─── FHIELD BUFFER MODEL (3-Stage Liquidation) ─────────────────────
    //  Stage 1: sweepLiquidations — Keeper batch-checks users in encrypted space
    //  Stage 2: requestBufferDecrypt — Aggregate decrypt for Buffer Pool
    //  Stage 3: Dutch Auction — Per-asset auction for liquidated collateral

    function sweepLiquidations(
        address[] calldata users,
        address collateralAsset,
        address debtAsset
    ) external nonReentrant {
        require(users.length > 0 && users.length <= maxSweepBatchSize, "Invalid batch size");
        require(assetConfig.isSupported(collateralAsset), "Unsupported collateral");
        require(assetConfig.isSupported(debtAsset), "Unsupported debt");

        bytes32 pKey = _pairKey(collateralAsset, debtAsset);

        _accrueAllReserves();

        uint256 debtPrice = oracle.getPrice(debtAsset);
        uint256 colPrice = oracle.getPrice(collateralAsset);
        uint256 bonus = assetConfig.getAsset(collateralAsset).liquidationBonus;
        uint256 pctPrec = assetConfig.PERCENTAGE_PRECISION();

        uint256 scaledRatio = (debtPrice * (pctPrec + bonus) * PRICE_PRECISION)
            / (colPrice * pctPrec);
        require(scaledRatio > 0, "Price ratio zero");

        uint256 swept;
        for (uint256 i = 0; i < users.length; i++) {
            if (!hasBorrowed[users[i]]) continue;
            if (block.timestamp < lastSweptTimestamp[users[i]] + SWEEP_COOLDOWN) continue;

            lastSweptTimestamp[users[i]] = block.timestamp;
            _sweepUser(users[i], collateralAsset, debtAsset, pKey, scaledRatio);
            swept++;
        }

        uint256 bounty = swept * keeperBountyPerUser;
        if (bounty > 0 && keeperBountyReserve[debtAsset] >= bounty) {
            keeperBountyReserve[debtAsset] -= bounty;
            IERC20(debtAsset).safeTransfer(msg.sender, bounty);
            emit KeeperBountyPaid(msg.sender, debtAsset, bounty);
        }

        emit Swept(msg.sender, collateralAsset, debtAsset, swept);
    }

    function _sweepUser(
        address user,
        address collateralAsset,
        address debtAsset,
        bytes32 pKey,
        uint256 scaledRatio
    ) internal {
        euint64 totalColValue = _computeEncryptedLiquidationCollateralValue(user);
        euint64 totalDebtValue = _computeEncryptedDebtValue(user);
        ebool isUnder = FHE.lt(totalColValue, totalDebtValue);

        euint64 userDebt = _safeDebt(user, debtAsset);
        euint64 userCol = _safeCollateral(user, collateralAsset);

        // Fix #1: debtToBuffer = userDebt * CLOSE_FACTOR / CLOSE_FACTOR_PRECISION
        euint64 debtToBuffer = FHELendingMath.divByPlaintext(
            FHELendingMath.mulByPlaintext(userDebt, CLOSE_FACTOR),
            CLOSE_FACTOR_PRECISION
        );
        FHE.allowThis(debtToBuffer);

        euint64 colToSeize = FHELendingMath.divByPlaintext(
            FHELendingMath.mulByPlaintext(debtToBuffer, scaledRatio),
            PRICE_PRECISION
        );
        FHE.allowThis(colToSeize);

        colToSeize = FHELendingMath.encryptedMin(colToSeize, userCol);
        FHE.allowThis(colToSeize);

        euint64 zero = FHELendingMath.encryptedZero();
        euint64 actualDebt = FHE.select(isUnder, debtToBuffer, zero);
        euint64 actualCol = FHE.select(isUnder, colToSeize, zero);
        FHE.allowThis(actualDebt);
        FHE.allowThis(actualCol);

        _debtBalances[user][debtAsset] = FHE.sub(userDebt, actualDebt);
        FHE.allowThis(_debtBalances[user][debtAsset]);
        FHE.allow(_debtBalances[user][debtAsset], user);
        userBorrowIndex[user][debtAsset] = _reserves[debtAsset].variableBorrowIndex;

        _collateralBalances[user][collateralAsset] = FHE.sub(userCol, actualCol);
        FHE.allowThis(_collateralBalances[user][collateralAsset]);
        FHE.allow(_collateralBalances[user][collateralAsset], user);
        userLiquidityIndex[user][collateralAsset] = _reserves[collateralAsset].liquidityIndex;

        BufferPool storage buf = _bufferPools[pKey];
        if (euint64.unwrap(buf.encDebt) == 0) {
            buf.encDebt = actualDebt;
        } else {
            buf.encDebt = FHE.add(buf.encDebt, actualDebt);
        }
        FHE.allowThis(buf.encDebt);

        if (euint64.unwrap(buf.encCollateral) == 0) {
            buf.encCollateral = actualCol;
        } else {
            buf.encCollateral = FHE.add(buf.encCollateral, actualCol);
        }
        FHE.allowThis(buf.encCollateral);
    }

    // ── Stage 2: Buffer Pool Decrypt ─────────────────────────────────────

    function requestBufferDecrypt(
        address collateralAsset,
        address debtAsset
    ) external nonReentrant {
        bytes32 pKey = _pairKey(collateralAsset, debtAsset);
        BufferPool storage buf = _bufferPools[pKey];
        PendingAuction storage pa = _pendingAuctions[pKey];

        require(euint64.unwrap(buf.encDebt) != 0, "Buffer empty");
        require(!pa.pending, "Already requested");

        pa.encCollateral = buf.encCollateral;
        pa.encDebt = buf.encDebt;
        pa.pending = true;
        FHE.allowThis(pa.encCollateral);
        FHE.allowThis(pa.encDebt);

        buf.encCollateral = euint64.wrap(0);
        buf.encDebt = euint64.wrap(0);

        FHE.decrypt(pa.encCollateral);
        FHE.decrypt(pa.encDebt);

        emit BufferDecryptRequested(pKey);
    }

    // ── Stage 3: Dutch Auction (per collateral-debt pair) ────────────────

    function startDutchAuction(
        address collateralAsset,
        address debtAsset
    ) external nonReentrant {
        bytes32 pKey = _pairKey(collateralAsset, debtAsset);
        PendingAuction storage pa = _pendingAuctions[pKey];
        Auction storage auc = auctions[pKey];

        require(pa.pending, "No decrypt pending");
        require(!auc.active, "Auction active");

        (uint64 colAmt, bool colReady) = FHE.getDecryptResultSafe(pa.encCollateral);
        (uint64 debtAmt, bool debtReady) = FHE.getDecryptResultSafe(pa.encDebt);
        require(colReady && debtReady, "Decrypt not ready");

        pa.encCollateral = euint64.wrap(0);
        pa.encDebt = euint64.wrap(0);
        pa.pending = false;

        if (colAmt == 0 || debtAmt == 0) return;

        totalBorrows[debtAsset] = totalBorrows[debtAsset] > debtAmt
            ? totalBorrows[debtAsset] - debtAmt : 0;
        totalDeposits[collateralAsset] = totalDeposits[collateralAsset] > colAmt
            ? totalDeposits[collateralAsset] - colAmt : 0;

        _updateRatesForAsset(debtAsset);
        if (collateralAsset != debtAsset) {
            _updateRatesForAsset(collateralAsset);
        }

        auc.collateralAsset = collateralAsset;
        auc.debtAsset = debtAsset;
        auc.collateralRemaining = colAmt;
        auc.debtToRecover = debtAmt;
        auc.debtRecovered = 0;
        auc.startTime = block.timestamp;
        auc.active = true;

        emit AuctionStarted(pKey, colAmt, debtAmt);
    }

    function getAuctionPrice(bytes32 pKey) public view returns (uint256) {
        Auction storage auc = auctions[pKey];
        require(auc.active, "No active auction");

        uint256 colPrice = oracle.getPrice(auc.collateralAsset);
        uint256 pctPrec = assetConfig.PERCENTAGE_PRECISION();
        uint256 elapsed = block.timestamp - auc.startTime;

        if (elapsed >= AUCTION_DURATION) {
            return (colPrice * AUCTION_FLOOR) / pctPrec;
        }

        uint256 decay = ((AUCTION_START_PREMIUM - AUCTION_FLOOR) * elapsed) / AUCTION_DURATION;
        return (colPrice * (AUCTION_START_PREMIUM - decay)) / pctPrec;
    }

    function bidDutchAuction(
        address collateralAsset,
        address debtAsset,
        uint64 collateralToBuy
    ) external nonReentrant {
        bytes32 pKey = _pairKey(collateralAsset, debtAsset);
        Auction storage auc = auctions[pKey];
        require(auc.active, "No active auction");
        require(collateralToBuy > 0 && collateralToBuy <= auc.collateralRemaining, "Invalid amount");

        uint256 pricePerCol = getAuctionPrice(pKey);
        uint256 debtPrice = oracle.getPrice(debtAsset);
        uint256 debtCost = (uint256(collateralToBuy) * pricePerCol) / debtPrice;
        require(debtCost > 0 && debtCost <= type(uint64).max, "Invalid cost");

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), debtCost);
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToBuy);

        auc.collateralRemaining -= collateralToBuy;
        auc.debtRecovered += uint64(debtCost);

        emit AuctionBid(pKey, msg.sender, collateralToBuy, uint64(debtCost));

        if (auc.collateralRemaining == 0) {
            _closeDutchAuction(pKey);
        }
    }

    function closeDutchAuction(
        address collateralAsset,
        address debtAsset
    ) external nonReentrant {
        bytes32 pKey = _pairKey(collateralAsset, debtAsset);
        Auction storage auc = auctions[pKey];
        require(auc.active, "No active auction");
        require(
            block.timestamp >= auc.startTime + AUCTION_DURATION
                || auc.collateralRemaining == 0,
            "Auction still running"
        );
        _closeDutchAuction(pKey);
    }

    function _closeDutchAuction(bytes32 pKey) internal {
        Auction storage auc = auctions[pKey];
        auc.active = false;

        int256 surplus = int256(uint256(auc.debtRecovered))
            - int256(uint256(auc.debtToRecover));

        if (surplus >= 0) {
            insuranceFund[auc.debtAsset] += uint256(surplus);
        } else {
            _coverBadDebt(auc.debtAsset, uint256(-surplus));
        }

        _updateRatesForAsset(auc.debtAsset);
        if (auc.collateralAsset != auc.debtAsset) {
            _updateRatesForAsset(auc.collateralAsset);
        }

        emit AuctionSettled(pKey, auc.debtRecovered, surplus);
    }

    // ── Safety Module (Insurance Fund) ───────────────────────────────────

    function _coverBadDebt(address debtAsset, uint256 shortfall) internal {
        uint256 covered;
        if (insuranceFund[debtAsset] >= shortfall) {
            insuranceFund[debtAsset] -= shortfall;
            covered = shortfall;
        } else {
            covered = insuranceFund[debtAsset];
            insuranceFund[debtAsset] = 0;
        }
        emit BadDebtCovered(debtAsset, shortfall, covered);
    }

    function depositInsurance(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        insuranceFund[asset] += amount;
        emit InsuranceDeposited(asset, amount);
    }

    // ─── VIEW FUNCTIONS ──────────────────────────────────────────────────

    function getEncryptedCollateral(address user, address asset) external view returns (euint64) {
        return _collateralBalances[user][asset];
    }

    function getEncryptedDebt(address user, address asset) external view returns (euint64) {
        return _debtBalances[user][asset];
    }

    function getPendingBorrow(address user, address asset) external view returns (euint64) {
        return _pendingBorrows[user][asset];
    }

    function getUtilizationRate(address asset) external view returns (uint256) {
        if (totalDeposits[asset] == 0) return 0;
        return totalBorrows[asset].rayDiv(totalDeposits[asset]);
    }

    function getBorrowRate(address asset) external view returns (uint256) {
        uint256 rfRay = _getReserveFactorRay(asset);
        (uint256 borrowRate, ) = interestRateStrategy.calculateInterestRates(
            totalDeposits[asset], totalBorrows[asset], rfRay
        );
        return borrowRate;
    }

    function getSupplyRate(address asset) external view returns (uint256) {
        uint256 rfRay = _getReserveFactorRay(asset);
        (, uint256 liquidityRate) = interestRateStrategy.calculateInterestRates(
            totalDeposits[asset], totalBorrows[asset], rfRay
        );
        return liquidityRate;
    }

    function getReserveData(address asset) external view returns (
        uint256 liquidityIndex,
        uint256 variableBorrowIndex,
        uint256 currentLiquidityRate,
        uint256 currentVariableBorrowRate,
        uint40 lastUpdateTimestamp
    ) {
        ReserveLogic.ReserveData storage r = _reserves[asset];
        return (
            r.liquidityIndex,
            r.variableBorrowIndex,
            r.currentLiquidityRate,
            r.currentVariableBorrowRate,
            r.lastUpdateTimestamp
        );
    }

    // ─── CONFIG ──────────────────────────────────────────────────────────

    function setCreditScore(address _creditScore) external onlyOwner {
        creditScore = ICreditScore(_creditScore);
    }

    function setPhoenixProgram(address _phoenixProgram) external onlyOwner {
        phoenixProgram = IPhoenixProgram(_phoenixProgram);
    }

    function setInterestRateStrategy(address _strategy) external onlyOwner {
        interestRateStrategy = IInterestRateStrategy(_strategy);
    }

    function setMaxSweepBatchSize(uint256 _max) external onlyOwner {
        require(_max > 0 && _max <= 10, "Invalid batch size");
        maxSweepBatchSize = _max;
    }

    function setKeeperBounty(uint256 _bountyPerUser) external onlyOwner {
        keeperBountyPerUser = _bountyPerUser;
    }

    function depositKeeperBounty(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        keeperBountyReserve[asset] += amount;
    }

    // ─── INTERNAL: Phoenix Relief ────────────────────────────────────────

    function _triggerPhoenixRelief(address liquidatedUser, uint256 penaltyAmount) internal {
        uint256 reliefShare = phoenixProgram.getReliefShare(liquidatedUser, penaltyAmount);
        if (reliefShare > 0) {
            phoenixProgram.onLiquidation(liquidatedUser, reliefShare);
        }
    }

    // ─── INTERNAL: Index Normalization ───────────────────────────────────

    function _normalizeDebt(
        euint64 debt,
        address user,
        address asset
    ) internal returns (euint64) {
        uint256 userIdx = userBorrowIndex[user][asset];
        if (userIdx == 0) return debt;

        uint256 currentIdx = _reserves[asset].variableBorrowIndex;
        if (currentIdx <= userIdx) return debt;

        uint256 growthScaled = ((currentIdx - userIdx) * NORMALIZATION_FACTOR) / userIdx;
        if (growthScaled == 0) return debt;

        euint64 debtBase = FHELendingMath.divByPlaintext(debt, NORMALIZATION_FACTOR);
        euint64 interestAccrued = FHELendingMath.mulByPlaintext(debtBase, growthScaled);

        euint64 result = FHE.add(debt, interestAccrued);
        FHE.allowThis(result);
        return result;
    }

    function _normalizeCollateral(
        euint64 balance,
        address user,
        address asset
    ) internal returns (euint64) {
        uint256 userIdx = userLiquidityIndex[user][asset];
        if (userIdx == 0) return balance;

        uint256 currentIdx = _reserves[asset].liquidityIndex;
        if (currentIdx <= userIdx) return balance;

        uint256 growthScaled = ((currentIdx - userIdx) * NORMALIZATION_FACTOR) / userIdx;
        if (growthScaled == 0) return balance;

        euint64 balBase = FHELendingMath.divByPlaintext(balance, NORMALIZATION_FACTOR);
        euint64 interest = FHELendingMath.mulByPlaintext(balBase, growthScaled);

        euint64 result = FHE.add(balance, interest);
        FHE.allowThis(result);
        return result;
    }

    // ─── INTERNAL: Collateral/Debt Value ─────────────────────────────────

    function _safeCollateral(address user, address asset) internal returns (euint64) {
        euint64 raw = _collateralBalances[user][asset];
        if (euint64.unwrap(raw) == 0) return FHELendingMath.encryptedZero();
        return _normalizeCollateral(raw, user, asset);
    }

    function _safeDebt(address user, address asset) internal returns (euint64) {
        euint64 raw = _debtBalances[user][asset];
        if (euint64.unwrap(raw) == 0) return FHELendingMath.encryptedZero();
        return _normalizeDebt(raw, user, asset);
    }

    function _computeEncryptedCollateralValue(
        address user,
        uint256 ltvBoost
    ) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            AssetConfig.AssetInfo memory info = assetConfig.getAsset(asset);

            euint64 balance = _safeCollateral(user, asset);
            uint256 price = oracle.getPrice(asset);

            uint256 effectiveLTV = info.ltv + ltvBoost;
            if (effectiveLTV > info.liquidationThreshold) {
                effectiveLTV = info.liquidationThreshold;
            }

            uint256 adjustedPrice = (price * effectiveLTV) / assetConfig.PERCENTAGE_PRECISION();
            euint64 value = FHELendingMath.mulByPlaintext(balance, adjustedPrice);
            totalValue = FHE.add(totalValue, value);
            FHE.allowThis(totalValue);
        }

        return totalValue;
    }

    function _computeEncryptedCollateralValueAfterWithdraw(
        address user,
        address withdrawAsset,
        euint64 withdrawAmount
    ) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            AssetConfig.AssetInfo memory info = assetConfig.getAsset(asset);

            euint64 balance = _safeCollateral(user, asset);
            if (asset == withdrawAsset) {
                balance = FHE.sub(balance, withdrawAmount);
            }

            uint256 price = oracle.getPrice(asset);
            uint256 adjustedPrice = (price * info.ltv) / assetConfig.PERCENTAGE_PRECISION();
            euint64 value = FHELendingMath.mulByPlaintext(balance, adjustedPrice);
            totalValue = FHE.add(totalValue, value);
            FHE.allowThis(totalValue);
        }

        return totalValue;
    }

    function _computeEncryptedLiquidationCollateralValue(address user) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            AssetConfig.AssetInfo memory info = assetConfig.getAsset(asset);

            euint64 balance = _safeCollateral(user, asset);
            uint256 price = oracle.getPrice(asset);
            uint256 adjustedPrice = (price * info.liquidationThreshold) / assetConfig.PERCENTAGE_PRECISION();
            euint64 value = FHELendingMath.mulByPlaintext(balance, adjustedPrice);
            totalValue = FHE.add(totalValue, value);
            FHE.allowThis(totalValue);
        }

        return totalValue;
    }

    function _computeEncryptedDebtValue(address user) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);

            euint64 debt = _safeDebt(user, asset);
            uint256 price = oracle.getPrice(asset);
            euint64 value = FHELendingMath.mulByPlaintext(debt, price);
            totalValue = FHE.add(totalValue, value);
            FHE.allowThis(totalValue);
        }

        return totalValue;
    }

    // ─── INTERNAL: Helpers ───────────────────────────────────────────────

    function _pairKey(address col, address debt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(col, debt));
    }

    function _accrueAllReserves() internal {
        uint256 count = assetConfig.getAssetCount();
        for (uint256 i = 0; i < count; i++) {
            _reserves[assetConfig.assetList(i)].accrueInterest();
        }
    }

    function _updateRatesForAsset(address asset) internal {
        uint256 rf = _getReserveFactorRay(asset);
        _reserves[asset].updateRates(
            totalDeposits[asset], totalBorrows[asset],
            interestRateStrategy, rf
        );
    }

    function _getReserveFactorRay(address asset) internal view returns (uint256) {
        uint256 rfBPS = assetConfig.getAsset(asset).reserveFactor;
        return (rfBPS * RayMath.RAY) / assetConfig.PERCENTAGE_PRECISION();
    }
}
