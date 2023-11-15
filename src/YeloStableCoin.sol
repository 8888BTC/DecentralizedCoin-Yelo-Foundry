// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract YeloStableCoin is ERC20Burnable, Ownable {
    error YeloStableCoin__NotGoAheadBurn();
    error YeloStableCoin__NotExistAddress();
    error YeloStableCoin__PutInMoreThanZero();

    constructor() ERC20("Yelo", "yo") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance < amount) {
            revert YeloStableCoin__NotGoAheadBurn();
        }
        super.burn(amount);
    }

    function mintYelo(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert YeloStableCoin__NotExistAddress();
        }
        if (amount <= 0) {
            revert YeloStableCoin__PutInMoreThanZero();
        }
        _mint(to, amount);

        return true;
    }
}
