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
import "../interfaces/IFhieldBuffer.sol";
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
    IFhieldBuffer public fhieldBuffer;

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

    uint256 public constant DUTCH_AUCTION_DECAY_RATE = 10;
    uint256 public constant DUTCH_AUCTION_MIN_PRICE = 8000;
    uint256 public constant DUTCH_AUCTION_START_PRICE = 9800;
    uint256 public constant SWEEP_COOLDOWN = 10;

    mapping(address => euint64) internal _fhieldDebtPool;
    mapping(address => euint64) internal _fhieldColPool;

    uint256 private _sweepNonce;

    struct Auction {
        address debtAsset;
        address collateralAsset;
        euint64 encDebt;
        euint64 encCollateral;
        uint256 totalDebt;
        uint256 totalCollateral;
        uint256 startBlock;
        bool started;
        bool settled;
    }

    mapping(bytes32 => Auction) public auctions;
    uint256 private _auctionNonce;

    mapping(address => uint256) public lastSweepBlock;

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset);
    event BorrowClaimed(address indexed user, address indexed asset, uint64 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset);
    event WithdrawClaimed(address indexed user, address indexed asset, uint64 amount);
    event SweepCompleted(bytes32 indexed batchId, uint256 userCount);
    event AuctionRequested(bytes32 indexed auctionId, address debtAsset, address collateralAsset);
    event AuctionStarted(bytes32 indexed auctionId, uint256 totalDebt, uint256 totalCollateral);
    event AuctionSettled(bytes32 indexed auctionId, address indexed liquidator, uint256 debtPaid, uint256 collateralReceived);

    constructor(
        address _assetConfig,
        address _oracle,
        address _interestRateStrategy,
        address _creditScore,
        address _fhieldBuffer
    ) Ownable(msg.sender) {
        assetConfig = AssetConfig(_assetConfig);
        oracle = PriceOracle(_oracle);
        interestRateStrategy = IInterestRateStrategy(_interestRateStrategy);
        creditScore = ICreditScore(_creditScore);
        fhieldBuffer = IFhieldBuffer(_fhieldBuffer);
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

    // ─── LIQUIDATION: 3-STAGE FHIELD BUFFER MODEL ─────────────────────

    // Stage 1 + 2: Blind batched sweeping + instant encrypted seizure
    function sweepLiquidations(address[] calldata users) external nonReentrant returns (bytes32 batchId) {
        batchId = keccak256(abi.encodePacked(block.number, msg.sender, _sweepNonce++));

        _accrueAllReserves();

        uint256 assetCount = assetConfig.getAssetCount();

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            euint64 colVal = _computeEncryptedLiquidationCollateralValue(user);
            euint64 debtVal = _computeEncryptedDebtValue(user);
            ebool isUnder = FHE.lt(colVal, debtVal);

            for (uint256 j = 0; j < assetCount; j++) {
                address asset = assetConfig.assetList(j);

                euint64 userDebt = _safeDebt(user, asset);
                euint64 userCol = _safeCollateral(user, asset);

                euint64 debtToSeize = FHELendingMath.divByPlaintext(
                    FHELendingMath.mulByPlaintext(userDebt, CLOSE_FACTOR),
                    CLOSE_FACTOR_PRECISION
                );
                euint64 colToSeize = FHELendingMath.divByPlaintext(
                    FHELendingMath.mulByPlaintext(userCol, CLOSE_FACTOR),
                    CLOSE_FACTOR_PRECISION
                );

                euint64 debtToTransfer = FHE.select(isUnder, debtToSeize, FHE.asEuint64(0));
                euint64 colToTransfer = FHE.select(isUnder, colToSeize, FHE.asEuint64(0));

                euint64 poolDebt = _safeFhieldPool(_fhieldDebtPool[asset]);
                _fhieldDebtPool[asset] = FHE.add(poolDebt, debtToTransfer);
                FHE.allowThis(_fhieldDebtPool[asset]);

                euint64 poolCol = _safeFhieldPool(_fhieldColPool[asset]);
                _fhieldColPool[asset] = FHE.add(poolCol, colToTransfer);
                FHE.allowThis(_fhieldColPool[asset]);

                _debtBalances[user][asset] = FHE.sub(userDebt, debtToTransfer);
                FHE.allowThis(_debtBalances[user][asset]);
                FHE.allow(_debtBalances[user][asset], user);

                _collateralBalances[user][asset] = FHE.sub(userCol, colToTransfer);
                FHE.allowThis(_collateralBalances[user][asset]);
                FHE.allow(_collateralBalances[user][asset], user);

                userBorrowIndex[user][asset] = _reserves[asset].variableBorrowIndex;
                userLiquidityIndex[user][asset] = _reserves[asset].liquidityIndex;
            }

            lastSweepBlock[user] = block.number;
        }

        emit SweepCompleted(batchId, users.length);
    }

    function _safeFhieldPool(euint64 raw) internal returns (euint64) {
        if (euint64.unwrap(raw) == 0) return FHELendingMath.encryptedZero();
        return raw;
    }

    function _accrueAllReserves() internal {
        uint256 count = assetConfig.getAssetCount();
        for (uint256 i = 0; i < count; i++) {
            _reserves[assetConfig.assetList(i)].accrueInterest();
        }
    }

    // Stage 3a: Request auction — triggers decrypt of fhield pool aggregates
    function requestAuction(
        address debtAsset,
        address collateralAsset
    ) external nonReentrant returns (bytes32 auctionId) {
        auctionId = keccak256(abi.encodePacked(block.number, msg.sender, _auctionNonce++));

        euint64 encDebt = _safeFhieldPool(_fhieldDebtPool[debtAsset]);
        euint64 encCol = _safeFhieldPool(_fhieldColPool[collateralAsset]);

        FHE.allowThis(encDebt);
        FHE.allowThis(encCol);
        FHE.decrypt(encDebt);
        FHE.decrypt(encCol);

        _fhieldDebtPool[debtAsset] = FHE.asEuint64(0);
        FHE.allowThis(_fhieldDebtPool[debtAsset]);

        _fhieldColPool[collateralAsset] = FHE.asEuint64(0);
        FHE.allowThis(_fhieldColPool[collateralAsset]);

        auctions[auctionId] = Auction({
            debtAsset: debtAsset,
            collateralAsset: collateralAsset,
            encDebt: encDebt,
            encCollateral: encCol,
            totalDebt: 0,
            totalCollateral: 0,
            startBlock: 0,
            started: false,
            settled: false
        });

        emit AuctionRequested(auctionId, debtAsset, collateralAsset);
    }

    // Stage 3b: Start auction after decrypt completes
    function startAuction(bytes32 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.debtAsset != address(0), "Auction not found");
        require(!auction.started, "Already started");

        (uint64 debt, bool debtReady) = FHE.getDecryptResultSafe(auction.encDebt);
        (uint64 col, bool colReady) = FHE.getDecryptResultSafe(auction.encCollateral);
        require(debtReady && colReady, "Decrypt not ready");
        require(debt > 0, "No debt to auction");

        auction.totalDebt = uint256(debt);
        auction.totalCollateral = uint256(col);
        auction.startBlock = block.number;
        auction.started = true;

        totalBorrows[auction.debtAsset] = totalBorrows[auction.debtAsset] > debt
            ? totalBorrows[auction.debtAsset] - debt
            : 0;

        uint256 rfDebt = _getReserveFactorRay(auction.debtAsset);
        _reserves[auction.debtAsset].updateRates(
            totalDeposits[auction.debtAsset], totalBorrows[auction.debtAsset], interestRateStrategy, rfDebt
        );

        emit AuctionStarted(auctionId, auction.totalDebt, auction.totalCollateral);
    }

    // Stage 3c: Liquidator bids at current Dutch Auction price
    function bid(bytes32 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.started && !auction.settled, "Invalid auction");

        uint256 elapsed = block.number - auction.startBlock;
        uint256 currentPriceBPS = _getAuctionPriceBPS(elapsed);
        require(currentPriceBPS >= DUTCH_AUCTION_MIN_PRICE, "Below min price");

        uint256 collateralToReceive = (auction.totalCollateral * currentPriceBPS)
            / CLOSE_FACTOR_PRECISION;

        auction.settled = true;

        IERC20(auction.debtAsset).safeTransferFrom(msg.sender, address(this), auction.totalDebt);
        IERC20(auction.collateralAsset).safeTransfer(msg.sender, collateralToReceive);

        totalDeposits[auction.collateralAsset] = totalDeposits[auction.collateralAsset] > collateralToReceive
            ? totalDeposits[auction.collateralAsset] - collateralToReceive
            : 0;

        uint256 rfCol = _getReserveFactorRay(auction.collateralAsset);
        _reserves[auction.collateralAsset].updateRates(
            totalDeposits[auction.collateralAsset], totalBorrows[auction.collateralAsset], interestRateStrategy, rfCol
        );

        _triggerFhieldRelief(auction.debtAsset, auction.totalDebt);

        emit AuctionSettled(auctionId, msg.sender, auction.totalDebt, collateralToReceive);
    }

    function getAuctionPrice(bytes32 auctionId) external view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        require(auction.started && !auction.settled, "Invalid auction");
        uint256 elapsed = block.number - auction.startBlock;
        return _getAuctionPriceBPS(elapsed);
    }

    function _getAuctionPriceBPS(uint256 elapsed) internal pure returns (uint256) {
        uint256 decay = DUTCH_AUCTION_DECAY_RATE * elapsed;
        if (decay >= DUTCH_AUCTION_START_PRICE) return DUTCH_AUCTION_MIN_PRICE;
        uint256 price = DUTCH_AUCTION_START_PRICE - decay;
        return price < DUTCH_AUCTION_MIN_PRICE ? DUTCH_AUCTION_MIN_PRICE : price;
    }

    function getFhieldPoolBalance(address asset) external view returns (euint64 debt, euint64 collateral) {
        return (_fhieldDebtPool[asset], _fhieldColPool[asset]);
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

    function setFhieldBuffer(address _fhieldBuffer) external onlyOwner {
        fhieldBuffer = IFhieldBuffer(_fhieldBuffer);
    }

    function setInterestRateStrategy(address _strategy) external onlyOwner {
        interestRateStrategy = IInterestRateStrategy(_strategy);
    }

    // ─── INTERNAL: fhield Relief ─────────────────────────────────────────

    function _triggerFhieldRelief(address asset, uint256 amount) internal {
        uint256 reliefShare = fhieldBuffer.getReliefShare(asset, amount);
        if (reliefShare > 0) {
            fhieldBuffer.onLiquidation(asset, reliefShare);
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

    function _getReserveFactorRay(address asset) internal view returns (uint256) {
        uint256 rfBPS = assetConfig.getAsset(asset).reserveFactor;
        return (rfBPS * RayMath.RAY) / assetConfig.PERCENTAGE_PRECISION();
    }
}
