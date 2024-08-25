// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MockERC20} from "./MockERC20.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {SwapTestnetUSDC} from "../src/SwapTestnetUSDC.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {BurnMintERC677} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";

contract CrossChainDepositTest is Test {
    
    // Avalanche Fuji Testnet constants
    uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043;
    address public constant FUJI_USDC_TOKEN = 0x5425890298aed601595a70AB815c96711a31Bc65;
    uint256 public constant amount = 1000_000;

    // Ethereum Sepolia Testnet constants
    address public constant SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant COMET = 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e;
    address public constant COMPOUND_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant FAUCETEER = 0x68793eA49297eB75DFB4610B68e076D2A5c7646C;
    uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

    TransferUSDC private fujiTransferUSDC;
    SwapTestnetUSDC private swapTestnetUSDC;
    CrossChainReceiver private crossChainReceiver;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    MockCCIPRouter public fujiRouter;
    MockCCIPRouter public sepoliaRouter;
    BurnMintERC677 public fujiLink;
    BurnMintERC677 public sepoliaLink;
    address public bob;
    // MockERC20 public fujiUsdc;
    // MockERC20 public sepoliaUsdc;

    uint256 avaxFujiFork;
    uint256 ethSepoliaFork;

    function setUp() public {
        uint256 bobPrivateKey = vm.envUint("PRIVATE_KEY");
        bob = vm.addr(bobPrivateKey);

        string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
        avaxFujiFork = vm.createSelectFork(AVALANCHE_FUJI_RPC_URL);
        ethSepoliaFork = vm.createFork(ETHEREUM_SEPOLIA_RPC_URL);

        vm.prank(bob);
        IERC20(FUJI_USDC_TOKEN).transfer(address(this), amount);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        fujiRouter = new MockCCIPRouter();
        fujiLink = new BurnMintERC677("ChainLink Token", "LINK", 18, 10 ** 27);

        // Step 1) Deploy TransferUSDC.sol to Avalanche Fuji
        assertEq(vm.activeFork(), avaxFujiFork);

        fujiTransferUSDC = new TransferUSDC(
            address(fujiRouter),
            address(fujiLink),
            FUJI_USDC_TOKEN
        );
        console.log("TransferUSDC deployed to: ", address(fujiTransferUSDC));
        fujiTransferUSDC.allowlistDestinationChain(SEPOLIA_CHAIN_SELECTOR, true);
        IERC20(FUJI_USDC_TOKEN).approve(address(fujiTransferUSDC), amount);

        // Step 2) Deploy SwapTestnetUSDC.sol on Ethereum Sepolia
        vm.selectFork(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);

        sepoliaRouter = new MockCCIPRouter();
        sepoliaLink = new BurnMintERC677("ChainLink Token", "LINK", 18, 10 ** 27);
        swapTestnetUSDC = new SwapTestnetUSDC(
            SEPOLIA_USDC_TOKEN,
            COMPOUND_USDC_TOKEN,
            FAUCETEER
        );
        console.log("SwapTestnetUSDC deployed to: ", address(swapTestnetUSDC));
        
        // Step 3) Deploy CrossChainReceiver.sol on Ethereum Sepolia
        sepoliaRouter = new MockCCIPRouter();
        crossChainReceiver = new CrossChainReceiver(
            address(sepoliaRouter),
            COMET,
            address(swapTestnetUSDC)
        );
        console.log("CrossChainReceiver deployed to: ", address(crossChainReceiver));

        // Step 4) Allowlist Avalanche Fuji chain on CrossChainReceiver.sol
        crossChainReceiver.allowlistSourceChain(FUJI_CHAIN_SELECTOR, true);

        // Step 5) Allowlist sender TransferUSDC on CrossChainReceiver.sol
        crossChainReceiver.allowlistSender(address(fujiTransferUSDC), true); 
    }

    function sendMessage(uint256 iterations) private {
        vm.selectFork(avaxFujiFork);
        uint64 gasLimit = 500_000; // TODO: Calculate gas limit: https://docs.chain.link/ccip/tutorials/ccipreceive-gaslimit
        
        vm.recordLogs(); // Starts recording logs to capture events.
        fujiTransferUSDC.transferUsdc(
            SEPOLIA_CHAIN_SELECTOR,
            address(crossChainReceiver),
            amount,
            gasLimit
        );
        console.log("transferUsdc function executed");

        // Fetches recorded logs to check for specific events and their outcomes.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 msgExecutedSignature = keccak256(
            "MsgExecuted(bool,bytes,uint256)"
        );
        console.log("Logs length: %d", logs.length);

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == msgExecutedSignature) {
                console.log("MsgExecuted event found");
                (, , uint256 gasUsed) = abi.decode(
                    logs[i].data,
                    (bool, bytes, uint256)
                );
                console.log(
                    "Number of iterations %d - Gas used: %d",
                    iterations,
                    gasUsed
                );
            }
        }
    }

    /// @notice Test case for the minimum number of iterations.
    function test_SendReceiveMin() public {
        sendMessage(0);
    }

    /// @notice Test case for an average number of iterations.
    function test_SendReceiveAverage() public {
        sendMessage(50);
    }

    /// @notice Test case for the maximum number of iterations.
    function test_SendReceiveMax() public {
        sendMessage(99);
    }
    

}