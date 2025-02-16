// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IGameEngine} from "../src/interfaces/IGameEngine.sol";
import "./utils/TestBase.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {Player} from "../src/Player.sol";
import {Fighter} from "../src/Fighter.sol";

contract ActionPointsTest is TestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_QuarterstaffDoubleAttack() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1;

        Fighter.PlayerLoadout memory fastLoadout =
            Fighter.PlayerLoadout({playerId: fastWeaponId, skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId});

        Fighter.PlayerLoadout memory slowLoadout =
            Fighter.PlayerLoadout({playerId: slowWeaponId, skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId});

        bytes memory results = gameEngine.processGame(
            _getFighterContract(fastLoadout.playerId).convertToFighterStats(fastLoadout),
            _getFighterContract(slowLoadout.playerId).convertToFighterStats(slowLoadout),
            _generateGameSeed(),
            0
        );

        // Add before decoding:
        console2.log("Raw Results Length:", results.length);
        for (uint256 i = 0; i < (results.length < 20 ? results.length : 20); i++) {
            console2.log("Byte", i, ":", uint8(results[i]));
        }

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        uint256 fastAttacks = 0;
        uint256 slowAttacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p1Result)) {
                fastAttacks++;
            }
            if (!_isDefensiveResult(actions[i].p2Result)) {
                slowAttacks++;
            }
        }

        // Assert ratio is between 1.5 and 3.0 (using integer math)
        // 15/10 = 1.5, 30/10 = 3.0
        require(
            fastAttacks * 10 >= slowAttacks * 15 && fastAttacks * 10 <= slowAttacks * 30,
            "Fast weapon should attack roughly twice as often as slow weapon"
        );

        console2.log("---Combat Summary---");
        console2.log("Total Rounds:", actions.length);
        console2.log("P1 Total Attacks:", fastAttacks);
        console2.log("P2 Total Attacks:", slowAttacks);
        console2.log("\n---Round Details---");
        for (uint256 i = 0; i < actions.length; i++) {
            console2.log("\nRound", i);
            console2.log("P1 Result Type:", uint8(actions[i].p1Result));
            console2.log("P1 Damage:", actions[i].p1Damage);
            console2.log("P1 Stamina Lost:", actions[i].p1StaminaLost);
            console2.log("P2 Result Type:", uint8(actions[i].p2Result));
            console2.log("P2 Damage:", actions[i].p2Damage);
            console2.log("P2 Stamina Lost:", actions[i].p2StaminaLost);
            console2.log("---");
        }
    }

    function test_QuarterstaffDoubleAttackPlayerBias() public view {
        uint16 fastWeaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;
        uint16 slowWeaponId = uint16(DefaultPlayerLibrary.CharacterType.BattleaxeOffensive) + 1;

        Fighter.PlayerLoadout memory fastLoadout =
            Fighter.PlayerLoadout({playerId: fastWeaponId, skinIndex: defaultSkinIndex, skinTokenId: fastWeaponId});

        Fighter.PlayerLoadout memory slowLoadout =
            Fighter.PlayerLoadout({playerId: slowWeaponId, skinIndex: defaultSkinIndex, skinTokenId: slowWeaponId});

        bytes memory results = gameEngine.processGame(
            _getFighterContract(slowLoadout.playerId).convertToFighterStats(slowLoadout),
            _getFighterContract(fastLoadout.playerId).convertToFighterStats(fastLoadout),
            _generateGameSeed(),
            0
        );

        // Add before decoding:
        console2.log("Raw Results Length:", results.length);
        for (uint256 i = 0; i < (results.length < 20 ? results.length : 20); i++) {
            console2.log("Byte", i, ":", uint8(results[i]));
        }

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        uint256 fastAttacks = 0;
        uint256 slowAttacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p2Result)) {
                fastAttacks++;
            }
            if (!_isDefensiveResult(actions[i].p1Result)) {
                slowAttacks++;
            }
        }

        // Assert ratio is between 1.5 and 3.0 (using integer math)
        // 15/10 = 1.5, 30/10 = 3.0
        require(
            fastAttacks * 10 >= slowAttacks * 15 && fastAttacks * 10 <= slowAttacks * 30,
            "Fast weapon should attack roughly twice as often as slow weapon"
        );

        console2.log("---Combat Summary---");
        console2.log("Total Rounds:", actions.length);
        console2.log("P1 Total Attacks:", fastAttacks);
        console2.log("P2 Total Attacks:", slowAttacks);
        console2.log("\n---Round Details---");
        for (uint256 i = 0; i < actions.length; i++) {
            console2.log("\nRound", i);
            console2.log("P1 Result Type:", uint8(actions[i].p1Result));
            console2.log("P1 Damage:", actions[i].p1Damage);
            console2.log("P1 Stamina Lost:", actions[i].p1StaminaLost);
            console2.log("P2 Result Type:", uint8(actions[i].p2Result));
            console2.log("P2 Damage:", actions[i].p2Damage);
            console2.log("P2 Stamina Lost:", actions[i].p2StaminaLost);
            console2.log("---");
        }
    }

    function test_SameWeaponInitiative() public view {
        uint16 weaponId = uint16(DefaultPlayerLibrary.CharacterType.QuarterstaffDefensive) + 1;

        Fighter.PlayerLoadout memory p1Loadout =
            Fighter.PlayerLoadout({playerId: weaponId, skinIndex: defaultSkinIndex, skinTokenId: weaponId});

        Fighter.PlayerLoadout memory p2Loadout =
            Fighter.PlayerLoadout({playerId: weaponId, skinIndex: defaultSkinIndex, skinTokenId: weaponId});

        bytes memory results = gameEngine.processGame(
            _getFighterContract(p1Loadout.playerId).convertToFighterStats(p1Loadout),
            _getFighterContract(p2Loadout.playerId).convertToFighterStats(p2Loadout),
            _generateGameSeed(),
            0
        );

        // Add before decoding:
        console2.log("Raw Results Length:", results.length);
        for (uint256 i = 0; i < (results.length < 20 ? results.length : 20); i++) {
            console2.log("Byte", i, ":", uint8(results[i]));
        }

        (,,, IGameEngine.CombatAction[] memory actions) = gameEngine.decodeCombatLog(results);

        uint256 p1Attacks = 0;
        uint256 p2Attacks = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            if (!_isDefensiveResult(actions[i].p1Result)) {
                p1Attacks++;
            }
            if (!_isDefensiveResult(actions[i].p2Result)) {
                p2Attacks++;
            }
        }

        // Assert attack counts differ by at most 1
        require(
            p1Attacks == p2Attacks || p1Attacks == p2Attacks + 1 || p1Attacks + 1 == p2Attacks,
            "Attack counts should differ by at most 1"
        );

        // Assert perfect alternating pattern between P1 and P2
        for (uint256 i = 0; i < actions.length; i++) {
            bool p1Attacked = !_isDefensiveResult(actions[i].p1Result);
            bool p2Attacked = !_isDefensiveResult(actions[i].p2Result);
            require(p1Attacked != p2Attacked, "Each round should have exactly one attacker");
        }
    }
}
