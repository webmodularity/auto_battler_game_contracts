// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    Player,
    TooManyPlayers,
    NotPlayerOwner,
    InvalidPlayerStats,
    NoPermission,
    PlayerDoesNotExist
} from "../src/Player.sol";
import {IPlayer} from "../src/interfaces/IPlayer.sol";
import {PlayerSkinRegistry, SkinRegistryDoesNotExist} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import {IGameDefinitions} from "../src/interfaces/IGameDefinitions.sol";
import {PlayerSkinNFT} from "../src/examples/PlayerSkinNFT.sol";
import "./utils/TestBase.sol";
import "./mocks/UnlockNFT.sol";

contract PlayerTest is TestBase {
    // Test addresses
    address public PLAYER_ONE;
    address public PLAYER_TWO;

    uint256 public ROUND_ID;

    event PlayerSkinEquipped(uint32 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);
    event PlayerCreationRequested(uint256 indexed requestId, address indexed requester);
    event PlayerCreationFulfilled(uint256 indexed requestId, uint32 indexed playerId, address indexed owner);
    event RequestedRandomness(uint256 round, bytes data);
    event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);
    event PlayerImmortalityChanged(uint32 indexed playerId, address indexed changer, bool isImmortal);
    event PlayerCreated(
        uint32 indexed playerId,
        uint16 indexed firstNameIndex,
        uint16 indexed surnameIndex,
        uint8 strength,
        uint8 constitution,
        uint8 size,
        uint8 agility,
        uint8 stamina,
        uint8 luck
    );

    function setUp() public override {
        super.setUp();

        // Set up test addresses
        PLAYER_ONE = address(0x1111);
        PLAYER_TWO = address(0x2222);

        // Reset VRF state
        ROUND_ID = 0;
    }

    function testCreatePlayerWithVRF() public skipInCI {
        // Create player and verify ownership
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Verify player state
        _assertPlayerState(playerContract, playerId, PLAYER_ONE, true);

        IPlayer.PlayerStats memory newPlayer = playerContract.getPlayer(playerId);
        _assertStatRanges(newPlayer);
    }

    function testMaxPlayers() public {
        // Test default slots first
        uint256 defaultSlots = playerContract.getPlayerSlots(PLAYER_ONE);

        // Fill up default slots
        for (uint256 i = 0; i < defaultSlots; i++) {
            _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, i % 2 == 0);
        }

        // Keep purchasing and filling slots until we hit max
        while (playerContract.getPlayerSlots(PLAYER_ONE) < 200) {
            // Use actual constant value
            // Purchase one additional slot batch (5 slots)
            vm.startPrank(PLAYER_ONE);
            uint256 batchCost = playerContract.getNextSlotBatchCost(PLAYER_ONE);
            vm.deal(PLAYER_ONE, batchCost);
            playerContract.purchasePlayerSlots{value: batchCost}();
            vm.stopPrank();

            // Fill up all new slots
            uint256 newSlotCount = playerContract.getPlayerSlots(PLAYER_ONE);
            while (playerContract.getActivePlayerCount(PLAYER_ONE) < newSlotCount) {
                _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, true);
            }

            // Verify slot count matches active players
            assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), newSlotCount);
        }
    }

    function test_RevertWhen_MaxPlayersReached() public {
        // Fill up default slots first
        uint256 defaultSlots = playerContract.getPlayerSlots(PLAYER_ONE);
        for (uint256 i = 0; i < defaultSlots; i++) {
            _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        }

        // Verify we hit the default slots limit
        uint256 activeCount = playerContract.getActivePlayerCount(PLAYER_ONE);
        assertEq(activeCount, defaultSlots);

        // Try to create one more without purchasing slots - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 feeAmount = playerContract.createPlayerFeeAmount();
        vm.deal(PLAYER_ONE, feeAmount);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.requestCreatePlayer{value: feeAmount}(false);
        vm.stopPrank();
    }

    function test_RevertWhen_AbsoluteMaxSlotsReached() public {
        // Fill up to max slots (200)
        while (playerContract.getPlayerSlots(PLAYER_ONE) < 200) {
            // Purchase slots
            vm.startPrank(PLAYER_ONE);
            uint256 batchCostTmp = playerContract.getNextSlotBatchCost(PLAYER_ONE);
            vm.deal(PLAYER_ONE, batchCostTmp);
            playerContract.purchasePlayerSlots{value: batchCostTmp}();
            vm.stopPrank();

            // Fill new slots
            uint256 newSlotCount = playerContract.getPlayerSlots(PLAYER_ONE);
            while (playerContract.getActivePlayerCount(PLAYER_ONE) < newSlotCount) {
                _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, true);
            }
        }

        // Try to purchase more slots at max - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 batchCost = playerContract.getNextSlotBatchCost(PLAYER_ONE);
        vm.deal(PLAYER_ONE, batchCost);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.purchasePlayerSlots{value: batchCost}();
        vm.stopPrank();

        // Try to create one more player at max - should revert
        vm.startPrank(PLAYER_ONE);
        uint256 feeAmount = playerContract.createPlayerFeeAmount();
        vm.deal(PLAYER_ONE, feeAmount);
        vm.expectRevert(TooManyPlayers.selector);
        playerContract.requestCreatePlayer{value: feeAmount}(true);
        vm.stopPrank();
    }

    function testMultiplePlayersWithVRF() public {
        address playerTwo = address(0x2);

        // Create players
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 playerId2 = _createPlayerAndFulfillVRF(playerTwo, playerContract, false);

        // Verify both players were created with correct owners
        _assertPlayerState(playerContract, playerId1, PLAYER_ONE, true);
        _assertPlayerState(playerContract, playerId2, playerTwo, true);

        // Verify players have different IDs
        assertTrue(playerId1 != playerId2, "Players should have different IDs");

        // Verify each player's stats
        IPlayer.PlayerStats memory stats1 = playerContract.getPlayer(playerId1);
        IPlayer.PlayerStats memory stats2 = playerContract.getPlayer(playerId2);
        _assertStatRanges(stats1);
        _assertStatRanges(stats2);
    }

    function testFailCreatePlayerBeforeVRFFulfillment() public {
        // First player creation request
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount() * 2); // Enough for two attempts
        vm.startPrank(PLAYER_ONE);
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);

        // Try to create another player before VRF fulfillment (should fail)
        vm.expectRevert("Pending request exists");
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();

        // Now fulfill the VRF and verify we can create another player
        uint256 randomness = uint256(keccak256(abi.encodePacked("test randomness")));
        vm.prank(operator);
        bytes memory data = abi.encode(335, abi.encode(0, ""));
        playerContract.fulfillRandomness(randomness, data);

        // Should now be able to create another player
        vm.prank(PLAYER_ONE);
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
    }

    function testFulfillRandomnessNonOperator() public {
        // Create player request
        uint256 requestId = _createPlayerRequest(PLAYER_ONE, playerContract, true);

        bytes32 requestHash = playerContract.requestedHash(requestId);
        assertTrue(requestHash != bytes32(0), "Request hash should be set");
        assertTrue(playerContract.requestPending(requestId), "Request should be pending");

        // Try to fulfill as non-operator
        address nonOperator = address(0xBEEF);
        vm.prank(nonOperator);
        vm.expectRevert("only operator");
        bytes memory data = abi.encode(0, abi.encode(requestId, ""));
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), data);
    }

    function testFulfillRandomnessNotValidRoundId() public {
        // Create player request
        uint256 requestId = _createPlayerRequest(PLAYER_ONE, playerContract, true);

        // Store the original request hash
        bytes32 originalHash = playerContract.requestedHash(requestId);
        assertTrue(originalHash != bytes32(0), "Request hash should be set");

        // Try to fulfill with invalid round ID
        vm.prank(operator);
        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(335 + 1, innerData);

        // This should NOT revert, but should not fulfill the request
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);

        // Verify the request hash is deleted but request is still pending
        assertTrue(playerContract.requestPending(requestId), "Request should still be pending");
        assertEq(playerContract.requestedHash(requestId), bytes32(0), "Request hash should be deleted");
    }

    function testEquipSkin() public {
        // First create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin to player
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Leather,
            IGameDefinitions.FightingStance.Balanced
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skinIndex, skinIndex, "Skin index should be updated");
        assertEq(player.skinTokenId, tokenId, "Token ID should be updated");
    }

    function testCannotEquipToUnownedPlayer() public {
        // First create a player owned by PLAYER_ONE
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Register a new skin collection
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Test Skin Collection", "TSC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin to a different address
        address otherAddress = address(0x2);
        vm.deal(otherAddress, 0.01 ether);
        vm.startPrank(otherAddress);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            otherAddress,
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Defensive
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Try to equip the skin (should fail)
        vm.expectRevert(abi.encodeWithSignature("PlayerDoesNotExist(uint32)", 1000));
        playerContract.equipSkin(playerId, skinIndex, tokenId);
        vm.stopPrank();

        // Now try to equip the same skin as PLAYER_ONE (who owns the player but not the skin)
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("NotSkinOwner()"));
        playerContract.equipSkin(playerId, skinIndex, tokenId);
        vm.stopPrank();
    }

    function testCannotEquipInvalidSkinIndex() public {
        // First create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Try to equip a non-existent skin collection
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        playerContract.equipSkin(playerId, 999, 1);
        vm.stopPrank();
    }

    function testNameRandomness() public skipInCI {
        // Create multiple players and track name frequencies
        uint256 numPlayers = 20; // Reduced from 50 to avoid gas limits
        uint256[] memory firstNameCounts = new uint256[](nameRegistry.SET_A_START() + nameRegistry.getNameSetALength());
        uint256[] memory surnameCounts = new uint256[](nameRegistry.getSurnamesLength());

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            address player = address(uint160(i + 1));
            vm.deal(player, playerContract.createPlayerFeeAmount());

            vm.startPrank(player);
            uint256 requestId =
                playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(i % 2 == 0);
            vm.stopPrank();

            bytes32 requestHash = playerContract.requestedHash(requestId);

            vm.prank(operator);
            playerContract.fulfillRandomness(
                uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i))),
                abi.encode(335, abi.encode(requestId, ""))
            );

            uint32 playerId = playerContract.getPlayerIds(player)[0];
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            firstNameCounts[stats.firstNameIndex]++;
            surnameCounts[stats.surnameIndex]++;
        }

        // Verify we got some variety in names
        uint256 uniqueFirstNames = 0;
        uint256 uniqueSurnames = 0;

        // Count unique first names
        for (uint16 i = 0; i < nameRegistry.getNameSetBLength(); i++) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }
        for (
            uint16 i = nameRegistry.SET_A_START();
            i < nameRegistry.SET_A_START() + nameRegistry.getNameSetALength();
            i++
        ) {
            if (firstNameCounts[i] > 0) uniqueFirstNames++;
        }

        // Count unique surnames
        for (uint16 i = 0; i < nameRegistry.getSurnamesLength(); i++) {
            if (surnameCounts[i] > 0) uniqueSurnames++;
        }

        // We should have a good distribution of names
        assertTrue(uniqueFirstNames > 3, "Should have multiple different first names");
        assertTrue(uniqueSurnames > 3, "Should have multiple different surnames");

        // Make sure we're not always getting the default names
        assertTrue(firstNameCounts[0] < numPlayers, "Too many default Set B names");
        assertTrue(firstNameCounts[nameRegistry.SET_A_START()] < numPlayers, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers, "Too many default surnames");
    }

    function test_PlayerCreation(address player) public {
        // Skip zero address and contracts
        vm.assume(player != address(0));
        vm.assume(uint160(player) > 0x10000); // Skip precompiles

        // Give enough ETH for the fee
        vm.deal(player, playerContract.createPlayerFeeAmount());

        vm.startPrank(player);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
        vm.stopPrank();

        bytes32 requestHash = playerContract.requestedHash(requestId);

        vm.prank(operator);
        playerContract.fulfillRandomness(
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, player))),
            abi.encode(335, abi.encode(requestId, ""))
        );

        uint32 playerId = playerContract.getPlayerIds(player)[0];

        // Get and validate player stats
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

        assertTrue(stats.strength >= 3 && stats.strength <= 21, "Invalid strength");
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21, "Invalid constitution");
        assertTrue(stats.size >= 3 && stats.size <= 21, "Invalid size");
        assertTrue(stats.agility >= 3 && stats.agility <= 21, "Invalid agility");
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21, "Invalid stamina");
        assertTrue(stats.luck >= 3 && stats.luck <= 21, "Invalid luck");

        // Verify total points are within expected range
        uint256 totalPoints = uint256(stats.strength) + uint256(stats.constitution) + uint256(stats.size)
            + uint256(stats.agility) + uint256(stats.stamina) + uint256(stats.luck);
        assertTrue(totalPoints >= 18 && totalPoints <= 126, "Total points out of range");
    }

    function test_statDistribution() public {
        uint256 numPlayers = 100;
        // Ensure we have enough slots for the test
        _ensurePlayerSlots(PLAYER_ONE, numPlayers, playerContract);

        uint256 maxStatCount = 0;
        uint256 highStatCount = 0;
        uint256 medStatCount = 0;
        uint256 lowStatCount = 0;

        for (uint256 i = 0; i < numPlayers; i++) {
            uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

            // Check each stat
            uint8[6] memory statArray =
                [stats.strength, stats.constitution, stats.size, stats.agility, stats.stamina, stats.luck];

            for (uint256 j = 0; j < 6; j++) {
                if (statArray[j] >= 19) maxStatCount++; // 19-21

                else if (statArray[j] >= 16) highStatCount++; // 16-18

                else if (statArray[j] >= 13) medStatCount++; // 13-15

                else lowStatCount++; // 3-12
            }
        }

        // Total stats checked = numPlayers * 6 stats per player
        uint256 totalStats = numPlayers * 6;

        // Log distributions
        console2.log("Stat Distribution for %d total stats:", totalStats);
        console2.log("Max stats (19-21): %d (%d%%)", maxStatCount, (maxStatCount * 100) / totalStats);
        console2.log("High stats (16-18): %d (%d%%)", highStatCount, (highStatCount * 100) / totalStats);
        console2.log("Med stats (13-15): %d (%d%%)", medStatCount, (medStatCount * 100) / totalStats);
        console2.log("Low stats (3-12): %d (%d%%)", lowStatCount, (lowStatCount * 100) / totalStats);

        // Verify rough distributions
        // Max stats should still be relatively rare (<20%)
        assertLt(maxStatCount * 100 / totalStats, 20);
        // Low stats should still be most common (>40%)
        assertGt(lowStatCount * 100 / totalStats, 40);
    }

    function testRetireOwnPlayer() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Retire the player
        vm.startPrank(PLAYER_ONE);
        playerContract.retireOwnPlayer(playerId);
        vm.stopPrank();

        // Verify player is retired
        assertTrue(playerContract.isPlayerRetired(playerId), "Player should be retired");
    }

    function testCannotRetireOtherPlayerCharacter() public {
        // Create a player owned by address(1)
        vm.prank(address(1));
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Try to retire it from address(2)
        vm.prank(address(2));
        vm.expectRevert(NotPlayerOwner.selector);
        playerContract.retireOwnPlayer(playerId);

        // Verify player is not retired
        assertFalse(playerContract.isPlayerRetired(playerId), "Player should not be retired");
    }

    function testGetPlayerIds() public {
        // Create multiple players for PLAYER_ONE
        uint32[] memory playerIds = new uint32[](3);
        for (uint256 i = 0; i < 3; i++) {
            playerIds[i] = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        }

        // Get all player IDs for PLAYER_ONE
        uint32[] memory retrievedIds = playerContract.getPlayerIds(PLAYER_ONE);

        // Verify we got all the IDs
        assertEq(retrievedIds.length, 3, "Should have 3 players");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(retrievedIds[i], playerIds[i], "Player ID mismatch");
        }
    }

    function testEquipUnlockableCollection() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Create unlock NFT
        UnlockNFT unlockNFT = new UnlockNFT();

        // Create skin collection that requires unlock NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Unlockable Collection", "UC", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection with unlock requirement
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));
        skinRegistry.setDefaultCollection(skinIndex, false); // Make sure it's not a default collection

        // Try to equip without owning unlock NFT (should fail)
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.Greatsword,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Offensive
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Now mint unlock NFT and try again (should succeed)
        unlockNFT.mint(PLAYER_ONE);
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(playerId, skinIndex, tokenId);

        // Verify skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skinIndex, skinIndex);
        assertEq(player.skinTokenId, tokenId);
    }

    function testEquipOwnedSkin() public {
        // Create player and equip skin
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Deploy and register a new skin NFT
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("TestSkin", "TEST", 0.01 ether);
        skinNFT.setMintingEnabled(true);

        // Register the skin collection
        vm.deal(address(this), skinRegistry.registrationFee());
        uint32 skinIndex = skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(address(skinNFT));
        skinRegistry.setSkinVerification(skinIndex, true);

        // Mint skin to player
        vm.deal(PLAYER_ONE, 0.01 ether);
        vm.startPrank(PLAYER_ONE);
        skinNFT.mintSkin{value: skinNFT.mintPrice()}(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Offensive
        );
        uint16 tokenId = 1;
        vm.stopPrank();

        // Equip the skin
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, skinIndex);
        assertEq(stats.skinTokenId, tokenId);
    }

    function testPlayerCreationEvents() public {
        // Give enough ETH for the fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());

        vm.startPrank(PLAYER_ONE);
        vm.expectEmit(true, true, false, false);
        emit PlayerCreationRequested(0, PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(true);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit PlayerCreationFulfilled(requestId, 1000, PLAYER_ONE);
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    function testFailCreatePlayerWithInsufficientFee() public {
        // Try to create a player with insufficient fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount() / 2);
        vm.startPrank(PLAYER_ONE);
        vm.expectRevert("Insufficient fee amount");
        playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount() / 2}(true);
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // Create a player and pay the fee
        uint256 initialBalance = address(this).balance;
        _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Verify fees were collected
        uint256 collectedFees = address(playerContract).balance;
        assertTrue(collectedFees > 0, "Fees should be collected");

        // Withdraw fees as owner
        playerContract.withdrawFees();

        // Verify balances after withdrawal
        _assertBalances(address(playerContract), 0, "Contract balance should be 0 after withdrawal");
        _assertBalances(address(this), initialBalance + collectedFees, "Owner should receive all fees");
    }

    function testEquipCollectionBasedSkin() public {
        // Create player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Create unlock NFT (like Shapecraft Key)
        PlayerSkinNFT unlockNFT = new PlayerSkinNFT("Unlock NFT", "UNLOCK", 0);
        unlockNFT.setMintingEnabled(true);

        // Create skin collection where skins stay with contract
        PlayerSkinNFT skinNFT = new PlayerSkinNFT("Collection Skins", "CSKIN", 0);
        skinNFT.setMintingEnabled(true);

        // Register skin with unlock requirement
        uint32 skinIndex = _registerSkin(address(skinNFT));
        skinRegistry.setRequiredNFT(skinIndex, address(unlockNFT));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setDefaultCollection(skinIndex, false); // Make sure it's not a default collection

        // Mint unlock NFT to player
        vm.startPrank(PLAYER_ONE);
        unlockNFT.mintSkin(
            PLAYER_ONE,
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Balanced
        );
        vm.stopPrank();

        // Mint skin but keep it in contract
        skinNFT.mintSkin(
            address(skinNFT), // Mint to contract itself, not PLAYER_ONE
            IGameDefinitions.WeaponType.SwordAndShield,
            IGameDefinitions.ArmorType.Plate,
            IGameDefinitions.FightingStance.Balanced
        );
        uint16 tokenId = 1;

        // Should be able to equip with just unlock NFT
        _equipSkinToPlayer(playerId, skinIndex, tokenId, true);

        // Verify the skin was equipped
        IPlayer.PlayerStats memory player = playerContract.getPlayer(playerId);
        assertEq(player.skinIndex, skinIndex, "Skin index should be updated");
        assertEq(player.skinTokenId, tokenId, "Token ID should be updated");
    }

    function testActivePlayerCountTracking() public {
        // Initial count should be 0
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 0);

        // Create first player and verify count
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Create second player and verify count
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 2);

        // Retire first player as owner
        vm.prank(PLAYER_ONE);
        playerContract.retireOwnPlayer(playerId1);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Try to retire same player again (should fail)
        vm.prank(PLAYER_ONE);
        vm.expectRevert(abi.encodeWithSignature("PlayerIsRetired(uint32)", playerId1));
        playerContract.retireOwnPlayer(playerId1);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);

        // Grant RETIRE permission to game contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: true, name: false, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Test game contract retirement
        playerContract.setPlayerRetired(playerId2, true);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 0);

        // Un-retire a player
        playerContract.setPlayerRetired(playerId2, false);
        assertEq(playerContract.getActivePlayerCount(PLAYER_ONE), 1);
    }

    function testImmortalityStatus() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Check initial state - should not be immortal
        assertFalse(playerContract.isPlayerImmortal(playerId));

        // Grant immortal permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: false, immortal: true});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set player as immortal
        playerContract.setPlayerImmortal(playerId, true);
        assertTrue(playerContract.isPlayerImmortal(playerId));

        // Toggle immortality off
        playerContract.setPlayerImmortal(playerId, false);
        assertFalse(playerContract.isPlayerImmortal(playerId));
    }

    function testCannotSetImmortalWithoutPermission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Try to set immortal without permission
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, true);
    }

    function testCannotSetImmortalForNonexistentPlayer() public {
        // Grant immortal permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: false, immortal: true});
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to set immortal for non-existent player
        uint32 nonExistentPlayerId = 999;
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, nonExistentPlayerId));
        playerContract.setPlayerImmortal(nonExistentPlayerId, true);
    }

    function testImmortalityEventEmission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: false, immortal: true});
        playerContract.setGameContractPermission(address(this), permissions);

        // Expect event when setting to true
        vm.expectEmit(true, true, false, true);
        emit PlayerImmortalityChanged(playerId, address(this), true);
        playerContract.setPlayerImmortal(playerId, true);

        // Expect event when setting to false
        vm.expectEmit(true, true, false, true);
        emit PlayerImmortalityChanged(playerId, address(this), false);
        playerContract.setPlayerImmortal(playerId, false);
    }

    function testMultiplePlayersImmortalityIndependence() public {
        // Create two players
        uint32 playerId1 = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
        uint32 playerId2 = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: false, immortal: true});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set only player 1 as immortal
        playerContract.setPlayerImmortal(playerId1, true);

        // Verify independence
        assertTrue(playerContract.isPlayerImmortal(playerId1), "Player 1 should be immortal");
        assertFalse(playerContract.isPlayerImmortal(playerId2), "Player 2 should not be immortal");
    }

    function testImmortalityPermissionRevocation() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Grant immortal permission
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: false, retire: false, name: false, attributes: false, immortal: true});
        playerContract.setGameContractPermission(address(this), permissions);

        // Set player as immortal
        playerContract.setPlayerImmortal(playerId, true);

        // Revoke permission
        permissions.immortal = false;
        playerContract.setGameContractPermission(address(this), permissions);

        // Try to modify immortality after revocation
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, false);
    }

    function testOwnerCannotBypassImmortalityPermission() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Even as owner, should not be able to set immortality without permission
        vm.startPrank(playerContract.owner());
        vm.expectRevert(abi.encodeWithSelector(NoPermission.selector));
        playerContract.setPlayerImmortal(playerId, true);
        vm.stopPrank();
    }

    function testPlayerCreatedEvent() public {
        // Give enough ETH for the fee
        vm.deal(PLAYER_ONE, playerContract.createPlayerFeeAmount());

        // Create player request
        vm.startPrank(PLAYER_ONE);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(false);
        vm.stopPrank();

        // Record logs for event verification
        vm.recordLogs();

        // Fulfill VRF request using helper
        _fulfillVRF(requestId, _generateGameSeed(), address(playerContract));

        // Get the logs and find our PlayerCreated event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundPlayerCreatedEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            // Check if this is our PlayerCreated event
            if (
                entries[i].topics[0]
                    == keccak256("PlayerCreated(uint32,uint16,uint16,uint8,uint8,uint8,uint8,uint8,uint8)")
            ) {
                foundPlayerCreatedEvent = true;

                // Get playerId from first indexed parameter
                uint32 playerId = uint32(uint256(entries[i].topics[1]));
                uint16 firstNameIndex = uint16(uint256(entries[i].topics[2]));
                uint16 surnameIndex = uint16(uint256(entries[i].topics[3]));

                // Decode the non-indexed parameters
                (uint8 strength, uint8 constitution, uint8 size, uint8 agility, uint8 stamina, uint8 luck) =
                    abi.decode(entries[i].data, (uint8, uint8, uint8, uint8, uint8, uint8));

                // Get stored player data for comparison
                IPlayer.PlayerStats memory storedStats = playerContract.getPlayer(playerId);

                // Use TestBase helper to verify stat ranges
                _assertStatRanges(storedStats);

                // Verify stats match stored data
                assertEq(storedStats.firstNameIndex, firstNameIndex, "First name index mismatch");
                assertEq(storedStats.surnameIndex, surnameIndex, "Surname index mismatch");
                assertEq(storedStats.strength, strength, "Strength mismatch");
                assertEq(storedStats.constitution, constitution, "Constitution mismatch");
                assertEq(storedStats.size, size, "Size mismatch");
                assertEq(storedStats.agility, agility, "Agility mismatch");
                assertEq(storedStats.stamina, stamina, "Stamina mismatch");
                assertEq(storedStats.luck, luck, "Luck mismatch");

                // Verify total stats equal 72
                uint16 totalStats = uint16(strength) + constitution + size + agility + stamina + luck;
                assertEq(totalStats, 72, "Total stats should equal 72");

                // Verify name indices are within valid ranges
                // For Set A names
                bool validFirstName = firstNameIndex >= nameRegistry.SET_A_START()
                    && firstNameIndex < (nameRegistry.SET_A_START() + nameRegistry.getNameSetALength())
                // For Set B names
                || firstNameIndex < nameRegistry.getNameSetBLength();

                assertTrue(validFirstName, "First name index out of range");
                assertTrue(surnameIndex < nameRegistry.getSurnamesLength(), "Surname index out of range");
            }
        }

        assertTrue(foundPlayerCreatedEvent, "PlayerCreated event was not emitted");
    }

    function testWinLossKillEvents() public {
        // Create a player
        uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);

        // Grant RECORD permission to test contract
        IPlayer.GamePermissions memory permissions =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
        playerContract.setGameContractPermission(address(this), permissions);

        // Test win event
        vm.recordLogs();
        playerContract.incrementWins(playerId);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundWinLossEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerWinLossUpdated(uint32,uint16,uint16)")) {
                foundWinLossEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                (uint16 wins, uint16 losses) = abi.decode(entries[i].data, (uint16, uint16));

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(wins, 1, "Wins should be 1");
                assertEq(losses, 0, "Losses should be 0");
            }
        }
        assertTrue(foundWinLossEvent, "PlayerWinLossUpdated event not emitted for win");

        // Test loss event
        vm.recordLogs();
        playerContract.incrementLosses(playerId);
        entries = vm.getRecordedLogs();
        foundWinLossEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerWinLossUpdated(uint32,uint16,uint16)")) {
                foundWinLossEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                (uint16 wins, uint16 losses) = abi.decode(entries[i].data, (uint16, uint16));

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(wins, 1, "Wins should still be 1");
                assertEq(losses, 1, "Losses should be 1");
            }
        }
        assertTrue(foundWinLossEvent, "PlayerWinLossUpdated event not emitted for loss");

        // Test kill event
        vm.recordLogs();
        playerContract.incrementKills(playerId);
        entries = vm.getRecordedLogs();
        bool foundKillEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("PlayerKillUpdated(uint32,uint16)")) {
                foundKillEvent = true;
                uint32 eventPlayerId = uint32(uint256(entries[i].topics[1]));
                uint16 kills = abi.decode(entries[i].data, (uint16));

                assertEq(eventPlayerId, playerId, "Player ID mismatch");
                assertEq(kills, 1, "Kills should be 1");
            }
        }
        assertTrue(foundKillEvent, "PlayerKillUpdated event not emitted");
    }

    // Skin Equipment Helper
    function _equipSkinToPlayer(uint32 playerId, uint32 skinIndexToEquip, uint16 tokenId, bool shouldSucceed)
        internal
    {
        vm.startPrank(PLAYER_ONE);
        if (shouldSucceed) {
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId);
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            assertEq(stats.skinIndex, skinIndexToEquip);
            assertEq(stats.skinTokenId, tokenId);
        } else {
            vm.expectRevert(InvalidPlayerStats.selector);
            playerContract.equipSkin(playerId, skinIndexToEquip, tokenId);
        }
        vm.stopPrank();
    }

    receive() external payable {}
}
