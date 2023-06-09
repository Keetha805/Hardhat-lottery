//Raffle
//Enter the lottery(paying some amount)
//Random winner verifiably
// Winner to be selected every X minutes -> completly automate
// Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keeper)

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughETH();
error Raffle__TransferFailed();
error Raffle__NotOpened();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 playersLength, uint256 raffleState);

/**
 * @title A sample Raffle Contract
 * @author Keetha
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements Chainlink VRF v2 and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    //Type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    //State Variables
    uint256 private immutable i_entranceFee;
    address[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_suscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUMBER_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // lottery variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    event RaffleEnter(address indexed player);
    event RaffleWinnerRequest(uint256 indexed requestId);
    event PickedWinner(address indexed winner);

    //Constructor
    constructor(
        address vrfCoordinatorV2, //contract -> mocks for tests
        uint256 entranceFee,
        bytes32 gasLane,
        uint16 suscriptionId,
        uint32 callBackGasLimit,
        RaffleState _raffleState,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_suscriptionId = suscriptionId;
        i_callbackGasLimit = callBackGasLimit;

        s_raffleState = _raffleState;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    //Receive and fallback
    //Functions
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpened();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public override returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //request num
        //do something
        //2 transaction
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gasLane
            i_suscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit, //max fulfillrandomwords
            NUMBER_WORDS
        );

        emit RaffleWinnerRequest(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = payable(s_players[indexOfWinner]);
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // require(success, "")

        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit PickedWinner(recentWinner);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUMBER_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestedConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
