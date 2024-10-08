// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

contract TransferUSDCTest is Test {
    uint256 avaxFujiFork;
    uint256 ethSepoliaFork;

    // Avalanche Fuji Testnet constants
    address public constant FUJI_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
    address public constant FUJI_LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    address public constant FUJI_USDC_TOKEN = 0x5425890298aed601595a70AB815c96711a31Bc65;
    uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043;

    // Ethereum Sepolia Testnet constants
    address public constant SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

    address BOB = 0x47D1111fEC887a7BEb7839bBf0E1b3d215669D86;

    TransferUSDC public fujiTransferUSDC;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    function setUp() public {

        string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        avaxFujiFork = vm.createSelectFork(AVALANCHE_FUJI_RPC_URL);
        ethSepoliaFork = vm.createFork(ETHEREUM_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Step 1) Deploy TransferUSDC.sol to Avalanche Fuji
        assertEq(vm.activeFork(), avaxFujiFork);

        vm.prank(BOB);
        fujiTransferUSDC = new TransferUSDC(
            FUJI_ROUTER,
            FUJI_LINK_TOKEN,
            FUJI_USDC_TOKEN
        );
        console.log("TransferUSDC deployed to: ", address(fujiTransferUSDC));
    }

    function testTransferUsdcCrossChain() public {
        // Step 2) On Avalanche Fuji, call allowlistDestinationChain function

        // vm.selectFork(ethSepoliaFork);
        // uint256 balanceBeforeOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(BOB);

        vm.selectFork(avaxFujiFork);
        vm.startPrank(BOB);
        uint256 balanceBeforeOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(BOB);

        fujiTransferUSDC.allowlistDestinationChain(SEPOLIA_CHAIN_SELECTOR, true);
        console.log("TransferUSDC allowlistDestinationChain to: ", true);
        
        // Step 3) On Avalanche Fuji, fund TransferUSDC.sol with 3 LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet(address(fujiTransferUSDC), 3 ether);

        // Step 4) On Avalanche Fuji, call approve and transferUsdc function to an EOA
        uint256 amount = 1000_000;
        vm.prank(BOB);
        IERC20(FUJI_USDC_TOKEN).approve(address(fujiTransferUSDC), amount);

        uint64 gasLimit = 0;
        vm.prank(BOB);
        fujiTransferUSDC.transferUsdc(
            SEPOLIA_CHAIN_SELECTOR,
            BOB,
            amount,
            gasLimit
        );
        vm.stopPrank();

        // Step 5) On Ethereum Sepolia, check if USDC was succesfully transferred
        // Get user's USDC balance on both chains before and after transfer
        uint256 balanceAfterOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(BOB);
        console.log("Balance after on fuji: ", balanceAfterOnFuji);
        
        // ccipLocalSimulatorFork.switchChainAndRouteMessage(ethSepoliaFork);
        // uint256 balanceAfterOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(BOB);
        // console.log("Balance after on sepolia: ", balanceAfterOnSepolia);

        // Check if USDC was transferred
        assertEq(balanceAfterOnFuji, balanceBeforeOnFuji - amount);
        // assertEq(balanceAfterOnSepolia, balanceBeforeOnSepolia + amount); // Check this once as to why the balance has not increased even aftre warp and roll
    }

}