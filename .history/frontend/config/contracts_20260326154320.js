require('dotenv').config();

const POOL_ABI = [
  'function totalDeposits(address) view returns (uint256)',
  'function totalBorrows(address) view returns (uint256)',
  'function getUtilizationRate(address) view returns (uint256)',
  'function getBorrowRate(address) view returns (uint256)',
  'function getSupplyRate(address) view returns (uint256)',
  'function getReserveData(address) view returns (uint256 liquidityIndex, uint256 variableBorrowIndex, uint256 currentLiquidityRate, uint256 currentVariableBorrowRate, uint40 lastUpdateTimestamp)',
  'function getEncryptedCollateral(address, address) view returns (uint128)',
  'function getEncryptedDebt(address, address) view returns (uint128)',
  'function assetConfig() view returns (address)',
  'function oracle() view returns (address)',
  'function deposit(address asset, uint64 amount) external',
  'function borrow(address asset, tuple(uint256 ctHash, uint8 securityZone, uint8 utype, bytes signature) amount) external',
  'function repay(address asset, uint64 amount) external',
  'function withdraw(address asset, tuple(uint256 ctHash, uint8 securityZone, uint8 utype, bytes signature) amount) external',
  'function claimBorrow(address asset) external',
  'function claimWithdraw(address asset) external',
  'event Deposit(address indexed user, address indexed asset, uint256 amount)',
  'event Borrow(address indexed user, address indexed asset)',
  'event BorrowClaimed(address indexed user, address indexed asset, uint64 amount)',
  'event Repay(address indexed user, address indexed asset, uint256 amount)',
  'event Withdraw(address indexed user, address indexed asset)',
  'event WithdrawClaimed(address indexed user, address indexed asset, uint64 amount)',
];

const ASSET_CONFIG_ABI = [
  'function getAsset(address) view returns (tuple(address underlying, address wrapper, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 reserveFactor, uint8 decimals, bool isActive))',
  'function getAssetCount() view returns (uint256)',
  'function assetList(uint256) view returns (address)',
  'function isSupported(address) view returns (bool)',
  'function PERCENTAGE_PRECISION() view returns (uint256)',
];

const ORACLE_ABI = [
  'function getPrice(address) view returns (uint256)',
];

const ERC20_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)',
  'function allowance(address, address) view returns (uint256)',
  'function approve(address spender, uint256 amount) external returns (bool)',
];

const FHERC20_ABI = [
  'function totalWrapped() view returns (uint256)',
  'function indicatedBalanceOf(address) view returns (uint16)',
  'function confidentialBalanceOf(address) view returns (uint128)',
  'function wrap(uint64 amount) external',
  'function unwrap(tuple(uint256 ctHash, uint8 securityZone, uint8 utype, bytes signature) amount) external',
  'function claimUnwrapped(bytes32 claimId) external',
  'function confidentialTransfer(address to, tuple(uint256 ctHash, uint8 securityZone, uint8 utype, bytes signature) amount) external',
  'function getUserClaims(address user) view returns (bytes32[])',
  'event UnwrapRequested(address indexed account, bytes32 claimId)',
  'event UnwrapClaimed(address indexed account, bytes32 claimId, uint64 amount)',
  'event Wrapped(address indexed account, uint64 amount)',
];

const addresses = {
  pool: process.env.POOL_ADDRESS || '',
  assetConfig: process.env.ASSET_CONFIG_ADDRESS || '',
  oracle: process.env.ORACLE_ADDRESS || '',
  assets: {
    USDC: process.env.USDC_ADDRESS || '',
    WETH: process.env.WETH_ADDRESS || '',
  },
  wrappers: {
    USDC: process.env.FHE_USDC_ADDRESS || '',
    WETH: process.env.FHE_WETH_ADDRESS || '',
  },
};

const rpcUrl = process.env.RPC_URL || '';
const chainId = parseInt(process.env.CHAIN_ID || '421614', 10);

function isConfigured() {
  return !!(rpcUrl && addresses.pool && addresses.assetConfig && addresses.oracle);
}

module.exports = {
  POOL_ABI,
  ASSET_CONFIG_ABI,
  ORACLE_ABI,
  ERC20_ABI,
  FHERC20_ABI,
  addresses,
  rpcUrl,
  chainId,
  isConfigured,
};
