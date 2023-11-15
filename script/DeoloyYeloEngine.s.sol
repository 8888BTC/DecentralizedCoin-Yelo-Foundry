// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {YeloStableCoin} from "../src/YeloStableCoin.sol";
import {YOEngine} from "../src/YOEngine.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployYeloEngine is Script {
    address[] public colleralAddress;
    address[] public priceFeedAddress;

    function run() external returns (YeloStableCoin, YOEngine, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        (address weth, address wbtc, address ethPriceFeed, address btcPriceFeed, uint256 deployKey) =
            helper.activeHelperConfig();
        colleralAddress = [weth, wbtc];
        priceFeedAddress = [ethPriceFeed, btcPriceFeed];

        vm.startBroadcast(deployKey);
        YeloStableCoin yelo = new YeloStableCoin();
        YOEngine engine = new YOEngine(colleralAddress, priceFeedAddress,address(yelo));

        yelo.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (yelo, engine, helper);
    }
}
