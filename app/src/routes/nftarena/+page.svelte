<script>
    import { slide } from 'svelte/transition';
    import { fade } from 'svelte/transition';
    import { onMount } from "svelte";
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { emitBetweenText } from '$lib/index.js';
    import { erc721ABI, erc721Bytecode, marketplaceAddress, marketplaceABI, contractAddress,contractAbi  } from "$lib/contract.config.js";
    import { ethers } from "ethers";
    import config from "$lib/config.js";
    import skillData from './data.json';
    import './styles.css';
    import Loading from "$lib/Loading.svelte";

    let isLogin = false;
    let connectToMetamask;
    let navigation = "hall";
    let matchPopUp = false;
    let rankMatchPopUp = false;
    let rankRewardPopup = false;
    let chainChoose = false;

    let x;
    let showSelectedAtributes =[];
    let selected = {};
    let selectedAtributes = {};

    let battleProfile = {};
    let challengeHistory = [];
    let defendHistory =[];
    let battleHistory = [];
    
    let challengePerDay = "";
    let challengeUsed ="";

    let isShowMintFree = true;

    let inputStake;

    let withdrawList =[];
    //pvp squad
    let squad = [{},{},{}];
    function chooseSquad(){
        if(!squad[0].id)
        {   squad[0].collection = selected.collection; 
            squad[0].id = selected.id;
            squad = squad;
            
            console.log(squad[0].id )
        }
        else if(!squad[1].id)
        {   squad[1].collection = selected.collection; 
            squad[1].id = selected.id;
            squad = squad;
        }
        else if(!squad[2].id)
        {
            squad[2].collection = selected.collection; 
            squad[2].id = selected.id;
            squad = squad;
        }
    }

    let y;
    let showSelectedRankAtributes =[];
    let selectedCollectionName;
    let selectedRank ={};
    let rankSquad = [{},{},{}];
    function chooseRankSquad(){
        if(!rankSquad[0].id)
        {   rankSquad[0].collection = selectedRank.collection; 
            rankSquad[0].id = selectedRank.id;
            rankSquad = rankSquad;
            
            console.log(squad[0].id )
        }
        else if(!rankSquad[1].id)
        {   rankSquad[1].collection = selectedRank.collection; 
            rankSquad[1].id = selectedRank.id;
            rankSquad = rankSquad;
        }
        else if(!rankSquad[2].id)
        {
            rankSquad[2].collection = selectedRank.collection; 
            rankSquad[2].id = selectedRank.id;
            rankSquad = rankSquad;
        }
        console.log(selectedAtributes,"selectedAtributes");
    }

    let passHold = "";


     


    // Example of using the data
    let effect = '';
    function getEffect(collections, attribute) {
        const item = skillData.find(item => item.collections === collections && item.attribute === attribute);
        effect = item ? item.desc : 'Effect not found';
        return effect;
    }


    let address = ""; 

    let userAddress;
    //Copy
    let textToCopy = address;

    let nftList = [];
    let currentItem = 0;
    let items = [];
    let done = false;
    let popupLoading = false;
    let loading = true;

    let matches = [];

    let withDrawPopUp = false;
    let questPopUp = false;
    let questList = [];
    let copyToClipboard;
    
    let provider;
    let signer;
    let marketplace;
    let prizePoolContract;

    async function getNFTOwner(address, id) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getNFTInfo",
                params: {
                    address,
                    id,
                    exclude: [ "metadata", "collectionName", "offers" ]
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();

            return responseBody.payload;
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }


    onMount(async () => {
        // Connect to metamask
        connectToMetamask = async function() {
            // Handle the case where user might not have a Metamask wallet installed
            if (!window.ethereum) {
                window.open("https://chromewebstore.google.com/detail/metamask/nkbihfbeogaeaoehlefnkodbefgpgknn", "_blank");
                return;
            }

            // Switch network
            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: config.chainId }],
                });
            } catch (error) {
                if (error.code === 4902) {
                    // Network has not been added, we will add here
                    try {
                        // Request to add the network
                        await window.ethereum.request({
                            method: 'wallet_addEthereumChain',
                            params: [{
                                chainId: config.chainId,
                                rpcUrls: [config.ethRpcUrl],
                                chainName: config.chainName,
                                nativeCurrency: {
                                    name: config.nativeCurrency.name,
                                    symbol: config.nativeCurrency.symbol,
                                    decimals: 18
                                },
                                blockExplorerUrls: [config.blockExplorerUrls]
                            }]
                        });
                        console.log('Network added to MetaMask');
                    } catch (addError) {
                        console.error('Failed to add the network:', addError);
                    }
                } else {
                    console.error('Failed to switch to the network:', error);
                }
            }

            // Connect to an account in the wallet
            const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });

            let provider = new ethers.providers.Web3Provider(window.ethereum);

            const signer = provider.getSigner();
            address = await signer.getAddress();
            location.reload()
            isLogin = true;

        }

        try {
            let provider = new ethers.providers.Web3Provider(window.ethereum);

            (async () => {
                const signer = provider.getSigner();

                try {
                    address = await signer.getAddress();
                    isLogin = true;
                } catch (e) {
                    isLogin = false;
                }
            })();
        } catch (e) {
            isLogin = false;
        }

        copyToClipboard = async function() {
            try {
                await window.navigator.clipboard.writeText(textToCopy);
                copied = true;
                setTimeout(() => (copied = false), 1000); // Reset 'copied' after 2 seconds
            } catch (err) {
                console.error('Failed to copy: ', err);
            }
        }


        //Initialize connection to contract
        await (async () => {
            provider = new ethers.providers.Web3Provider(window.ethereum);
            signer = provider.getSigner();
            userAddress = await signer.getAddress();
            address = userAddress;
            prizePoolContract = new ethers.Contract(contractAddress, contractAbi, signer);
            marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, signer);
        })();

        (async () => {
            // Get nfts that user owns
            try {
                await (async function() {
                    // Get the nft list in local storage
                    try {
                        const localNFTList = JSON.parse(localStorage.nftList || "[]");
                        const requests = [];
                        console.log(localNFTList, "1111111111111111111111111111111")
                        // Check if user is still the owner
                        for (const nft of localNFTList) {
                            requests.push((async () => {
                                const { owner, lister } = await getNFTOwner(nft.collectionAddress, nft.id);
                                /*
                                if (owner !== userAddress && lister !== userAddress) {
                                    return;
                                }*/

                                nftList.push(nft);
                                nftList = nftList;
                                console.log(nftList, "nftListyyyyyyyyyyyyyyyyyyyyyyyyyyy")
                            })());
                        }

                        await Promise.all(requests);

                        // Update the new local nft list
                        localStorage.nftList = JSON.stringify(nftList);
                    } catch (e) {
                        console.log("b", e);
                    }

                    const response = await fetch(config.indexerUrl, {
                        method: "POST",
                        body: JSON.stringify({
                            method: "getNFTHoldings",
                            params: {
                                address
                            }
                        }),
                        headers: {
                            "Content-Type": "application/json"
                        }
                    });
                    /*
                        if (response.ok) {
                            const responseBody = await response.json();

                            console.log(responseBody);

                            for (const nft of responseBody.payload.nftHoldings) {
                                if (!nftList.find(_nft => nft.collection === _nft.collectionAddress && nft.id.toString() === _nft.id)) {
                                    nftList.push({ collectionAddress: nft.collection, id: nft.id.toString() });
                                }
                            }
                        } else {
                            const responseBody = await response.json();

                            if (responseBody.error && responseBody.error.message) {
                                throw new Error(responseBody.error.message);
                            }
                        }
                    */        
                })();
            } catch (e) {}

        const excludedAddresses = [
            "0x373521e5530dAC6D54B1afd0DD16C37Df41c8200",
            "0xF474423749eB320f48359AB8a44CE90F46c859c2",
            "0x9c2bf93A7D29fa6f367ad641E411e1fD2B9C6833",
        ];

        nftList = nftList.filter(nft => !excludedAddresses.includes(nft.collectionAddress));
            // Load the first batch of nfts
            loadNFTs(nftList);

           
        })();

        async function loadNFTs() {
            loading = true;
            
            const nfts = [];

            for (let index = currentItem; index < currentItem + 100; index++) {
                const id = nftList[index];

                nfts.push(id);
            }
            console.log(nfts, "nftsnftsnftsnfts")

            try {
                const curatedNFTs = nfts.filter(id => typeof id !== "undefined" && id !== null);

                if (curatedNFTs.length !== nfts.length) { done = true; }

                const nftInfos = (await getNFTsInfo(curatedNFTs, [ "metadata", "offers", "owner" ])).nftInfos;

                const newNfts = nftInfos.map(nft => ({ ...nft, id: nft.id }));

                items = [ ...items, ...newNfts ];
            } catch (e) {
                console.log(e);

                done = true;
                loading = false;
            }
            loading = false;
            currentItem += 100;
        }

        
        //Get activities


        //Call 10 NFTS
        if (!done && !loading) {
            loadNFTs(nftList);
        }
        await initProfile();
        await getMatches();
        await getAllBattleHistory();
        await getUserQuests();
        await getRankUserProfile();
        await getRankAndNearby();
        await getWithdrawList(address);
    });


    async function getNFTsInfo(nfts, exclude) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getNFTsInfo",
                params: {
                    nfts,
                    exclude
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            selectedCollectionName = responseBody.payload.nftInfos[0].collectionName;
            selectedCollectionName = selectedCollectionName
            return responseBody.payload;
           
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }


    async function getAttributes(nfts) {
        const attributeList = (await getNFTsInfo(nfts, ["owner", "listingDetails", "offers"]))
            .nftInfos
            .map(nft => {
                //Check if NFT has missing attributes
                if (!nft?.metadata?.attributes?.length) {
                    throw new Error(`NFT is missing attributes`);
                }

                const attributes = nft.metadata.attributes;
                return attributes.map(attribute => attribute["value"]);
            });
        return attributeList; // Returns array of values from first NFT
    }


    //////////////////////ALL GAME FUNCTION///////////////////////////////////////////////////////////////////////////


    //Load all map in UI
    async function getMatches() {
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getAllMatch",
                params: {}
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            if (!responseBody.success || !responseBody.payload || !responseBody.payload.data) {
                console.error("Invalid response format:", responseBody);
                throw new Error("Invalid response format from server");
            }
        
            matches = responseBody.payload.data[1];
            console.log(matches, "matches")
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }; 

    // Create a Match
    async function loadQueue(nfts, address, value) {
        popupLoading = true;
        // Validate inputs
        if (!nfts?.length) {
            popupLoading = false;
            return;
            
        }
        
        // Validate value is greater than 0
        const floatValue = parseFloat(value);
        if (isNaN(floatValue) || floatValue <= 0) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Deposit value must be greater than 0";
            return;
        }

        // Get attributes of nfts
        const filteredNfts = nfts.map(nft => ({ collectionAddress: nft.collection, id: nft.id }));
        const attributeList = await getAttributes(filteredNfts);
        const finalNfts = [];
        for (let i = 0; i < attributeList.length; i++) {
            finalNfts.push({
                collection: nfts[i].collection,
                id: parseInt(nfts[i].id),
                attributes: attributeList[i]
            });
        }
        
        console.log(finalNfts, "finalNftsfinalNfts")
        // STEP 1: Initialize battle on backend and get battleID
        const initialResponse = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "loadQueue",
                params: {
                    daddress: address,
                    value: floatValue, // FIX: Send float value instead of integer
                    matchBody: {
                        nfts: finalNfts
                    }
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (!initialResponse.ok) {
            const responseBody = await initialResponse.json();
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Failed to initialize battle";
            throw new Error(responseBody.error?.message || "Failed to initialize battle");
            return;
        }
        const responseBody = await initialResponse.json();
        console.log(responseBody, "responseBody");

        // FIX: Correctly access the nested response data
        if (!responseBody.success || !responseBody.payload || !responseBody.payload.data) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Invalid response format from server";
            throw new Error("Invalid response format from server");
        }

        const responseData = responseBody.payload.data;
        console.log(responseData, "responseData")
        
        // Only proceed if we get the expected response
        if (responseData[0] !== "pendingBattle") {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Unexpected response";
            throw new Error(`Unexpected response from server: ${responseData[0]}`);
        }
        
        const { battleID, value: confirmedValue } = responseData[1];

        try {
            // STEP 2: Call contract function to create the battle and lock funds
            const valueToUse = parseFloat(confirmedValue.toString());
            
            // Convert value to proper format for contract (v5 syntax)
            const valueInWei = ethers.utils.parseEther(valueToUse.toString());
            
            // Create battle in contract
            const tx = await prizePoolContract.create(battleID, { value: valueInWei });
            
            // STEP 3: Immediately send transaction hash to backend
            await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "confirmDefenderDeposit",
                    params: {
                        battleID: battleID,
                        txHash: tx.hash
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
            
            // STEP 4: Wait for transaction to complete with better error handling
            try {
                const receipt = await tx.wait();
                // Check receipt status for transaction success
                if (receipt.status !== 1) {
                    popupLoading = false;
                    generalError = true;
                    generalErrorValue = ("Transaction failed with status: " + receipt.status);
                    throw new Error("Transaction failed with status: " + receipt.status);
                }
            } catch (error) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = ("Transaction failed: " + (error.message || "Unknown error"));
                console.error("Transaction failed:", error);
                throw new Error("Transaction failed: " + (error.message || "Unknown error"));
            }
            
            // STEP 5: Notify backend of completion
            const finalResponse = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "finalizeDefenderDeposit",
                    params: {
                        battleID: battleID
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!finalResponse.ok) {
                const responseBody = await finalResponse.json();
                popupLoading = false;
                generalError = true;
                generalErrorValue = "Failed to finalize battle creation";
                throw new Error(responseBody.error?.message || "Failed to finalize battle creation");
            }
            popupLoading = false;
            // Reload page to show the created battle
            location.reload();
            
        } catch (error) {
            popupLoading = false;
            throw error;
        }
    }

    async function challenge(nfts, caddress, daddress, battleID) {
        // Validate inputs
        checkSquad();
        if (!nfts?.length) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Invalid NFTs input";
            throw new Error("Invalid NFTs input");
        }
        popupLoading = true;

        // Get attributes of nfts
        const filteredNfts = nfts.map(nft => ({ collectionAddress: nft.collection, id: nft.id }));
        const attributeList = await getAttributes(filteredNfts);
        
        const finalNfts = [];
        for (let i = 0; i < attributeList.length; i++) {
            finalNfts.push({
                collection: nfts[i].collection,
                id: parseInt(nfts[i].id),
                attributes: attributeList[i]
            });
        }
        
        // STEP 1: Verify battle and simulate combat
        const initialResponse = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "match",
                params: {
                    battleID, 
                    caddress,
                    daddress,
                    matchBody: {
                        nfts: finalNfts
                    }
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (!initialResponse.ok) {
            const responseBody = await initialResponse.json();
            popupLoading = false;
            generalError = true;
            generalErrorValue = responseBody.error?.message;
            throw new Error(responseBody.error?.message || "Failed to initialize challenge");
        }

        const responseBody = await initialResponse.json();
        if (!responseBody.success || !responseBody.payload || !responseBody.payload.data) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Invalid response format from server";
            throw new Error("Invalid response format from server");
        }
        const responseData = responseBody.payload.data;

        // STEP 2: If it's a tie, proceed directly to battle page
        if (responseData[0] === "tie") {
            console.log("Battle resulted in a tie");
            goto("./nftarena/battle");
            return;
        }
        
        // For non-tie results, proceed with contract interaction
        if (responseData[0] !== "challengeWithDeposit") {
            console.log(responseData[0],"responseData");
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Unexpected response from server";
            throw new Error("Unexpected response from server");
        }
        
        const battleInfo = responseData[1];
        
        try {
            // STEP 3: Call contract function to join battle
            
            const valueToUse = parseFloat(battleInfo.value.toString());
            // Convert value to proper format for contract (v5 syntax)
            const valueInWei = ethers.utils.parseEther(valueToUse.toString());
            
            // Join battle in contract
            const tx = await prizePoolContract.join(battleInfo.battleID, { value: valueInWei });
            
            // STEP 4: Immediately send transaction hash to backend
            await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "confirmChallengerDeposit",
                    params: {
                        battleID: battleInfo.battleID,
                        txHash: tx.hash
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
            
            // STEP 5: Wait for transaction to complete with better error handling
            try {
                const receipt = await tx.wait();
                // Check receipt status for transaction success
                if (receipt.status !== 1) {
                    popupLoading = false;
                    generalError = true;
                    generalErrorValue = ("Transaction failed with status: " + receipt.status);
                    throw new Error("Transaction failed with status: " + receipt.status);
                }
            } catch (error) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = ("Transaction failed: " + (error.message || "Unknown error"));
                console.error("Transaction failed:", error);
                throw new Error("Transaction failed: " + (error.message || "Unknown error"));
            }
            
            // STEP 6: Notify backend of completion
            const finalResponse = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "finalizeChallengerDeposit",
                    params: {
                        battleID: battleInfo.battleID
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!finalResponse.ok) {
                const responseBody = await finalResponse.json();
                popupLoading = false;
                generalError = true;
                generalErrorValue = (responseBody.error?.message || "Failed to finalize challenge");
                throw new Error(responseBody.error?.message || "Failed to finalize challenge");
            }
            popupLoading = false;
            
            // Navigate to battle page
            console.log("Challenge completed, going to battle page");
            goto("./nftarena/battle");
            
        } catch (error) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = ("Error challenging battle:", error);
            console.error("Error challenging battle:", error);
            throw error;
        }
    }

    async function getWithdrawList(address) {
        try {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "withdrawList",
                    params: {
                        address: address
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!response.ok) {
                const responseBody = await response.json();
                throw new Error(responseBody.error?.message || "Failed to get withdraw list");
            }

            const responseBody = await response.json();
            
            // Access the nested response data
            if (!responseBody.success || !responseBody.payload || !responseBody.payload.data) {
                throw new Error("Invalid response format from server");
            }
            
            const responseData = responseBody.payload.data;
            
            // responseData should be ["withdrawList", claimableBattles]
            if (responseData[0] !== "withdrawList") {
                throw new Error(`Unexpected response from server: ${responseData[0]}`);
            }
            
            // Return the list of claimable battles
            console.log(responseData[1], "withdrawList")
            withdrawList = [...responseData[1]];
            return responseData[1];
            
        } catch (error) {
            console.error("Error getting withdraw list:", error);
            throw error;
        }
    }

    // Function to claim winnings from a battle
    async function claimBattleWinnings(address, battleID) {
        try {
            popupLoading = true;
            // 1. Log the current contract nonce for debugging
            const currentNonce = await prizePoolContract.nonce();
            console.log("Current nonce from contract:", currentNonce.toString());
            // STEP 1-4: Get signature from backend
            const claimResponse = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "claim",
                    params: {
                        address: address,
                        battleID: battleID
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!claimResponse.ok) {
                const responseBody = await claimResponse.json();
                popupLoading = false;
                generalError = true;
                generalErrorValue = (responseBody.error?.message || "Failed to initiate claim");
                throw new Error(responseBody.error?.message || "Failed to initiate claim");
            }

            const responseBody = await claimResponse.json();
            
            // Access the nested response data
            if (!responseBody.success || !responseBody.payload || !responseBody.payload.data) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = "Invalid response format from server";
                throw new Error("Invalid response format from server");
            }
            console.log("Full response from server:", responseBody);
            const responseData = responseBody.payload.data;
            console.log(responseData, "responseData")
            // Verify response type
            if (responseData[0] !== "claimSignature") {
                console.log(responseData, "responseData")
                popupLoading = false;
                generalError = true;
                generalErrorValue = "Invalid response format from server";
                throw new Error(`Unexpected response from server: ${responseData[0]}`);
            }
            
            const { signature } = responseData[1];
            
            // STEP 5: Call contract claim function with signature
            const tx = await prizePoolContract.claim(
                battleID,
                signature.r,
                signature.s,
                signature.v,
                {
                    gasLimit: 2000000, // Add explicit gas limit
                }
            );
            console.log("Transaction sent:", tx.hash);
            
            // STEP 6: Immediately send transaction hash to backend
            await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "confirmClaimTx",
                    params: {
                        battleID: battleID,
                        address: address,
                        txHash: tx.hash
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
            
            // STEP 8: Wait for transaction to complete
            console.log("Waiting for transaction confirmation...");
            try {
                const receipt = await tx.wait();
                if (receipt.status !== 1) {
                    popupLoading = false;
                    generalError = true;
                    generalErrorValue = ("Transaction failed with status: " + receipt.status);
                    throw new Error("Transaction failed with status: " + receipt.status);
                }
            } catch (error) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = ("Transaction failed: " + (error.message || "Unknown error"));

                throw new Error("Transaction failed: " + (error.message || "Unknown error"));
            }
            
            // Notify backend of successful completion
            const finalResponse = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "finalizeClaimTx",
                    params: {
                        battleID: battleID
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!finalResponse.ok) {
                const responseBody = await finalResponse.json();
                popupLoading = false;
                generalError = true;
                generalErrorValue = (responseBody.error?.message || "Failed to finalize claim");
                throw new Error(responseBody.error?.message || "Failed to finalize claim");
            }
            
            // Update UI or navigate
            console.log("Claim completed successfully");
            popupLoading = false;
            await getWithdrawList(address);
            return true;
        } catch (error) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = ("Error claiming battle winnings:", error);
            console.error("Error claiming battle winnings:", error);
            throw error;
        }
    }

    // Function to delist a battle
    async function delistBattle(address, battleID) {
        popupLoading = true;
        try {
            // STEP 1: Call contract delist function
            const tx = await prizePoolContract.delist(battleID);
            
            // STEP 2: Immediately send transaction hash to backend
            await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "confirmDelistTx",
                    params: {
                        battleID: battleID,
                        address: address,
                        txHash: tx.hash
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
            
            // STEP 4: Wait for transaction to complete
            try {
                const receipt = await tx.wait();
                if (receipt.status !== 1) {
                    popupLoading = false;
                    generalError = true;
                    generalErrorValue = ("Transaction failed with status: " + receipt.status);
                    throw new Error("Transaction failed with status: " + receipt.status);
                }
            } catch (error) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = ("Transaction failed: " + (error.message || "Unknown error"));
                console.error("Transaction failed:", error);
                throw new Error("Transaction failed: " + (error.message || "Unknown error"));
            }
            
            // Notify backend of successful completion
            const finalResponse = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "finalizeDelistTx",
                    params: {
                        battleID: battleID
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!finalResponse.ok) {
                const responseBody = await finalResponse.json();
                popupLoading = false;
                generalError = true;
                generalErrorValue = (responseBody.error?.message || "Failed to finalize delist");
                throw new Error(responseBody.error?.message || "Failed to finalize delist");
            }
            
            popupLoading = false;
            location.reload();
            return true;
        } catch (error) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = ("Error delisting battle:", error);
            console.error("Error delisting battle:", error);
            throw error;
        }
    }


    async function getAllBattleHistory() {
    try {
            const response = await fetch(config.rpcUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    method: "getAllBattleHistory",
                    params: {
                    address: userAddress
                    }
                })
            });

            if (response.ok) {
                const responseBody = await response.json();
            
                battleProfile = responseBody.payload.data[1]
                challengeHistory = battleProfile.challengeHistory
                defendHistory = battleProfile.defendHistory
                battleHistory = [...challengeHistory,...defendHistory]
                
                challengePerDay =   battleProfile.stats.challengePerDay
                challengeUsed = battleProfile.stats.challengeUsed;

                return responseBody.payload.data[1];
            } else {
                const responseBody = await response.json();
                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        } catch (error) {
            console.error('Failed to fetch battle history:', error);
            throw error;
        }
    }
    
    async function initProfile() {
        try {
                const response = await fetch(config.rpcUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        method: "initProfile",
                        params: {
                        address: userAddress
                        }
                    })
                });

                if (response.ok) {
                    const responseBody = await response.json();
                
                    questList = responseBody.payload.data[1];
                    return responseBody.payload.data[1];
                } else {
                    const responseBody = await response.json();
                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);
                    }
                }
            } catch (error) {
                console.error('Failed to fetch battle history:', error);
                throw error;
            }
    }
    
    async function getUserQuests() {
    try {   
            console.log("getUserQuests")
            const response = await fetch(config.rpcUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    method: "getUserQuests",
                    params: {
                    userAddress: userAddress
                    }
                })
            });

            if (response.ok) {
                const responseBody = await response.json();
               
                questList = responseBody.payload.data[1];
                return responseBody.payload.data[1];
            } else {
                const responseBody = await response.json();
                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        } catch (error) {
            console.error('Failed to fetch battle history:', error);
            throw error;
        }
    }



    async function claimQuestReward(questId) {
    try {
            const response = await fetch(config.rpcUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    method: "claimQuestReward",
                    params: {
                    userAddress: userAddress,
                    questId: questId
                    }
                })
            });

            if (response.ok) {
                const responseBody = await response.json();
               
                location.reload()

                return responseBody.payload.data[1];
            } else {
                const responseBody = await response.json();
                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                    
                }
            }
        } catch (error) {
            console.error('Failed to fetch battle history:', error);
            throw error;
        }
    }

    /////////////////////////////////////////////////////////RANK/////////////////////////////////////////////////
    async function enterRank(nfts, address) {
        // Get attributes of nfts
        const filteredNfts = nfts.map(nft => ({ collectionAddress: nft.collection, id: nft.id }));
        const attributeList = await getAttributes(filteredNfts);
        const finalNfts = [];
        for (let i = 0; i < attributeList.length; i++) {
            finalNfts.push({
                collection: nfts[i].collection,
                id: parseInt(nfts[i].id),
                attributes: attributeList[i]
            });
        }
        console.log(finalNfts,"finalRankNfts");
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "enterRank",
                params: {
                    address,
                    rankSquad: finalNfts
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            rankMatchPopUp = false;
            window.reload();
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }

    async function changeRankSquad(nfts, address) {
        // Get attributes of nfts
        const filteredNfts = nfts.map(nft => ({ collectionAddress: nft.collection, id: nft.id }));
        const attributeList = await getAttributes(filteredNfts);
        const finalNfts = [];
        for (let i = 0; i < attributeList.length; i++) {
            finalNfts.push({
                collection: nfts[i].collection,
                id: parseInt(nfts[i].id),
                attributes: attributeList[i]
            });
        }
        console.log(finalNfts,"finalRankNfts");
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "changeRankSquad",
                params: {
                    address,
                    rankSquad: finalNfts
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            rankMatchPopUp = false;
            location.reload();
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }

    let rankAndNearbys = [];

    async function getRankAndNearby() {
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getRankAndNearby",
                params:{
                    address: userAddress
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            rankAndNearbys = responseBody.payload.data[1];
            rankAndNearbys = rankAndNearbys;
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }; 

    let rankUserProfile = {
        rankSquad: [],  // Initialize with empty array
        userAddress: ""
    };

    let challengeRankUsed;
    let challengeRankPerDay;
    let seasonInfo = [];
    let rankBattleHistories = [];

    async function getRankUserProfile() {
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getRankUserProfile",
                params:{
                    address: userAddress
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();
            rankUserProfile = responseBody.payload.data[1];
            console.log(rankUserProfile, "rankUserProfilerankUserProfile")
            rankUserProfile = rankUserProfile;
            challengeRankUsed = rankUserProfile.challengesUsed;
            challengeRankPerDay = rankUserProfile.totalChallengesPerDay;
            seasonInfo = rankUserProfile.seasonInfo;
            seasonInfo = [...seasonInfo];

            rankBattleHistories = rankUserProfile.battleHistory;
            rankBattleHistories = [...rankBattleHistories]
            console.log(rankBattleHistories, "rankBattleHistories")
        
            console.log("rankUserProfile",rankUserProfile);
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }; 

    async function rankChallenge(caddress, daddress) {     
        // Receive available matches
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "rankChallenge",
                params: {
                    caddress,
                    daddress
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();

            console.log(responseBody);
    
            goto("./nftarena/rankBattle");
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }
    /////////////////////////////////////Check error on front-end/////////////////////////////////////////////
    let error = false;
    let errorOutChallenge;

    let errorRank = false;
    let errorOutRankChallenge;
    let errorRankSquadAvailable = false;
    let generalError = false;
    let generalErrorValue = "Error";

    function checkSquad() {
        if (!squad[0].id || !squad[1].id || !squad[2].id) {
            error = true;
        }
    }
    function checkRankSquad() {
        if (!rankSquad[0].id || !rankSquad[1].id || !rankSquad[2].id) {
            error = true;
        }
    }
    function checkOutChallenge() {
        if (challengeUsed >= challengePerDay) {
            errorOutChallenge = true;
        }
    }

    function checkOutRankChallenge() {
        if (challengeRankUsed >= challengeRankPerDay) {
            errorOutRankChallenge = true;
        }
    }

    function checkRankSquadAvailable(){
        if(rankUserProfile?.rankSquad?.length === 0 ){
            errorRankSquadAvailable = true;
        }
    }

    setInterval(()=>{
        if(error === true){
            setTimeout(()=>{error = false}, 2000)
        }
        if(errorOutChallenge === true){
            setTimeout(()=>{errorOutChallenge = false}, 2000)
        }
        if(errorRank === true){
            setTimeout(()=>{errorRank = false}, 2000)
        }
        if(errorOutRankChallenge === true){
            setTimeout(()=>{errorOutRankChallenge = false}, 2000)
        }
        if(errorRankSquadAvailable === true){
            setTimeout(()=>{errorRankSquadAvailable = false}, 2000)
        }
        if(generalError === true){
            setTimeout(()=>{generalError = false; generalErrorValue = "Error" }, 2000)
        }
    }, 100);

    ////////////////////////////////////////////////////////////////
    
    let loadingItems1 = [{},{},{},{},{}];
    let loadingItems2 = [{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}];;

    //Copy form old pvp page
    let totalSeconds, totalMinutes , totalHours, totalDays;
    let deadline = 1735650000000;
    let deadline2 = 1735650000000;

    let totalHours1
    let totalHours2

    function formatTimeLeftBattle(timestamp) {
        let milliseconds = Date.now() - timestamp;
        totalSeconds = Math.floor(milliseconds / 1000);
        totalMinutes = Math.floor(totalSeconds / 60);
        totalHours = Math.floor(totalMinutes / 60);
        totalDays = Math.floor(totalHours / 24);

        totalSeconds = totalSeconds % 60;
        totalMinutes =  totalMinutes % 60;
        totalHours2 =  totalHours % 24;
        if(totalDays < 1){
            totalDays =  0;
        } else {totalDays = totalDays}

        return `${totalDays > 0 ? totalDays + 'd ' : ''}${totalHours > 0 ? totalHours + 'h ' : ''}${totalMinutes}m`;
    }


    function formatTimeLeftRank(timestamp) {
        let milliseconds =  timestamp - Date.now();
        totalSeconds = Math.floor(milliseconds / 1000);
        totalMinutes = Math.floor(totalSeconds / 60);
        totalHours = Math.floor(totalMinutes / 60);
        totalDays = Math.floor(totalHours / 24);

        totalSeconds = totalSeconds % 60;
        totalMinutes =  totalMinutes % 60;
        totalHours =  totalHours % 24;
        totalDays = totalDays;

        return `${totalDays > 0 ? totalDays + 'd ' : ''}${totalHours > 0 ? totalHours + 'h ' : ''}${totalMinutes}m`;
    }


    // Function to dynamically format time left based on the remaining duration
    function formatTimeLeft(milliseconds) {
        totalSeconds = Math.floor(milliseconds / 1000);
        totalMinutes = Math.floor(totalSeconds / 60);
        totalHours = Math.floor(totalMinutes / 60);
        totalDays = Math.floor(totalHours / 24);

        totalSeconds = totalSeconds % 60;
        totalMinutes =  totalMinutes % 60;
        totalHours =  totalHours % 24;
        if(totalDays < 1){
            totalDays =  0;
        } else {totalDays = totalDays}
    }

    // Trigger updates date now second
    let dateNow;
    let resetChallengeHours = 0;
    let resetChallengeMinutes = 0;

    setInterval(() => {
        dateNow = Date.now();
        formatTimeLeft(deadline - dateNow);
        formatTimeLeftBattle(deadline2 - dateNow);
        getTimeUntilReset();  // Just call it without parameters
    }, 1000);

    function getTimeUntilReset() {
        const now = new Date();
        const targetHour = 14; // 2 PM UTC
        
        let targetDate = new Date();
        targetDate.setUTCHours(targetHour, 0, 0, 0);
        
        if (now.getUTCHours() >= targetHour) {
            targetDate.setUTCDate(targetDate.getUTCDate() + 1);
        }
        
        const diff = targetDate.getTime() - now.getTime();
        
        // Just update the global variables directly
        resetChallengeHours = Math.floor(diff / (1000 * 60 * 60));
        resetChallengeMinutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    }

    let searchTerm = '';
    let filters = {
        damage: false,
        res: false,
        heal: false,
        maxHp: false
    };
    let name=[{},{}]
    // Get collection name helper
    function getNameByCollection2(collection) {
        const found = name.find(item => item.collection === collection);
        return found ? found.name : collection;
    }

    // Toggle filter function
    function toggleFilter(name) {
        filters[name] = !filters[name];
        filters = filters; // trigger reactivity
    }

  // Computed filtered skills
    $: filteredSkills = skillData.filter(skill => {
        const collectionName = getNameByCollection2(skill.collections);
        const searchMatch = !searchTerm || 
            collectionName.toLowerCase().includes(searchTerm.toLowerCase()) ||
            skill.collections.toLowerCase().includes(searchTerm.toLowerCase());

        const damageMatch = !filters.damage || skill.dmg !== 0;
        const resMatch = !filters.res || skill.resChange !== 0;
        const healMatch = !filters.heal || skill.heal !== 0;
        const maxHpMatch = !filters.maxHp || skill.hpChange !== 0;

        return searchMatch && damageMatch && resMatch && healMatch && maxHpMatch;
    });

    function calculateTotalWithdrawable() {
        if (!withdrawList || withdrawList.length === 0) {
            return 0;
        }
        
        // Sum up all values in the withdrawList
        return withdrawList.reduce((total, item) => total + (item.value * 2), 0);
    }
</script>


{#if isLogin }
    <div class="hidden sm:flex relative flex-col justify-center items-center w-full h-screen bg-dark text-white ">
        <!--Game Screen-->
        <div class="flex flex-col relative md:w-[90vw] w-[100vw] h-[45vw] maw-w-[1920px] max-h-[45vw] m-auto bg-cover rounded-md font-geo px-[2vw] py-[1vw] text-[1vw] overflow-hidden">
            <!--Game nav-->
            <div class="flex justify-between z-10  pl-[1vw]">
                <div class="flex gap-[2.5vw]">
                    <button class="flex items-center text-white" on:click={()=>{goto("../")}}>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-[2vw] w-[2vw] mr-[0.5vw]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                        </svg>
                        <span class="text-[1vw]">BACK</span>
                    </button>
                    <button class="flex flex-col items-center gap-[0.5vw] hover:text-yellow-400"
                    on:click={()=>{navigation = "hall"}}>
                        <img class="h-[2.5vw] mt-[0.5vw]" src="/game/ui/pvp.svg"/>
                        <span class="text-[1vw] font-semibold">
                            PvP
                        </span>
                    </button>
                </div>
                <div class="flex flex-col mt-[0.6vw]">
                    <span class="text-[0.9vw]">
                        Ver 1.0 - Submission for the Electroneum Hackathon
                    </span>
                </div>
            </div>


            <!--Hall-->
            {#if navigation === "hall"}
                <div class="flex gap-[4vw] mt-[1vw] z-10 pl-[1vw]" in:fade={{ duration: 300 }} >
                    <div class="relative justify-center items-center  flex flex-col bg-arenaMedium rounded-md p-[0.5vw]  w-fit">
                        <!--Table-->
                        <div class="flex flex-col flex-grow">
                            <!--Header-->
                            <div class="flex gap-[0.5vw] text-arenaLight px-[0.8vw]">
                                <div class="w-[10%]"></div>
                                <div class="w-[50%]">Address</div>
                                <div class="w-[20%]">Stake</div>
                                <div class="flex justify-center w-[20%]">
                                    <button class="flex w-[20%] justify-center" on:click={()=>{getMatches()}}>
                                        <img alt="refresh rank board" class="h-[1.5vw] w-[1.5vw]" src="/game/ui/refresh.svg"/>
                                    </button>
                                </div>
                            </div>
                            <!--Table-->
                            <div class="flex flex-col gap-[0.7vw] text-[0.8vw] my-[0.5vw] px-[0.8vw] pt-[0.7vw] bg-arenaDark min-h-[28vw] max-h-[28vw] w-[45vw] rounded-md overflow-y-scroll ">
                                {#if matches.length > 0}
                                    {#each matches as match, index}
                                        <!--Example-->
                                        <div class="flex items-center gap-[0.5vw] w-full hover:text-yellow-400">
                                            <div class="w-[10%]">{index+1}</div>
                                            <div class="w-[50%]">{emitBetweenText(match.daddress, 10)}</div>
                                            <div class="w-[20%]">{match.value} {config.nativeCurrency.name}</div>
                                            <div class="w-[20%]">
                                                {#if address !== match.daddress}
                                                    <button on:click={() => {
                                                        checkSquad();
                                                        checkOutChallenge();
                                                        if (!error&&!errorOutChallenge) {
                                                            challenge(squad, address, match.daddress, match.battleID);
                                                        }
                                                    }} class="flex gap-[0.5vw] w-full justify-center items-center text-green hover:text-button">
                                                        <img src="/game/ui/fight.svg" alt="sword icon" class="h-[1.5vw]"/>
                                                        <span class="text-[1vw] ">
                                                            FIGHT
                                                        </span>
                                                    </button>
                                                {:else}
                                                    <button class="flex gap-[0.5vw] w-full justify-center items-center text-green hover:text-button"
                                                    on:click={() => {
                                                        delistBattle(address, match.battleID)
                                                    }} >
                                                        <span class="text-[1vw] text-red-500 hover:text-button">
                                                            CANCEL
                                                        </span>
                                                    </button>
                                                {/if}
                                            </div>
                                        </div>
                                    {/each}
                                {:else}
                                    <span class="m-auto text-[1.2vw]">
                                        There are no defenders now, let's create a match
                                    </span>
                                {/if}  
                            </div>
                        </div>
                    </div>
                    <!---->
                    <div class="flex flex-col justify-between">
                        <div class="flex flex-col gap-[0.5px]">
                            <span class="text-[3vw]">
                                PVP MODE
                            </span>
                            <span class="text-[1.22vw]">
                                Solo other, winner take staked ${config.nativeCurrency.name} from loser
                            </span>

                            <div class="flex flex-col bg-black border border-white rounded-md px-[1vw] py-[0.2vw] w-fit text-[0.8vw] mt-[0.5vw]">
                                <div class="flex items-center gap-[0.2vw]">
                                    <span>Challenged: {challengeUsed}/{challengePerDay}</span>
                                    <img alt="fight icon" class="h-[0.8vw]" src="/game/ui/fight.svg"/>
                                </div> 
                                <span class="text-[0.7vw] text-darkGray">
                                Reset in {resetChallengeHours}h:{resetChallengeMinutes}m
                                </span>
                            </div>
                        </div>
                        <!--Create a match-->
                        <button class=" flex justify-center items-center h-fit py-[0.7vw] rounded-md border-[0.15vw] border-button hover:border-buttonHover gap-[0.5vw]"
                        on:click={()=>{matchPopUp = true}}>
                            <span class="text-[1vw] text-button hover:text-buttonHover">
                                CREATE A MATCH
                            </span>
                            <img src="/game/ui/fight.svg" alt="fight icon" class="h-[1.5vw]"/>

                        </button>
                        <!--Address-->
                        
                        
                        <div class="flex flex-col rounded-md py-[1vw]">
                            <div class="flex gap-[1vw] mb-[0.5vw] justify-between">
                                <span class="text-[1.1vw] self-start text-white mb-[0.3vw]">
                                    Recent battle history
                                </span>
                                <button class="flex items-center gap-[0.5vw] relative border rounded-md px-[1vw] border-button text-button hover:text-buttonHover hover:border-buttonHover"
                                on:click={()=>{withDrawPopUp = true}}>
                                    <span>Withdraw rewards</span>
                                    {#if withdrawList?.length >0}
                                        <div class=" flex items-center justify-center bg-red-600 w-[1vw] h-[1vw] rounded-full text-[0.5vw] right-[1.5vw] glow-border-run-red">
                            
                                        </div>
                                    {/if}
                                </button>
                            </div>
                            <div class="flex flex-col rounded-md py-[1vw] border border-white">
                                <div class="flex flex-col justify-start text-[0.9vw] font-normal gap-[0.2vw] min-h-[7vw] max-h-[7vw] mx-[1vw] overflow-y-scroll">
                                    {#each battleHistory as battle} 
                                        {#if battle.type === "challenge"}
                                            <button class="flex hover:text-[#81F328]" on:click={window.open(`/nftarena/${battle.type}/${battle.challengerAddress}/${battle.index}`)}>
                                                {#if battle.winner === 1}
                                                    <div class="flex text-[#81F328] mr-[1vw]">
                                                        <span>Won</span>
                                                    </div>
                                                {:else if battle.winner === 2}
                                                    <div class="text-red-700 mr-[1vw]">
                                                        Lost
                                                    </div>
                                                {/if}
                                                <span class="underline">
                                                    You challenge <span class="text-button">{emitBetweenText(battle.defenderAddress, 10)}</span>
                                                </span>
                                                {#if battle.winner === 1}
                                                    <div class="flex gap-[0.2vw] items-center ml-[2vw]">
                                                        <span class=" font-semibold text-white">+ 0</span>
                                                        <img class="h-[1vw]" alt="currency" src="/icons/ETN.png"/>
                                                    </div>
                                                {:else if battle.winner === 2}
                                                    <div class="flex gap-[0.2vw] items-center ml-[2vw]">
                                                        <span class=" font-semibold text-white">- 0</span>
                                                        <img class="h-[1vw]" alt="currency"  src="/icons/ETN.png"/>
                                                    </div>
                                                {/if}
                                            </button>
                                        {/if}
                                        {#if battle.type === "defend"}
                                        <button class="flex justify-between hover:text-[#81F328]" on:click={window.open(`/nftarena/${battle.type}/${battle.defenderAddress}/${battle.index}`)}>
                                            {#if battle.winner === 2}
                                                <div class="flex text-[#81F328] mr-[1vw]">
                                                    <span>Won</span>
                                                </div>
                                            {:else if battle.winner === 1}
                                                <div class="text-red-700 mr-[1vw]">
                                                    Lost
                                                </div>
                                            {/if}
                                            <span class="underline">
                                                You defend <span class="text-button">{emitBetweenText(battle.challengerAddress, 10)}</span>
                                            </span>
                                            {#if battle.winner === 2}
                                                <div class="flex gap-[0.2vw] items-center ml-[2vw]">
                                                    <span class=" font-semibold text-white">+ 0</span>
                                                    <img class="h-[1vw]" alt="currency" src="/icons/ETN.png"/>
                                                </div>
                                            {:else if battle.winner === 1}
                                                <div class="flex gap-[0.2vw] items-center ml-[2vw]">
                                                    <span class=" font-semibold text-white">- 0</span>
                                                    <img class="h-[1vw]" alt="currency" src="/icons/ETN.png"/>
                                                </div>
                                            {/if}
                                            <span class="self-end text-[0.8vw] text-darkGray w-[6vw]">
                                                {formatTimeLeftBattle(battle.timestamp)}
                                            </span>
                                        </button>
                                    {/if}
                                    {/each}
                                </div>
                            </div>
                        </div>
                    </div>
                    
                </div>
            {/if}

            {#if navigation === "myTeam"}
                <div class ="mt-[2vw] flex flex-col rounded-md w-full z-10" in:fade={{ duration: 300 }} >
                    <div class="relative {selected.id?"grid grid-cols-10":""} gap-[2vw] w-full">
                        <!--Squad-->
                        <!---->
                        <div class="relative col-span-6 flex flex-col rounded-md">
                            <div class=" flex flex-col justify-center items-center border border-arenaLight mt-[0.5vw] flex justify-center px-[1vw] py-[0.5vw] bg-arenaMedium gap-[0.5vw] rounded-md z-10">
                                <span class="text-[1.3vw] self-center text-white font-semibold">
                                    MY SQUAD
                                </span>
                                <div class="flex gap-[0.5vw]">
                                    <!--1-->
                                    {#if squad[0].id}
                                        <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[0] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                            <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[4vw] h-[4vw] z-10">
                                                <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                            </div>
                                            <img class="bg-black w-[4vw] h-[4vw]" src={`${config.rpcUrl}/cdn/nft/${squad[0].collection}/${squad[0].id}/200/200`}/>
                                        </button>
                                    {:else}
                                        <div class="flex">
                                            <img class="w-[4vw] h-[4vw]"  alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                        </div>
                                    {/if}
                                    <!--2-->
                                    {#if squad[1].id}
                                        <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[1] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                            <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[4vw] h-[4vw] z-10">
                                                <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                            </div>
                                            <img class="bg-black w-[4vw] h-[4vw]" src={`${config.rpcUrl}/cdn/nft/${squad[1].collection}/${squad[1].id}/200/200`}/>
                                        </button>
                                    {:else}
                                        <div class="flex">
                                            <img class="w-[4vw] h-[4vw]"  alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                        </div>
                                    {/if}
                                    <!--3-->
                                    {#if squad[2].id}
                                        <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[2] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                            <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[4vw] h-[4vw] z-10">
                                                <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                            </div>
                                            <img class="bg-black w-[4vw] h-[4vw]" src={`${config.rpcUrl}/cdn/nft/${squad[2].collection}/${squad[2].id}/200/200`}/>
                                        </button>
                                    {:else}
                                        <div class="flex">
                                            <img class="w-[4vw] h-[4vw]"  alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                        </div>
                                    {/if}
                                </div>
                            
                            </div>
                            <div class="flex flex-col justify-between bg-arenaDark">
                                <div class="flex flex-wrap min-h-[20vw] max-h-[20vw] gap-[0.8vw] p-[1vw] rounded-md overflow-y-scroll">
                                    <!--Example-->
                                    {#if items.length > 0 && !loading}
                                        {#each items as item}  
                                            <button on:click={async () => {
                                                selected.id = item.id;
                                                selected.collection = item.collection;
                                                chooseSquad();
                                                await getAttributes([{ collectionAddress: item.collection, id: item.id }]);
                                                
                                                // test
                                                x = await getAttributes([{ collectionAddress: selected.collection, id: selected.id  }]);
                                                showSelectedAtributes  = x[0];
                                        
                                            }} class="flex bg-black hover:border border-linearGreen h-fit rounded-md overflow-hidden">
                                                <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${item.collection}/${item.id}/200/200`}/>
                                            </button>
                                        {/each}                         
                                    {:else if loading }
                                        {#each loadingItems2 as loadItem} 
                                        <div class="loading w-[5vw] h-[5vw] ">
        
                                        </div>
                                        {/each}
                                    {:else if items.length == 0}
                                        <div class="flex flex-col text-white m-auto items-center">
                                            <span class="text-arenaLight">Looks like you don't have any NFTs to battle with</span>
                                            <button class="flex self-center p-[0.3vw] rounded-md bg-button hover:bg-buttonHover w-fit text-white text-[0.8vw] mt-[0.5vw]"
                                            on:click={()=>{goto("./nftarena/importnft")}}>
                                                Import & Generate skills for your NFT
                                            </button>
                                        </div>
                                    {/if}
                                </div>
                                <div class="flex self-center justify-center">
                                    <button class="flex w-fit text-white my-[0.5vw] text-[0.9vw] gap-[0.5vw] items-center underline"
                                    on:click={()=> { window.open(`${config.site}/collections/`, "_blank") }}>
                                        <span>Explore NFT Collections on our marketplace </span>
                                        <img class="h-[1vw] inline" src="/game/ui/visit.svg" alt="visit site" />
                                    </button>

                                </div>
                            </div>

                        </div>
                        <div class="col-span-4 flex flex-col rounded-md " >
                            {#if selected.id}
                                <div class="flex flex-col p-[1vw] bg-arenaMedium rounded-md" in:slide={{ duration: 300 }}>
                                    <div class="flex gap-[1vw]">
                                        <div class="w-[5vw] h-[5vw] bg-black">
                                            <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${selected.collection}/${selected.id}/200/200`}/>
                                        </div>
                                        <!---->
                                        <div class="flex flex-col justify-center gap-[10px]">
                                            <span class="text-arenaLight">
                                                From <span class="text-button font-thin"> {selectedCollectionName}</span>
                                            </span>
                                            <span class=" font-semibold">
                                                #{selected.id}
                                            </span>
                                        </div>
                                    </div>
                                    <div class="flex flex-col bg-arenaDark p-[1vw] text-arenaLight rounded-md mt-[1vw] gap-[1vw] max-h-[23vw] min-h-[23vw] overflow-y-scroll">
                                        <!-- skill-->
                                        {#each showSelectedAtributes as showSelectedAtribute}
                                            <div class="flex flex-col">
                                                <span>
                                                    <span class="text-button">
                                                        {showSelectedAtribute}
                                                    </span>
                                                </span>
                                                <span class="text-[0.8vw] font-medium">
                                                    Encounter Rate:
                                                    <span class="text-white">
                                                        {(100/showSelectedAtributes.length).toFixed(2)}%
                                                    </span>
                                                </span>
                                                <span class="text-[0.8vw] text-white font-medium ml-[1vw]">
                                                    {getEffect(selected.collection,showSelectedAtribute)}  
                                                </span>
                                            </div>
                                        {/each}
                    
                                    </div>
                                </div>
                            {/if}
                        </div>
                    </div>
                </div>
            {/if}
                
            {#if navigation === "allSkill"} 
                <div class ="mt-[0.5vw] flex flex-col rounded-md w-full bg-arenaMedium gap-[0.5vw] pb-[0.5vw] z-10 min-h-[32vw]" in:fade={{ duration: 300 }} >
                    <div class="flex flex-col p-[0.5vw]">
                        <!-- Filter Controls -->
                        <div class="flex py-[0.50vw] justify-start gap-[5vw]">
                            <input 
                            class="border-[0.2vw] border-arenaLight p-[0.3vw] text-[0.8vw] w-[20vw] rounded-md bg-arenaDark text-arenaLight" 
                            placeholder="Search by collection name or contract"
                            bind:value={searchTerm}
                            />
                            <div class="flex gap-[0.5vw]">
                                <button 
                                    class=" w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight {filters.damage ? 'bg-black' : 'bg-arenaDark'}"
                                    on:click={() => {toggleFilter('damage'); console.log(filters)}}
                                >
                                    <img class="h-[1.5vw]" src="game/ui/dame.svg" alt="dame filter"/>
                                </button>
                                <button 
                                    class=" w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight {filters.res ? 'bg-black' : 'bg-arenaDark'}"
                                    on:click={() => toggleFilter('res')}
                                >
                                    <img class="h-[1.5vw]" src="game/ui/res.svg" alt="res filter"/>
                                </button>
                                <button 
                                    class="w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight {filters.heal ? 'bg-black' : 'bg-arenaDark'}"
                                    on:click={() => toggleFilter('heal')}
                                >
                                    <img class="h-[1.5vw]" src="game/ui/heal.svg" alt="heal filter"/>
                                </button>
                                <button 
                                    class=" w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight {filters.maxHp ? 'bg-black' : 'bg-arenaDark'}"
                                    on:click={() => toggleFilter('maxHp')}
                                >
                                    <img class="h-[1.5vw]" src="game/ui/maxHp.svg" alt="maxHp filter"/>
                                </button>
                                <button 
                                    class="w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight"
                                >
                                    <img class="h-[1.5vw]" src="game/ui/speed.svg" alt="speed filter"/>
                                </button>
                                <button 
                                class="bg-arenaDark w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight"
                            >
                                <img class="h-[1.5vw]" src="game/ui/stun.svg" alt="stun filter"/>
                            </button>
                            <button 
                            class="bg-arenaDark w-[4vw] justify-center rounded-md flex items-center border-[0.2vw] border-arenaLight"
                        >
                            <img class="h-[1.5vw]" src="game/ui/poison.svg" alt="poison filter"/>
                        </button>
                            </div>
                        </div>
                        <!--Skill Table-->
                        <div class="flex flex-col flex-grow w-ful bg-arenaDark max-h-[27vw]">
                            <!--Header-->
                            <div class="flex gap-[0.5vw] px-[0.8vw] bg-arenaDark text-arenaLight">
                                <div class="w-[20%]">Collection</div>
                                <div class="w-[30%]">Trait</div>
                                <div class="w-[20%]">Description</div>
                            </div>
                            <!--Table-->
                            <div class="flex flex-col gap-[0.7vw] text-[0.8vw] my-[0.5vw] px-[0.8vw] bg-arenaDark rounded-md overflow-y-scroll min-h-[24vw] ">
                                <!--Example-->
                                {#each filteredSkills as skill}
                                    <div class="flex items-center gap-[0.5vw] w-full hover:text-yellow-400">
                        
                                        <div class="w-[20%]">example name</div>
                                        <div class="w-[30%]">{skill.attribute}</div>
                                        <div class="w-[50%]">
                                            {skill.desc}
                                        </div>
                                    </div>
                                {/each} 
                            </div>
                        </div>
                        <button class="flex self-center mt-[0.5vw] p-[0.5vw] rounded-md bg-arenaMedium w-fit text-white border border-button hover:border-buttonHover">
                                Import NFT
                        </button>
                    </div>
                </div>
            {/if}
            <!--Popup Match-->
            {#if matchPopUp}
                <div class="absolute font-semibold flex flex-col items-center inset-0 bg-black bg-opacity-70 z-30 text-white z-10 w-full" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                    <div class ="relative flex flex-col mt-[2vw]  pt-[1vw] pb-[1vw] px-[2vw] bg-arenaBg rounded-md w-[86vw]">
                        <button class="self-end" on:click={()=>{ matchPopUp = false}}>
                            <img class="absolute h-[3vw] inline-block right-[1vw]" alt="close icon" src="/game/ui/close.svg"/>
                        </button>
                        <!---->
                        <div class="grid grid-cols-10 gap-[2vw] w-full">
                            <div class="col-span-6 flex flex-col rounded-md p-[0.5vw] gap-[0.5vw]">
                                <span class="text-[1.3vw]">
                                    Choose your NFT
                                </span>
                                <span class="text-[1vw] font-normal text-white">
                                    You can choose duplicated NFTs
                                </span>
                                <!--NFT places-->
                                <div class="flex flex-col border-[0.3px] border-arenaLight rounded-md">
                                    <div class="flex flex-wrap rounded-md justify-start min-h-[16vw] max-h-[16vw] overflow-y-scroll bg-arenaDark gap-x-[0.5vw] p-[1vw]">
                                        <!--Example-->
                                        {#if items.length >0 && !loading}
                                            <div class="flex flex-wrap gap-[0.5vw] justify-start items-start gap-y-[0.1vw]">
                                                {#each items as item}  
                                                    <button on:click={async () => {
                                                        selected.id = item.id;
                                                        selected.collection = item.collection;
                                                        chooseSquad();
                                                        x = await getAttributes([{ collectionAddress: selected.collection, id: selected.id  }]);
                                                        showSelectedAtributes  = x[0];
                                                    }} class="flex bg-black hover:border border-yellow h-fit rounded-md overflow-hidden">
                                                        <img alt="NFT" class="bg-black w-[5vw] h-[5vw] object-cover" src={`${config.rpcUrl}/cdn/nft/${item.collection}/${item.id}/200/200`}/>
                                                    </button>
                                                {/each}
                                            </div>                          
                                        {:else if loading }
                                            {#each loadingItems1 as loadItem} 
                                            <div class="loading w-[5vw] h-[5vw] ">
        
                                            </div>
                                            {/each}
                                        {:else if items.length ===0}
                                            <div class="flex flex-col text-white m-auto items-center">
                                                <span class="text-arenaLight">Looks like you don't have any NFTs to battle with</span>
                                                <div class="flex items-center gap-[1vw]">
                                                    <div class="flex items-center gap-[1vw]">
                                                        <button class="flex self-center p-[0.3vw] rounded-md bg-button hover:bg-buttonHover w-fit text-white text-[0.8vw]"
                                                        on:click={()=>{goto("./nftarena/importnft")}}>
                                                            Import & Generate skills for your NFT
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>
                                        {/if}
                                    </div>
                                    <div class="flex items-center py-[0.5vw] bg-arenaMedium">
                                        <span class="text-[1.3vw] ml-[3vw] mr-[4vw]">
                                            My Squad
                                        </span>
                                        <!--Squad-->
                                        <div class="flex justify-center gap-[2vw] rounded-md">
                                            <!--1-->
                                            {#if squad[0].id}
                                                <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[0] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                                    <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[5vw] h-[5vw] z-10">
                                                        <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                                    </div>
                                                    <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${squad[0].collection}/${squad[0].id}/200/200`}/>
                                                </button>
                                            {:else}
                                                <div class="flex">
                                                    <img class="w-[5vw] h-[5vw]"  alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                                </div>
                                            {/if}
                                            <!--2-->
                                            {#if squad[1].id}
                                                <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[1] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                                    <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[5vw] h-[5vw] z-10">
                                                        <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                                    </div>
                                                    <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${squad[1].collection}/${squad[1].id}/200/200`}/>
                                                </button>
                                            {:else}
                                                <div class="flex">
                                                    <img class="w-[5vw] h-[5vw]" alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                                </div>
                                            {/if}
                                            <!--3-->
                                            {#if squad[2].id}
                                                <button class="flex relative shadow-md rounded-md overflow-hidden" on:click={()=>{squad[2] = {}; squad = squad}} in:fade={{ duration: 300 }} >
                                                    <div class="hover:opacity-70 opacity-0 flex absolute bg-black justify-center items-center w-[5vw] h-[5vw] z-10">
                                                        <img class="w-[3vw] h-[3vw]" alt="close icon" src="/game/ui/close.svg"/>
                                                    </div>
                                                    <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${squad[2].collection}/${squad[2].id}/200/200`}/>
                                                </button>
                                            {:else}
                                                <div class="flex">
                                                    <img class="w-[5vw] h-[5vw]"  alt="empty slot" src="/game/ui/emptySlot.svg"/>
                                                </div>
                                            {/if}
                                        </div>
                                    </div>

                                </div>

                            </div>
                            <div class="col-span-4 flex flex-col rounded-md justify-end" >
                                {#if selected.id}
                                    <div class="flex flex-col p-[1vw] bg-arenaMedium rounded-md" in:slide={{ duration: 300 }}>
                                        <div class="flex gap-[1vw]">
                                            <div class="w-[5vw] h-[5vw] bg-black">
                                                <img class="bg-black w-[5vw] h-[5vw]" src={`${config.rpcUrl}/cdn/nft/${selected.collection}/${selected.id}/200/200`}/>
                                            </div>
                                            <!---->
                                            <div class="flex flex-col justify-center gap-[10px]">
                                                <span class="text-arenaLight">
                                                    From <span class="text-button font-thin"> {selectedCollectionName}</span>
                                                </span>
                                                <span class=" font-semibold">
                                                    #{selected.id}
                                                </span>
                                            </div>
                                        </div>
                                        <div class="flex flex-col bg-arenaDark p-[1vw] text-arenaLight rounded-md mt-[1vw] gap-[1vw] max-h-[15vw] min-h-[15vw] overflow-y-scroll">
                                            <!-- skill-->
                                            {#each showSelectedAtributes as showSelectedAtribute}
                                                <div class="flex flex-col">
                                                    <span>
                                                        <span class="text-button">
                                                            {showSelectedAtribute}
                                                        </span>
                                                    </span>
                                                    <span class="text-[0.8vw] font-medium">
                                                        Encounter Rate:
                                                        <span class="text-white">
                                                            {(100/showSelectedAtributes.length).toFixed(2)}%
                                                        </span>
                                                    </span>
                                                    <span class="text-[0.8vw] text-white font-medium ml-[1vw]">
                                                        {getEffect(selected.collection,showSelectedAtribute)}  
                                                    </span>
                                                </div>
                                            {/each}
                        
                                        </div>
                                    </div>
                                {/if}
                            </div>
                        </div>
                        <!--Stake-->
                        <div class="flex flex-col self-center w-fit w-[36vw] items-center justify-center gap-[0.3vw] bg-arenaMedium font-normal py-[0.5vw] my-[1.5vw] rounded-md">
                            <div class="flex gap-[0.6vw] text-[1.1vw] px-[1vw]">
                                <span class="">Stake :</span>
                                <input bind:value={inputStake} class="flex justify-end text-white bg-arenaDark rounded-md w-[8vw] px-[0.4vw]" placeholder="0"/>
                                <span>{config.nativeCurrency.name}</span>
                            </div>
                        </div>
                        <!--Create a match-->
                        <button on:click={() => {
                            checkSquad();

                            if (!error) {
                                loadQueue(squad, address, inputStake);
                            }
                        }} class="flex justify-center self-center items-center h-fit py-[0.7vw] rounded-md border-[0.15vw] border-button hover:border-buttonHover gap-[0.5vw] w-fit px-[11vw]">
                            <img alt="fight" src="/game/ui/fight.svg" class="h-[2vw]"/>
                            <span class="text-[1vw] ">
                                CREATE A MATCH
                            </span>
                            <!--
                            <div class="absolute bg-dark w-[50vw] h-[20vw] opacity-50">

                            </div>-->
                        </button>
                    </div>
                </div>
            {/if}



            <!--Error PopUp-->
            {#if error}
                <div class="absolute text-[2vw] bottom-0 right-[20vw] mb-[3vw] bg-red-500 px-[1vw] py-[0.5vw] rounded-md z-50" in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
                    You have to choose squad before battle
                </div>
            {/if}
            {#if errorOutChallenge}
                <div class="absolute text-[2vw] bottom-0 right-[20vw] mb-[3vw] bg-red-500 px-[1vw] py-[0.5vw] rounded-md z-50" in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
                    You have used all your challenge attempts for today.
                </div>
            {/if}

            {#if errorRankSquadAvailable}
                <div class="absolute text-[1.5vw] bottom-0 right-[20vw] mb-[3vw] bg-red-500 px-[1vw] py-[0.5vw] rounded-md z-50" in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
                    Please click "Enter Rank" to set up your rank squad before battle
                </div>
            {/if}
            {#if generalError}
                <div class="absolute text-[1.5vw] bottom-0 right-[20vw] mb-[3vw] bg-red-500 px-[1vw] py-[0.5vw] rounded-md z-50" in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
                    {generalErrorValue}
                </div>
            {/if}

            {#if withDrawPopUp}
                <div class="hidden md:flex fixed justify-center font-semibold  flex-col inset-0 bg-black bg-opacity-70 z-50"> 
                    <div class="relative flex flex-col justify-start min-h-[20vw] pb-[3vw] w-[45vw] bg-arenaDark rounded-md items-center self-center border-[0.2vw] border-arenaLight">
                        <button class="absolute self-end right-[0.5vw]" on:click={()=>{ withDrawPopUp = false}}>
                            <img class=" h-[2.5vw] inline-block " alt="close icon" src="/game/ui/close.svg"/>
                        </button>   
                        <span class="text-[2vw] text-button mt-[2vw]">
                            Withdraw Rewards
                        </span>
                        <span class="font-normal mb-[1vw] border rounded-md px-[1vw]">
                            Total withdrawable: <span class="text-button">{calculateTotalWithdrawable(withdrawList)} {config.nativeCurrency.name}</span> 
                        </span>
                        {#if withdrawList?.length >0}
                        <div class="flex flex-col justify-start text-[0.9vw] font-normal gap-[0.2vw] min-h-[10vw] max-h-[10vw] rounded-md p-[1vw] mx-[1vw] overflow-y-scroll bg-black">
                            {#each withdrawList as withdrawItem} 
                                <div class="flex items-center">
                                    {#if address === withdrawItem.caddress}
                                        <div class="flex text-[#81F328] mr-[1vw]">
                                            Challenge Success
                                        </div>
                                        <span class="">
                                            You challenged <span class="text-button">{emitBetweenText(withdrawItem.daddress, 10)}</span>
                                        </span>
                                    {:else if address === withdrawItem.daddress}
                                        <div class="text-[#81F328] mr-[1vw]">
                                            Defend Success
                                        </div>
                                        <span class="">
                                            You defended <span class="text-button">{emitBetweenText(withdrawItem.caddress, 10)}</span>
                                        </span>
                                    {/if}
                                    <div class="flex gap-[0.2vw] items-center ml-[2vw]">
                                        <span class=" font-semibold text-white">{withdrawItem.value*2}</span>
                                        <img class="h-[1vw]" alt="currency" src="/icons/ETN.png"/>
                                    </div>
                                    <button class="mx-[1vw] px-[1vw] rounded-md bg-button hover:bg-black hover:border-buttonHover hover:border" on:click={()=>claimBattleWinnings(address, withdrawItem.battleID)}>
                                        Withdraw
                                    </button>
    
                                </div>
                            {/each}
                        </div>
                        {:else}
                            <span class="mt-[2vw] text-[1.1vw] font-normal">
                                Looks like you don't have any winning matches to claim stake
                            </span>   
                        {/if}

                    </div>
                </div>
            {/if}



            <!--Game nav-->
            <div class="relative flex items-center gap-[2.5vw] z-10 pl-[1vw] mt-[1vw]">
                <button class="flex flex-col items-center gap-[0.5vw] hover:text-yellow-400" 
                on:click={()=>{navigation="myTeam"}}>
                    <img alt="my squad" class="h-[2.5vw]" src="/game/ui/squad.svg"/>
                    <span class="text-[0.9vw] font-semibold">
                        My squad
                    </span>
                </button>
                <button class="flex flex-col items-center gap-[0.5vw] hover:text-yellow-400" on:click={()=>{navigation="allSkill"}} >
                    <img class="h-[2.5vw]" src="/game/ui/skills.svg"/>
                    <span class="text-[0.9vw] font-semibold">
                        All skills
                    </span>
                </button>
                <button class="flex flex-col items-center gap-[0.5vw] hover:text-yellow-400" on:click={()=>{goto("./nftarena/importnft")}} >
                    <img class="h-[2.5vw]" src="/game/ui/import.svg"/>
                    <span class="text-[0.9vw] font-semibold">
                        Import existing NFT
                    </span>
                </button>

                
                <div class="absolute flex flex-col bg-arenaDark gap-[0.2vw] px-[1vw] py-[1vw]  rounded-md right-[4vw] border border-arenaMedium">
                    <div class="flex justify-between bg-arenaDark gap-[0.5vw]">
                        <span class="text-[0.9vw] text-arenaLight">
                            Your profile: 
                        </span>
                        <span class="text-[0.9vw]">
                            {emitBetweenText(address, 10)}
                        </span>
                    </div>
                    <div class="flex justify-between bg-arenaDark gap-[0.5vw] text-[0.9vw] text-[#9F8A42">
                        <div class="text-arenaLight">
                            Withdrawable
                        </div>
                        <button class="flex gap-[0.2vw] text-button text-buttonHover underline" on:click={()=>{withDrawPopUp = true}}>
                            <span class="text-[0.9vw]">
                                {calculateTotalWithdrawable(withdrawList)}
                            </span>
                            <span class="text-[0.9vw]">
                                {config.nativeCurrency.name}
                            </span>
                        </button>
                        
                    </div>
                </div>

            </div>
            <!--Background-->
            {#if navigation === "rankMode"}
                <img class="absolute bg-cover w-full h-full" alt="background" src="/game/ui/rankModeBg.webp"/>
            {:else}
                <img class="absolute bg-cover w-full h-full" alt="background" src="/game/ui/bgpvp.webp"/>
            {/if}

            <!--PopUp start-->
            {#if !loading && items.length ===0 && (navigation === "hall" || navigation === "rankMode" )&& isShowMintFree}
                <div class="absolute flex right-10 bottom-10 z-10 w-[20vw] h-[15vw] bg-black bg-opacity-80 rounded-md border border-button" >
                    <div class="flex flex-col justify-center items-center relative w-full h-full ">
                        <button class="flex self-center p-[0.3vw] rounded-md bg-button hover:bg-buttonHover w-fit text-white text-[0.9vw] mt-[0.5vw]"
                        on:click={()=>{goto("./nftarena/importnft")}}>
                            Import & Generate skills for your NFT
                        </button>
                        <span class="text-[0.9vw] mt-[1vw] pt-[1vw] border-t">
                            Don't own any ERC721 NFTs?
                        </span>
                        <button class="flex self-center p-[0.3vw] rounded-md bg-button hover:bg-buttonHover w-fit text-white text-[0.9vw] mt-[0.5vw]"
                        on:click={()=> { window.open(`${config.site}/mint/`, "_blank") }}>
                            Check out our launchpad 
                        </button>
                        <button on:click={()=>isShowMintFree = false}>
                            <img class="absolute w-[2vw] h-[2vw] right-[1vw] top-[1vw] z-10" alt="close icon" src="/game/ui/closeRed.svg"/>
                        </button>
                    </div>
                </div>
            {/if}
            {#if popupLoading}
                <div class="z-50">
                    <Loading/>
                </div>
            {/if}
        </div>
        
    </div>
{/if}

{#if !isLogin}
    <!--Force to connect wallet-->
    <div class="hidden sm:flex fixed justify-center font-semibold  flex-col inset-0 bg-black bg-opacity-90 z-50 font-geo" > 
        <div class="relative flex flex-col justify-center h-[45vw]">
            <img class="absolute" alt="background" src="/game/load/bgLoad.webp"/>
            <!--Catto-->
            <img alt="catto nft" class="absolute left-[5vw] bottom-[21vw] z-10 h-[15vw] w-auto object-contain floating" src="/game/load/coolCat.png"/>
            <!--Ape-->
            <div class="flex absolute left-[17vw] bottom-[13vw] w-[50vw]  h-[15vw] floating3">
                <div class="flex justify-start relative w-full h-full">
                    <img alt="random nft" class="absolute  z-10 h-[15vw] w-auto object-contain" src="/game/load/ape.png"/>

                    <img alt="fire" class="absolute left-[1vw] top-[1vw] z-20 h-[12vw] w-[28vw] widthPulse" src="/game/load/fire.png"/>
                    
                </div>
            </div>
            <!--punk-->
            <div class="flex absolute left-[5vw] bottom-[3vw]  z-10 h-[12vw]  w-[11vw] floating">
                <div class="flex relative w-full h-full">
                    <img alt="random nft" class="absolute z-10 h-[12vw] w-auto object-contain" src="/game/load/punk.png"/>
                    <img alt="hit effect" class="absolute left-[6vw] top-[2vw] z-20 h-auto w-[10vw] object-contain glitch" src="/game/load/hit.png"/>
                </div>
            </div>
            <!--Azuki-->
            <div class="flex absolute right-[5vw] bottom-[21vw] w-[50vw]  h-[13vw] floating">
                <div class="flex relative w-full h-full">
                    <img alt="random nft" class=" absolute right-[0vw] bottom-[1vw] h-[13vw] w-auto object-contain" src="/game/load/a1.png"/>

                    <img alt="thunder" class="absolute right-[6vw] top-[1vw] z-20 h-[7vw] w-[38vw]  widthPulse" src="/game/load/thunder.png"/>
                    
                </div>
            </div>
            <!--Wk-->
            <div class="flex absolute right-[17vw] bottom-[13vw]  h-[16vw] w-[11vw]">
                <div class="flex relative w-full h-full">
                    <img alt="random nft" class="absolute z-10 h-[16vw] w-auto object-contain floating4" src="/game/load/cryptoPunk.png"/> 
                    <img alt="spell" class="absolute right-[2vw] top-[3vw] z-20 h-auto w-[10vw] object-contain floating2" src="/game/load/wkSpel.png"/>
                
                </div>
            </div>
            <!--Penguin-->
            <div class="flex absolute right-[5vw] bottom-[3vw]  h-[13vw] w-[11vw] floating">
                <div class="flex relative w-full h-full">
                    <img alt="random nft" class="absolute z-10 h-[13vw] w-auto object-contain" src="/game/load/pen.png"/>
                    <img alt="explode" class="absolute right-[5vw] top-[5vw] z-20 h-auto w-[8vw] object-contain shrink" src="/game/load/explode.png"/>
                </div>
            </div>
            <span class="absolute z-[20] text-[1.5vw] self-center top-[5vw] text-button font-semibold">
                Thunder Field
            </span>
            <span class="absolute z-[20] text-[3.5vw] self-center top-[8vw] font-bold text-button">
                NFT ARENA
            </span>
            <div class="flex flex-col items-center gap-[0.5vw] absolute z-[20]  text-[1.5vw] self-center bottom-[4vw] font-bold text-white">
                <span>
                    Battle with any ERC-721 NFT in a PvP game.
                </span>
                <span>
                    Auto-generated skills based on the NFT's trait name.
                </span>
                <span>
                    Winner takes staked $ETN from loser.
                </span>
            </div>

            <div class="w-[17vw] h-[17vw] gap-[0.5vw] flex flex-col justify-center items-center bg-black z-20 self-center rounded-full bg-opacity-90 glow-border-run">
                <span class="text-[1.3vw] text-white mt-[1vw]">
                    PLAY NOW
                </span>
                {#if !isLogin}
                    <button class="text-white hover:text-buttonHover hover:border-buttonHover rounded-md border p-2 glow-border-run text-[1.3vw]" on:click={() => connectToMetamask()} >
                        Connect Wallet
                    </button>
                {/if}
            </div>
            <!--Social link-->
            <div class="absolute flex items-center self-center bottom-[1vw] gap-[1vw]">
                <button on:click={()=>{window.open(`${config.site}`, "_blank")}} class="flex shrink-self-hover">
                    <img class="inline-block w-[1.5vw]" src="/game/elements/web.png" alt="web icon"/>
                </button>
                <button on:click={()=>{window.open(`${config.twitter}`, "_blank")}} class="flex shrink-self-hover">
                    <img class="inline-block w-[2.2vw]" src="/game/elements/x.png" alt="X icon"/>
                </button>
            </div>
        </div>
    </div>
    
{/if}



 <!--Mobile notice--->
 <div class=" relative sm:hidden flex flex-col w-full min-h-screen font-Hoves bg-black text-white px-4">
    <div class="flex flex-col z-10 text-button text-xl font-semibold mx-auto my-auto gap-[5px]">
        <span class="font-bold">
            MOBILE UNSUPPORTED
        </span>
        <span>
            Game is curently not supporting mobile devices. Please use PC to access this.
        </span> 
    </div>

    <!-- animation-->
    <div class="containerLeaf">
        <div class="sakura"><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
            <span></span><span></span><span></span><span></span><span></span>
        </div>
    </div>
</div>

