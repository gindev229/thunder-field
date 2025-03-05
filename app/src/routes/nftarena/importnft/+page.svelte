
<script>
    import { fade,slide } from 'svelte/transition'; 
    import { goto } from '$app/navigation';
    import { emitBetweenText } from '$lib/index.js';
    import { erc721ABI, erc721Bytecode, marketplaceAddress, marketplaceABI } from "$lib/contract.config.js";
    import Loading from "$lib/Loading.svelte";
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import config from "$lib/config.js";

    let connectToMetamask;
    let isLogin = false;
    let loading = true;
    let popupLoading = false;
    let isImportSuccess = false;

    let userAddress;
    let address;


    let nftList = [];



    let attributes = [];
    let tokenURI = "";
    let metadata = {};
    let owner, price, lister, isSold, collectionName ;
    let resultSkills = [];
 


    let inputNftContract = '';
    let inputId = '';
    let subMitNftContract = '';
    let subMitNftId = '';

    

    async function getNFTInfo(collectionAddress, id) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getNFTInfo",
                params: {
                    address:collectionAddress,
                    id:id,
                    exclude: ["offers" ]
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            const responseBody = await response.json();

            const getResult = responseBody.payload;
            //New
            tokenURI = getResult.tokenURI,
            collectionName = getResult.collectionName;
            metadata = getResult.metadata, 
            owner = getResult.owner,
            lister = getResult.lister;
            //Reactive
            owner = owner;
            lister = lister;
        } else {

            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                popupLoading = false;
                generalError = true;
                generalErrorValue = responseBody.error.message;
                throw new Error(responseBody.error.message);
            }
        }
	}

    async function generateNFTSkill(collectionAddress, attributes) {
        try {    
            //
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "generateNFTSkill",
                    params: {
                        collectionAddress,
                        attributes:attributes
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
 

            if (response.ok) {
                const responseBody = await response.json();
                resultSkills = responseBody.payload.data[1];
                return responseBody.payload;
            } else {
                const responseBody = await response.json();
                if (responseBody.error && responseBody.error.message) {
                    popupLoading = false;
                    generalError = true;
                    generalErrorValue = responseBody.error.message;
                    throw new Error(responseBody.error.message);
                }
                popupLoading = false;
                generalError = true;
                generalErrorValue = "Unknown error occurred";
                throw new Error("Unknown error occurred");

            }
        } catch (error) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = error;
            throw error;
        }
    }

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

    async function addNFTToLocalList(collectionAddress, id) {
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            const signer = provider.getSigner();
            const userAddress = await signer.getAddress();

            const nftList = JSON.parse(localStorage.nftList || "[]");

            for (const nft of nftList) {
                if (nft.collectionAddress === collectionAddress && nft.id === id) {
                    return;
                }
            }

            const { owner, lister } = await getNFTOwner(collectionAddress, id);


            nftList.unshift({ collectionAddress, id });
            
            localStorage.nftList = JSON.stringify(nftList);
            
    }

    async function importAndGenerateNFT(collectionAddress, id){
        //Reset
        subMitNftContract= "";
        subMitNftId= "";
        subMitNftContract = subMitNftContract;
        subMitNftId = subMitNftId;
        attributes = [];
        attributes = attributes;
        resultSkills = [];
        resultSkills = resultSkills;
        isOwnerError = false;
        isImportSuccess = false;
        //
        popupLoading = true;
        await getNFTInfo(collectionAddress, id);
        if (!collectionName) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "Collection does not exist";
            return; 
        }
        if (!tokenURI) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "This NFT is not existed, you can check on explorer";
            return; 
        }
        
        subMitNftContract = inputNftContract;
        subMitNftContract = subMitNftContract; //For reactive
        subMitNftId= inputId;
        subMitNftId= subMitNftId;  //For reactive
        if (!metadata?.attributes || metadata?.attributes.length === 0) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "This NFT has no traits, you may want to use another NFTs";
            return; 
        }

        if (Array.isArray(metadata.attributes)) {
                for (const attribute of metadata.attributes) {
                    attributes.push({ attribute: attribute["trait_type"], value: attribute["value"] });
                }
            }
        attributes = attributes;
        await generateNFTSkill(subMitNftContract, attributes);
        if (!resultSkills || resultSkills?.length === 0) {
            popupLoading = false;
            generalError = true;
            generalErrorValue = "This NFT has no traits, you may want to use another NFTs";
            return; 
        }

        if (owner !== userAddress && lister !== userAddress) {
            popupLoading = false;
            generalError = true;
            isOwnerError = true;
            generalErrorValue = "You are not owner of this NFT";
            return; 
        }

        addNFTToLocalList(subMitNftContract, subMitNftId);
        isImportSuccess = true;
        popupLoading = false;
    
    }

    let generalError = false;
    let generalErrorValue = "Error";
    let isOwnerError = false;

    setInterval(()=>{
        if(generalError === true){
            setTimeout(()=>{generalError = false; generalErrorValue = "Error" }, 2000)
        }
    }, 100);

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
            location.reload()
            isLogin = true;

        }

        
        let provider;
        let signer;
        let marketplace;

        try {
            provider = new ethers.providers.Web3Provider(window.ethereum);

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

        //
        await (async () => {
            provider = new ethers.providers.Web3Provider(window.ethereum);
            signer = provider.getSigner();
            userAddress = await signer.getAddress();
            address = userAddress;
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

                        // Check if user is still the owner
                        for (const nft of localNFTList) {
                            requests.push((async () => {
                                const { owner, lister } = await getNFTOwner(nft.collectionAddress, nft.id);

                                if (owner !== userAddress && lister !== userAddress) {
                                    return;
                                }

                                nftList.push(nft);
                            })());
                        }

                        await Promise.all(requests);

                        // Update the new local nft list
                        localStorage.nftList = JSON.stringify(nftList);
                    } catch (e) {
                        console.log("b", e);
                    }

                    // Get the nft list from the indexer
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

                    if (response.ok) {
                        const responseBody = await response.json();

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
                })();
            } catch (e) {}


        })();



    })

