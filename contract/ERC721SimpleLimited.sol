// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ERC721SimpleLimited is ERC721URIStorage {
    uint256 public tokenIds;
    uint256 public mintLimit;
    address public admin;
    string public defaultTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        address initialAdmin,
        string memory initialTokenURI
    ) ERC721(name, symbol) {
        admin = initialAdmin;
        defaultTokenURI = initialTokenURI;
    }

    function mintNFT(address recipient) external returns (uint256) {
        tokenIds++;

        require(tokenIds <= mintLimit, "Exceeded mint limit");

        _mint(recipient, tokenIds);
        _setTokenURI(tokenIds, defaultTokenURI);

        emit NFTMinted(recipient, tokenIds);

        return tokenIds;
    }

    function setMintLimit(uint newMintLimit) external {
        require(msg.sender == admin, "Only admin can set mint limit");

        mintLimit = newMintLimit;
    }

    event NFTMinted(address recipient, uint256 id);
}
