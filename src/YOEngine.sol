// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {YeloStableCoin} from "./YeloStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./Libraries/OracleLib.sol";

/*
 * @title YOEngine
 * @author 8ronne Yao
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.//该系统被设计为尽可能最小误差，并让代币始终保持 1 个代币 == $1 挂钩。
 * This is a stablecoin with the properties: 这是一种稳定币具有以下特性：：
 * - Exogenously Collateralized 外生抵押品
 * - Dollar Pegged 锚定美元
 * - Algorithmically Stable 算法稳定
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC. //类似于DAI Coin
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral. // 该合约去中心化稳定币的核心 处理所有逻辑 用于铸造和赎回 DSC，以及存入和提取抵押品。
 * @notice This contract is based on the MakerDAO DSS system //该合约基于MakerDao Dss system
 */

contract YOEngine is ReentrancyGuard {
    /////////////////////////////////
    ////         Error           ////
    /////////////////////////////////
    error YOEngine__NotMoreThanZero();
    error YOEngine__isAllowAddress(address tokenAdd);
    error YOEngine__transferFailed();
    error YOEngine__LengthIsNotEqual();
    error YOEngine__HealthFactorIsNotEnought(uint256 healthNumber);
    error YeloStableCoin__isnotLiquidatWithHealthNice();
    error YOEngine__HealthIsNotRevertAtWork();
    error YOEngine__mintFailed();
    ////////////////////////////////
    ////        Type            ////
    ////////////////////////////////

    using OracleLib for AggregatorV3Interface;

    ////////////////////////////////
    ////    State Variables     ////
    ////////////////////////////////
    uint256 private constant CHAINLINK_PRICE_FEED_SIDENOTE = 1e10;
    uint256 private constant CALCULATING_SIDENOTE = 1e18;
    uint256 private constant LIQUITE_SHRESHORLD = 5e17;
    uint256 private constant LIQUITE_HEALTHFACTOR_NUMBER = 1;
    uint256 private constant LIQUITE_BOUNS = 1e17;
    mapping(address collateralAdd => address priceFeed) private s_CollateralAddToPriceFeed;
    mapping(address userAdd => mapping(address collateralAdd => uint256 collateralAmount)) private
        s_userAddWithCollateralAddToAmount;
    mapping(address user => uint256 YeloAmount) private s_userToYeloAmount;
    address[] private s_tokenAdd;
    YeloStableCoin private immutable i_yo;

    ////////////////////////////////
    ////         Events         ////
    ////////////////////////////////

    event YOEngine__UserDepositActive(address indexed user, address indexed collateralAdd, uint256 indexed amount);
    event YOEngine__RedeemLists(address redeemFrom, address redeemTo, address collateralAdd, uint256 amount);

    ////////////////////////////////
    ////       modifier         ////
    ////////////////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert YOEngine__NotMoreThanZero();
        }
        _;
    }

    modifier isAllowedAdd(address tokenAdd) {
        if (s_CollateralAddToPriceFeed[tokenAdd] == address(0)) {
            revert YOEngine__isAllowAddress(tokenAdd);
        }
        _;
    }

    /////////////////////////////////
    //////    function         //////
    /////////////////////////////////

    constructor(address[] memory collateralAdd, address[] memory priceFeedAdd, address yelo) {
        if (collateralAdd.length != priceFeedAdd.length) {
            revert YOEngine__LengthIsNotEqual();
        }
        for (uint256 i = 0; i < collateralAdd.length; i++) {
            s_CollateralAddToPriceFeed[collateralAdd[i]] = priceFeedAdd[i];
            s_tokenAdd.push(collateralAdd[i]);
        }
        i_yo = YeloStableCoin(yelo);
    }

    /////////////////////////////////
    //////// public function   //////
    /////////////////////////////////

    function depositCollateral(address collateralAddress, uint256 collateralAmount)
        public
        isAllowedAdd(collateralAddress)
        moreThanZero(collateralAmount)
        nonReentrant
    {
        //check user collateralAmount
        s_userAddWithCollateralAddToAmount[msg.sender][collateralAddress] += collateralAmount;
        emit YOEngine__UserDepositActive(msg.sender, collateralAddress, collateralAmount);
        bool success = IERC20(collateralAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert YOEngine__transferFailed();
        }
    }

    function mintYelo(uint256 amount) public moreThanZero(amount) nonReentrant {
        s_userToYeloAmount[msg.sender] += amount;
        // if user mint too much
        __revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_yo.mintYelo(msg.sender, amount);
        if (!success) {
            revert YOEngine__mintFailed();
        }
    }

    function getInUsd(address tokenAdd, uint256 tokenAmount) public view returns (uint256) {
        return _getInUsd(tokenAdd, tokenAmount);
    }

    /////////////////////////////////
    //////// external function   ////
    /////////////////////////////////

    function depositCollateralAndMintYelo(address collateralAdd, uint256 collateralAmount, uint256 mintAmount)
        external
    {
        depositCollateral(collateralAdd, collateralAmount);
        mintYelo(mintAmount);
    }

    function redeemCollateral(address collateralAdd, uint256 redeemAmount)
        public
        isAllowedAdd(collateralAdd)
        moreThanZero(redeemAmount)
        nonReentrant
    {
        __revertIfHealthFactorIsBroken(msg.sender);
        _redeemCollateral(msg.sender, msg.sender, collateralAdd, redeemAmount);
    }

    function burnYelo(uint256 amount) external moreThanZero(amount) {
        _burnYelo(amount, msg.sender, msg.sender);
    }

    function redeemCollateralForBurnYelo(address collateralAdd, uint256 redeemAmount, uint256 burnAmount)
        external
        nonReentrant
    {
        _burnYelo(burnAmount, msg.sender, msg.sender);
        redeemCollateral(collateralAdd, redeemAmount);
    }

    function liquidationUser(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        //先得知道user是否达到清算阈值
        uint256 startHealthFactor = _healthFactor(user);
        if (startHealthFactor >= LIQUITE_HEALTHFACTOR_NUMBER) {
            revert YeloStableCoin__isnotLiquidatWithHealthNice();
        }
        // if covering 100Yelo so that need 100$ of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // give them 10% bouns
        uint256 bounsCollateral = tokenAmountFromDebtCovered * LIQUITE_BOUNS;

        uint256 collateralRedeemValued = tokenAmountFromDebtCovered + bounsCollateral;
        _redeemCollateral(msg.sender, user, collateral, collateralRedeemValued);
        _burnYelo(debtToCover, user, msg.sender);
        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= LIQUITE_HEALTHFACTOR_NUMBER) {
            revert YOEngine__HealthIsNotRevertAtWork();
        }
    }

    function getTokenAmountFromUsd(address collateral, uint256 debtToCover) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_CollateralAddToPriceFeed[collateral]);
        (, int256 answer,,,) = priceFeed.checkPriceFeed();

        return (debtToCover * CALCULATING_SIDENOTE) / (uint256(answer) * CHAINLINK_PRICE_FEED_SIDENOTE);
    }

    /////////////////////////////////////////
    /////   Internal / View function     ////
    ////////////////////////////////////////

    function __revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < LIQUITE_HEALTHFACTOR_NUMBER) {
            revert YOEngine__HealthFactorIsNotEnought(userHealthFactor);
        }
    }

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totallyYeloValued, uint256 totallyCollateralValued) = _getUserWithYeloAndCollateralValued(user);
        return (totallyCollateralValued / totallyYeloValued) * LIQUITE_SHRESHORLD;
    }

    function _getUserWithYeloAndCollateralValued(address user)
        internal
        view
        returns (uint256 totallyYeloValued, uint256 totallyCollateralValued)
    {
        totallyYeloValued = s_userToYeloAmount[user]; // YeloAmount = YeloValued -> 1 coin == 1$
        totallyCollateralValued = _getTotallyCollateralValued(user);
    }

    function _getTotallyCollateralValued(address user) internal view returns (uint256 amountInUsd) {
        for (uint256 i = 0; i < s_tokenAdd.length; i++) {
            address token = s_tokenAdd[i];
            uint256 amount = s_userAddWithCollateralAddToAmount[user][token];
            amountInUsd = _getInUsd(token, amount);
        }
    }

    function _getInUsd(address tokenAdd, uint256 tokenAmount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_CollateralAddToPriceFeed[tokenAdd]);

        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ((uint256(answer) * CHAINLINK_PRICE_FEED_SIDENOTE) * tokenAmount) / CALCULATING_SIDENOTE;
    }

    function _burnYelo(uint256 amountYeloToken, address onBeHalfOf, address yeloFrom) internal moreThanZero(0) {
        s_userToYeloAmount[onBeHalfOf] -= amountYeloToken;
        bool success = i_yo.transferFrom(yeloFrom, address(this), amountYeloToken);
        if (!success) {
            revert YOEngine__transferFailed();
        }
        i_yo.burn(amountYeloToken);
    }

    function _redeemCollateral(address from, address to, address collateralAdd, uint256 redeemAmount)
        private
        moreThanZero(redeemAmount)
    {
        s_userAddWithCollateralAddToAmount[from][collateralAdd] -= redeemAmount;
        emit YOEngine__RedeemLists(from, to, collateralAdd, redeemAmount);
        // if user health factor not enough revert
        bool success = IERC20(collateralAdd).transfer(to, redeemAmount);
        if (!success) {
            revert YOEngine__transferFailed();
        }
    }

    function getCollateralAddToPriceFeed(address collateralAdd) external view returns (address) {
        return s_CollateralAddToPriceFeed[collateralAdd];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getUserInfo(address user)
        external
        view
        returns (uint256 totallyYeloValued, uint256 totallyCollateralValued)
    {
        totallyYeloValued = s_userToYeloAmount[user]; // YeloAmount = YeloValued -> 1 coin == 1$
        totallyCollateralValued = _getTotallyCollateralValued(user);
    }

    //  address[] private s_tokenAdd;
    function getCollateralAddress() external view returns (address[] memory) {
        return s_tokenAdd;
    }

    // mapping(address userAdd => mapping(address collateralAdd => uint256 collateralAmount)) private
    //     s_userAddWithCollateralAddToAmount;

    function getCollateralBalanceOfUser(address user, address collateralAdd) external view returns (uint256) {
        return s_userAddWithCollateralAddToAmount[user][collateralAdd];
    }
}
