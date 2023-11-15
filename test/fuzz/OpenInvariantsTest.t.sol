    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// // Think about invariants

// // 1.抵押品的总供应量应该始终小于抵押品总价值

// // 2.getter函数永远不应该恢复

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";

// import {DeployYeloEngine} from "../../script/DeoloyYeloEngine.s.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {YeloStableCoin} from "../../src/YeloStableCoin.sol";
// import {YOEngine} from "../../src/YOEngine.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployYeloEngine deployer;
//     HelperConfig config;
//     YeloStableCoin yelo;
//     YOEngine engine;

//     address weth;
//     address wbtc;
//     address ethPriceFeed;
//     address btcPriceFeed;
//     uint256 deployKey;

//     function setUp() external {
//         deployer = new DeployYeloEngine();
//         (yelo, engine, config) = deployer.run();

//         (weth, wbtc, ethPriceFeed, btcPriceFeed, deployKey) = config.activeHelperConfig();

//         targetContract(address(engine));
//     }

//     function invariant_TotalSupplyNotMoreThanTotalColleral() public view {
//         uint256 totalYeloSupply = yelo.totalSupply();
//         uint256 wethColleralAmount = IERC20(weth).balanceOf(address(engine));

//         uint256 wbtcColleralAmount = IERC20(wbtc).balanceOf(address(engine));

//         uint256 totalColleralUSD =
//             engine.getInUsd(address(weth), wethColleralAmount) + engine.getInUsd(address(wbtc), wbtcColleralAmount);

//         assert(totalColleralUSD >= totalYeloSupply);
//     }
// }
