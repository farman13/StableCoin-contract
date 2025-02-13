// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deploy;

    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address weth;
    address wbtc;
    address ethPriceFeed;
    address public USER = makeAddr("user");
    uint256 constant STARTING_BALANCE = 20 ether;

    function setUp() public {
        deploy = new DeployDSC();
        (dsc, dsce, config) = deploy.run();
        (weth, wbtc, ethPriceFeed,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_BALANCE); // giving user weth tokens (ethers)
    }

    function testgetUSDValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000USD = 30000e18
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }

    function testDepositCollateral() public {
        uint256 ethAmount = 9 ether;

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), 10 ether); // calling approval() from ERC20Mock type contract ,so dsce take weth tokens from it.
        dsce.DepositCollateral(weth, ethAmount);
        vm.stopPrank();

        uint256 ExpectedCollateralBalance = 9 ether;
        uint256 ActualCollateralBalance = ERC20Mock(weth).balanceOf(address(dsce)); // calling balanceOf() from dsce behalf.

        assertEq(ActualCollateralBalance, ExpectedCollateralBalance);
    }

    function testIfCollateralIsZero() public {
        vm.prank(USER);
        //  ERC20Mock(weth).approve(address(dsce), 10 ether);    (Not needed here , bcoz MoreThanZero modifier checks it before the actual function execution starts).

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.DepositCollateral(weth, 0);
    }

    function testIfCollateralIsAllowed() public {
        //uint256 ethAmount = 1 ether;
        // address eth = 0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe; // Not Allowed(registered) Address in our tokenAddresses[].
        ERC20Mock randomToken = new ERC20Mock("ran", "Wran", USER, STARTING_BALANCE);

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.DepositCollateral(address(randomToken), STARTING_BALANCE);
    }

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testRevertIfTokenLengthDoesNotMatchPriceFeedLength() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeedAddresses.push(ethPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedsMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testgetTokenAmountFromUsd() public view {
        uint256 UsdAmount = 100 ether; // dsc in wei 100dsc in wei
        // $2000/ETH -> 100/2000 = 0.05
        uint256 expectedAmount = 0.05 ether;
        uint256 actualAmount = dsce.getTokenAmountFromUsd(weth, UsdAmount);
        vm.assertEq(expectedAmount, actualAmount);
    }
}
