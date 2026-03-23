// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FHERC20Wrapper is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlying;
    string public name;
    string public symbol;

    mapping(address => euint64) private _confidentialBalances;
    mapping(address => uint16) private _indicatedBalances;
    mapping(address => mapping(address => bool)) private _operators;

    uint256 public totalWrapped;

    struct Claim {
        address to;
        euint64 amount;
        bool claimed;
    }

    mapping(bytes32 => Claim) private _claims;
    mapping(address => bytes32[]) private _userClaims;
    uint256 private _claimNonce;

    event Wrapped(address indexed account, uint64 amount);
    event UnwrapRequested(address indexed account, bytes32 claimId);
    event UnwrapClaimed(address indexed account, bytes32 claimId, uint64 amount);
    event ConfidentialTransfer(address indexed from, address indexed to);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    constructor(address _underlying, string memory _name, string memory _symbol) {
        underlying = IERC20(_underlying);
        name = _name;
        symbol = _symbol;
    }

    function wrap(uint64 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        underlying.safeTransferFrom(msg.sender, address(this), amount);

        euint64 encAmount = FHE.asEuint64(amount);
        euint64 currentBalance = _confidentialBalances[msg.sender];

        if (euint64.unwrap(currentBalance) == 0) {
            _confidentialBalances[msg.sender] = encAmount;
            _indicatedBalances[msg.sender] = 5001;
        } else {
            _confidentialBalances[msg.sender] = FHE.add(currentBalance, encAmount);
            _indicatedBalances[msg.sender] += _indicatorTick();
        }

        FHE.allowThis(_confidentialBalances[msg.sender]);
        FHE.allow(_confidentialBalances[msg.sender], msg.sender);

        totalWrapped += amount;
        emit Wrapped(msg.sender, amount);
    }

    function unwrap(InEuint64 memory amount) external nonReentrant {
        euint64 encAmount = FHE.asEuint64(amount);
        euint64 balance = _confidentialBalances[msg.sender];

        ebool sufficient = FHE.gte(balance, encAmount);
        euint64 actualAmount = FHE.select(sufficient, encAmount, FHE.asEuint64(0));

        _confidentialBalances[msg.sender] = FHE.sub(balance, actualAmount);
        FHE.allowThis(_confidentialBalances[msg.sender]);
        FHE.allow(_confidentialBalances[msg.sender], msg.sender);

        bytes32 claimId = keccak256(abi.encodePacked(msg.sender, _claimNonce++));
        _claims[claimId] = Claim({to: msg.sender, amount: actualAmount, claimed: false});
        _userClaims[msg.sender].push(claimId);

        FHE.decrypt(actualAmount);

        if (_indicatedBalances[msg.sender] > _indicatorTick()) {
            _indicatedBalances[msg.sender] -= _indicatorTick();
        }

        emit UnwrapRequested(msg.sender, claimId);
    }

    function claimUnwrapped(bytes32 claimId) external nonReentrant {
        Claim storage claim = _claims[claimId];
        require(claim.to == msg.sender, "Not claim owner");
        require(!claim.claimed, "Already claimed");

        (uint64 decrypted, bool ready) = FHE.getDecryptResultSafe(claim.amount);
        require(ready, "Decrypt not ready");
        claim.claimed = true;

        uint64 amount = decrypted;
        require(amount > 0, "Nothing to claim");

        totalWrapped -= amount;
        underlying.safeTransfer(msg.sender, amount);

        emit UnwrapClaimed(msg.sender, claimId, amount);
    }

    function confidentialTransfer(address to, InEuint64 memory amount) external nonReentrant {
        _transfer(msg.sender, to, FHE.asEuint64(amount));
    }

    function confidentialTransferFrom(
        address from,
        address to,
        InEuint64 memory amount
    ) external nonReentrant {
        require(_operators[from][msg.sender], "Not operator");
        _transfer(from, to, FHE.asEuint64(amount));
    }

    function setOperator(address operator, bool approved) external {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
    }

    function isOperator(address owner, address operator) external view returns (bool) {
        return _operators[owner][operator];
    }

    function confidentialBalanceOf(address account) external view returns (euint64) {
        return _confidentialBalances[account];
    }

    function indicatedBalanceOf(address account) external view returns (uint16) {
        return _indicatedBalances[account];
    }

    function getUserClaims(address user) external view returns (bytes32[] memory) {
        return _userClaims[user];
    }

    function _transfer(address from, address to, euint64 encAmount) internal {
        euint64 senderBalance = _confidentialBalances[from];
        ebool sufficient = FHE.gte(senderBalance, encAmount);
        euint64 actualAmount = FHE.select(sufficient, encAmount, FHE.asEuint64(0));

        _confidentialBalances[from] = FHE.sub(senderBalance, actualAmount);
        FHE.allowThis(_confidentialBalances[from]);
        FHE.allow(_confidentialBalances[from], from);

        euint64 recipientBalance = _confidentialBalances[to];
        if (euint64.unwrap(recipientBalance) == 0) {
            _confidentialBalances[to] = actualAmount;
            _indicatedBalances[to] = 5001;
        } else {
            _confidentialBalances[to] = FHE.add(recipientBalance, actualAmount);
        }
        FHE.allowThis(_confidentialBalances[to]);
        FHE.allow(_confidentialBalances[to], to);

        if (_indicatedBalances[from] > _indicatorTick()) {
            _indicatedBalances[from] -= _indicatorTick();
        }
        if (_indicatedBalances[to] != 0) {
            _indicatedBalances[to] += _indicatorTick();
        }

        emit ConfidentialTransfer(from, to);
    }

    function _indicatorTick() internal view returns (uint16) {
        if (totalWrapped == 0) return 1;
        uint256 tick = totalWrapped / type(uint16).max;
        return tick == 0 ? 1 : uint16(tick);
    }
}
