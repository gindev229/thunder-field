// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./interfaces/IMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

contract Marketplace is IMarketplace {
    /*//////////////////////////////////////////////////////////////
                                Royalties
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint8) public royaltyOf;
    mapping(address => address) public creatorOf;
    address public admin;
    address public treasury;
    uint8 public adminRoyalty;

    constructor(address _admin, uint8 _adminRoyalty, address _treasury) {
        admin = _admin;
        adminRoyalty = _adminRoyalty;
        treasury = _treasury;
    }

    function setRoyalty(address collection, uint8 royalty) external {
        require(msg.sender == admin, "Only marketplace can directly set royalties for creators");
        require(royalty <= 30, "Creator royalty can not exceed 30%");

        royaltyOf[collection] = royalty;
    }

    function setCreator(address collection, address creator) external {
        require(msg.sender == admin, "Only marketplace can directly set creators");

        creatorOf[collection] = creator;
    }

    function setAdminRoyalty(uint8 royalty) external {
        require(msg.sender == admin, "Only marketplace can set platform fee");
        require(royalty <= 5, "Platform fee can not exceed 5%");

        adminRoyalty = royalty;
    }

    function setRoyaltyFromSig(address collection, uint8 royalty, bytes32 r, bytes32 s, uint8 v) external {
        // Get message hash of marketplace auth for creators to set royalty
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", 
            keccak256(abi.encodePacked(
                "SET_ROYALTY",
                msg.sender,
                collection,
                royalty
            ))
        ));

        // Verify signature
        require(ecrecover(messageHash, v, r, s) == admin, "Invalid signature");

        // Update royalty and assign creator
        royaltyOf[collection] = royalty;
        creatorOf[collection] = msg.sender;
    }

    // In case the marketplace key is compromised, change admin to another account
    function changeAdmin(address newAdmin) external {
        require(msg.sender == admin, "Only the marketplace can give perms to another accounts");

        admin = newAdmin;
    }


    /*//////////////////////////////////////////////////////////////
                               Marketplace
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(uint => uint)) public priceOf;
    mapping(address => mapping(uint => address)) public ownerOf;
    mapping(address => mapping(uint => mapping(address => uint))) public offers;
    mapping(address => mapping(uint => bool)) public sold;

    function list(address collection, uint id, uint price) external {
        require(sold[collection][id] || ownerOf[collection][id] == address(0), "Can only list if NFT was never listed before or sold");

        // Store the price
        priceOf[collection][id] = price;
        // Store the owner
        ownerOf[collection][id] = msg.sender;
        // Open for sale
        sold[collection][id] = false;

        // Transfer the NFT from owner to marketplace, user must approve this before
        IERC721(collection).safeTransferFrom(msg.sender, address(this), id);

        emit Listed(collection, id, price, msg.sender);
    }

    function changePrice(address collection, uint id, uint price) external {
        require(ownerOf[collection][id] == msg.sender, "Only owner can set the price");
        require(!sold[collection][id], "Can only change the price if NFT is listed");

        // Store the price
        priceOf[collection][id] = price;

        emit PriceChanged(collection, id, price);
    }

    function unlist(address collection, uint id) external {
        require(ownerOf[collection][id] == msg.sender, "Only owner can unlist");
        require(!sold[collection][id], "Can only unlist if NFT is listed");

        // Close sale
        sold[collection][id] = true;

        // Transfer the listed NFT from marketplace to owner of NFT
        IERC721(collection).safeTransferFrom(address(this), msg.sender, id);

        emit Unlisted(collection, id);
    }

    function buy(address collection, uint id) external payable {
        require(ownerOf[collection][id] != address(0), "NFT must be listed before");
        require(msg.value == priceOf[collection][id], "Amount sent is not enough");
        require(!sold[collection][id], "NFT must not be sold before");

        // Close sale
        sold[collection][id] = true;

        // Send NFT to buyer
        IERC721(collection).safeTransferFrom(address(this), msg.sender, id);
        // Transfer money to seller with royalties cut
        payable(ownerOf[collection][id]).transfer(priceOf[collection][id] * (100 - adminRoyalty - royaltyOf[collection]) / 100);
        // Transfer 50% platform fee to marketplace
        payable(admin).transfer(priceOf[collection][id] * adminRoyalty / 200);
        // Transfer 50% platform fee to treasury
        payable(treasury).transfer(priceOf[collection][id] * adminRoyalty / 200);
        // Transfer royalty to creator
        payable(creatorOf[collection]).transfer(priceOf[collection][id] * royaltyOf[collection] / 100);

        emit Bought(collection, id, msg.sender);
    }

    function offer(address collection, uint id) external payable {
        // Return funds from previous offer if any
        payable(msg.sender).transfer(offers[collection][id][msg.sender]);

        // Store current offer
        offers[collection][id][msg.sender] = msg.value;

        emit Offered(collection, id, msg.value, msg.sender);
    }

    function removeOffer(address collection, uint id) external {
        // User withdraw offer funds 
        payable(msg.sender).transfer(offers[collection][id][msg.sender]);

        // User remove offer
        offers[collection][id][msg.sender] = 0;

        emit OfferRemoved(collection, id, msg.sender);
    }

    function acceptOffer(address collection, uint id, address proposer) external {
        console.log("a");

        require(ownerOf[collection][id] == msg.sender, "Only owner can accept offers");
        require(!sold[collection][id], "NFT must not be sold before");

        uint price = offers[collection][id][proposer];

        // Remove offer
        offers[collection][id][proposer] = 0;
        // Reset sold to true
        sold[collection][id] = true;

        // Send NFT to buyer
        IERC721(collection).safeTransferFrom(address(this), proposer, id);
        // Transfer money to owner with royalties cut
        payable(msg.sender).transfer(price * (100 - adminRoyalty - royaltyOf[collection]) / 100);
        // Transfer 50% platform fee to marketplace
        payable(admin).transfer(price * adminRoyalty / 200);
        // Transfer 50% platform fee to treasury
        payable(treasury).transfer(price * adminRoyalty / 200);
        // Transfer royalty to creator
        payable(creatorOf[collection]).transfer(price * royaltyOf[collection] / 100);

        emit OfferAccepted(collection, id, price, proposer);
    }


    // ERC-721 receiver
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
