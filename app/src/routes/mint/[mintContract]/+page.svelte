<script>
    import { fly } from 'svelte/transition';
    import Nav from "../../Nav.svelte";
    import { fade } from 'svelte/transition';
    import { erc721ABI, erc721Bytecode, erc721Merkle, erc721Simple } from "$lib/contract.config.js";
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import { page } from '$app/stores';
    import { goto } from "$app/navigation";
    import Loading from "$lib/Loading.svelte";
    import config from "$lib/config.js";
    import {bigIntToFloat, formatTimeLeft} from "$lib/index.js";





    const simpleCollections = {
        "0x748723AF17899E3C2C1cA682be2733Bca87FDDc8": {
            total: 1000
        }
    }

    const temCollections =
    {
        "": {
            total: "",
            freemintItem:"",
            publicItem:"",
            freemintTime:"",
            publicTime:"",
            publicPrice:"",
            mintedFree:"",
            mintedPublic:"",
        }

    }


    //mint load
    let mintLoad = true;

    let frontAddress, yourFrontWlSlots, yourFrontFmSlots
    let fmAddress = []; 
    let wlAddress = []; 

    const tokens = $page.url.pathname.split("/");
    const collectionAddress = tokens.at(-1);
    
    let loading = false, done = false, loadMintInfo = true, loadTotalMint = true;
    let mint, getRarity;

    let collectionName = "Loading", collectionDescription = "Loading";

    let startFreemint, deadlineFreemint, startWhitelist , deadlineWhitelist , startPublic,  deadlinePublic;

    let mintedAmount = 0, totalAmount = 0;
    let totalWhitelist = 0, totalFree = 0, totalPublic = 0;
    let mintedWhitelist = 0, mintedFree = 0, mintedPublic = 0;
    let whitelistSlots = 0, freeSlots = 0, publicSlots = 0;
    let whitelistPrice = "0", publicPrice = "0";
    let resultMetadata = { description: "", attributes: [] }, resultId = "1", minted = false, imgLoad = true;

    let attributePoints = {}; 
    let totalAttributePoints = {};
    let nftPoints = {};

    let provider, signer, address;

    let websiteLink, twitterLink, discordLink, telegramLink;

    async function walletHelper() {
        try {
            await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: config.chainId }],
            });
        } catch (error) {
            if (error.code === 4902) {
                try {
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

        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });

        if (accounts.length) {
            provider = new ethers.providers.Web3Provider(window.ethereum);
            signer = provider.getSigner();
        }

        const { chainId } = await provider.getNetwork();

        if (chainId !== parseInt(config.chainId)) throw new Error(`Network must be ${config.chainName}`);
    }

    
    onMount(() => {
        if (simpleCollections[collectionAddress]) {
            mint = async function() {
                loading = true;
                await walletHelper();
                    if (freemintTimeStart > 0 || freemintTimeLeft < 0){
                    loading = false;
                    console.log("Mint has not started")
                    return;
                }
                try {
                    const collectionContract = new ethers.Contract(collectionAddress, erc721Simple, signer);
                    const mintTx = await collectionContract.mintNFT(address);

                    const receipt = await mintTx.wait();

                    const event = receipt.events.find(event => event.event === "Transfer");
                    const id = event.args[2].toString();


                    //addNFTToLocalList(collectionAddress, id);

                    const { metadata } = await getNFTInfo(collectionAddress, id, [ "owner", "collectionName", "offers", "listingDetails" ]);

                    resultMetadata = metadata;

                    loading = false; 

                    resultId = id;
                    minted = true;

                } catch (e) {
                    loading = false;

                    throw e;
                } 
            }
        } else {
            mint = async function(option) {
                loading = true;
                await walletHelper();
                // Get merkle proof 
                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "getMintMerkleProof",
                        params: {
                            address,
                            contract: collectionAddress,
                            option
                        }
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    try {
                        const responseBody = await response.json();

                        const proof = responseBody.payload.proof;
                        const drop = responseBody.payload.drop;


                        const collectionContract = new ethers.Contract(collectionAddress, erc721Merkle, signer);
                        const mintTx = await collectionContract.mint(
                            address,
                            BigInt(drop.tokenId),
                            drop.tokenURI,
                            option !== "public" && !drop.fcfsWhitelist,
                            proof,
                            {
                                value: BigInt(drop.price)
                            }
                        );

                        await mintTx.wait();

                        //addNFTToLocalList(collectionAddress, drop.tokenId);

                        const { metadata } = await getNFTInfo(collectionAddress, drop.tokenId, [ "owner", "collectionName", "offers", "listingDetails" ]);

                        resultMetadata = metadata;

                        loading = false; 

                        minted = true;
                        resultId = drop.tokenId;

      
                    } catch (e) {
                        loading = false;
                        errorFrontCode =(e.code);
                        console.log(errorFrontCode);
                        throw e;
                        
                    }
                } else {
                    const responseBody = await response.json();

                    loading = false; 

                    if (responseBody.error && responseBody.error.message) {
                        errorFrontCode = responseBody.error.message;
                        console.log(errorFrontCode);
                        throw new Error(responseBody.error.message);
                    }
                }
            }
        }

        function addNFTToLocalList(collectionAddress, id) {
            const nftList = JSON.parse(localStorage.nftList || "[]");

            let check = true;

            for (const nft of nftList) {
                if (nft.collectionAddress === collectionAddress && nft.id === id) {
                    check = false;
                    break;
                }
            }

            if (check) nftList.push({ collectionAddress, id });

            localStorage.nftList = JSON.stringify(nftList);
        }

        if (simpleCollections[collectionAddress]) {
            (async function getTotalMintAmount() {
                try {
                    provider = new ethers.providers.Web3Provider(window.ethereum);
                    signer = provider.getSigner();
                    address = await signer.getAddress();
                } catch (e) {
                    console.log("Address", e);

                    address = "";
                }

                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "getSimpleMintAmount",
                        params: {
                            address: collectionAddress
                        }
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    const responseBody = await response.json();

                    mintedAmount = responseBody.payload.total;
                    totalAmount = simpleCollections[collectionAddress].total;
                } else {
                    const responseBody = await response.json();

                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);
                    }
                }
            })();
        } else {
            (async function getMintInfo() {
                mintLoad = true;
                try {
                    provider = new ethers.providers.Web3Provider(window.ethereum);
                    signer = provider.getSigner();
                    address = await signer.getAddress();
                } catch (e) {
                    address = "";
                }

                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "getMintInfo",
                        params: {
                            address,
                            contract: collectionAddress
                        }
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    const responseBody = await response.json();

                    //console.log(responseBody.payload);

                    mintedWhitelist = responseBody.payload.whitelistAmount;
                    mintedFree = responseBody.payload.freeAmount;
                    mintedPublic = responseBody.payload.publicAmount;
                    whitelistSlots = responseBody.payload.whitelistSlots;
                    freeSlots = responseBody.payload.freeSlots;
                    publicSlots = responseBody.payload.publicSlots;
                    whitelistPrice = responseBody.payload.whitelistPrice;
                    publicPrice = responseBody.payload.publicPrice;

                    mintedAmount = mintedWhitelist + mintedPublic + mintedFree;

                    loadMintInfo = false;

                    mintLoad = false;
                } else {
                    const responseBody = await response.json();
                    mintLoad = false;
                    if (responseBody.error && responseBody.error.message) {
                        
                        throw new Error(responseBody.error.message);
                    }
                }
            })();

            (async function getTotalMintAmount() {
                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "getTotalMintAmount",
                        params: {
                            address: collectionAddress
                        }
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    const responseBody = await response.json();

                    totalWhitelist = responseBody.payload.whitelistAmount;
                    totalFree = responseBody.payload.freeAmount;
                    totalPublic = responseBody.payload.publicAmount;

                    totalAmount = totalWhitelist + totalPublic + totalFree;

                    loadTotalMint = false;
                } else {
                    const responseBody = await response.json();

                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);
                    }
                }
            })();
        }

        (async function getRarity() {

            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getRarityPoints",
                    params: {
                        contract: collectionAddress
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (response.ok) {
                const responseBody = await response.json();

                attributePoints = responseBody.payload.attributePoints;
                totalAttributePoints = responseBody.payload.totalAttributePoints;
                nftPoints = responseBody.payload.nftPoints;

            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        })();

        (async function getCollectionNameAndDes() {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getCollectionNameAndDes",
                    params: {
                        address: collectionAddress
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (response.ok) {
                const responseBody = await response.json();

                collectionName = responseBody.payload.name;
                collectionDescription = responseBody.payload.description;
            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        })();

        (async function getMintDuration() {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getMintDuration",
                    params: {
                        address: collectionAddress
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (response.ok) {
                const responseBody = await response.json();

                startFreemint = responseBody.payload.freemintDuration[0];
                deadlineFreemint = responseBody.payload.freemintDuration[1];
                startWhitelist = responseBody.payload.whitelistMintDuration[0];
                deadlineWhitelist = responseBody.payload.whitelistMintDuration[1];
                startPublic = responseBody.payload.publicMintDuration[0];
                deadlinePublic = responseBody.payload.publicMintDuration[1];

            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        })();

        (async function getLinks() {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getLinks",
                    params: {
                        address: collectionAddress
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
            
            if (response.ok) {
                const responseBody = await response.json();

                websiteLink = responseBody.payload.website;
                twitterLink = responseBody.payload.twitter;
                discordLink = responseBody.payload.discord;
                telegramLink = responseBody.payload.telegram;

            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        })();

        async function getNFTInfo(address, id, exclude) {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getNFTInfo",
                    params: {
                        address,
                        id,
                        exclude
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

    });


    let connectToMetamask;

    onMount(async () => {
        connectToMetamask = async function() {
            if (!window.ethereum) {
                window.open("https://chromewebstore.google.com/detail/metamask/nkbihfbeogaeaoehlefnkodbefgpgknn", "_blank");
                return;
            }

            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: config.chainId }],
                });
            } catch (error) {
                if (error.code === 4902) {
                    try {
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

            const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });

            let provider = new ethers.providers.Web3Provider(window.ethereum);
            const signer = provider.getSigner();
            address = await signer.getAddress();

            location.reload();
        }
            let provider = new ethers.providers.Web3Provider(window.ethereum);
            const signer = provider.getSigner();
            frontAddress = await signer.getAddress();
            
            (async function(){
            await (async function checkMintSpots() {
                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "checkMintSpots",
                        params: []
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    const responseBody = await response.json();
                    const allColMintAddress = responseBody.payload.mintAddress;
                    let allMintAddress = allColMintAddress.slice(1).filter(row => row[0] === collectionAddress);
                        const fmAddress2 = allMintAddress.filter(row => row[2] === "freemint");
                        const wlAddress2 = allMintAddress.filter(row => row[2] === "wl");
                    fmAddress = fmAddress2;
                    wlAddress = wlAddress2;
                    return responseBody.payload;
                } else {
                    const responseBody = await response.json();

                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);
                    }  
                } 
            })()

            yourFrontWlSlots = countOccurrences(frontAddress, wlAddress);
            yourFrontFmSlots = countOccurrences(frontAddress, fmAddress); 

            //Count
            function countOccurrences(frontAddress, addressList) {
                return addressList.filter(row => row[1].toLowerCase().trim() === frontAddress.toLowerCase().trim()).length;
            }
        })()

    });






    $: freemintTimeLeft = deadlineFreemint - dateNow;
    $: freemintTimeStart = startFreemint - dateNow;

    $: whitelistTimeLeft = deadlineWhitelist - dateNow;
    $: whitelistTimeStart = startWhitelist - dateNow

    $: publicTimeLeft = deadlinePublic - dateNow;
    $: publicTimeStart = startPublic - dateNow
    
    let dateNow;
    setInterval(() => {
        dateNow = Date.now();
    }, 1000);

    let isSoldOut = false;
    let loadingAva = true;
    let loadingBanner = true;

    let errorFrontCode = "";
    $: {
        if (errorFrontCode !== "") {
            setTimeout(() => {
                errorFrontCode = "";
            }, 3000);
        }
    }
    



    
</script>
    <div class="relative flex justify-center bg-black text-white w-full min-h-screen">
        <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
            <div class="flex flex-col">
                <Nav/>
                <div class="flex relative sm:h-[340px] h-[180px] mt-[30px] ">
                    <div class="flex overflow-hidden h-full w-full bg-black parent">
                        <img alt="Collection banner" 
                        class="w-full object-cover h-full shrink-on-hover {loadingBanner?"loading":""}" 
                        src={`${config.rpcUrl}/banner/${collectionAddress}`}
                        on:load={()=>{loadingBanner = false}}/>
                    </div>
                    <div class="absolute flex flex-wrap self-end justify-between w-full rounded-md gap-0 sm:mb-[-30px] mb-[-100px] z-10">
                        <div class="flex items-center gap-2 font-semibold text-2xl m-2 py-2 px-6 bg-darkCard bg-opacity-90 rounded-lg shadow-lg">
                            <img alt="Collection avatar" 
                            class="rounded-full inline-block h-[40px] min-w-[40px] {loadingAva?"loading":""}" 
                            src={`${config.rpcUrl}/logo/${collectionAddress}/200/200`}
                            on:load={()=>{loadingAva = false}}/>
                            <span class="text-md text-blue">
                                {collectionName}
                            </span>
                        </div>

                        {#if startPublic == 123456789101112 && temCollections[collectionAddress] || temCollections[collectionAddress]?.show}
                            <div class="flex justify-end items-center text-lg gap-2 m-2 py-1 px-6 bg-darkCard bg-opacity-90 rounded-lg shadow-lg text-blue">
                                <span class="text-md font-bold">
                                    {temCollections[collectionAddress].status}
                                </span>
                            </div>
                        {:else if (publicTimeStart > 0 && publicTimeLeft > 0) & (whitelistTimeStart > 0 && whitelistTimeLeft > 0) & (freemintTimeStart > 0 && freemintTimeLeft > 0)}
                            <div class="flex justify-end items-center text-lg gap-2 m-2 py-1 px-6 bg-darkCard bg-opacity-90 rounded-lg shadow-lg text-blue">
                                <span class="text-md">
                                   Starts in: {formatTimeLeft(freemintTimeStart)}
                                </span>
                                <div class="bg-[#FFED4A] rounded-full h-[13px] w-[13px] mt-[5px]"></div>
                            </div>
                        {:else if (publicTimeStart < 0 && publicTimeLeft > 0) || (whitelistTimeStart < 0 && whitelistTimeLeft > 0)|| (freemintTimeStart < 0 && freemintTimeLeft > 0)}
                            <div class="flex justify-end items-center text-lg gap-2 m-2 py-1 px-6 bg-darkCard bg-opacity-90 rounded-lg shadow-lg text-blue">
                                <span class="text-blue">Minting now</span>
                                <div class="bg-[#14FF00] rounded-full h-[13px] w-[13px] mt-[5px]"></div>
                            </div>
                        {:else if publicTimeLeft < 0 }
                            <div class="flex justify-end items-center text-lg gap-2 m-2 py-1 px-6 bg-darkCard bg-opacity-90 rounded-lg shadow-lg text-blue">
                                <span class="text-white">Ended</span>
                                <div class="bg-[#14FF00] rounded-full h-[13px] w-[13px] mt-[5px]"></div>
                                
                            </div>
                        {/if}
                    </div>
                </div>
                <!---->
                <div class="flex md:flex-row flex-col justify-between w-full mt-[50px] lg:gap-[50px] gap-[20px] mb-[100px]">
                    <div class="flex flex-col w-full md:order-1 order-2">
                        <div class="flex w-full flex-col gap-[10px]">
                            <div class="flex w-full justify-between">
                                <span class="text-2xl font-semibold text-blue">
                                    About
                                </span>
                                <div class="flex self-end gap-[30px] sm:my-0 my-[10px]">
                                    {#if websiteLink}
                                        <button class="self-hover" on:click={() => { window.open(websiteLink, "_blank") }}>
                                            <img class=" h-[20px] inline-block" src="/icons/weblink.svg" alt="website icon"/>
                                        </button>
                                    {/if}
                                    {#if twitterLink}
                                        <button class="self-hover" on:click={() => { window.open(twitterLink, "_blank") }}>
                                            <img class="h-[20px]  inline-block" src="/icons/twitterX.svg" alt="Twitter/X icon"/>
                                        </button>
                                    {/if}

                                </div>
                            </div>
                            <div class="flex flex-wrap font-semibold md:gap-[30px] gap-[20px]">
                                {#if !simpleCollections[collectionAddress]}
                                    <span>
                                        <span class="text-darkGray">Minted:</span>

                                        <span>{ (mintedWhitelist >= totalWhitelist?totalWhitelist :mintedWhitelist) + 
                                        (mintedPublic >= totalPublic ? totalPublic :mintedPublic) + 
                                        (mintedFree >= totalFree ? totalFree :mintedFree) 
                                        >= totalAmount? totalAmount : (mintedWhitelist >= totalWhitelist?totalWhitelist :mintedWhitelist) + (mintedPublic >= totalPublic ? totalPublic :mintedPublic) + (mintedFree >= totalFree ? totalFree :mintedFree) }
                                        </span>
                                    </span>
                                {/if}
                                {#if startPublic == 123456789101112 || temCollections[collectionAddress]}
                                    <div class="flex gap-[5px]">
                                        <span class="text-darkGray">Total:</span>
                                        <span>
                                            {temCollections[collectionAddress].total}
                                        </span>
                                    </div>
                                {:else}
                                    
                                    <span>
                                        <span class="text-darkGray">Total:</span>
                                        <span>{totalAmount-totalFree}</span>
                                    </span>
                                {/if}
                                <button on:click={()=>{location.reload()}}>
                                    <img alt="reload" class="h-[26px] px-2 py-1 border border-white hover:border-blue bg-white shadow rounded-md" src="/reload1.svg"/>
                                </button>
                            </div>
                            <span class="">
                                {collectionDescription}
                                {#if simpleCollections[collectionAddress]?.description}
                                    {simpleCollections[collectionAddress].description}
                                {/if}
                                {#if temCollections[collectionAddress]?.description}
                                    <span class="font-normal italic">
                                        {temCollections[collectionAddress]?.description}
                                    </span>
                                {/if}
                            </span>
                            {#if !simpleCollections[collectionAddress]}
                                {#if mintLoad === false}
                                        <button on:click={() => mint("free")} class="self-end flex flex-col 
                                            {mintedFree < totalFree && freeSlots > 0 && freemintTimeStart < 0 && freemintTimeLeft > 0 && address !== "" ? "bg-darkCard hover:border hover:border-blue glow":"bg-[#373535]"}  w-full p-4 rounded-md shadow-lg " 
                                            disabled = {!(mintedFree < totalFree && freeSlots > 0 && freemintTimeStart < 0 && freemintTimeLeft > 0 && address !== "" )} >
                                            <div class="text-2xl font-semibold flex flex-wrap w-full justify-between items-center">
                                                <span class="text-blue">
                                                    Free Mint
                                                </span>
                                                {#if startPublic == 123456789101112 && temCollections[collectionAddress] || temCollections[collectionAddress]?.freemintTime ==="Upcoming"}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="text-blue">
                                                            {temCollections[collectionAddress].freemintTime}
                                                        </span>
                                                    </div>

                                                {:else if mintedFree >= totalFree}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="text-blue">
                                                            Ended
                                                        </span>
                                                    </div>
                                                {:else if freemintTimeStart > 0 &&  freemintTimeLeft > 0}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">Starts in:</span>
                                                        <span class="text-blue">
                                                            {formatTimeLeft(freemintTimeStart)}
                                                        </span>
                                                    </div>
                                                {:else if freemintTimeStart < 0 && freemintTimeLeft > 0}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">Ends in:</span>
                                                        <span class="text-blue">
                                                            {formatTimeLeft(freemintTimeLeft)}
                                                        </span>
                                                    </div>
                                                {:else if freemintTimeLeft < 0 }
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">
                                                        </span>
                                                        <span class="text-blue">
                                                            Ended
                                                        </span>
                                                    </div>
                                                {/if}
                                            </div>
                                            <!---->
                                            <div class="flex flex-wrap justify-between sm:max-w-[600px] sm:w-[350px]  w-[300px] gap-[20px] mt-[30px]">
                                                <div class="flex flex-col gap-2">
                                                    <span class="text-darkGray">
                                                        Price
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        <img class="h-[30px]" src="/icons/ETN.png" alt="coin icon"/>
                                                        <span class="text-xl font-bold">
                                                            0
                                                        </span>
                                                    </div>
                                                </div>
                                                <div class="flex flex-col gap-2 ml-[20px]">
                                                    <span class="text-darkGray">
                                                        Minted
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        <span class="text-xl font-bold">
                                                            {#if temCollections[collectionAddress]}
                                                                {temCollections[collectionAddress].mintedFree}
                                                            {:else}
                                                                {mintedFree >= totalFree? totalFree : mintedFree }
                                                            {/if}
                                                        </span>
                                                    </div>
                                                </div>
                                                <div class="flex flex-col gap-2">
                                                    <span class="text-darkGray">
                                                        Total
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        {#if temCollections[collectionAddress]}
                                                            <span class="text-xl font-bold">
                                                                {temCollections[collectionAddress].freemintItem}
                                                            </span>
                                                        {:else}
                                                            <span class="text-xl font-bold">
                                                                {totalFree}
        
                                                            </span>
                                                        {/if}
                                                    </div>
                                                </div>
                                                    
                      
                                                {#if address}
                                                    <div class="flex flex-col gap-2">
                                                        <span class="text-darkGray">
                                                            Your slot
                                                        </span>
                                                        <div class="relative flex items-center gap-[10px] pb-[10px]">
                                                            {#if temCollections[collectionAddress]?.hideSlots}
                                                                <span class="text-xl font-bold text-blue z-10">
                                                                    TBA
                                                                </span>
                                                            {:else}
                                                                <span class="text-xl font-bold text-blue z-10">
                                                                    {yourFrontFmSlots > 0? yourFrontFmSlots : 0 }
                                                                </span>
                                                                {#if yourFrontFmSlots> 0}
                                                                    <span class="absolute glow ml-[3px]">
                                                                        
                                                                    </span>
                                                                {/if}
                                                            {/if}
                                                        </div>
                                                    </div>
                                                {/if}
                                            </div>
                                            {#if !address}
                                                <button on:click={() => connectToMetamask()} class="text-lg border py-1 px-6 rounded rounded-lg mt-4 text-white font-semibold bg-linearBlue self-hover">
                                                    Connect Wallet
                                                </button>
                                            {/if}
                                        </button>
                                {:else}
                                    <div class="self-end flex flex-col bg-darkCard loading w-full p-4 rounded-md shadow-lg min-h-[160px]">
                                        <div class="text-2xl font-semibold flex flex-wrap w-full justify-between items-center">
                                            <span class="text-blue">
                                            </span>
                                        </div>
                                    </div>
                                {/if}
                            {/if}

     
                            {#if !simpleCollections[collectionAddress] && (temCollections[collectionAddress] || whitelistPrice > 0 )}
                                {#if temCollections[collectionAddress]?.whitelistPrice || whitelistPrice > 0}
                                    {#if mintLoad === false}
                                        <button on:click={() => mint("whitelist")} class="self-end flex flex-col 
                                            {mintedWhitelist < totalWhitelist && whitelistSlots > 0 && whitelistTimeStart < 0 && whitelistTimeLeft > 0 && address !== "" ? "bg-darkCard hover:border hover:border-blue glow":"bg-[#373535] "}  w-full p-4 rounded-md shadow-lg " 
                                            disabled = {!(mintedWhitelist < totalWhitelist && whitelistSlots > 0 && whitelistTimeStart < 0 && whitelistTimeLeft > 0 && address !== "")}>
                                            <div class="text-2xl font-semibold flex flex-wrap w-full justify-between items-center">
                                                <span class="text-blue">
                                                    Whitelist Mint (FCFS)
                                                </span> 
                                                {#if startPublic == 123456789101112 && temCollections[collectionAddress] || temCollections[collectionAddress]?.whitelistTime ==="Upcoming" }
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="text-blue">
                                                            {temCollections[collectionAddress].whitelistTime}
                                                        </span>
                                                    </div>
                                                {:else if mintedWhitelist >= totalWhitelist}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="text-blue">
                                                            Ended
                                                        </span>
                                                    </div>
                                                {:else if whitelistTimeStart > 0 &&  whitelistTimeLeft > 0}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">Starts in:</span>
                                                        <span class="text-blue">
                                                            {formatTimeLeft(whitelistTimeStart)}
                                                        </span>
                                                    </div>
                                                {:else if whitelistTimeStart < 0 && whitelistTimeLeft > 0}
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">Ends in:</span>
                                                        <span class="text-blue">
                                                            {formatTimeLeft(whitelistTimeLeft)}
                                                        </span>
                                                    </div>
                                                {:else if whitelistTimeLeft < 0 }
                                                    <div class="flex text-lg justify-between items-center gap-[10px]">
                                                        <span class="font-normal text-darkGray">

                                                        </span>
                                                        <span class="text-blue">
                                                            Ended
                                                        </span>
                                                    </div>
                                                {/if}
                                            </div>
                                            <!---->
                                            <div class="flex flex-wrap justify-between sm:max-w-[600px] sm:w-[350px]  w-[300px] gap-[20px] mt-[30px]">
                                                <!--Mint price container-->
                                                <div class="flex flex-col gap-2">
                                                    <span class="text-darkGray">
                                                        Price
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        <img class="h-[30px]" src="/icons/ETN.png" alt="coin icon"/>
                                                        <!--Mint price-->
                                                        <span class="text-xl font-bold">
                                                            {temCollections[collectionAddress] ? temCollections[collectionAddress].whitelistPrice : bigIntToFloat(BigInt(whitelistPrice))}
                                                        </span>
                                                    </div>
                                                </div>
                                                <!--Items price container-->
                                                <div class="flex flex-col gap-2 ml-[20px]">
                                                    <span class="text-darkGray">
                                                        Minted
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        <!--items number-->
                                                        <span class="text-xl font-bold">
                                                            {mintedWhitelist >= totalWhitelist? totalWhitelist: mintedWhitelist}
                                                        </span>
                                                    </div>
                                                </div>
                                                <!--Items price container-->
                                                <div class="flex flex-col gap-2">
                                                    <span class="text-darkGray">
                                                        Total
                                                    </span>
                                                    <div class="flex items-center gap-[10px] pb-[10px]">
                                                        <!--items number-->
                                                        {#if temCollections[collectionAddress]}
                                                            <span class="text-xl font-bold">
                                
                                                                {temCollections[collectionAddress] ? temCollections[collectionAddress].whitelistItem : totalWhitelist}
                                                            </span>
                                                        
                                                        {:else}
                                                            <span class="text-xl font-bold">
                                                                {simpleCollections[collectionAddress] ? totalAmount : totalWhitelist}
                                                            </span>
                                                        {/if}
                                                    </div>
                                                </div>
                                                <!--Your slot container-->
                                                {#if address}
                                                <!--Your slot container-->
                                                <div class="flex flex-col gap-2">
                                                    <span class="text-darkGray">
                                                        Your slot
                                                    </span>
                                                    <div class="relative flex items-center gap-[10px] pb-[10px]">
                                                        <!--items number-->
                                                        {#if temCollections[collectionAddress]?.hideSlots}
                                                        <span class="text-xl font-bold text-blue z-10">
                                                                TBA
                                                            </span>
                                                        {:else}
                                                            <!--items number-->
                                                            <span class="text-xl font-bold text-blue z-10">
                                                                {yourFrontWlSlots > 0? yourFrontWlSlots : 0 }

                                                            </span>
                                                            {#if yourFrontWlSlots > 0}
                                                                <span class="absolute glow ml-[3px]">
                                                                    
                                                                </span>
                                                            {/if}
                                                        {/if}
                                                    </div>
                                                </div>
                                            {/if}
                                            </div>
                                            {#if !address}
                                                <button on:click={() => connectToMetamask()} class="text-lg border py-1 px-6 rounded rounded-lg mt-4 text-white font-semibold bg-linearBlue self-hover">
                                                    Connect Wallet
                                                </button>
                                            {/if}
                                        </button>
                                        <!--{:else}
                                            <div class="loading self-end min-h-[166px] flex flex-col  w-full p-4 rounded-md shadow-lg "></div>
                                        -->
                                    {:else}
                                        <div class="self-end flex flex-col bg-darkCard loading w-full p-4 rounded-md shadow-lg min-h-[160px]">
                                            <div class="text-2xl font-semibold flex flex-wrap w-full justify-between items-center">
                                                <span class="text-blue">
                                                </span>
                                            </div>
                                        </div>
                                    {/if}
                                {/if}
                            {/if}
                
                            <!--Public mint container-->
                            <button on:click={() => mint("public")} class="self-end flex flex-col 
                                {(simpleCollections[collectionAddress] && publicTimeStart < 0 && publicTimeLeft > 0) && address !== "" || (mintedPublic < totalPublic && publicSlots > 0 && publicTimeStart < 0 && publicTimeLeft > 0 && address !== "")? "relative glow bg-darkCard hover:border hover:border-blue":"bg-[#373535]"} w-full p-4 rounded-md shadow-lg " 
                                disabled = {!(simpleCollections[collectionAddress] && publicTimeStart < 0 && publicTimeLeft > 0 && address !== "") && !(mintedPublic < totalPublic && publicSlots > 0 && publicTimeStart < 0 && publicTimeLeft > 0 && address !== "")}>
                                <div class="text-2xl font-semibold flex flex-wrap w-full justify-between items-center">
                                    <span class="text-blue">
                                        Public Mint (FCFS)
                                    </span>
                                    {#if startPublic == 123456789101112 && temCollections[collectionAddress] ||temCollections[collectionAddress]?.publicTime ==="Upcoming"}
                                        <div class="flex text-lg justify-between items-center gap-[10px]">
                                            <span class="text-blue">
                                                {temCollections[collectionAddress].publicTime}
                                            </span>
                                        </div>
                                    {:else if publicTimeStart > 0 &&  publicTimeLeft > 0}
                                        <div class="flex text-lg justify-between items-center gap-[10px]">
                                            <span class="font-normal text-darkGray">Starts in:</span>
                                            <span class="text-blue">
                                                {formatTimeLeft(publicTimeStart)}
                                            </span>
                                        </div>
                                    {:else if publicTimeStart < 0 && publicTimeLeft > 0}
                                        <div class="flex text-lg justify-between items-center gap-[10px]">
                                            <span class="font-normal text-darkGray">Ends in:</span>
                                            <span class="text-blue">
                                                {formatTimeLeft(publicTimeLeft)}
                                            </span>
                                        </div>
                                    {:else if publicTimeLeft < 0 }
                                        <div class="flex text-lg justify-between items-center gap-[10px]">
                                            <span class="font-normal text-darkGray">

                                            </span>
                                            <span class="text-blue">
                                                Ended
                                            </span>
                                        </div>
                                    {/if}
                                </div>
                                <!---->
                                <div class="flex flex-wrap justify-between sm:max-w-[600px] sm:w-[350px]  w-[300px] gap-[20px] mt-[30px]">
                                    <!--Mint price container-->
                                    <div class="flex flex-col gap-2">
                                        <span class="text-darkGray">
                                            Price
                                        </span>
                                        <div class="flex items-center gap-[10px] pb-[10px]">
                                            <img class="h-[30px]" src="/icons/ETN.png" alt="coin icon"/>
                                            <!--Mint price-->
                                            <span class="text-xl font-bold">
                                                {temCollections[collectionAddress] ? temCollections[collectionAddress].publicPrice : bigIntToFloat(BigInt(publicPrice))}
                                            </span>
                                        </div>
                                    </div>
                                    <!--Items price container-->
                                    <div class="flex flex-col gap-2 ml-[20px]">
                                        <span class="text-darkGray">
                                            Minted
                                        </span>
                                        <div class="flex items-center gap-[10px] pb-[10px]">
                                            <!--items number-->
                                            {#if temCollections[collectionAddress]}
                                                <!--items number-->
                                                <span class="text-xl font-bold">
                                                    {temCollections[collectionAddress].mintedPublic}
                                                </span>
                                            {:else}
                                                <span class="text-xl font-bold">
                                                    {simpleCollections[collectionAddress] ? (mintedAmount <= totalAmount? mintedAmount : totalAmount)  : (mintedPublic >= totalPublic? totalPublic:mintedPublic)}
                                                </span>
                                            {/if}
                                        </div>
                                    </div>
                                    <!--Items  container-->
                                    <div class="flex flex-col gap-2">
                                        <span class="text-darkGray">
                                            Total
                                        </span>
                                        <div class="flex items-center gap-[10px] pb-[10px]">
                                            <!--items number-->
                                            {#if temCollections[collectionAddress]}
                                                <span class="text-xl font-bold">
                                                    {temCollections[collectionAddress].publicItem}
                                                </span>
                                            
                                            {:else}
                                                <span class="text-xl font-bold">
                                                    {simpleCollections[collectionAddress] ? totalAmount : totalPublic}

                                                </span>
                                            {/if}
                                        </div>
                                    </div>

                                </div>
                                {#if !address}
                                    <button on:click={() => connectToMetamask()} class="text-lg border py-1 px-6 rounded rounded-lg mt-4 text-white font-semibold bg-linearBlue self-hover">
                                        Connect Wallet
                                    </button>
                                {/if}
                            </button>
                                
                            
        </div>
    </div>
        <div class="flex flex-col md:order-2 order-1">
            <div class="relative self-center flex flex-col w-full overflow-hidden max-w-[480px] max-h-[480px] lg:min-w-[480px] lg:min-h-[480px]">
                <img src={`${config.rpcUrl}/mpimage/${collectionAddress}`} class="object-contain max-h-[480px]  max-w-[480px] lg:min-w-[480px] lg:min-h-[480px]" alt="mint images"/>
            </div>
        </div>
    </div>
            
                        
        </div>
    </div>
</div>
{#if loading}
    <Loading/>
{/if}

{#if done}
    <div class="fixed flex font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-20 mt-[10px] gap-[20px]" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}> 
        <div class="flex flex-col items-center sm:w-[400px] w-[300px] bg-darkCard shadow-md mx-auto my-auto py-4 gap-[20px] rounded-lg shadow">
            <span class="text-4xl text-blue">
                Success
            </span>
            <img src="/icons/tick.svg" class="h-[150px] inline-block my-[10px]" alt="done icon"/>
            <button on:click={() => {location.reload()}} class="self-center w-[300px] py-[6px] bg-button rounded-xl font-semibold shadow-md hover:bg-buttonHover text-xl text-white">
                Confirm
            </button>
        </div>
    </div>
{/if}

{#if minted}
    <div class="fixed font-semibold flex flex-col justify-center items-center inset-0 text-white bg-black shadow-md bg-opacity-90 z-30" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
        <div class =" flex flex-col pt-4 pb-8 px-6 bg-darkCard rounded-md max-w-[850px] overflow-hidden">
            <button class="self-end" on:click={()=>{minted = false; location.reload()}}>
                <img class="h-[20px] inline-block" src="/icons/x.png" alt="close icon"/>
            </button>
            <div class ="grid md:grid-cols-2 grid-cols-1 gap-[30px] h-fit rounded-md mt-[10px]" >
                <!--Img container-->
                <div class="flex flex-col">
                    <div class="flex justify-center parent h-fit top-0 col-span-1 flex items-start ">
                        <div class="flex justify-center overflow-hidden rounded-md max-h-[300px] max-w-[300px] {imgLoad? "loading":""}">
                            <img src={`${config.rpcUrl}/cdn/nft/${collectionAddress}/${resultId}/350/350`}
                            class="object-contain shrink-on-hover max-h-[300px] max-w-[300px] 
                            min-h-[300px] min-w-[300px] {imgLoad? "loading":""}"
                            on:load={()=>{imgLoad = false}} alt="your minted NFTs"/>
                        </div>
                    </div>
                    <button on:click={ () => {goto(`/items/${collectionAddress}/${resultId}`)}} class="py-1 px-[80px] mr-[25px] mt-[15px] text-md font-base self-center shadow-md bg-button hover:bg-buttonHover text-white rounded-md">
                        View item
                    </button>
                </div>
                <!--Detail containers-->
                <div class="flex  flex-col col-span-1 gap-[10px] text-sm max-h-[350px] overflow-y-scroll">
                    <!--Item name-->
                    <span class="text-3xl font-bold text-blue ">
                        {collectionName} #{resultId}
                    </span>
                    <!---->
                    <div class="flex justify-between mt-[5px] text-md  ">
                        <!--From collection-->
                        <div class="flex font-semibold items-center">
                            <span class="text-darkGray">from </span>
                            <button on:click={()=>{goto(`../../collections/${collectionAddress}`)}} class="pl-2 pr-1 text-blue">{collectionName}</button>
                            <img class="h-4 inline-block" src="/icons/verified.svg" alt="verified icon"/>
                        </div>
                    </div>
                    <!--Description container-->
                    <div class="flex flex-col gap-[5px] my-[5px]">
                        <span class="text-md font-semibold text-darkGray">
                            Description
                        </span>
                        <!--Description-->
                        <span class="text-sm text-white">
                            {resultMetadata?.description}
                        </span>
                    </div>
                    <!--Attribute + Rarity container-->
                    <div class={`flex flex-col text-sm pl-[20px] pt-[10px] pb-[25px] font-semibold gap-[20px] mt-[5px] rounded-lg ${loading ? "loading" : ""}`}>
                        {#if nftPoints[resultId]}
                            <!--Rarity container-->
                            <span class="text-sm font-normal font-semibold">
                                <span class="text-darkGray">Rarity Score:</span>
                                <span>{ nftPoints[resultId] || "Loading" }</span>
                            </span>
                        {/if}
                        {#if resultMetadata?.attributes}
                            <div class="flex flex-wrap justify-between gap-[20px] mr-[20px] text-sm ">
                                {#each resultMetadata.attributes as attribute}
                                    <!--Attribute container-->
                                    <div class="flex flex-col max-w-[330px] min-w-[330px] p-2 rounded-xl border">
                                        <span class="font-medium text-darkGray ">
                                            {attribute["trait_type"]}
                                        </span>
                                        <div class="flex justify-between mt-[2px]">
                                            {attribute["value"]}
                                            <span class="mt-[2px] font-medium text-darkGray">
                                                {#if attributePoints[attribute["trait_type"]]}
                                                    {(attributePoints[attribute["trait_type"]][attribute["value"]])}/{totalAttributePoints[attribute["trait_type"]]}
                                                {/if}
                                            </span>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {/if}
                    </div>
                    <!--Info-->
                    <!--Info Header-->
                    <span class="text-md font-semibold text-darkGray mt-[20px]">
                        Information
                    </span>
                    <!--Info Container-->
                    <div class="flex flex-col border border-white pl-[20px] pr-[25px] pt-[10px] pb-[25px] font-semibold gap-[10px] rounded-lg"> 
                        <div class="flex justify-between">
                            <span class="text-darkGray font-medium">Royalties</span>
                            <span>1%</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="text-darkGray font-medium">Blockchain</span>
                            <span>{config.chainName}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{/if}

{#if errorFrontCode !=""}
    <div class="fixed bottom-5 right-10 flex items-center gap-[5px] pl-2 z-10 bg-red-500 md:w-[500px] w-[300px] h-[100px] rounded-md shadow-md" in:fly={{ duration: 500, x: 300 }} out:fly={{ duration: 500, x: 300 }}>
        <img class="h-[20px]" src="/icons/warning.svg" alt="warning icon"/>
        <span class="font-semibold text-white">
            {#if errorFrontCode == "-32603"}
                Insufficient Fund
            {:else if errorFrontCode == "ACTION_REJECTED"}
                Rejected by user
            {:else if errorFrontCode == "Requested account does not have any mint with this option."}
                No slot left for this address
            {:else if errorFrontCode == "Too many requests."}
                Rate limit, Too many requests. Wait a moment and try again
            {:else if errorFrontCode = "Error"}
                Error
            {:else}
                RPC Error. Try Again
            {/if}
        </span>
    </div>
{/if}
