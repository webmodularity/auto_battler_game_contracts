// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GelatoVRFConsumerBase} from "../../lib/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";

// Interfaces
import {IPlayer} from "../../src/interfaces/IPlayer.sol";
import {IDefaultPlayer} from "../../src/interfaces/IDefaultPlayer.sol";
import {IMonster} from "../../src/interfaces/IMonster.sol";
import {IGameEngine} from "../../src/interfaces/IGameEngine.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/IPlayerSkinNFT.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/IPlayerSkinRegistry.sol";

// Concrete implementations (needed for deployment)
import {Player} from "../../src/Player.sol";
import {DefaultPlayer} from "../../src/DefaultPlayer.sol";
import {Monster} from "../../src/Monster.sol";
import {GameEngine} from "../../src/GameEngine.sol";
import {DefaultPlayerSkinNFT} from "../../src/DefaultPlayerSkinNFT.sol";
import {PlayerSkinRegistry} from "../../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../../src/PlayerNameRegistry.sol";
import {MonsterNameRegistry} from "../../src/MonsterNameRegistry.sol";
import {Fighter} from "../../src/Fighter.sol";

// Libraries
import {DefaultPlayerLibrary} from "../../src/lib/DefaultPlayerLibrary.sol";
import {MonsterLibrary} from "../../src/lib/MonsterLibrary.sol";
import {MonsterSkinNFT} from "../../src/MonsterSkinNFT.sol";
import {NameLibrary} from "../../src/lib/NameLibrary.sol";

