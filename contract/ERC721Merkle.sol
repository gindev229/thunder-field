// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract ERC721Merkle is ERC721URIStorage {
    uint256 public _tokenIds;
    bytes32 public _root;
    address public _owner;
    address public _royaltyReceiver;
    address public _feeReceiver;
    uint8 _royalty;

    constructor(
        string memory name,
        string memory symbol,
        bytes32 root,
        address owner,
        address royaltyReceiver,
        address feeReceiver,
        uint8 royalty
    ) ERC721(name, symbol) {
        _root = root;
        _owner = owner;
        _royaltyReceiver = royaltyReceiver;
        _feeReceiver = feeReceiver;
        _royalty = royalty;
    }


    /*//////////////////////////////////////////////////////////////  
                                   Mint
    //////////////////////////////////////////////////////////////*/

    function mint(
        address recipient,
        uint256 tokenId,
        string calldata tokenURI,
        bool isWhitelist,
        bytes32[] calldata leaves
    ) external payable returns (uint256) {
        // Generate starter hash
        bytes32 starterHash = sha256(abi.encodePacked(isWhitelist ? recipient : address(0), tokenId, tokenURI, msg.value));
        // Regenerate the root
        bytes32 genRoot = generateRoot(starterHash, leaves);
        // Compare the generated root with the stored root
        require(genRoot == _root, "Generated root does not match with stored root");

        // Mint and set token uri for NFT
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit NFTMinted(recipient, tokenId);

        // Transfer minting fees to fee receiver and owner
        uint256 royaltyFee = msg.value * _royalty / 100;
        payable(_royaltyReceiver).transfer(royaltyFee);
        payable(_feeReceiver).transfer(msg.value - royaltyFee);

        return tokenId;
    }

    // Optional event for faster mint event query compared to Transfer
    event NFTMinted(address recipient, uint256 id);


    /*//////////////////////////////////////////////////////////////  
                                Ownership
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) external {
        require(msg.sender == _owner, "Only the owner can transfer ownership");

        _owner = newOwner;
    }

    function changeTokenURI(uint256 tokenId, string calldata tokenURI) external {
        require(msg.sender == _owner, "Only the owner can change token URIs");

        _setTokenURI(tokenId, tokenURI);
    }

    function changeRoot(bytes32 root) external {
        require(msg.sender == _owner, "Only the owner can change merkle root");

        _root = root;
    }


    /*//////////////////////////////////////////////////////////////  
                                Utilities
    //////////////////////////////////////////////////////////////*/

    function generateRoot(bytes32 starterHash, bytes32[] memory leaves) pure internal returns (bytes32) {
        bytes32 genHash = starterHash;

        for (uint i = 0; i < leaves.length;) {
            if (uint(genHash) > uint(leaves[i])) {
                genHash = sha256(abi.encodePacked(genHash, leaves[i]));
            } else {
                genHash = sha256(abi.encodePacked(leaves[i], genHash));
            }

            // Unchecked because there is no way the amount of leaves is more than 2^256
            unchecked {
                i++;
            }
        }

        return genHash;
    }
}
