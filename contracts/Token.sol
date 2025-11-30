// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Token {
    string public constant name = "Token";
    string public constant symbol = "TKN";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public owed;

    mapping(address => bool) private known;
    address[] private holders;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed user, uint256 amount);
    event Burn(address indexed user, uint256 amount);
    event DividendRecorded(uint256 amount);
    event DividendWithdrawn(address indexed user, uint256 amount);

    function _addHolder(address user) internal {
        if (!known[user]) {
            known[user] = true;
            holders.push(user);
        }
    }

    function _removeHolder(address user) internal {
        if (known[user] && balanceOf[user] == 0) {
            known[user] = false;
            uint256 len = holders.length;
            for (uint256 i = 0; i < len; i++) {
                if (holders[i] == user) {
                    holders[i] = holders[len - 1];
                    holders.pop();
                    break;
                }
            }
        }
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        _addHolder(to);
        _removeHolder(msg.sender);

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function mint() external payable {
        require(msg.value > 0, "no eth");

        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;

        _addHolder(msg.sender);

        emit Mint(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "insufficient");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        _removeHolder(msg.sender);

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "eth fail");

        emit Burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    function recordDividend() external payable {
        require(msg.value > 0, "empty");

        uint256 n = holders.length;
        if (n == 0) return;

        for (uint256 i = 0; i < n; i++) {
            address user = holders[i];
            uint256 bal = balanceOf[user];
            if (bal == 0) continue;

            uint256 share = (msg.value * bal) / totalSupply;
            owed[user] += share;
        }

        emit DividendRecorded(msg.value);
    }

    function withdrawDividends() external {
        uint256 amt = owed[msg.sender];
        require(amt > 0, "none");

        owed[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "fail");

        emit DividendWithdrawn(msg.sender, amt);
    }

    function holdersLength() external view returns (uint256) {
        return holders.length;
    }
}
