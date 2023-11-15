// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/Mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    HelperConfigInternal public activeHelperConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    struct HelperConfigInternal {
        address weth;
        address wbtc;
        address ethPriceFeed;
        address btcPriceFeed;
        uint256 deployKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeHelperConfig = getSepoliaNetWork();
        } else {
            activeHelperConfig = getOrCreateAnvilNetWork();
        }
    }

    function getSepoliaNetWork() public view returns (HelperConfigInternal memory) {
        return HelperConfigInternal({
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            ethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            btcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetWork() public returns (HelperConfigInternal memory) {
        if (activeHelperConfig.ethPriceFeed != address(0)) {
            return activeHelperConfig;
        }
        vm.startBroadcast();
        ERC20Mock weth = new ERC20Mock();
        ERC20Mock wbtc = new ERC20Mock();

        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
        vm.stopBroadcast();

        return HelperConfigInternal({
            weth: address(weth),
            wbtc: address(wbtc),
            ethPriceFeed: address(ethPriceFeed),
            btcPriceFeed: address(btcPriceFeed),
            deployKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }
}
