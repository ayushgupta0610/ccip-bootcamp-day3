// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TransferUSDCTest is Test {
    uint256 avaxFujiFork;
    uint256 ethSepoliaFork;

    // Avalanche Fuji Testnet constants
    address public constant FUJI_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
    address public constant FUJI_LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    address public constant FUJI_USDC_TOKEN = 0x5425890298aed601595a70AB815c96711a31Bc65;
    uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043;

    // Ethereum Sepolia Testnet constants
    address public constant SEPOLIA_ROUTER = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address public constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

    address bob;

    TransferUSDC public fujiTransferUSDC;

    function setUp() public {
        uint256 bobPrivateKey = vm.envUint("PRIVATE_KEY");
        bob = vm.addr(bobPrivateKey);

        string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        avaxFujiFork = vm.createSelectFork(AVALANCHE_FUJI_RPC_URL);
        ethSepoliaFork = vm.createFork(ETHEREUM_SEPOLIA_RPC_URL);

        // Step 1) Deploy TransferUSDC.sol to Avalanche Fuji
        assertEq(vm.activeFork(), avaxFujiFork);

        vm.prank(bob);
        fujiTransferUSDC = new TransferUSDC(
            FUJI_ROUTER,
            FUJI_LINK_TOKEN,
            FUJI_USDC_TOKEN
        );
        console.log("TransferUSDC deployed to: ", address(fujiTransferUSDC));
    }

    function testTransferUsdcCrossChain() public {
        // Step 2) On Avalanche Fuji, call allowlistDestinationChain function
        vm.selectFork(ethSepoliaFork);
        uint256 balanceBeforeOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(bob);

        vm.selectFork(avaxFujiFork);
        vm.startPrank(bob);
        uint256 balanceBeforeOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(bob);

        fujiTransferUSDC.allowlistDestinationChain(SEPOLIA_CHAIN_SELECTOR, true);
        console.log("TransferUSDC allowlistDestinationChain to: ", true);
        
        // Step 3) On Avalanche Fuji, fund TransferUSDC.sol with 3 LINK
        IERC20(FUJI_LINK_TOKEN).transfer(address(fujiTransferUSDC), 3 ether);

        // Step 4) On Avalanche Fuji, call approve and transferUsdc function to an EOA
        uint256 amount = 1000_000;
        IERC20(FUJI_USDC_TOKEN).approve(address(fujiTransferUSDC), amount);

        console.log("FUJI_USDC_TOKEN approved to: ", address(fujiTransferUSDC));
        uint64 gasLimit = 500_000; // TODO: Calculate gas limit: https://docs.chain.link/ccip/tutorials/ccipreceive-gaslimit
        fujiTransferUSDC.transferUsdc(
            SEPOLIA_CHAIN_SELECTOR,
            bob,
            amount,
            gasLimit
        );
        vm.stopPrank();

        // Step 5) On Ethereum Sepolia, check if USDC was succesfully transferred
       
        // Get user's USDC balance on both chains before and after transfer
        uint256 balanceAfterOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(bob);

        vm.selectFork(ethSepoliaFork);
        vm.warp(block.timestamp + 1000000); // Increase time to allow for cross-chain transfer
        vm.roll(block.number + 1000000); // Increase block number to allow for cross-chain transfer
        uint256 balanceAfterOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(bob);

        // Check if USDC was transferred
        assertEq(balanceAfterOnFuji, balanceBeforeOnFuji - amount);
        assertEq(balanceAfterOnSepolia, balanceBeforeOnSepolia + amount);
    }


}