</script>



<div class="relative  flex flex-col w-full h-screen bg-dark text-white ">
    <!--Game Screen-->
    <div class="flex flex-col relative w-[90vw] h-[45vw] maw-w-[1920px] max-h-[45vw] m-auto bg-cover rounded-md font-geo px-[2vw] py-[1vw] text-[1vw] overflow-hidden">
        <div class="flex">
            <div class="w-[30vw] h-full bg-arenaMedium p-[2vw] flex flex-col">
                <!-- Back button -->
                <div class="mb-[3vw]">
                <button class="flex items-center text-white" on:click={()=>{goto("../nftarena")}}>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-[2vw] w-[2vw] mr-[1vw]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                    </svg>
                    <span class="text-[1.1vw]">BACK</span>
                </button>
                </div>
                
                <!-- Import NFTs section -->
                <h1 class="text-[1.5vw] font-bold text-white mb-[1vw]">IMPORT YOUR EXISTING NFTS</h1>
                <button class="flex justify-start items-start mb-[2vw] text-darkGray underline hover:text-buttonHover" on:click={()=>{window.open(`${config.blockExplorerUrls}/address/${address}`, "_blank")}}>
                    View your ERC721 NFTs you own on block explorer
                </button>
                <!-- Form fields -->
                <div class="flex flex-col gap-[1vw]">
                    <input 
                        type="text" 
                        bind:value={inputNftContract}
                        placeholder="Enter NFT Contract" 
                        class=" bg-black border border-white/40 text-white p-[1vw] text-[1.1vw] w-full"
                    />
                    
                    <input 
                        type="text" 
                        bind:value={inputId}
                        placeholder="Enter your NFT ID" 
                        class="bg-black border border-white/40 text-white p-[1vw] text-[1.1vw] w-full"
                    />
                    
                    <button 
                        on:click={importAndGenerateNFT(inputNftContract,inputId )}
                        class="bg-button hover:bg-buttonHover  text-white py-[1vw] text-[1.3vw] font-semibold mt-[1vw]"
                    >
                        IMPORT NFTS
                    </button>
                    {#if isOwnerError}
                        <div class="flex flex-col text-red-500">
                            <span class="">
                                You are not owner of this NFT
                            </span>
                            <div class="flex gap-[0.2vw]">
                                <span>
                                    Owner of this NFT is
                                </span>
                                <button class="flex underline" on:click={()=>{window.open(`${config.blockExplorerUrls}/address/${owner}`, "_blank")}}>
                                    {emitBetweenText(owner, 10)}
                                </button>
                            </div>
                        </div>
                    {/if}
                    {#if isImportSuccess}
                        <div class="flex flex-col text-button">
                            <span class="">
                               Import Succesfull
                            </span>
                            <span>
                                You can now use this NFT to battle 
                            </span>
                        </div>
                    {/if}
                    
                </div>
            </div>
            
            <div class="w-[70vw] bg-black flex flex-col justify-center items-center justify-center gap-[10px] p-[2vw]">
                {#if collectionName}
                    <div class="flex flex-col rounded-md w-[35vw]" >
                        <div class="flex flex-col p-[1vw] bg-arenaMedium rounded-md" in:slide={{ duration: 300 }}>
                            <div class="flex gap-[1vw]">
                                <div class="w-[7vw] h-[7vw] loading">
                                    <img class="bg-black w-[7vw] h-[7vw]" src={`${config.rpcUrl}/cdn/nft/${subMitNftContract}/${subMitNftId}/200/200`}/>
                                </div>
                                <!---->
                                <div class="flex flex-col justify-center gap-[10px]">
                                    <span class="text-lightestWood">
                                        From <span class="text-button font-thin"> {collectionName}</span>
                                    </span>
                                    <span class=" font-semibold">
                                        #{inputId}
                                    </span>
                                </div>
                            </div>
                            <div class="flex flex-col bg-arenaDark p-[1vw] text-arenaLight rounded-md mt-[1vw] gap-[1vw] max-h-[23vw] min-h-[23vw] overflow-y-scroll">
                                <span class="text-white text-[1.2vw]">
                                    Generated Skills Based on NFT Trait Names:
                                </span>
                                {#if attributes?.length >0 && resultSkills?.length == 0}
                                    <!-- skill-->
                                    {#each attributes as attribute}
                                        <div class="flex flex-col">
                                            <span>
                                                <span class="text-button">
                                                    {attribute.attribute}.{attribute.value}
                                                </span>
                                            </span>
                                            <span class="text-[0.8vw] font-medium">
                                                Encounter Rate:
                                                <span class="text-white">
                                                    {(100/(attributes.length)).toFixed(2)}%
                                                </span>
                                            </span>
                                            <span class="text-[0.8vw] text-white font-medium ml-[1vw]">
                                                Loading skill
                                            </span>
                                        </div>
                                    {/each}
                                {:else if attributes?.length >0 && resultSkills?.length >0}
                                    <!-- skill-->
                                    {#each resultSkills as resultSkill}
                                        <div class="flex flex-col">
                                            <span>
                                                <span class="text-button">
                                                    {resultSkill.attribute}
                                                </span>
                                            </span>
                                            <span class="text-[0.8vw] font-medium">
                                                Encounter Rate:
                                                <span class="text-white">
                                                    {(100/(resultSkills.length)).toFixed(2)}%
                                                </span>
                                            </span>
                                            <span class="text-[0.8vw] text-white font-medium ml-[1vw]">
                                                {resultSkill.desc}
                                            </span>
                                        </div>
                                    {/each}
                                {/if}
                            </div>
                        </div>
                    </div>
                {:else}
                    <img alt="Portal" src="/game/ui/importPortal.webp" class="w-[35vw] h-[35vw]"/>
                {/if}
                <div>

                </div>
                <div class="absolute flex flex-col bottom-[5vw] items-center">
                    <span class=" text-[1vw]">After importing existing NFTs, you can use that NFT on battle</span>
                    <span class=" text-[1vw]">Skills of your NFT will be automatically AI-generated based on your NFT trait name</span>
                </div>
                
            </div>
        </div>
        {#if generalError}
            <div class="absolute text-[1.5vw] bottom-0 right-[20vw] mb-[3vw] bg-red-500 px-[1vw] py-[0.5vw] rounded-md z-50" in:slide={{ duration: 200 }} out:slide={{ duration: 200 }}>
                {generalErrorValue}
            </div>
        {/if}
        {#if popupLoading}
            <div class="z-50">
                <Loading/>
            </div>
        {/if}
    </div>
</div>






