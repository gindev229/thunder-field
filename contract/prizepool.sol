// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
* @title IPrizePool
* @dev Interface for a prize pool contract that manages battle stake transactions
*/

interface IPrizePool {
    struct Pool { 
        address daddress; // Defender's address
        address caddress; // Challenger's address
        uint dmoney;      // Defender's staked amount  
        uint cmoney;      // Challenger's staked amount  
        bool active;      // Battle status: active (true) or concluded (false)  
    }

    function create(bytes32  battleId) external payable;

    function join(bytes32  battleId) external payable;

    function delist(bytes32  battleId) external;

    function claim(bytes32  battleId, bytes32 r, bytes32 s, uint8 v) external;

    event Create(address creator, uint lockValue, bytes32 battleId);
    event Join(address joiner, uint addValue, bytes32 battleId);
    event Delete(bytes32 battleId);
    event Claim(bytes32 battleId, address claimant);
}

contract PrizePool is IPrizePool {
    address public arena;  
    uint public nonce;     
    mapping(bytes32 => Pool) public pools; 

    
    constructor(address initArena) {
        arena = initArena;
        nonce = 1;
    }



    function create(bytes32 battleId) external payable {
        require(msg.value > 0);
        require(pools[battleId].active == false);
        pools[battleId].daddress = msg.sender;
        pools[battleId].dmoney = msg.value;
        pools[battleId].active = true;
        nonce++;
        emit Create(msg.sender, msg.value, battleId);
    }



    function join(bytes32 battleId) external payable {
        require(msg.value > 0);
        require(msg.value == pools[battleId].dmoney);
        require(pools[battleId].active == true);
        require(pools[battleId].daddress != msg.sender);
        nonce++;
        pools[battleId].cmoney = msg.value;
        pools[battleId].caddress = msg.sender;
        pools[battleId].active = false;
        emit Join(msg.sender, msg.value, battleId);
    }



    function delist(bytes32 battleId) external {
        require(pools[battleId].active == true); 
        require(pools[battleId].daddress == msg.sender); // Check if caller is the defender who created the match
        require(pools[battleId].dmoney > 0); 
        require(pools[battleId].caddress == address(0)); // Check if no challenger has joined 
        uint refundAmount = pools[battleId].dmoney;
        nonce++;
        pools[battleId].active = false;
        delete pools[battleId]; // Delete match
        payable(msg.sender).transfer(refundAmount); 
        emit Delete(battleId);
    }


    function claim(bytes32 battleId, bytes32 r, bytes32 s, uint8 v) external {
        //Match must be concluded
        require(pools[battleId].active == false);
        //Only challenger and Defender can withdraw
        require(pools[battleId].daddress == msg.sender || pools[battleId].caddress == msg.sender);

        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked("claim", battleId, msg.sender, nonce))
        ));
        require(ecrecover(messageHash, v, r, s) == arena);
        
        uint pay = pools[battleId].dmoney + pools[battleId].cmoney; // Winner receive 99% total money
        uint fee = pay * 1 / 100; // Platform fee is 1%
        nonce++;
        delete pools[battleId];
        payable(msg.sender).transfer(pay - fee); //Only transfer prize to Defender or Challenger
        payable(arena).transfer(fee);
        emit Claim(battleId, msg.sender);
    }
}
