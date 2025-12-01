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

  mapping (address => mapping (address => uint256)) public _allowances;
  
  // Dividend tracking
  address[] public tokenHolders;
  mapping (address => bool) public isTokenHolder;
  mapping (address => uint256) public withdrawableDividends;

  // Events
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "Transfer to zero address");
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    
    _addTokenHolder(to);
    
    emit Transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(to != address(0), "Transfer to zero address");
    require(balanceOf[from] >= value, "Insufficient balance");
    require(_allowances[from][msg.sender] >= value, "Insufficient allowance");
    
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    
    _addTokenHolder(to);
    
    emit Transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must send ETH to mint");
    
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    
    _addTokenHolder(msg.sender);
    
    emit Transfer(address(0), msg.sender, msg.value);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    
    emit Transfer(msg.sender, address(0), amount);
    
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    uint256 count = 0;
    for (uint256 i = 0; i < tokenHolders.length; i++) {
      if (balanceOf[tokenHolders[i]] > 0) {
        count++;
      }
    }
    return count;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0, "Index must be greater than 0");
    
    uint256 count = 0;
    for (uint256 i = 0; i < tokenHolders.length; i++) {
      if (balanceOf[tokenHolders[i]] > 0) {
        count++;
        if (count == index) {
          return tokenHolders[i];
        }
      }
    }
    
    revert("Index out of bounds");
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ETH for dividend");
    require(totalSupply > 0, "No tokens in circulation");
    
    for (uint256 i = 0; i < tokenHolders.length; i++) {
      address holder = tokenHolders[i];
      uint256 holderBalance = balanceOf[holder];
      
      if (holderBalance > 0) {
        uint256 dividend = msg.value.mul(holderBalance).div(totalSupply);
        withdrawableDividends[holder] = withdrawableDividends[holder].add(dividend);
      }
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "No dividends to withdraw");
    
    withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }

  // Internal helper function
  function _addTokenHolder(address holder) internal {
    if (!isTokenHolder[holder] && holder != address(0)) {
      tokenHolders.push(holder);
      isTokenHolder[holder] = true;
    }
  }
}