abstract contract TestBase is Test {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;
    uint256 private constant VRF_ROUND = 335;
    address public operator;
    Player public playerContract;
    DefaultPlayer public defaultPlayerContract;
    Monster public monsterContract;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    uint32 public defaultSkinIndex;
    GameEngine public gameEngine;
    MonsterSkinNFT public monsterSkin;
    uint32 public monsterSkinIndex;
    MonsterNameRegistry public monsterNameRegistry;

    /// @notice Modifier to skip tests in CI environment
    /// @dev Uses vm.envOr to check if CI environment variable is set
    modifier skipInCI() {
        if (!vm.envOr("CI", false)) {
            _;
        }
    }

    function setUp() public virtual {
        operator = address(0x42);
        setupRandomness();
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        monsterSkin = new MonsterSkinNFT();

        // Register and configure skins
        defaultSkinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setSkinVerification(defaultSkinIndex, true);
        skinRegistry.setSkinType(defaultSkinIndex, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        monsterSkinIndex = _registerSkin(address(monsterSkin));
        skinRegistry.setSkinVerification(monsterSkinIndex, true);
        skinRegistry.setSkinType(monsterSkinIndex, IPlayerSkinRegistry.SkinType.Monster);

        // Create name registries and initialize names
        nameRegistry = new PlayerNameRegistry();
        string[] memory setANames = NameLibrary.getInitialNameSetA();
        string[] memory setBNames = NameLibrary.getInitialNameSetB();
        string[] memory surnameList = NameLibrary.getInitialSurnames();

        nameRegistry.addNamesToSetA(setANames);
        nameRegistry.addNamesToSetB(setBNames);
        nameRegistry.addSurnames(surnameList);

        // Initialize monster name registry
        monsterNameRegistry = new MonsterNameRegistry();
        string[] memory monsterNames = NameLibrary.getInitialMonsterNames();
        monsterNameRegistry.addMonsterNames(monsterNames);

        gameEngine = new GameEngine();

        // Create the player contracts with all required dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), operator);
        defaultPlayerContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));
        monsterContract = new Monster(address(skinRegistry), address(nameRegistry));

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis

        // Mint default characters and monsters
        _mintDefaultCharacters();
        _mintMonsters();
    }

    function _registerSkin(address skinContract) internal returns (uint32) {
        vm.deal(address(this), skinRegistry.registrationFee());
        vm.prank(address(this));
        return skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(skinContract);
    }

    function setupRandomness() internal {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            console2.log("Testing in CI mode with mock randomness");
            vm.warp(1_000_000);
            vm.roll(DEFAULT_FORK_BLOCK);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Try to use RPC fork, fallback to mock if not available
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                console2.log("No RPC_URL found, using mock randomness");
                vm.warp(1_000_000);
                vm.roll(DEFAULT_FORK_BLOCK);
                vm.prevrandao(bytes32(uint256(0x1234567890)));
            }
        }
    }

    // Helper function for VRF fulfillment with round matching
    function _fulfillVRF(uint256 requestId, uint256, /* randomSeed */ address vrfConsumer) internal {
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(VRF_ROUND, data);

        // Call fulfillRandomness as operator
        vm.prank(operator);
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);
    }

    // Helper to create a player request, stopping before VRF fulfillment.
    // This is useful for testing VRF fulfillment mechanics separately,
    // such as testing operator permissions or invalid round IDs.
    function _createPlayerRequest(address owner, IPlayer contractInstance, bool useSetB) internal returns (uint256) {
        vm.deal(owner, contractInstance.createPlayerFeeAmount());
        vm.startPrank(owner);
        uint256 requestId = Player(address(contractInstance)).requestCreatePlayer{
            value: Player(address(contractInstance)).createPlayerFeeAmount()
        }(useSetB);
        vm.stopPrank();
        return requestId;
    }

    // Helper function to create a player with VRF
    function _createPlayerAndFulfillVRF(address owner, Player contractInstance, bool useSetB)
        internal
        returns (uint32)
    {
        // Give enough ETH to cover the fee
        vm.deal(owner, contractInstance.createPlayerFeeAmount());

        // Request player creation
        uint256 requestId = _createPlayerRequest(owner, contractInstance, useSetB);

        // Fulfill VRF request
        _fulfillVRF(
            requestId,
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, VRF_ROUND))),
            address(contractInstance)
        );

        // Get the player ID from the contract
        uint32[] memory playerIds = contractInstance.getPlayerIds(owner);
        require(playerIds.length > 0, "Player not created");

        return playerIds[playerIds.length - 1];
    }

    // Helper function to assert stat ranges
    function _assertStatRanges(IPlayer.PlayerStats memory stats) internal pure virtual {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21, "Strength out of range");
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21, "Constitution out of range");
        assertTrue(stats.size >= 3 && stats.size <= 21, "Size out of range");
        assertTrue(stats.agility >= 3 && stats.agility <= 21, "Agility out of range");
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21, "Stamina out of range");
        assertTrue(stats.luck >= 3 && stats.luck <= 21, "Luck out of range");
    }

    // Helper function to create a player loadout that supports both practice and duel game test cases
    function _createLoadout(uint32 fighterId) internal view returns (Fighter.PlayerLoadout memory) {
        Fighter fighter = _getFighterContract(fighterId);
        (uint32 skinIndex, uint16 tokenId) = fighter.getCurrentSkin(fighterId);
        return Fighter.PlayerLoadout({playerId: fighterId, skinIndex: skinIndex, skinTokenId: tokenId});
    }

    // Helper function to validate combat results
    function _assertValidCombatResult(
        uint16 version,
        IGameEngine.WinCondition condition,
        IGameEngine.CombatAction[] memory actions
    ) internal pure {
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(IGameEngine.WinCondition).max), "Invalid win condition");
        assertTrue(version > 0, "Invalid version");
    }

    // Helper function to validate events
    function _assertValidCombatEvent(bytes32 player1Data, bytes32 player2Data) internal {
        // Get the last CombatResult event and validate the packed data
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        bytes32 eventPlayer1Data;
        bytes32 eventPlayer2Data;

        for (uint256 i = entries.length; i > 0; i--) {
            // CombatResult event has 4 topics (event sig + 3 indexed params)
            if (entries[i - 1].topics.length == 4) {
                eventPlayer1Data = bytes32(entries[i - 1].topics[1]);
                eventPlayer2Data = bytes32(entries[i - 1].topics[2]);
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "CombatResult event not found");

        // Decode both expected and actual player data
        (
            uint32 expectedId1,
            uint8 expectedStr1,
            uint8 expectedCon1,
            uint8 expectedSize1,
            uint8 expectedAgi1,
            uint8 expectedSta1,
            uint8 expectedLuck1
        ) = abi.decode(abi.encodePacked(uint96(0), player1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId1,
            uint8 actualStr1,
            uint8 actualCon1,
            uint8 actualSize1,
            uint8 actualAgi1,
            uint8 actualSta1,
            uint8 actualLuck1
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 1 data
        assertEq(actualId1, expectedId1, "Player 1 ID mismatch");
        assertEq(actualStr1, expectedStr1, "Player 1 strength mismatch");
        assertEq(actualCon1, expectedCon1, "Player 1 constitution mismatch");
        assertEq(actualSize1, expectedSize1, "Player 1 size mismatch");
        assertEq(actualAgi1, expectedAgi1, "Player 1 agility mismatch");
        assertEq(actualSta1, expectedSta1, "Player 1 stamina mismatch");
        assertEq(actualLuck1, expectedLuck1, "Player 1 luck mismatch");

        // Decode and verify player 2 data
        (
            uint32 expectedId2,
            uint8 expectedStr2,
            uint8 expectedCon2,
            uint8 expectedSize2,
            uint8 expectedAgi2,
            uint8 expectedSta2,
            uint8 expectedLuck2
        ) = abi.decode(abi.encodePacked(uint96(0), player2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId2,
            uint8 actualStr2,
            uint8 actualCon2,
            uint8 actualSize2,
            uint8 actualAgi2,
            uint8 actualSta2,
            uint8 actualLuck2
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 2 data
        assertEq(actualId2, expectedId2, "Player 2 ID mismatch");
        assertEq(actualStr2, expectedStr2, "Player 2 strength mismatch");
        assertEq(actualCon2, expectedCon2, "Player 2 constitution mismatch");
        assertEq(actualSize2, expectedSize2, "Player 2 size mismatch");
        assertEq(actualAgi2, expectedAgi2, "Player 2 agility mismatch");
        assertEq(actualSta2, expectedSta2, "Player 2 stamina mismatch");
        assertEq(actualLuck2, expectedLuck2, "Player 2 luck mismatch");
    }

    // Helper function to check if a combat result is defensive
    function _isDefensiveResult(IGameEngine.CombatResultType result) internal pure returns (bool) {
        return result == IGameEngine.CombatResultType.PARRY || result == IGameEngine.CombatResultType.BLOCK
            || result == IGameEngine.CombatResultType.DODGE || result == IGameEngine.CombatResultType.MISS
            || result == IGameEngine.CombatResultType.HIT || result == IGameEngine.CombatResultType.COUNTER
            || result == IGameEngine.CombatResultType.COUNTER_CRIT || result == IGameEngine.CombatResultType.RIPOSTE
            || result == IGameEngine.CombatResultType.RIPOSTE_CRIT;
    }

    // Helper function to generate a deterministic but unpredictable seed for game actions
    function _generateGameSeed() internal view returns (uint256) {
        return uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender))
        );
    }

    // Helper function to simulate VRF fulfillment with standard test data
    function _simulateVRFFulfillment(uint256 requestId, uint256 roundId) internal returns (bytes memory) {
        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(roundId, innerData);
        return dataWithRound;
    }

    // Helper function to decode VRF event logs
    function _decodeVRFRequestEvent(Vm.Log[] memory entries)
        internal
        pure
        returns (uint256 roundId, bytes memory eventData)
    {
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RequestedRandomness(uint256,bytes)")) {
                (roundId, eventData) = abi.decode(entries[i].data, (uint256, bytes));
                break;
            }
        }
        return (roundId, eventData);
    }

    // Helper function to assert player ownership and basic state
    function _assertPlayerState(Player contractInstance, uint32 playerId, address expectedOwner, bool shouldExist)
        internal
    {
        if (shouldExist) {
            assertEq(contractInstance.getPlayerOwner(playerId), expectedOwner, "Incorrect player owner");
            IPlayer.PlayerStats memory stats = contractInstance.getPlayer(playerId);
            assertTrue(stats.strength != 0, "Player should exist");
            assertFalse(contractInstance.isPlayerRetired(playerId), "Player should not be retired");
        } else {
            vm.expectRevert();
            contractInstance.getPlayerOwner(playerId);
        }
    }

    // Helper function to assert ETH balances after transactions
    function _assertBalances(address account, uint256 expectedBalance, string memory message) internal {
        assertEq(account.balance, expectedBalance, message);
    }

    // Helper function to assert VRF request
    function _assertVRFRequest(uint256 requestId, uint256 roundId) internal {
        // Get recorded logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Look for the VRF request event
        bool foundEvent = false;
        for (uint256 i = entries.length; i > 0; i--) {
            if (entries[i - 1].topics[0] == keccak256("RequestedRandomness(uint256,bytes)")) {
                // Found event, verify round ID matches
                assertEq(uint256(entries[i - 1].topics[1]), roundId, "VRF round ID mismatch");
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "VRF request event not found");
    }

    /// @notice Helper to ensure an address has enough slots for desired player count
    /// @param owner Address to purchase slots for
    /// @param desiredSlots Total number of slots needed
    /// @param contractInstance Player contract instance
    function _ensurePlayerSlots(address owner, uint256 desiredSlots, IPlayer contractInstance) internal {
        require(desiredSlots <= 200, "Cannot exceed MAX_TOTAL_SLOTS");

        uint256 currentSlots = contractInstance.getPlayerSlots(owner);
        if (currentSlots >= desiredSlots) return; // Already have enough slots

        // Calculate how many batches of 5 slots we need to purchase
        uint256 slotsNeeded = desiredSlots - currentSlots;
        uint256 batchesNeeded = (slotsNeeded + 4) / 5; // Round up division

        // Purchase required batches
        for (uint256 i = 0; i < batchesNeeded; i++) {
            vm.startPrank(owner);
            uint256 batchCost = contractInstance.getNextSlotBatchCost(owner);
            vm.deal(owner, batchCost);
            contractInstance.purchasePlayerSlots{value: batchCost}();
            vm.stopPrank();
        }

        // Verify we have enough slots
        assertGe(contractInstance.getPlayerSlots(owner), desiredSlots);
    }

    /// @notice Mints default characters for testing
    /// @dev This creates a standard set of characters with different fighting styles
    function _mintDefaultCharacters() internal {
        DefaultPlayerLibrary.createAllDefaultCharacters(defaultSkin, defaultPlayerContract, defaultSkinIndex);
    }

    function _mintMonsters() internal {
        MonsterLibrary.createAllMonsters(monsterSkin, monsterContract, monsterSkinIndex);
    }

    // Helper functions
    function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint32) {
        return _createPlayerAndFulfillVRF(owner, playerContract, useSetB);
    }

    function _createPlayerAndExpectVRFFail(address owner, bool useSetB, string memory expectedError) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        vm.expectRevert(bytes(expectedError));
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    function _createPlayerAndExpectVRFFail(
        address owner,
        bool useSetB,
        string memory expectedError,
        uint256 customRoundId
    ) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(customRoundId, innerData);

        vm.expectRevert(bytes(expectedError));
        vm.prank(operator);
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);
    }

    // Helper function for VRF fulfillment
    function _fulfillVRF(uint256 requestId, uint256 randomSeed) internal {
        _fulfillVRF(requestId, randomSeed, address(playerContract));
    }

    function getWeaponName(uint8 weapon) internal view returns (string memory) {
        if (weapon == gameEngine.WEAPON_SWORD_AND_SHIELD()) return "SwordAndShield";
        if (weapon == gameEngine.WEAPON_MACE_AND_SHIELD()) return "MaceAndShield";
        if (weapon == gameEngine.WEAPON_RAPIER_AND_SHIELD()) return "RapierAndShield";
        if (weapon == gameEngine.WEAPON_GREATSWORD()) return "Greatsword";
        if (weapon == gameEngine.WEAPON_BATTLEAXE()) return "Battleaxe";
        if (weapon == gameEngine.WEAPON_QUARTERSTAFF()) return "Quarterstaff";
        if (weapon == gameEngine.WEAPON_SPEAR()) return "Spear";
        return "Unknown";
    }

    function getArmorName(uint8 armor) internal view returns (string memory) {
        if (armor == gameEngine.ARMOR_CLOTH()) return "Cloth";
        if (armor == gameEngine.ARMOR_LEATHER()) return "Leather";
        if (armor == gameEngine.ARMOR_CHAIN()) return "Chain";
        if (armor == gameEngine.ARMOR_PLATE()) return "Plate";
        return "Unknown";
    }

    function getStanceName(uint8 stance) internal view returns (string memory) {
        if (stance == gameEngine.STANCE_DEFENSIVE()) return "Defensive";
        if (stance == gameEngine.STANCE_BALANCED()) return "Balanced";
        if (stance == gameEngine.STANCE_OFFENSIVE()) return "Offensive";
        return "Unknown";
    }

    // Helper function to get the appropriate Fighter contract
    function _getFighterContract(uint32 playerId) internal view returns (Fighter) {
        if (playerId <= 2000) {
            return Fighter(address(defaultPlayerContract));
        } else if (playerId <= 10000) {
            return Fighter(address(monsterContract));
        } else {
            return Fighter(address(playerContract));
        }
    }
}
