// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address weth;
        address weth_pricefeed;
        address wbtc;
        address wbtc_pricefeed;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ETHUSD_PRICE = 2000e8;
    int256 public constant INITIAL_BTCUSD_PRICE = 1000e8;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            weth_pricefeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wbtc_pricefeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilConfig) {
        if (activeNetworkConfig.weth_pricefeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUSdPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_ETHUSD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator btcUSdPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_BTCUSD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        anvilConfig = NetworkConfig({
            weth: address(wethMock),
            weth_pricefeed: address(ethUSdPriceFeed),
            wbtc: address(wbtcMock),
            wbtc_pricefeed: address(btcUSdPriceFeed),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
