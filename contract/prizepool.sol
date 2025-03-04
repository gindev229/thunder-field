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
    address public arena;  // Arena Platform Address
    uint public nonce;     // Security counter to prevent replay attacks
    mapping(bytes32 => Pool) public pools; // Maps battleId to Pool struct

    
    constructor(address initArena) {
        arena = initArena;
        nonce = 1;
    }

    /**
    * @dev Creates a new battle with the sender as defender
    * @param battleId Unique identifier for the battle
    * @notice Defender must send a non-zero amount of ETH to stake
    */

    function create(bytes32 battleId) external payable {
        require(msg.value > 0);
        require(pools[battleId].active == false);
        pools[battleId].daddress = msg.sender;
        pools[battleId].dmoney = msg.value;
        pools[battleId].active = true;
        nonce++;
        emit Create(msg.sender, msg.value, battleId);
    }

    /**
    * @dev Allows a challenger to join an existing battle
    * @param battleId Identifier of the battle to join
    * @notice Challenger must stake exactly the same amount as the defender
    * Match must be active
    * @notice Cannot join your own match
    */

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

    /**
     * @dev Allows a defender to cancel their battle and retrieve their stake
     * @param battleId Identifier of the battle to cancel
     * @notice Only the original defender can cancel, and only if no challenger has joined and match is active
     *  Only transfer money back to defender(who creates this match)
     */

    function delist(bytes32 battleId) external {
        require(pools[battleId].active == true); // Check if match is active
        require(pools[battleId].daddress == msg.sender); // Check if caller is the defender who created the match
        require(pools[battleId].dmoney > 0); // Check if defender has money to withdraw
        require(pools[battleId].caddress == address(0)); // Check if no challenger has joined 
        uint refundAmount = pools[battleId].dmoney;
        nonce++;
        pools[battleId].active = false;
        delete pools[battleId]; // Delete match
        payable(msg.sender).transfer(refundAmount); // Only transfer money back to defender address
        emit Delete(battleId);
    }

    /**
     * @dev Allows winner to claim prize after battle conclusion
     * @notice Only defender or challenger can claim
     * @notice Only transfer prize to defender or challenger, platform receives a 1% fee
     * @param battleId Identifier of the concluded battle
     * @param r Part of the arena signature
     * @param s Part of the arena signature
     * @param v Part of the arena signature
     * Match must be concluded: not active
     */
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
