// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IPlayer.sol";
import "../interfaces/IPlayerSkinNFT.sol";

library DefaultPlayerLibrary {
    function getDefaultWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = IPlayerSkinNFT.WeaponType.Quarterstaff;
        armor = IPlayerSkinNFT.ArmorType.Cloth;
        stance = IPlayerSkinNFT.FightingStance.Balanced;
        stats = IPlayer.PlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 0,
            surnameIndex: 0,
            wins: 0,
            losses: 0,
            kills: 0
        });
        ipfsCID = "QmRQEMsXzytfLuhRyntfD23Gu41GNxdn4PyrBL1XoM3sPb";
    }

    function getBalancedWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        weapon = IPlayerSkinNFT.WeaponType.SwordAndShield;
        armor = IPlayerSkinNFT.ArmorType.Chain;
        stance = IPlayerSkinNFT.FightingStance.Balanced;
        stats = IPlayer.PlayerStats({
            strength: 12,
            constitution: 12,
            size: 12,
            agility: 12,
            stamina: 12,
            luck: 12,
            skinIndex: skinIndex,
            skinTokenId: tokenId,
            firstNameIndex: 1001,
            surnameIndex: 3,
            wins: 0,
            losses: 0,
            kills: 0
        });
        ipfsCID = "QmSVzjJMzZ8ARnYVHHsse1N2VJU3tUvacV1GUiJ2vqgFDZ";
    }

    function getGreatswordUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18,
                constitution: 10,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1010,
                surnameIndex: 18,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmUCL71TD41AFZBd1BkVMLVbjDTAF5A6HiNyGcmiXa8upT"
        );
    }

    function getBattleaxeUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Battleaxe,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 16,
                constitution: 12,
                size: 14,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getSpearUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Spear,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Balanced,
            IPlayer.PlayerStats({
                strength: 14,
                constitution: 12,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getQuarterstaffUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 14,
                size: 12,
                agility: 12,
                stamina: 14,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getRapierAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.RapierAndShield,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 12,
                size: 12,
                agility: 14,
                stamina: 12,
                luck: 12,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getOffensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.Greatsword,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Offensive,
            IPlayer.PlayerStats({
                strength: 18,
                constitution: 8,
                size: 16,
                agility: 10,
                stamina: 10,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getDefensiveTestWarrior(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 10,
                constitution: 16,
                size: 10,
                agility: 10,
                stamina: 16,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }

    function getSwordAndShieldUser(uint32 skinIndex, uint16 tokenId)
        internal
        pure
        returns (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        )
    {
        return (
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive,
            IPlayer.PlayerStats({
                strength: 12,
                constitution: 14,
                size: 12,
                agility: 12,
                stamina: 12,
                luck: 10,
                skinIndex: skinIndex,
                skinTokenId: tokenId,
                firstNameIndex: 1,
                surnameIndex: 1,
                wins: 0,
                losses: 0,
                kills: 0
            }),
            "QmSwordAndShieldUserCIDHere"
        );
    }
}
