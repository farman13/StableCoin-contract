// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//import {ReentranyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract DSCEngine {
    //ERRORS
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedsMustBeSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransactionFailed();
    error DSCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngine__DSCMintFailed();
    error DSCEngine__HeathFactorOk();
    error DSCEngine__HeathFactorNotImproved();

    //State Variables
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTHFACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address tokenAddress => address priceFeed) private s_priceFeeds; // accpeted collateral address wit hits pricefeed address(initialized by constructor).
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposited; // amount of particular collateral submitted for a user
    mapping(address user => uint256 DSCMinted) private s_DSCMinted; // amount of DSC minted by a particular user.
    address[] private s_collateralTokens; // storing the addresses of collateral currently accepting(constructor).

    DecentralizedStableCoin private immutable i_dscAddress;

    //Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralReedemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    //Modifiers
    modifier MoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier IsAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //Constructor
    constructor(address[] memory tokenAddresses, address[] memory priceFeedsAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedsMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dscAddress = DecentralizedStableCoin(dscAddress);
    }

    //External Functions
    function DepositCollateralAndMintDSC(
        address _tokenCollateralAddress,
        uint256 _amountCollateral,
        uint256 _DSCamountToMint
    ) external {
        DepositCollateral(_tokenCollateralAddress, _amountCollateral);
        MintDSC(_DSCamountToMint);
    }

    function ReedemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        MoreThanZero(amountDscToBurn)
    {
        BurnDSC(amountDscToBurn);
        ReedemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function ReedemCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        public
        MoreThanZero(_amountCollateral)
    //nonReentrant
    {
        _ReedemCollateral(msg.sender, msg.sender, _tokenCollateralAddress, _amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function BurnDSC(uint256 amountToBurn) public MoreThanZero(amountToBurn) {
        _BurnDSC(msg.sender, msg.sender, amountToBurn);
    }

    function Liquidate(address collateral, address user, uint256 debtToCover) external MoreThanZero(debtToCover) {
        // need to check the health factor of user.
        uint256 startingHealthfactor = _healthFactor(user);
        if (startingHealthfactor >= MIN_HEALTHFACTOR) {
            revert DSCEngine__HeathFactorOk();
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralReedemed = tokenAmountFromDebtCovered + bonusCollateral;

        _ReedemCollateral(user, msg.sender, collateral, totalCollateralReedemed);
        _BurnDSC(user, msg.sender, debtToCover);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingHealthfactor) {
            revert DSCEngine__HeathFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor(address user) external view {
        _healthFactor(user);
    }

    //Internal & private Functions

    function _ReedemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
        MoreThanZero(amountCollateral)
    //nonReentrant
    {
        s_CollateralDeposited[from][tokenCollateralAddress] -= amountCollateral; // 100weth-1000weth (no need to write that check as solidity automatically handles it through safeMath)
        emit CollateralReedemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransactionFailed();
        }
    }

    function _BurnDSC(address onBehalf, address dscFrom, uint256 amountToBurn) private MoreThanZero(amountToBurn) {
        s_DSCMinted[onBehalf] -= amountToBurn;
        bool success = i_dscAddress.transferFrom(dscFrom, address(this), amountToBurn);
        // this condition is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransactionFailed();
        }
        i_dscAddress.burn(amountToBurn);
    }

    function _getAccountInfo(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUSD = getAccountCollateralValueInUsd(user);

        return (totalDSCMinted, collateralValueInUSD);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = _getAccountInfo(user);
        uint256 collateralAdjustedForThresold = (collateralValueInUsd * LIQUIDATION_THRESOLD) / LIQUIDATION_PRECISION; //200%
        return collateralAdjustedForThresold * PRECISION / totalDSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTHFACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    //Public Functions

    function getTokenAmountFromUsd(address token, uint256 usdAmtInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1000e18 * 1e18 / 2000e8 * 1e10;
        return (usdAmtInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function DepositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        MoreThanZero(amountCollateral)
        IsAllowedToken(tokenCollateralAddress)
    {
        s_CollateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransactionFailed();
        }
    }

    function MintDSC(uint256 DSCamountToMint) public MoreThanZero(DSCamountToMint) {
        s_DSCMinted[msg.sender] += DSCamountToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dscAddress.mint(msg.sender, DSCamountToMint);
        if (!success) {
            revert DSCEngine__DSCMintFailed();
        }
    }

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_CollateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
