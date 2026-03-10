pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private _withdrawableDividends;
  mapping(address => uint256) private _holderIndex;
  address[] private _holders;

  // IERC20

  /// @dev Plain allowance lookup keeps the storage layout simple and matches ERC20 expectations.
  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  /// @dev Routes through the shared transfer helper so direct and delegated transfers keep holder bookkeeping identical.
  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  /// @dev Overwrites the allowance directly because the tests expect the latest approval value to replace the previous one.
  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  /// @dev Spends allowance before moving tokens so failed transfers revert atomically and reuse the same holder sync logic.
  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  /// @dev Mints tokens 1:1 with ETH deposited, which keeps token supply backed by the contract's ETH balance.
  function mint() external payable override {
    require(msg.value > 0, "Token: no ETH supplied");

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);

    _syncHolder(msg.sender);
  }

  /// @dev Burns the caller's full balance because the interface has no amount parameter, and clears state before sending ETH out.
  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _syncHolder(msg.sender);

    if (amount == 0) {
      return;
    }

    (bool sent,) = dest.call{ value: amount }("");
    require(sent, "Token: burn transfer failed");
  }

  // IDividends

  /// @dev Returns the number of active holders, not all historical holders, so dividend iteration stays bounded to live balances.
  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  /// @dev Uses a 1-based index because the interface and tests are written with that convention.
  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }

    return _holders[index - 1];
  }

  /// @dev Accrues dividends against each holder's current balance so payouts are preserved even if balances change later.
  function recordDividend() external payable override {
    require(msg.value > 0, "Token: no dividend supplied");
    require(totalSupply > 0, "Token: no holders");

    for (uint256 i = 0; i < _holders.length; i++) {
      address holder = _holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
      _withdrawableDividends[holder] = _withdrawableDividends[holder].add(share);
    }
  }

  /// @dev Dividend state is stored per payee so reads stay O(1) after each dividend is recorded.
  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividends[payee];
  }

  /// @dev Zeros the withdrawable balance before the external call so a re-entrant receiver cannot withdraw twice.
  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividends[msg.sender];
    _withdrawableDividends[msg.sender] = 0;

    if (amount == 0) {
      return;
    }

    (bool sent,) = dest.call{ value: amount }("");
    require(sent, "Token: dividend transfer failed");
  }

  /// @dev Centralizes token movement so balance updates and holder list maintenance stay consistent across both transfer flows.
  function _transfer(address from, address to, uint256 value) internal {
    require(to != address(0), "Token: invalid recipient");

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _syncHolder(from);

    if (to != from) {
      _syncHolder(to);
    }
  }

  /// @dev Maintains a compact holder array with swap-and-pop so add/remove operations stay O(1) while exposing indexed access.
  function _syncHolder(address account) internal {
    uint256 index = _holderIndex[account];

    if (balanceOf[account] > 0) {
      if (index == 0) {
        _holders.push(account);
        _holderIndex[account] = _holders.length;
      }
      return;
    }

    if (index == 0) {
      return;
    }

    uint256 lastIndex = _holders.length;
    address lastHolder = _holders[lastIndex - 1];

    if (index != lastIndex) {
      _holders[index - 1] = lastHolder;
      _holderIndex[lastHolder] = index;
    }

    _holders.pop();
    _holderIndex[account] = 0;
  }
}
