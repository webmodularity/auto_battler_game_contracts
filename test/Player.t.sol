// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Player, InvalidContractAddress, PlayerDoesNotExist} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import "../src/interfaces/IPlayer.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "./utils/TestBase.sol";

// Add events from Player contract
event EquipmentStatsUpdated(address indexed oldStats, address indexed newStats);

event SkinRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

event NameRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

contract PlayerTest is TestBase {
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    PlayerEquipmentStats public equipmentStats;
    DefaultPlayerSkinNFT public defaultSkin;
    uint32 public skinIndex;

    address public constant PLAYER_ONE = address(0x1);
    uint256 public constant PLAYER_ONE_ID = 1;

    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);

    function setUp() public {
        setupRandomness();

        // Deploy contracts in correct order
        equipmentStats = new PlayerEquipmentStats();
        skinRegistry = new PlayerSkinRegistry();
        nameRegistry = new PlayerNameRegistry();
        playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats));

        // Deploy default skin contract
        defaultSkin = new DefaultPlayerSkinNFT();

        // Register default skin and get collection index
        vm.deal(address(this), 1 ether);
        skinIndex = skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
    }

    function _validatePlayerAttributes(IPlayer.PlayerStats memory stats, string memory context) private pure {
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        uint16 total = uint16(stats.strength) + uint16(stats.constitution) + uint16(stats.size) + uint16(stats.agility)
            + uint16(stats.stamina) + uint16(stats.luck);
        assertEq(total, 72, string.concat(context, ": Total attributes should be 72"));
    }

    function testCreatePlayer() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        address player = address(0x1);
        vm.prank(player);
        (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer(true);
        assertTrue(playerId > 0, "Player ID should be non-zero");
        _validatePlayerAttributes(newPlayer, "Single player test");
    }

    function testMultiplePlayers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(uint160(i + 1)));
            (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer(i % 2 == 0);
            assertTrue(playerId > 0, "Player ID should be non-zero");
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }

    function testStatRanges() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        vm.prank(PLAYER_ONE);
        (uint256 playerId, IPlayer.PlayerStats memory stats) = playerContract.createPlayer(true);
        IPlayer.CalculatedStats memory calculated = playerContract.calculateStats(stats);

        // Update expected ranges for new health calculation
        assertTrue(calculated.maxHealth >= 75 + 36 + 18, "Health below min"); // Min stats (3) = 75 + (3*12) + (3*6)
        assertTrue(calculated.maxHealth <= 75 + 252 + 126, "Health above max"); // Max stats (21) = 75 + (21*12) + (21*6)

        // ... rest of test assertions ...
    }

    function assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc) internal pure {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Updated calculated stat bounds based on new formulas
        uint256 minHealth = 45 + (3 * 8) + (3 * 4); // min constitution and size
        uint256 maxHealth = 45 + (21 * 8) + (21 * 4); // max constitution and size
        assertTrue(calc.maxHealth >= minHealth && calc.maxHealth <= maxHealth, "Health out of range");

        assertTrue(calc.damageModifier >= 50 && calc.damageModifier <= 200, "Damage mod out of range");
        assertTrue(calc.hitChance >= 30 && calc.hitChance <= 100, "Hit chance out of range");
        assertTrue(calc.critChance <= 50, "Crit chance too high");
        assertTrue(calc.critMultiplier >= 150 && calc.critMultiplier <= 300, "Crit multiplier out of range");
    }

    function testEquipSkin() public {
        // Create a player
        vm.startPrank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer(true);
        vm.stopPrank();

        // Register the skin contract and set as default
        vm.deal(address(this), 1 ether);
        skinIndex = skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);

        // Mint default skin with basic equipment (no stat requirements)
        IPlayer.PlayerStats memory stats = IPlayer.PlayerStats({
            strength: 10,
            constitution: 10,
            size: 10,
            agility: 10,
            stamina: 10,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: 1,
            firstNameIndex: 1,
            surnameIndex: 1
        });

        uint16 tokenId = defaultSkin.mintDefaultPlayerSkin(
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Cloth,
            IPlayerSkinNFT.FightingStance.Balanced,
            stats,
            "QmRLKFYsTAk4d39KeNTpzXPt1iFwux4YkMsVuopfszhMT5"
        );

        // Now try to equip as PLAYER_ONE
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(playerId, skinIndex, tokenId);

        // Verify skin is equipped
        IPlayer.PlayerStats memory playerStats = playerContract.getPlayer(playerId);
        assertEq(playerStats.skinIndex, skinIndex, "Skin index should match");
        assertEq(playerStats.skinTokenId, tokenId, "Skin token ID should match");
    }

    function testCannotEquipToUnownedPlayer() public {
        // Create a player owned by address(0x1)
        vm.prank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer(true);

        // Register the skin contract and set as default
        vm.deal(address(this), 1 ether);
        skinIndex = skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);

        // Mint default skin to address(0x2)
        address otherPlayer = address(0x2);
        IPlayer.PlayerStats memory stats = IPlayer.PlayerStats({
            strength: 10,
            constitution: 10,
            size: 10,
            agility: 10,
            stamina: 10,
            luck: 10,
            skinIndex: skinIndex,
            skinTokenId: 1,
            firstNameIndex: 1,
            surnameIndex: 1
        });

        uint16 tokenId = defaultSkin.mintDefaultPlayerSkin(
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Cloth,
            IPlayerSkinNFT.FightingStance.Balanced,
            stats,
            "QmRLKFYsTAk4d39KeNTpzXPt1iFwux4YkMsVuopfszhMT5"
        );

        // Try to equip skin to player owned by address(0x1)
        vm.prank(otherPlayer);
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, playerId));
        playerContract.equipSkin(playerId, skinIndex, tokenId);
    }

    function testCannotEquipInvalidSkinIndex() public {
        // Create a player
        vm.prank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer(true);

        // Try to equip non-existent skin collection
        vm.prank(PLAYER_ONE);
        vm.expectRevert(); // Should revert when trying to access invalid skin index
        playerContract.equipSkin(playerId, 999, 1);
    }

    function testDefaultNameCombination() public {
        // Test Set B default name (index 0)
        (string memory firstName, string memory surname) = nameRegistry.getFullName(0, 0);
        assertEq(firstName, "Alex", "First default feminine name should be Alex");
        assertEq(surname, "the Novice", "First surname should be 'the Novice'");

        // Test Set A default name (index 1000)
        (firstName, surname) = nameRegistry.getFullName(1000, 0);
        assertEq(firstName, "Alex", "First default masculine name should be Alex");
        assertEq(surname, "the Novice", "First surname should be 'the Novice'");

        // Both should result in "Alex the Novice"
    }

    function testNameRandomness() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }

        // Create multiple players and track name frequencies
        uint256 numPlayers = 50;
        uint256[] memory firstNameCounts = new uint256[](2000); // Large enough for both sets
        uint256[] memory surnameCounts = new uint256[](100); // Large enough for surnames

        for (uint256 i = 0; i < numPlayers; i++) {
            // Create player alternating between Set A and Set B
            vm.prank(address(uint160(i + 1)));
            (uint256 playerId, IPlayer.PlayerStats memory stats) = playerContract.createPlayer(i % 2 == 0);

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
        assertTrue(uniqueFirstNames > 5, "Should have multiple different first names");
        assertTrue(uniqueSurnames > 5, "Should have multiple different surnames");

        // Make sure we're not always getting the default names
        assertTrue(firstNameCounts[0] < numPlayers / 2, "Too many default Set B names");
        assertTrue(firstNameCounts[nameRegistry.SET_A_START()] < numPlayers / 2, "Too many default Set A names");
        assertTrue(surnameCounts[0] < numPlayers / 2, "Too many default surnames");
    }

    function testSwapRegistries() public {
        // Deploy new registry contracts
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();
        PlayerSkinRegistry newSkinRegistry = new PlayerSkinRegistry();
        PlayerNameRegistry newNameRegistry = new PlayerNameRegistry();

        // Store old addresses for comparison
        address oldEquipmentStats = address(equipmentStats);
        address oldSkinRegistry = address(skinRegistry);
        address oldNameRegistry = address(nameRegistry);

        // Test equipment stats swap
        vm.expectEmit(true, true, false, false);
        emit EquipmentStatsUpdated(oldEquipmentStats, address(newEquipmentStats));
        playerContract.setEquipmentStats(address(newEquipmentStats));
        assertEq(address(playerContract.equipmentStats()), address(newEquipmentStats));

        // Test skin registry swap
        vm.expectEmit(true, true, false, false);
        emit SkinRegistryUpdated(oldSkinRegistry, address(newSkinRegistry));
        playerContract.setSkinRegistry(address(newSkinRegistry));
        assertEq(address(playerContract.skinRegistry()), address(newSkinRegistry));

        // Test name registry swap
        vm.expectEmit(true, true, false, false);
        emit NameRegistryUpdated(oldNameRegistry, address(newNameRegistry));
        playerContract.setNameRegistry(address(newNameRegistry));
        assertEq(address(playerContract.nameRegistry()), address(newNameRegistry));
    }

    function testCannotSwapToZeroAddress() public {
        vm.expectRevert(InvalidContractAddress.selector);
        playerContract.setEquipmentStats(address(0));

        vm.expectRevert(InvalidContractAddress.selector);
        playerContract.setSkinRegistry(address(0));

        vm.expectRevert(InvalidContractAddress.selector);
        playerContract.setNameRegistry(address(0));
    }

    function testOwnerCanSwapRegistries() public {
        // We are the owner (test contract) so this should work
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();
        PlayerSkinRegistry newSkinRegistry = new PlayerSkinRegistry();
        PlayerNameRegistry newNameRegistry = new PlayerNameRegistry();

        // These should all succeed
        playerContract.setEquipmentStats(address(newEquipmentStats));
        playerContract.setSkinRegistry(address(newSkinRegistry));
        playerContract.setNameRegistry(address(newNameRegistry));

        // Verify the changes took effect
        assertEq(address(playerContract.equipmentStats()), address(newEquipmentStats));
        assertEq(address(playerContract.skinRegistry()), address(newSkinRegistry));
        assertEq(address(playerContract.nameRegistry()), address(newNameRegistry));
    }

    function testOnlyOwnerCanSwapRegistries() public {
        // Create a non-owner address
        address nonOwner = makeAddr("nonOwner");

        // Store original equipment stats address
        address originalEquipmentStats = address(playerContract.equipmentStats());

        // Transfer ownership away from test contract
        playerContract.transferOwnership(nonOwner);

        // Try to set new equipment stats (should fail)
        PlayerEquipmentStats newEquipmentStats = new PlayerEquipmentStats();

        // Just expect any revert - we don't care about the specific error
        vm.expectRevert();
        playerContract.setEquipmentStats(address(newEquipmentStats));

        // Verify equipment stats didn't change
        assertEq(
            address(playerContract.equipmentStats()), originalEquipmentStats, "Equipment stats should not have changed"
        );
    }
}
