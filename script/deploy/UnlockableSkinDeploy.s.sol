// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PlayerSkinRegistry} from "../../src/PlayerSkinRegistry.sol";
import {PlayerSkinNFT} from "../../src/examples/PlayerSkinNFT.sol";
import {GameEngine} from "../../src/GameEngine.sol";

contract UnlockableSkinDeployScript is Script {
    function run(address skinRegistryAddress) public {
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        PlayerSkinRegistry skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));

        // Deploy unlockable skin collection
        PlayerSkinNFT unlockableSkin = new PlayerSkinNFT("Shapecraft Key Collection", "SKHHSKIN", 0);

        // Register unlockable skin collection
        uint32 unlockableSkinIndex = skinRegistry.registerSkin(address(unlockableSkin));

        // Set the unlock NFT address for this collection
        skinRegistry.setRequiredNFT(unlockableSkinIndex, 0x05aA491820662b131d285757E5DA4b74BD0F0e5F);

        // Set the IPFS base URI
        unlockableSkin.setBaseURI("ipfs://QmXeA9ARshQiRWkt6cffcrr2EN5jjofhBi5GQaVmVEKJSX/");

        // Enable minting
        unlockableSkin.setMintingEnabled(true);

        console2.log("\n=== Minting Unlockable Characters ===");

        // Mint Quarterstaff Mystic (ID 1)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            5, // WEAPON_QUARTERSTAFF
            0, // ARMOR_CLOTH
            2 // STANCE_OFFENSIVE
        );

        // Mint Mace Guardian (ID 2)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            1, // WEAPON_MACE_AND_SHIELD
            2, // ARMOR_CHAIN
            0 // STANCE_DEFENSIVE
        );

        // Mint Battle Master (ID 3)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            4, // WEAPON_BATTLEAXE
            1, // ARMOR_LEATHER
            2 // STANCE_OFFENSIVE
        );

        // Set the collection as verified
        skinRegistry.setSkinVerification(unlockableSkinIndex, true);

        // Disable minting after we're done
        unlockableSkin.setMintingEnabled(false);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("UnlockablePlayerSkinNFT:", address(unlockableSkin));
        console2.log("Unlockable Skin Registry Index:", unlockableSkinIndex);

        vm.stopBroadcast();
    }
}
