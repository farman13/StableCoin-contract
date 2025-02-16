// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * Collateral : Exogenous (ETH & BTC)
 * Minting : Algorithmic
 * Relatvie Stability : Pegged to USD
 */

/* This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the
   DSCEngine smart contract.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "FTK") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount >= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}
