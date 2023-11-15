// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployYeloEngine} from "../../script/DeoloyYeloEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {YeloStableCoin} from "../../src/YeloStableCoin.sol";
import {YOEngine} from "../../src/YOEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {MockFailedMintYelo} from "../Mocks/MockFailedMintYelo.sol";
import {MockFailedTransfer} from "../Mocks/MockFailedTransfer.sol";
import {MockFailedTransferFrom} from "../Mocks/MockFailedTransferFrom.sol";

contract YOEngineTest is Test {
    event YOEngine__UserDepositActive(address indexed user, address indexed collateralAdd, uint256 indexed amount);

    YeloStableCoin yelo;
    YOEngine engine;
    HelperConfig helperConfig;
    DeployYeloEngine deployer;

    address weth;
    address wbtc;
    address ethPriceFeed;
    address btcPriceFeed;
    uint256 deployKey;

    address USER = makeAddr("USER");
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant DEPOSIT_COLLAREAL = 10 ether;
    uint256 public constant AMOUNT_TOMINT = 0.1 ether;
    uint256 amountToMint;

    function setUp() public {
        deployer = new DeployYeloEngine();
        (yelo, engine, helperConfig) = deployer.run();

        (weth, wbtc, ethPriceFeed, btcPriceFeed, deployKey) = helperConfig.activeHelperConfig();

        if (block.chainid == 31337) {
            vm.deal(USER, STARTING_BALANCE);
        }

        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_BALANCE);
    }

    function testGetInUSD() public view {
        uint256 startBanlance = 5 ether;
        uint256 expectUsd = 10000e18;
        uint256 actualUsd = engine.getInUsd(weth, startBanlance);
        console.log(actualUsd);
        assert(actualUsd == expectUsd);
    }
    /////////////////////////////////////////////
    ///////////// constructor            ////////
    /////////////////////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAdd;

    function testReverLengthNotSameWhileIsContractsDeploy() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeedAdd.push(ethPriceFeed);
        vm.expectRevert(YOEngine.YOEngine__LengthIsNotEqual.selector);
        engine = new YOEngine(tokenAddresses,priceFeedAdd,address(yelo));
    }

    function testAddressAccordinglyTrue() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeedAdd.push(ethPriceFeed);
        priceFeedAdd.push(btcPriceFeed);

        engine = new YOEngine(tokenAddresses,priceFeedAdd,address(yelo));

        address ethtokenAddresses = engine.getCollateralAddToPriceFeed(address(weth));
        address ethAccordinglyPriceFeed = priceFeedAdd[0];

        address btctokenAddresses = engine.getCollateralAddToPriceFeed(address(wbtc));
        address btcAccordinglyPriceFeed = priceFeedAdd[1];
        assert(ethtokenAddresses == ethAccordinglyPriceFeed);
        assert(btctokenAddresses == btcAccordinglyPriceFeed);
    }

    /////////////////////////////////////////////
    ///////////// depositCollateral      ////////
    /////////////////////////////////////////////

    function testdepositCollateralFilledOutThatIfNotMoreThanZeroRevert() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), DEPOSIT_COLLAREAL);
        vm.expectRevert(YOEngine.YOEngine__NotMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testdepositCollateralFilledOutThatIfNotAllowedAddRevert() public {
        ERC20Mock random = new ERC20Mock();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), DEPOSIT_COLLAREAL);

        // 使用具体的错误选择器和触发错误的地址
        bytes memory expectedRevertData =
            abi.encodeWithSelector(YOEngine.YOEngine__isAllowAddress.selector, address(random));
        vm.expectRevert(expectedRevertData);

        engine.depositCollateral(address(random), DEPOSIT_COLLAREAL);
        vm.stopPrank();
    }

    function testEventAtWork() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), DEPOSIT_COLLAREAL);
        vm.expectEmit(true, true, true, false, address(engine));
        emit YOEngine__UserDepositActive(USER, address(weth), DEPOSIT_COLLAREAL);
        engine.depositCollateral(weth, DEPOSIT_COLLAREAL);
        vm.stopPrank();
    }

    function testIfTransferisFailedRevert() public {
        address owner = msg.sender; //通常在测试合约里这里是 默认提供的测试账户

        vm.startPrank(owner);
        MockFailedTransferFrom mockFailedYelo = new MockFailedTransferFrom();
        tokenAddresses = [address(mockFailedYelo)];
        priceFeedAdd = [ethPriceFeed];

        YOEngine mockEngine = new YOEngine(tokenAddresses,priceFeedAdd,address(mockFailedYelo));
        mockFailedYelo.mint(USER, STARTING_BALANCE);
        mockFailedYelo.approve(address(mockEngine), DEPOSIT_COLLAREAL);
        mockFailedYelo.transferOwnership(address(mockEngine));
        vm.stopPrank();

        vm.startPrank(USER);
        vm.expectRevert(YOEngine.YOEngine__transferFailed.selector);
        mockEngine.depositCollateral(address(mockFailedYelo), DEPOSIT_COLLAREAL);
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), DEPOSIT_COLLAREAL);
        engine.depositCollateral(address(weth), DEPOSIT_COLLAREAL);
    }
    /////////////////////////////////////////////
    /////////////   mintYelo             ////////
    /////////////////////////////////////////////

    function testMintYeloNotMoreThanZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), DEPOSIT_COLLAREAL);
        vm.expectRevert(YOEngine.YOEngine__NotMoreThanZero.selector);
        engine.mintYelo(0);
        vm.stopPrank();
    }

    function testMintYeloIsRevertWhileTransferFailed() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.startPrank(owner);
        MockFailedMintYelo mockYelo = new MockFailedMintYelo();
        tokenAddresses = [weth];
        priceFeedAdd = [ethPriceFeed];

        YOEngine mockEngine = new YOEngine(
            tokenAddresses,
            priceFeedAdd,
            address(mockYelo)
        );
        mockYelo.transferOwnership(address(mockEngine));
        vm.stopPrank();
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockEngine), DEPOSIT_COLLAREAL);

        vm.expectRevert(YOEngine.YOEngine__mintFailed.selector);
        mockEngine.depositCollateralAndMintYelo(address(weth), DEPOSIT_COLLAREAL, AMOUNT_TOMINT);
        vm.stopPrank();
    }
}
