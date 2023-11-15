// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

import {YeloStableCoin} from "../../src/YeloStableCoin.sol";
import {YOEngine} from "../../src/YOEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    YOEngine public engine;
    YeloStableCoin public yelo;

    ERC20Mock weth = new ERC20Mock();
    ERC20Mock wbtc = new ERC20Mock();
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    uint256 public timesMintIsCalled;
    address[] public users;

    constructor(YOEngine _engine, YeloStableCoin _yelo) {
        engine = _engine;
        yelo = _yelo;

        address[] memory collateralTokens = engine.getCollateralAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function mintYelo(uint256 amount, uint256 addressSeed) public {
        if (users.length == 0) {
            return;
        }
        address sender = users[addressSeed % users.length];
        (uint256 totallyYeloValued, uint256 totallyCollateralValued) = engine.getUserInfo(sender);

        int256 maxYeloToMinted = (int256(totallyCollateralValued) / 2) - int256(totallyYeloValued);

        if (maxYeloToMinted < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxYeloToMinted));

        if (amount == 0) {
            return;
        }

        vm.startPrank(sender);
        engine.mintYelo(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);

        engine.depositCollateral(address(collateral), amountCollateral);
        users.push(msg.sender);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        if (collateralSeed == 0) {
            return;
        }
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        engine.redeemCollateral(address(collateral), amountCollateral);
    }
}
