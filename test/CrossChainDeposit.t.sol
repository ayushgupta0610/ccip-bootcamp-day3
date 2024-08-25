// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {SwapTestnetUSDC} from "../src/SwapTestnetUSDC.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrossChainDepositTest is Test {
    
    // Avalanche Fuji Testnet constants
    address public constant FUJI_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
    address public constant FUJI_LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    address public constant FUJI_USDC_TOKEN = 0x5425890298aed601595a70AB815c96711a31Bc65;
    uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043;

    // Ethereum Sepolia Testnet constants
    address public constant SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public constant SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant COMET = 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e;
    address public constant COMPOUND_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant FAUCETEER = 0x68793eA49297eB75DFB4610B68e076D2A5c7646C;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

    TransferUSDC private fujiTransferUSDC;
    SwapTestnetUSDC private swapTestnetUSDC;
    CrossChainReceiver private crossChainReceiver;

    address bob;
    uint256 avaxFujiFork;
    uint256 ethSepoliaFork;

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

        // Step 2) Deploy SwapTestnetUSDC.sol on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);
        vm.startPrank(bob);

        swapTestnetUSDC = new SwapTestnetUSDC(
            SEPOLIA_USDC_TOKEN,
            COMPOUND_USDC_TOKEN,
            FAUCETEER
        );
        console.log("SwapTestnetUSDC deployed to: ", address(swapTestnetUSDC));
        
        // Step 3) Deploy CrossChainReceiver.sol on Ethereum Sepolia
        crossChainReceiver = new CrossChainReceiver(
            SEPOLIA_ROUTER,
            COMET,
            address(swapTestnetUSDC)
        );
        console.log("CrossChainReceiver deployed to: ", address(crossChainReceiver));

        // Step 4) Allowlist Avalanche Fuji chain on CrossChainReceiver.sol
        crossChainReceiver.allowlistSourceChain(FUJI_CHAIN_SELECTOR, true);

        // Step 5) Allowlist sender TransferUSDC on CrossChainReceiver.sol
        crossChainReceiver.allowlistSender(address(fujiTransferUSDC), true); 
    }

    function testDepositCrossChain() public {
        // Step 4) On Avalanche Fuji, call allowlistDestinationChain function
        // vm.selectFork(ethSepoliaFork);
        // uint256 balanceBeforeOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(bob);

        vm.selectFork(avaxFujiFork);
        vm.startPrank(bob);
        uint256 balanceBeforeOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(bob);

        fujiTransferUSDC.allowlistDestinationChain(SEPOLIA_CHAIN_SELECTOR, true);
        console.log("TransferUSDC allowlistDestinationChain to: ", true);
        
        // On Avalanche Fuji, fund TransferUSDC.sol with 3 LINK
        IERC20(FUJI_LINK_TOKEN).transfer(address(fujiTransferUSDC), 3 ether);

        // On Avalanche Fuji, call approve and transferUsdc function to crossChainReceiver
        uint256 amount = 1000_000;
        IERC20(FUJI_USDC_TOKEN).approve(address(fujiTransferUSDC), amount);

        console.log("FUJI_USDC_TOKEN approved to: ", address(fujiTransferUSDC));
        uint64 gasLimit = 500_000; // TODO: Calculate gas limit: https://docs.chain.link/ccip/tutorials/ccipreceive-gaslimit
        fujiTransferUSDC.transferUsdc(
            SEPOLIA_CHAIN_SELECTOR,
            address(crossChainReceiver),
            amount,
            gasLimit
        );
        vm.stopPrank();

        // Step 5) On Ethereum Sepolia, check if USDC was succesfully transferred
        // Get user's USDC balance on both chains before and after transfer
        uint256 balanceAfterOnFuji = IERC20(FUJI_USDC_TOKEN).balanceOf(bob);

        vm.selectFork(ethSepoliaFork);
        // vm.warp(block.timestamp + 1000000); // Increase time to allow for cross-chain transfer
        // vm.roll(block.number + 1000000); // Increase block number to allow for cross-chain transfer
        // uint256 balanceAfterOnSepolia = IERC20(SEPOLIA_USDC_TOKEN).balanceOf(bob);

        // Check if USDC was transferred
        assertEq(balanceAfterOnFuji, balanceBeforeOnFuji - amount);
        // assertEq(balanceAfterOnSepolia, balanceBeforeOnSepolia + amount); // Check this once as to why the balance has not increased even aftre warp and roll
    }


}