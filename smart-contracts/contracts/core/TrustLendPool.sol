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

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset);
    event BorrowClaimed(address indexed user, address indexed asset, uint64 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset);
    event WithdrawClaimed(address indexed user, address indexed asset, uint64 amount);
    event LiquidationRequested(bytes32 indexed requestId, address indexed borrower, address liquidator);
    event LiquidationExecuted(bytes32 indexed requestId, address indexed borrower, uint64 debtRepaid);

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
        euint64 current = _collateralBalances[msg.sender][asset];

        if (euint64.unwrap(current) == 0) {
            _collateralBalances[msg.sender][asset] = encAmount;
            userLiquidityIndex[msg.sender][asset] = reserve.liquidityIndex;
        } else {
            euint64 normalized = _normalizeCollateral(current, msg.sender, asset);
            _collateralBalances[msg.sender][asset] = FHE.add(normalized, encAmount);
            userLiquidityIndex[msg.sender][asset] = reserve.liquidityIndex;
        }

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

        euint64 currentDebt = _debtBalances[msg.sender][asset];
        if (euint64.unwrap(currentDebt) == 0) {
            _debtBalances[msg.sender][asset] = actualAmount;
            userBorrowIndex[msg.sender][asset] = reserve.variableBorrowIndex;
        } else {
            euint64 normalizedDebt = _normalizeDebt(currentDebt, msg.sender, asset);
            _debtBalances[msg.sender][asset] = FHE.add(normalizedDebt, actualAmount);
            userBorrowIndex[msg.sender][asset] = reserve.variableBorrowIndex;
        }

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

        _pendingBorrows[msg.sender][asset] = FHE.asEuint64(0);

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
        euint64 currentDebt = _debtBalances[msg.sender][asset];

        if (euint64.unwrap(currentDebt) != 0) {
            euint64 normalizedDebt = _normalizeDebt(currentDebt, msg.sender, asset);
            euint64 actualRepay = FHELendingMath.encryptedMin(encAmount, normalizedDebt);
            _debtBalances[msg.sender][asset] = FHE.sub(normalizedDebt, actualRepay);
            userBorrowIndex[msg.sender][asset] = reserve.variableBorrowIndex;

            FHE.allowThis(_debtBalances[msg.sender][asset]);
            FHE.allow(_debtBalances[msg.sender][asset], msg.sender);
        }

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

        _pendingWithdrawals[msg.sender][asset] = FHE.asEuint64(0);

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
        euint64 borrowerDebt = _debtBalances[borrower][debtAsset];

        if (euint64.unwrap(borrowerDebt) != 0) {
            euint64 normalizedDebt = _normalizeDebt(borrowerDebt, borrower, debtAsset);
            euint64 actualRepay = FHELendingMath.encryptedMin(encRepay, normalizedDebt);
            _debtBalances[borrower][debtAsset] = FHE.sub(normalizedDebt, actualRepay);
            userBorrowIndex[borrower][debtAsset] = _reserves[debtAsset].variableBorrowIndex;

            FHE.allowThis(_debtBalances[borrower][debtAsset]);
            FHE.allow(_debtBalances[borrower][debtAsset], borrower);
        }
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
        euint64 borrowerCollateral = _collateralBalances[borrower][collateralAsset];

        if (euint64.unwrap(borrowerCollateral) != 0) {
            euint64 normalized = _normalizeCollateral(borrowerCollateral, borrower, collateralAsset);
            euint64 actualSeize = FHELendingMath.encryptedMin(encSeize, normalized);
            _collateralBalances[borrower][collateralAsset] = FHE.sub(normalized, actualSeize);
            userLiquidityIndex[borrower][collateralAsset] = _reserves[collateralAsset].liquidityIndex;

            FHE.allowThis(_collateralBalances[borrower][collateralAsset]);
            FHE.allow(_collateralBalances[borrower][collateralAsset], borrower);
        }
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

    function _computeEncryptedCollateralValue(
        address user,
        uint256 ltvBoost
    ) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            AssetConfig.AssetInfo memory info = assetConfig.getAsset(asset);
            euint64 balance = _collateralBalances[user][asset];

            if (euint64.unwrap(balance) != 0) {
                euint64 normalized = _normalizeCollateral(balance, user, asset);
                uint256 price = oracle.getPrice(asset);

                uint256 effectiveLTV = info.ltv + ltvBoost;
                if (effectiveLTV > info.liquidationThreshold) {
                    effectiveLTV = info.liquidationThreshold;
                }

                uint256 adjustedPrice = (price * effectiveLTV) / assetConfig.PERCENTAGE_PRECISION();
                euint64 value = FHELendingMath.mulByPlaintext(normalized, adjustedPrice);
                totalValue = FHE.add(totalValue, value);
                FHE.allowThis(totalValue);
            }
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
            euint64 balance = _collateralBalances[user][asset];

            if (euint64.unwrap(balance) != 0) {
                euint64 effectiveBalance = balance;
                if (asset == withdrawAsset) {
                    effectiveBalance = FHE.sub(balance, withdrawAmount);
                }
                uint256 price = oracle.getPrice(asset);
                uint256 adjustedPrice = (price * info.ltv) / assetConfig.PERCENTAGE_PRECISION();
                euint64 value = FHELendingMath.mulByPlaintext(effectiveBalance, adjustedPrice);
                totalValue = FHE.add(totalValue, value);
                FHE.allowThis(totalValue);
            }
        }

        return totalValue;
    }

    function _computeEncryptedLiquidationCollateralValue(address user) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            AssetConfig.AssetInfo memory info = assetConfig.getAsset(asset);
            euint64 balance = _collateralBalances[user][asset];

            if (euint64.unwrap(balance) != 0) {
                uint256 price = oracle.getPrice(asset);
                uint256 adjustedPrice = (price * info.liquidationThreshold) / assetConfig.PERCENTAGE_PRECISION();
                euint64 value = FHELendingMath.mulByPlaintext(balance, adjustedPrice);
                totalValue = FHE.add(totalValue, value);
                FHE.allowThis(totalValue);
            }
        }

        return totalValue;
    }

    function _computeEncryptedDebtValue(address user) internal returns (euint64) {
        uint256 count = assetConfig.getAssetCount();
        euint64 totalValue = FHE.asEuint64(0);

        for (uint256 i = 0; i < count; i++) {
            address asset = assetConfig.assetList(i);
            euint64 debt = _debtBalances[user][asset];

            if (euint64.unwrap(debt) != 0) {
                euint64 normalizedDebt = _normalizeDebt(debt, user, asset);
                uint256 price = oracle.getPrice(asset);
                euint64 value = FHELendingMath.mulByPlaintext(normalizedDebt, price);
                totalValue = FHE.add(totalValue, value);
                FHE.allowThis(totalValue);
            }
        }

        return totalValue;
    }

    // ─── INTERNAL: Helpers ───────────────────────────────────────────────

    function _getReserveFactorRay(address asset) internal view returns (uint256) {
        uint256 rfBPS = assetConfig.getAsset(asset).reserveFactor;
        return (rfBPS * RayMath.RAY) / assetConfig.PERCENTAGE_PRECISION();
    }
}
