let _config = null;
let _provider = null;
let _signer = null;
let _contracts = {};
let _rawProvider = null;

const UI_TO_CONTRACT_SYMBOL = { ETH: 'WETH', USDT: 'USDC', WBTC: 'WETH' };

function resolveSymbol(uiSymbol) {
  return UI_TO_CONTRACT_SYMBOL[uiSymbol] || uiSymbol;
}

async function loadConfig() {
  if (_config) return _config;
  const res = await fetch('/api/config');
  _config = await res.json();
  return _config;
}

function setProvider(provider) {
  _rawProvider = provider;
  _provider = null;
  _signer = null;
  _contracts = {};
}

function getProvider() {
  const raw = _rawProvider || window.ethereum;
  if (!_provider && raw) {
    _provider = new ethers.BrowserProvider(raw);
  }
  return _provider;
}

async function getSigner() {
  if (!_signer) {
    const provider = getProvider();
    if (!provider) return null;
    _signer = await provider.getSigner();
  }
  return _signer;
}

function resetSigner() {
  _signer = null;
  _provider = null;
  _contracts = {};
}

async function getContract(name) {
  if (_contracts[name]) return _contracts[name];
  const config = await loadConfig();
  const signer = await getSigner();
  if (!signer || !config.isConfigured) return null;

  const abiMap = {
    pool: { abi: config.abis.pool, addr: config.addresses.pool },
    assetConfig: { abi: config.abis.assetConfig, addr: config.addresses.assetConfig },
    oracle: { abi: config.abis.oracle, addr: config.addresses.oracle },
  };

  const entry = abiMap[name];
  if (!entry || !entry.addr) return null;

  _contracts[name] = new ethers.Contract(entry.addr, entry.abi, signer);
  return _contracts[name];
}

async function getERC20(address) {
  const config = await loadConfig();
  const signer = await getSigner();
  if (!signer) return null;
  return new ethers.Contract(address, config.abis.erc20, signer);
}

async function getWalletBalances(account) {
  const config = await loadConfig();
  if (!config.isConfigured) return {};

  const signer = await getSigner();
  if (!signer) return {};

  const balances = {};

  for (const [symbol, addr] of Object.entries(config.addresses.assets)) {
    if (!addr) continue;
    try {
      const token = new ethers.Contract(addr, config.abis.erc20, signer);
      const [bal, dec] = await Promise.all([
        token.balanceOf(account),
        token.decimals(),
      ]);
      balances[symbol] = {
        raw: bal.toString(),
        formatted: ethers.formatUnits(bal, dec),
        decimals: Number(dec),
      };
    } catch {
      balances[symbol] = { raw: '0', formatted: '0.0', decimals: 18 };
    }
  }

  for (const [uiKey, contractKey] of Object.entries(UI_TO_CONTRACT_SYMBOL)) {
    if (balances[contractKey] && !balances[uiKey]) {
      balances[uiKey] = balances[contractKey];
    }
  }

  return balances;
}

async function deposit(assetSymbol, amount) {
  const config = await loadConfig();
  const assetAddr = config.addresses.assets[resolveSymbol(assetSymbol)];
  if (!assetAddr) throw new Error(`Unknown asset: ${assetSymbol}`);

  const signer = await getSigner();
  const pool = await getContract('pool');
  const token = await getERC20(assetAddr);

  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const approveTx = await token.approve(config.addresses.pool, rawAmount);
  await approveTx.wait();

  const depositTx = await pool.deposit(assetAddr, rawAmount);
  return depositTx.wait();
}

async function repay(assetSymbol, amount) {
  const config = await loadConfig();
  const assetAddr = config.addresses.assets[resolveSymbol(assetSymbol)];
  if (!assetAddr) throw new Error(`Unknown asset: ${assetSymbol}`);

  const signer = await getSigner();
  const pool = await getContract('pool');
  const token = await getERC20(assetAddr);

  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const approveTx = await token.approve(config.addresses.pool, rawAmount);
  await approveTx.wait();

  const repayTx = await pool.repay(assetAddr, rawAmount);
  return repayTx.wait();
}

async function wrap(assetSymbol, amount) {
  const config = await loadConfig();
  const resolved = resolveSymbol(assetSymbol);
  const assetAddr = config.addresses.assets[resolved];
  const wrapperAddr = config.addresses.wrappers[resolved];
  if (!assetAddr || !wrapperAddr) throw new Error(`Unknown asset: ${assetSymbol}`);

  const signer = await getSigner();
  const token = await getERC20(assetAddr);

  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const approveTx = await token.approve(wrapperAddr, rawAmount);
  await approveTx.wait();

  const wrapper = new ethers.Contract(wrapperAddr, [
    'function wrap(uint64 amount) external',
  ], signer);
  const wrapTx = await wrapper.wrap(rawAmount);
  return wrapTx.wait();
}

async function getMarketData() {
  const res = await fetch('/api/markets');
  return res.json();
}

async function borrow(assetSymbol, amount) {
  const config = await loadConfig();
  const assetAddr = config.addresses.assets[resolveSymbol(assetSymbol)];
  if (!assetAddr) throw new Error(`Unknown asset: ${assetSymbol}`);

  const pool = await getContract('pool');
  const token = await getERC20(assetAddr);

  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const borrowTx = await pool.borrow(assetAddr, rawAmount);
  return borrowTx.wait();
}

async function withdraw(assetSymbol, amount) {
  const config = await loadConfig();
  const assetAddr = config.addresses.assets[resolveSymbol(assetSymbol)];
  if (!assetAddr) throw new Error(`Unknown asset: ${assetSymbol}`);

  const pool = await getContract('pool');
  const token = await getERC20(assetAddr);

  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const withdrawTx = await pool.withdraw(assetAddr, rawAmount);
  return withdrawTx.wait();
}

async function unwrap(assetSymbol, amount) {
  const config = await loadConfig();
  const resolved = resolveSymbol(assetSymbol);
  const wrapperAddr = config.addresses.wrappers[resolved];
  if (!wrapperAddr) throw new Error(`Unknown wrapper: ${assetSymbol}`);

  const signer = await getSigner();
  const wrapper = new ethers.Contract(wrapperAddr, [
    'function unwrap(uint64 amount) external',
  ], signer);

  const token = await getERC20(config.addresses.assets[resolved]);
  const decimals = await token.decimals();
  const rawAmount = ethers.parseUnits(amount, decimals);

  const unwrapTx = await wrapper.unwrap(rawAmount);
  return unwrapTx.wait();
}

export const ContractInteraction = {
  loadConfig,
  setProvider,
  getProvider,
  getSigner,
  resetSigner,
  getContract,
  getERC20,
  getWalletBalances,
  deposit,
  borrow,
  repay,
  withdraw,
  wrap,
  unwrap,
  getMarketData,
};
