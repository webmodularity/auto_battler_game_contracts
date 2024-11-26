// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";
import "../interfaces/IPlayerSkinNFT.sol";

contract PlayerSkinNFT is IPlayerSkinNFT, ERC721, Owned {
    uint16 private constant _MAX_SUPPLY = 10000;
    uint16 private _currentTokenId;

    bool public mintingEnabled;
    uint256 public mintPrice;

    mapping(uint256 => SkinAttributes) private _skinAttributes;
    string public baseURI;

    error InvalidBaseURI();
    error MaxSupplyReached();
    error InvalidTokenId();
    error InvalidMintPrice();
    error MintingDisabled();

    constructor(string memory _name, string memory _symbol, uint256 _mintPrice)
        ERC721(_name, _symbol)
        Owned(msg.sender)
    {
        mintPrice = _mintPrice;
        mintingEnabled = false; // Start with minting disabled
    }

    function MAX_SUPPLY() external pure override returns (uint16) {
        return _MAX_SUPPLY;
    }

    function CURRENT_TOKEN_ID() external view override returns (uint16) {
        return _currentTokenId;
    }

    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function mintSkin(address to, WeaponType weapon, ArmorType armor, FightingStance stance)
        external
        payable
        override
        returns (uint16)
    {
        // Owner can mint for free, others must pay
        if (msg.sender != owner) {
            if (!mintingEnabled) revert MintingDisabled();
            if (msg.value != mintPrice) revert InvalidMintPrice();
        }

        if (_currentTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();

        uint16 newTokenId = _currentTokenId++;
        _mint(to, newTokenId);

        _skinAttributes[newTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        emit SkinMinted(to, newTokenId, weapon, armor, stance);
        return newTokenId;
    }

    function getSkinAttributes(uint256 tokenId) external view override returns (SkinAttributes memory) {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        if (bytes(_baseURI).length == 0) revert InvalidBaseURI();
        baseURI = _baseURI;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseURI, id, ".json"));
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}