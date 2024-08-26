// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Test, console, Vm} from "forge-std/Test.sol";
// import {MockERC20} from "./MockERC20.sol";
// import {TransferUSDC} from "../src/TransferUSDC.sol";
// import {SwapTestnetUSDC} from "../src/SwapTestnetUSDC.sol";
// import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

// contract CrossChainDepositGasEstimateTest is Test {
    
//     address public constant BOB = 0x47D1111fEC887a7BEb7839bBf0E1b3d215669D86;
//     // Avalanche Fuji Testnet constants
//     // address public constant FUJI_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
//     // address public constant FUJI_LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
//     // address public constant FUJI_USDC_TOKEN = 0x5425890298aed601595a70AB815c96711a31Bc65;
//     // uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043;
//     uint256 public constant amount = 1000_000;

//     // Ethereum Sepolia Testnet constants
//     // address public constant SEPOLIA_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     // address public constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
//     address public constant COMET = 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e;
//     address public constant COMPOUND_USDC_TOKEN = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     address public constant FAUCETEER = 0x68793eA49297eB75DFB4610B68e076D2A5c7646C;
//     // uint64 public constant SEPOLIA_CHAIN_SELECTOR = 16015286601757825753;

//     TransferUSDC private fujiTransferUSDC;
//     SwapTestnetUSDC private swapTestnetUSDC;
//     CrossChainReceiver private crossChainReceiver;
//     CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
//     Register.NetworkDetails fujiNetworkDetails;
//     Register.NetworkDetails sepoliaNetworkDetails;
//     MockERC20 public fujiUsdc;
//     MockERC20 public sepoliaUsdc;
//     // BurnMintERC677 public fujiLink;
//     // BurnMintERC677 public sepoliaLink;

//     uint256 avaxFujiFork;
//     uint256 ethSepoliaFork;

//     function setUp() public {
 
//         string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");
//         string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("ETHEREUM_SEPOLIA_RPC_URL");
//         avaxFujiFork = vm.createSelectFork(AVALANCHE_FUJI_RPC_URL);
//         ethSepoliaFork = vm.createFork(ETHEREUM_SEPOLIA_RPC_URL);


//         ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
//         vm.makePersistent(address(ccipLocalSimulatorFork));
//         fujiUsdc = new MockERC20("USDC", "USDC", 1000_000 * 1e6);
//         // fujiLink = new BurnMintERC677("ChainLink Token", "LINK", 18, 10 ** 27);

//         // Step 1) Deploy TransferUSDC.sol to Avalanche Fuji
//         assertEq(vm.activeFork(), avaxFujiFork);
//         fujiNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

//         fujiTransferUSDC = new TransferUSDC(
//             fujiNetworkDetails.routerAddress,
//             fujiNetworkDetails.linkAddress,
//             address(fujiUsdc)
//         );
//         console.log("TransferUSDC deployed to: ", address(fujiTransferUSDC));
//         // fujiTransferUSDC.allowlistDestinationChain(sepoliaNetworkDetails.chainSelector, true);
//         fujiUsdc.approve(address(fujiTransferUSDC), amount);

//         // Step 2) Deploy SwapTestnetUSDC.sol on Ethereum Sepolia
//         vm.selectFork(ethSepoliaFork);
//         assertEq(vm.activeFork(), ethSepoliaFork);
//         sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

//         sepoliaUsdc = new MockERC20("USDC", "USDC", 1000_000 * 1e6);
//         swapTestnetUSDC = new SwapTestnetUSDC(
//             address(sepoliaUsdc),
//             COMPOUND_USDC_TOKEN,
//             FAUCETEER
//         );
//         console.log("SwapTestnetUSDC deployed to: ", address(swapTestnetUSDC));
        
//         // Step 3) Deploy CrossChainReceiver.sol on Ethereum Sepolia
//         crossChainReceiver = new CrossChainReceiver(
//             sepoliaNetworkDetails.routerAddress,
//             COMET,
//             address(swapTestnetUSDC)
//         );
//         console.log("CrossChainReceiver deployed to: ", address(crossChainReceiver));

//         // Step 4) Allowlist Avalanche Fuji chain on CrossChainReceiver.sol
//         crossChainReceiver.allowlistSourceChain(fujiNetworkDetails.chainSelector, true);

//         // Step 5) Allowlist sender TransferUSDC on CrossChainReceiver.sol
//         crossChainReceiver.allowlistSender(address(fujiTransferUSDC), true); 
//     }

//     function sendMessage(uint256 iterations) private {
//         vm.selectFork(avaxFujiFork);
//         fujiTransferUSDC.allowlistDestinationChain(sepoliaNetworkDetails.chainSelector, true);
//         ccipLocalSimulatorFork.requestLinkFromFaucet(address(fujiTransferUSDC), 3 ether);

//         uint64 gasLimit = 500_000; // TODO: Calculate gas limit: https://docs.chain.link/ccip/tutorials/ccipreceive-gaslimit
        
//         vm.recordLogs(); // Starts recording logs to capture events.
//         fujiTransferUSDC.transferUsdc(
//             sepoliaNetworkDetails.chainSelector,
//             address(crossChainReceiver),
//             amount,
//             gasLimit
//         );
//         console.log("transferUsdc function executed");

//         // Fetches recorded logs to check for specific events and their outcomes.
//         Vm.Log[] memory logs = vm.getRecordedLogs();
//         bytes32 msgExecutedSignature = keccak256(
//             "MsgExecuted(bool,bytes,uint256)"
//         );
//         console.log("Logs length: %d", logs.length);

//         for (uint i = 0; i < logs.length; i++) {
//             if (logs[i].topics[0] == msgExecutedSignature) {
//                 console.log("MsgExecuted event found");
//                 (, , uint256 gasUsed) = abi.decode(
//                     logs[i].data,
//                     (bool, bytes, uint256)
//                 );
//                 console.log(
//                     "Number of iterations %d - Gas used: %d",
//                     iterations,
//                     gasUsed
//                 );
//             }
//         }
//     }

//     /// @notice Test case for the minimum number of iterations.
//     function test_SendReceiveMinLocal() public {
//         sendMessage(0);
//     }

//     /// @notice Test case for an average number of iterations.
//     function test_SendReceiveAverageLocal() public {
//         sendMessage(50);
//     }

//     /// @notice Test case for the maximum number of iterations.
//     function test_SendReceiveMaxLocal() public {
//         sendMessage(99);
//     }
    

// }