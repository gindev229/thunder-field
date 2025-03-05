<script>
    import Seo from '$lib/Seo.svelte';
    import { fade } from 'svelte/transition'; 
    import Nav from "../Nav.svelte";
    import {timeAgo} from '$lib/index.js';
    import {roundNum} from '$lib/index.js';
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { emitBetweenText } from '$lib/index.js';
    import { erc721ABI, erc721Bytecode, marketplaceAddress, marketplaceABI } from "$lib/contract.config.js";
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import config from "$lib/config.js";
    import Loading from "$lib/Loading.svelte";
    import Done from "$lib/Done.svelte";



    let popUp = false;
    let filterSideBar = false;
    let pagenition = "Items";
    let importError = false;

    const tokens = $page.url.pathname.split("/");
    const address = ethers.utils.getAddress(tokens.at(-1));

    const collectionNames = {};
    let userAddress;
    let loadingAct = false;
    let loadingOfferMade = false;
    //Copy
    let textToCopy = address;
  	let copied = false;
    let copyToClipboard;

    let offers = [], offersInfos = [];
    let offersReceivedInfos = [], offersReceived = [];
    let offersReceivedLoading = false, offersReceivedRendered = false;
    let currentOfferReceived = 0;
    let removeOffer, acceptOffer;
    let getOffersMade;
    let getActivities;
    let offersRendered = false;
    let activitiesRendered = false;

    let nftList = [];
    let currentItem = 0;
    let items = [];
    let done = false;
    let loading = true;

    let provider;
    let signer;
    let marketplace;
    let target;

    
    onMount(async () => {
        //Copy to Clipboard Function
        copyToClipboard = async function() {
            try {
                await window.navigator.clipboard.writeText(textToCopy);
                copied = true;
                setTimeout(() => (copied = false), 1000); // Reset 'copied' after 2 seconds
            } catch (err) {
                console.error('Failed to copy: ', err);
            }
        }
        async function loadCredentials() {
            try {
                if (window.ethereum) {
                    // Check if any accounts are available
                    const accounts = await window.ethereum.request({ method: "eth_accounts" });
                    
                    if (accounts.length > 0) {
                        // We have a connected wallet
                        provider = new ethers.providers.Web3Provider(window.ethereum);
                        signer = provider.getSigner();
                        userAddress = accounts[0];
                        marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, signer);
                    } else {
                        // No wallet connected, fallback to read-only provider
                        provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                        userAddress = null;
                        marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
                    }
                } else {
                    // MetaMask not installed, use read-only provider
                    provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                    userAddress = null;
                    marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
                }
            } catch (error) {
                console.error("Error in loadCredentials:", error);
                // Fallback to read-only provider on any error
                provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                userAddress = null;
                marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
            }
        }
        await loadCredentials(loadCredentials);

        (async () => {
            // Get nfts that user owns
            try {
                await (async function() {
                    /*// Get the nft list in local storage
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
                    }*/

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
                        console.log(responseBody,"responseBody")
                        // Update the new local list as well
                        for (const nft of responseBody.payload.nftHoldings) {
                            if (!nftList.find(_nft => nft.collection === _nft.collectionAddress && nft.id.toString() === _nft.id)) {
                                nftList.push({ collectionAddress: nft.collection, id: nft.id.toString() });
                            }
                        }
                        console.log("nftList.length", nftList.length)
                        // const localNFTList = JSON.parse(localStorage.nftList || "[]");
                        // nftList = [...nftList, ...localNFTList];
                    } else {
                        const responseBody = await response.json();

                        if (responseBody.error && responseBody.error.message) {
                            throw new Error(responseBody.error.message);
                        }
                    }
                })();
            } catch (e) {}

            // Load the first batch of nfts
            loadNFTs(nftList);

            // Load offers in the background
            for (const nft of nftList) {
                try {
                    let { offers, lister, isSold } = await getNFTInfo(nft.collectionAddress, nft.id);

                    if (!collectionNames[nft.collectionAddress]) {
                        collectionNames[nft.collectionAddress] = await getCollectionName(nft.collectionAddress);
                    }

                    for (const offeror in offers) {
                        let price, date;

                        if (typeof offers[offeror] === "string") {
                            price = offers[offeror];
                        } else if (typeof offers[offeror] === "object") {
                            price = offers[offeror].price;
                            date = offers[offeror].date
                        }

                        offersReceivedInfos.push({
                            collection: nft.collectionAddress,
                            id: nft.id,
                            price,
                            date,
                            from: offeror,
                            lister,
                            isSold
                        });
                    }
                } catch (e) {
                    console.log(e);

                    continue;
                }
            }

            offersReceivedInfos = offersReceivedInfos.reverse();

            offersReceivedLoading = true;
            offersReceived.push(...offersReceivedInfos.slice(currentOfferReceived, currentOfferReceived + 10));
            offersReceived = offersReceived;
            currentOfferReceived += 10;
            offersReceivedLoading = false;

            offersReceivedRendered = true;
        })();

        async function loadNFTs() {
            loading = true;
            
            const nfts = [];
            
            //push 18 NFT per schrol
            for (let index = currentItem; index < currentItem + 18; index++) {
                const id = nftList[index];

                nfts.push(id);
            }

            try {
                const curatedNFTs = nfts.filter(id => typeof id !== "undefined" && id !== null);

                if (curatedNFTs.length !== nfts.length) { done = true; }

                const nftInfos = (await getNFTsInfo(curatedNFTs, [ "metadata", "offers", "owner" ])).nftInfos;

                const newNfts = nftInfos.map(nft => ({ ...nft, id: nft.id }));

                items = [ ...items, ...newNfts ];

                console.log(items, "items")
                await loadOnChainListed();
            } catch (e) {
                console.log(e);

                done = true;
                loading = false;
            }



            loading = false;
            currentItem += 18;

            if (onChainItems.length < 18 && items.length < nftList.length) {
                // Use a flag to prevent overlapping calls
                setTimeout(() => loadNFTs(), 100);
            }
        }

        //wallet helper
        async function walletHelper() {
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

			// Connect to wallet if not already connected
            const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });

			if (accounts.length) {
                provider = new ethers.providers.Web3Provider(window.ethereum);
                signer = provider.getSigner();
                marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, signer);
                console.log(provider,"provider");
            }

			const { chainId } = await provider.getNetwork();

			// Only continue when network is correct
            if (chainId !== parseInt(config.chainId)) throw new Error(`Network must be ${config.chainName}`);
		}

        
        async function loadOnChainListed(){      
            for(let x = 0; x < items.length; x++){
                console.log(marketplace,"marketplace")
                try {
                    // Use provider instead of signer for read-only operations
                    const contractViewOnly = new ethers.Contract(items[x].collection, erc721ABI, provider);

                    let [owner, sold, price] = await Promise.all([
                        marketplace.ownerOf(items[x].collection, items[x].id),
                        marketplace.sold(items[x].collection, items[x].id),
                        marketplace.priceOf(items[x].collection, items[x].id)
                    ]);

                    //let target = new ethers.Contract(items[x].collection, erc721ABI, signer);
                    let ownerOnchain = await contractViewOnly.ownerOf(items[x].id); // Use the same contract for ownerOnchain check
                    //let ownerOnchain = await target.ownerOf(items[x].id);
                    console.log(owner, "owner")

                    let itemObject = {
                        collection: items[x].collection,
                        id: items[x].id,
                        collectionName: items[x].collectionName,
                        isSold: sold,
                        price: price,
                        owner : sold === true || owner === "0x0000000000000000000000000000000000000000" ?  ownerOnchain : owner
                    };
                    const itemExists = onChainItems.some(
                        item => item.collection === itemObject.collection && item.id === itemObject.id
                    );
                    if(!itemExists && itemObject.owner == address){
                        onChainItems.push(itemObject);
                        onChainItems = [...onChainItems];

                    }

                } catch (error) {
                    console.log(error);
                }
            }
        }


        //Get offers made
        let currentOffer = 0, offerLoading = false;

        getOffersMade = async function(address) {
            if (!offersRendered) {
                const response = await fetch(config.rpcUrl, {
                    method: "POST",
                    body: JSON.stringify({
                        method: "getOffersMade",
                        params: {
                            address
                        }
                    }),
                    headers: {
                        "Content-Type": "application/json"
                    }
                });

                if (response.ok) {
                    // Success
                    const responseBody = await response.json();

                    for (const offer of responseBody.payload.offers) {
                        if (!collectionNames[offer.collection]) {
                            collectionNames[offer.collection] = await getCollectionName(offer.collection)
                        }

                        offersInfos.push(offer);
                    }

                    offersInfos = offersInfos.reverse();

                    offerLoading = true;
                    offers.push(...offersInfos.slice(currentOffer, 10));
                    offers = offers;
                    currentOffer += 10;
                    offerLoading = false;

                    offersRendered = true;
                } else {
                    // Fail
                    const responseBody = await response.json();

                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);   
                    }
                }
            }
        }

        //Remove offers
        removeOffer = async function(collectionAddress, id) {
            popupLoading = true;
            let offerAmount = await marketplace.offers(collectionAddress, BigInt(id), userAddress);
            

            //Remove offer ver2
            if (offerAmount.toString() !== "0") {
                try {
                    await walletHelper();
                    const tx = await marketplace.removeOffer(collectionAddress, id);
                    await tx.wait();
                    
                    popupLoading = false;
                    popupDone = true;
                    
                    setTimeout(() => {
                        location.reload();
                    }, 2000);
                } catch (e) {
                    popupLoading = false;
                    throw e;
                }
            }         
        }

        // Accept offer
        acceptOffer = async function(address, id, proposer, price, lister, isSold) {
            popupLoading = true;
            
            let offerAmount = await marketplace.offers(address, BigInt(id), proposer);

            if(offerAmount.toString() === "0" ){
                popupLoading = false;
                
            } else {
                try {
                    await walletHelper();

                        // List the NFT first if not listed
                        if (lister === "0x0000000000000000000000000000000000000000" || isSold) {
                            const nftContract = new ethers.Contract(address, erc721ABI, signer);
                            
                            const tx = await nftContract.approve(marketplace.address, id);
                            await tx.wait();

                            const tx2 = await marketplace.list(address, id, price);
                            await tx2.wait();
                        }

                        // Accept the offer
                        const tx = await marketplace.acceptOffer(address, id, proposer);
                        await tx.wait();

                        popupLoading = false;
                        popupDone = true;
                        
                        setTimeout(() => {
                            location.reload();
                        }, 2000);
                } catch (e) {
                    popupLoading = false;
                    errorFrontCode = (e.code);
                    throw e;
                }
            }
        }

        //Get NFTs info
        async function getNFTInfo(address, id, optionalExclude) {
			const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getNFTInfo",
					params: {
						address,
						id,
                        exclude: optionalExclude || [ "metadata", "collectionName", "owner" ]
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

                return responseBody.payload;
            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        }

        //Get activities
        let currentActivity = 0, activityLoading = false;
        
        getActivities = async function() {
            if (!activitiesRendered) {
                const pageIndex = await getActivityPageIndex(address);
                const returnedActivities = [ ...await getActivityPage(address, pageIndex) ].reverse();

                for (const activity of returnedActivities) {
                    if (!collectionNames[activity.collection]) {
                        collectionNames[activity.collection] = await getCollectionName(activity.collection);
                    }

                    activitiesInfos.push(activity); 
                }

                activitiesInfos = activitiesInfos; 

                activityLoading = true;
                activities.push(...activitiesInfos.slice(currentActivity, currentActivity + 10));
                activities = activities;
                currentActivity += 10;
                activityLoading = false;

                console.log(activitiesInfos);

                activitiesRendered = true;
            }
        }

        //Call 18 NFTS by scroll
        window.addEventListener("scroll", () => {
            // console.log((window.innerHeight + window.scrollY + 200), document.body.offsetHeight);

            if ((window.innerHeight + window.scrollY + 100) >= document.body.offsetHeight) {
                if (pagenition === "offersMade" && !offerLoading && offersRendered) {
                    offerLoading = true;
                    offers.push(...offersInfos.slice(currentOffer, 10));
                    offers = offers;
                    currentOffer += 10;
                    offerLoading = false;
                } else if (pagenition === "Activity" && !activityLoading && activitiesRendered) {
                    activityLoading = true;
                    activities.push(...activitiesInfos.slice(currentActivity, currentActivity + 10));
                    activities = activities;
                    currentActivity += 10;
                    activityLoading = false;
                } else if (pagenition === "offersReceived" && !offersReceivedLoading && offersReceivedRendered) {
                    offersReceivedLoading = true;
                    offersReceived.push(...offersReceivedInfos.slice(currentOfferReceived, currentOfferReceived + 10));
                    offersReceived = offersReceived;
                    currentOfferReceived += 10;
                    offersReceivedLoading = false;
                } else if (pagenition === "Items" && !done && !loading) {
                    loadNFTs(nftList); 
                }
            }
        });

        let isloadMissingNFTs = false;
        /*loadmising NFT
        function loadMissingNFTs() {
            console.log("loading1");
            const intervalId = setInterval(async () => {
                if (items.length >= nftList.length && done && !loading) {
                    clearInterval(intervalId);
                    return;
                }

                console.log("loading2");
                if (!loading && items.length < nftList.length) {
                    await loadNFTs();
                    console.log("loading3");
                    console.log(items.length, "items.length");
                    console.log(nftList.length, "nftList.length");
                }
            }, 500);
        }

        // Call the function to load missing NFTs
        loadMissingNFTs();*/

    });
    
    function bigIntToFloat(number) {
        const natural = number / 10n ** 18n;
        const decimal = number % 10n ** 18n;

        return parseFloat(natural.toString() + "." + decimal.toString().padStart(18, "0"));
    }
    
    
    //manually add nft
    let addCollectionAddress = "";
    let addCollectionID = "";

    async function addNFTToLocalList(collectionAddress, id) {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner();
        const userAddress = await signer.getAddress();

        // Get the nft list in local storage
        const nftList = JSON.parse(localStorage.nftList || "[]");

        // Duplication check
        for (const nft of nftList) {
            // Prevent duplication
            if (nft.collectionAddress === collectionAddress && nft.id === id) {
                return;
            }
        }

        console.log(userAddress);

        // Ownership check
        const { owner, lister } = await getNFTOwner(collectionAddress, id);

        if (owner !== userAddress && lister !== userAddress) {
            return;
        }

        // Add NFT to list
        nftList.unshift({ collectionAddress, id });
        
        // Update the list
        localStorage.nftList = JSON.stringify(nftList);
        // ...and reload the site
        // location.reload();
    }

    //Acitivity
    let activities = [], activitiesInfos = [];

    async function getActivityPageIndex(address) {
        loadingAct = true;

        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getActivityPageIndex",
                params: {
                    address
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            // Success
            const responseBody = await response.json();

            return responseBody.payload.pageIndex;
        } else {
            // Fail
            const responseBody = await response.json();
            loadingAct = false;
            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }
        }
    }

    async function getActivityPage(address, pageIndex) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getActivityPage",
                params: {
                    address,
                    pageIndex
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            // Success
            const responseBody = await response.json();
            loadingAct = false;

            return responseBody.payload.page;
        } else {
            // Fail
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }

            loadingAct = false;
        }
    }

    async function getCollectionName(address) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getCollectionInfo",
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

            return responseBody.payload.name;
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    };
    
    function reducedNFTName(collection, id) {
        if (`${collection} #${id}`.length > 28) {
            return `${collection.substr(0, collection.length-3-(`${collection} #${id}`.length-28))}... #${id}`
        } else {
            return `${collection} #${id}`;
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

            return responseBody.payload;
        } else {
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);
            }
        }
    }



    //check-on chain NFT on profile
    let onChainItems = [];


    //popup stuffs
    let popupDone;
    let popupLoading;

    //loading img
    let imgActivityLoad = true;
    let imgItemLoad = true;
    let imgLoad = true;
    let imgOfferLoad = true;

    let loadingItems = [{},{},{},{},{},{}];
</script>

<Seo title={"Thunder Field - User Address"} description={""} keywords={""}/>
<div class="flex font-Hoves bg-black w-full min-h-screen">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <div class="flex flex-col">
            <Nav/>

            <!--Address container-->
            <div class="flex flex-wrap items-center justify-between mt-[30px] mb-[20px] bg-darkCard rounded-md shadow-md px-[20px] py-[30px]">
                <div class="flex items-center gap-[20px]">
                    <!--Ava-->
                    <div class={`sm:w-[80px] w-[40px] h-[40px] sm:h-[80px] rounded-full bg-[#F5FAB8] shadow-md`} >
                    </div>
                    <!--Address + copy button cotainer-->
                    <div class="flex flex-col">
                        <span class="text-lightGray text-sm">
                            User address
                        </span>
                        <div class="flex gap-1 font-semibold">
                            <span class="text-blue text-2xl">
                                {emitBetweenText(address, 10)}
                            </span>
                            <!--Copy button-->
                            <button class="fill-darkGray hover:fill-black" on:click={copyToClipboard}>
                                {#if copied}
                                    <img class="h-[20px] ml-[12px]" src="/icons/tick.svg" alt="copy address icon"/>
                                {:else}
                                    <svg class="inline-block h-[20px] ml-[12px] fill-inherit" viewBox="0 0 19 22" fill="none" xmlns="http://www.w3.org/2000/svg">
                                        <path class="fill-inherit" fill-rule="evenodd" clip-rule="evenodd" d="M19 16.2609V0.956522L18.05 0H5.7L4.75 0.956522V4.78261H0.95L0 5.73913V21.0435L0.95 22H13.3L14.25 21.0435V17.2174H18.05L19 16.2609ZM14.25 15.3043V5.73913L13.3 4.78261H6.65V1.91304H17.1V15.3043H14.25ZM1.9 6.69565H12.35V20.087H1.9V6.69565Z"/>
                                    </svg>
                                {/if}
                            </button>
                        </div>
                        <button 
                        on:click={()=>{window.open(`${config.blockExplorerUrls}/address/${address}`, "_blank")}}
                        class="flex text-sm text-button hover:text-buttonHover underline">
                            View on {config.chainName} Explorer
                        </button>
                    </div>
                </div>


            </div>
            <!--Pagnition Option-->
            <div class="flex flex-wrap gap-[10px] my-[20px] font-semibold text-lg">
                <button class="py-1 sm:px-[25px] px-[10px] rounded-md {pagenition === "Items"?"text-white bg-button":"text-blue"}"
                on:click={()=>{pagenition = "Items"}}>
                    Items
                </button>
                <button class="py-1 sm:px-[25px] px-[10px]  rounded-md {pagenition === "Activity"?"text-white bg-button":"text-blue"}"
                on:click={()=>{pagenition = "Activity";getActivities()}}>
                    Activity
                </button>
                <button class="py-1 sm:px-[25px] px-[10px]  rounded-md {pagenition === "offersMade"?"text-white bg-button":"text-blue"}"
                on:click={()=>{pagenition = "offersMade"; getOffersMade(address); console.log(pagenition)}}>
                    Offers Made
                </button>
                <button class="py-1 sm:px-[25px] px-[10px]  rounded-md {pagenition === "offersReceived"?"text-white bg-button":"text-blue"}"
                on:click={()=>{pagenition = "offersReceived"; console.log(pagenition)}}>
                    Offers Received
                </button>
            </div>
            <!--Filter items container-->         
            <div class="flex justify-between my-[20px]">
                <!--Filter side bar-->
                {#if pagenition === "Activity" ||  pagenition ==="Items"}
                    {#if filterSideBar}
                        <div class="sm:flex hidden flex-col min-w-[260px] max-w-[260px] min-h-[560px] text-lg gap-[20px]">
                            <!--Filter when in Item page-->   
                            {#if pagenition==="Items"}
                                <!--Listed check-->
                                <div class="flex w-full items-center justify-between">
                                    <span>
                                        Listed
                                    </span>
                                    <input type="checkbox" class="h-[20px] w-[20px] bg-darkGray text-lightGray"/>
                                </div>
                                <!--Unlisted check-->
                                <div class="flex w-full items-center justify-between">
                                    <span>
                                        Unlisted
                                    </span>
                                    <input type="checkbox" class="h-[20px] w-[20px] bg-darkGray text-lightGray"/>
                                </div>
                            {/if}
                            <!--Filter when in Activity page-->
                            {#if pagenition==="Activity"}
                                <!--Listing check-->
                                <div class="flex w-full items-center justify-between">
                                    <span>
                                        Listing
                                    </span>
                                    <input type="checkbox" class="h-[20px] w-[20px] bg-darkGray text-lightGray"/>
                                </div>
                                <!--Transfer check-->
                                <div class="flex w-full items-center justify-between">
                                    <span>
                                        Transfer
                                    </span>
                                    <input type="checkbox" class="h-[20px] w-[20px] bg-darkGray text-lightGray"/>
                                </div>
                                <!--Mint check-->
                                <div class="flex w-full items-center justify-between">
                                    <span>
                                        Mint
                                    </span>
                                    <input type="checkbox" class="h-[20px] w-[20px] bg-darkGray text-lightGray"/>
                                </div>
                            {/if}
                        </div>
                    {/if}
                {/if}
                <!--All cards containers only appear in Items Page-->
                {#if pagenition ==="Items"}
                    <div class="flex flex-wrap gap-5 justify-center"> 
                        <!--All cards-->
                        {#each onChainItems as item}
                            {#if item.owner == address}
                                <!--Cards-->
                                <button on:click={() => {goto(`../items/${item.collection}/${item.id}`);}} 
                                    class="relative group parent flex flex-col text-white gap-1 rounded-xl cursor-pointer relative bg-darkCard  min-h-[325px] max-h-[355px] px-2 py-2 hover:border-blue hover:border shadow-xl">
                                    <!--Card img-->
                                    <div class="{imgLoad? "loading":""} flex items-center min-w-[208px] max-w-[208px] min-h-[208px] max-h-[208px] rounded-t-xl overflow-hidden">
                                        <img src={`${config.rpcUrl}/cdn/nft/${item.collection}/${item.id}/350/350`}
                                        on:load={()=>{ imgItemLoad = false}} class="shrink-on-hover object-contain rounded-t-xl min-w-[208px] max-w-[208px]" alt="test"/>
                                    </div>
                                    <!--Card Info-->
                                    <div class="flex flex-col gap-[5px]">
                                        <span class="font-bold text-blue text-lg">
                                            {reducedNFTName(item.collectionName, item.id)}
                                        </span>
                                        <div class="flex items-center gap-[5px]">
                                            <img class="h-[20px] inline-block border-[1px] border-darkGray rounded-full" src="/icons/ETN.png" alt="coin icon"/>
                                            <!--Price-->
                                            {#if item.price === "-1" || item.isSold}
                                                <!--Price value-->
                                                <span class="font-bold text-lightGray">
                                                    Unlisted
                                                </span>
                                            {:else}
                                                <!--Price value-->
                                                <span class="font-bold">
                                                    { bigIntToFloat(BigInt(item.price)) }
                                                </span>
                                            {/if}
                                        </div>
                                    </div>
                                    <!--Hover buy card-->
                                    <div class="absolute flex md:hidden group-hover:flex bottom-0 gap-[10px] mb-2">
                                        <!--<button class="flex w-[180px] justify-center py-1  bg-[#5960BE] hover:bg-orange rounded-lg font-semibold">
                                            Purchase
                                        </button>
                                        <button class="flex items-center gap-1 py-1 px-1 border-2 border-darkGray hover:border-[#FD8900] hover:text-[#FD8900] text-lightGray hover:fill-[#FD8900] fill-[#9295BF] rounded-lg">
                                            <svg class="h-[20px] inline-block fill-inherit"  viewBox="0 0 43 38" fill="none" xmlns="http://www.w3.org/2000/svg">
                                                <path class="fill-inherit" fill-rule="evenodd" clip-rule="evenodd" d="M0 2C0 0.89544 0.89544 0 2 0C5.24962 0 8.13466 2.07942 9.16228 5.16228L9.44152 6H34.06C35.3718 5.99996 36.4874 5.99992 37.3902 6.08058C38.33 6.16452 39.2694 6.35024 40.128 6.87168C41.3334 7.60366 42.2422 8.73676 42.6954 10.0721C43.0182 11.0234 42.9956 11.9807 42.8738 12.9163C42.7566 13.8151 42.5146 14.9042 42.23 16.1848L41.6176 18.9408C41.328 20.2436 41.087 21.3282 40.8212 22.2086C40.5432 23.1298 40.2012 23.9606 39.6462 24.72C38.8116 25.862 37.6892 26.7624 36.3934 27.3292C35.5316 27.7064 34.6464 27.86 33.6868 27.9316C32.7698 28 31.659 28 30.3242 28H19.6758C18.341 28 17.2302 28 16.3131 27.9316C15.3536 27.86 14.4684 27.7064 13.6066 27.3292C12.3107 26.7624 11.1884 25.862 10.3538 24.72C9.79882 23.9606 9.45688 23.1298 9.17878 22.2086C8.91298 21.3282 8.67204 20.2438 8.3825 18.9408L6.07 8.53458L5.36754 6.42718C4.88438 4.9777 3.5279 4 2 4C0.89544 4 0 3.10456 0 2ZM10.4932 10L12.2714 18.0016C12.5808 19.3942 12.7906 20.332 13.0081 21.0526C13.2182 21.7484 13.398 22.1062 13.5834 22.36C14.0007 22.931 14.5619 23.3812 15.2098 23.6646C15.4978 23.7906 15.886 23.8886 16.6109 23.9426C17.3615 23.9988 18.3224 24 19.749 24H30.251C31.6776 24 32.6384 23.9988 33.389 23.9426C34.114 23.8886 34.5022 23.7906 34.7902 23.6646C35.4382 23.3812 35.9994 22.931 36.4166 22.36C36.602 22.1062 36.7818 21.7484 36.992 21.0526C37.2094 20.332 37.4192 19.3942 37.7286 18.0016L38.306 15.4032C38.615 14.013 38.816 13.0997 38.9072 12.3995C38.9964 11.716 38.9444 11.4662 38.9074 11.3574C38.7564 10.9123 38.4534 10.5346 38.0518 10.2906C37.9534 10.2309 37.721 10.126 37.0344 10.0647C36.331 10.0019 35.3958 10 33.9718 10H10.4932Z" />
                                                <path class="fill-inherit" d="M20 34C20 36.2092 18.2092 38 16 38C13.7909 38 12 36.2092 12 34C12 31.7908 13.7909 30 16 30C18.2092 30 20 31.7908 20 34Z" />
                                                <path class="fill-inherit" d="M34 38C36.2092 38 38 36.2092 38 34C38 31.7908 36.2092 30 34 30C31.7908 30 30 31.7908 30 34C30 36.2092 31.7908 38 34 38Z" />
                                            </svg>
                                            <span class=" text-inherit font-semibold">
                                                Add
                                            </span>
                                        </button>-->
                                    </div>
                                    <!--Card Rarity-->
                                    <!--<span class="ml-[0px] text-sm text-lightGray bottom-0 mt-3">
                                        <span>Rarity:</span>
                                        <span class="">10%</span>
                                    </span>-->
                                </button>
                            {/if}
                        {/each}
                        <!--Loading Cards-->
                        {#if loading }
                            {#each loadingItems as loadItem}    
                                <!--Cards-->
                                <div class="relative group parent flex flex-col text-white  gap-1 rounded-xl cursor-pointer relative bg-darkCard  min-h-[325px] max-h-[325px] px-2 py-2 shadow-xl">
                                    <!--Card img-->
                                    <div class="flex items-center min-w-[208px] max-w-[208px] min-h-[208px] max-h-[208px] loading rounded-t-xl overflow-hidden">
                                        <div class="shrink-on-hover object-contain rounded-t-xl min-w-[208px] max-w-[208px]" alt="test">
                                        </div>
                                    </div>
                                    <!--Card Info-->
                                    <div class="flex flex-col gap-[5px]">
                                        <div class="font-bold text-blue loading min-w-[100px] min-h-[10px]">
                                            
                                        </div>
                                        <div class="flex items-center gap-[5px]">
                                            <!--Price-->
                                            <div class="font-semibold loading min-w-[100px] min-h-[20px]">
                                                
                                            </div>
                                        </div>
                                    </div>
                                    <!--Card Rarity-->
                                    <span class="ml-[0px] text-sm text-lightGray bottom-0 mt-3">
                                    </span>
                                </div>
                            {/each}
                        {/if}
                    </div>
                {/if}
                <!--Activity-->
                <!--Activity large screen-->
                {#if pagenition ==="Activity"}
                    {#if activities.length > 0}
                        <div class="xl:flex hidden flex-col rounded-md text-white text-left border bg-darkCard shadow-md w-full py-[15px] lg:px-8 px-4 ml-[20px]">
                            <!--Header-->
                            <div class="lg:flex hidden text-lightGray text-sm pb-[12px] w-full" >
                                <div class="rounded-tr-sm  w-[10%]">Event</div>
                                <div class="rounded-tr-sm  w-[30%]">Item</div>
                                <div class="rounded-tr-sm   w-[20%]">Price</div>
                                <div class="rounded-tr-sm  w-[15%]">From</div>
                                <div class="rounded-tr-sm  w-[15%]">To</div>
                                <div class="rounded-tr-sm  w-[10%]">Date</div>
                            </div>
                            <!--Body-->
                            <div class="rounded-b-sm">
                                <!--Row-->
                                {#each activities as activity}
                                    <div class="text-sm flex lg:items-center lg:justify-center justify-between hover:text-yellow-500 py-[15px] border-t border-grayBorder">
                                        <!--Event-->
                                        <div class="flex lg:w-[10%]  flex items-center">
                                            {#if activity.type === "transfer"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/transfer.svg" alt="transfer NFT icon"/>
                                            {:else if activity.type === "list"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/listing.svg" alt="listing NFT icon"/>
                                            {:else if activity.type === "unlist"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/unlist.svg" alt="unlist NFT icon"/>
                                            {:else if activity.type === "sale"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/sale.svg" alt="sale NFT icon"/>
                                            {:else if activity.type === "mint"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/mint.svg" alt="mint NFT icon"/>
                                            {/if}
                                            <!--Event name-->
                                            <!--<span class=" font-bold blue-text">{activity.type}</span>-->
                                        </div>
                                        <!--Items-->
                                        <button class="flex lg:w-[30%] items-center" on:click={() => goto(`../../items/${activity.collection}/${activity.id}`)}>
                                            <!--Items image-->
                                            <img class="h-[60px] {imgActivityLoad? "loading":""} inline-block mr-[5px] rounded-full" 
                                            src="{config.rpcUrl}/cdn/nft/{activity.collection}/{activity.id}/200/200"
                                            on:load={()=>{ imgActivityLoad = false}} alt="user NFT"/>
                                            <!--Items name-->
                                            <div class="flex flex-col font-semibold text-blue">
                                                <span class=""> 
                                                    {collectionNames[activity.collection]}
                                                </span>
                                                <!--Item id-->
                                                <span class=" self-start   font-thin text-lightGray"> #{activity.id}</span>
                                            </div>
                                        </button>
                                        <!--Price-->
                                        <div class="flex lg:w-[20%]  flex items-center">
                                            <img class="lg:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                            <!--Offer value-->
                                            <span class=" font-semibold">
                                                {roundNum(bigIntToFloat(BigInt(activity.price)),5)} 
                                            </span>
                                        </div>
                                        <!--From Address-->
                                        <button class="flex lg:w-[15%] "
                                        on:click={() => { window.location.href = `../../${activity.from}`; }}>
                                            <span class="underline ml-[3px]">
                                                {emitBetweenText(activity.from, 10)}
                                            </span>
                                        </button>
                                        <!--To Address-->
                                        <button class="flex lg:w-[15%] "
                                        on:click={() => { window.location.href = `../../${activity.to}`; }}>
                                            <span class="underline ml-[3px]">
                                                {emitBetweenText(activity.to, 10)}
                                            </span>
                                        </button>
                                        <!--Date Offer-->
                                        <div class="  lg:w-[10%] lg:order-1 order-2 ">
                                            {timeAgo(activity.date)} 
                                        </div>

                                    </div>
                                {/each}
                            </div>
                        </div>
                    {:else if activities.length === 0}
                        <div class="xl:flex hidden flex-col rounded-md text-left bg-darkCard w-full py-[15px] lg:px-8 px-4 ml-[20px]">
                            <span class="text-xl text-lightGray">
                                There are no activities yet
                            </span>
                        </div>
                    {/if}
                {/if}
                <!--Activity Small screen-->
                {#if pagenition ==="Activity"}
                    {#if activities.length !==0}
                        <div class="xl:hidden flex flex-col text-white rounded-md text-left border border-grayBorder bg-darkCard w-full py-[15px] sm:px-4 px-4 sm:ml-[20px] ml-[0px] gap-[20px] ">
                            {#each activities as activity}
                                <div class="flex flex-col py-[10px] ">
                                    <!--Status-->
                                    <div class="flex lg:w-[10%] items-center">
                                        {#if activity.type === "transfer"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/transfer.svg" alt="transfer NFT icon"/>
                                        {:else if activity.type === "list"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/listing.svg" alt="listing NFT icon"/>
                                        {:else if activity.type === "unlist"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/unlist.svg" alt="unlist NFT icon"/>
                                        {:else if activity.type === "sale"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/sale.svg" alt="sale NFT icon"/>
                                        {:else if activity.type === "mint"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/mint.svg" alt="mint NFT icon"/>
                                        {/if}
                                        <!--<span class=" font-bold blue-text text-xl">
                                            {activity.type}
                                        </span>-->
                                    </div>
                                    <!---->
                                    <div class="flex  flex-wrap w-full justify-between mt-[10px] sm:ml-[20px] pr-4">
                                        <div class="flex items-center gap-2">
                                            <!--Image-->
                                            <button on:click={() => goto(`../../items/${activity.collection}/${activity.id}`)}>
                                                <img class="sm:h-[100px] h-[50px] inline-block mr-[5px] rounded-full" src="{config.rpcUrl}/cdn/nft/{activity.collection}/{activity.id}/200/200" alt="user's NFT"/>
                                            </button>
                                            <!--Collection Name + From + To-->
                                            <div class="flex  flex-col">
                                                <!--Collection Name-->
                                                <span class="sm:text-xl text-sm text-blue font-bold mb-[10px]"> 
                                                    {collectionNames[activity.collection]}
                                                    <!--Id-->
                                                    <span>#{activity.id}</span>
                                                </span>
                                                <div class="flex gap-1">
                                                    <span class="sm:text-medium text-sm mr-1 text-lightGray">From</span>
                                                    <!--From Address-->
                                                    <button class="flex sm:text-medium text-sm underline "
                                                    on:click={() => { window.location.href = `../../${activity.from}`; }}>
                                                        {emitBetweenText(activity.from, 10)}
                                                    </button>
                                                </div>
                                                <div class="flex gap-1">
                                                    <span class="sm:text-medium text-sm mr-1 text-lightGray">To</span>
                                                    <!--To Address-->
                                                    <button class="flex sm:text-medium text-sm underline "
                                                    on:click={() => { window.location.href = `../../${activity.to}`; }}>
                                                        {emitBetweenText(activity.to, 10)}
                                                    </button>
                                                </div>
                                                
                                            </div>
                                        </div>
                                        <!--Price + Date-->
                                        <div class="flex flex-col sm:self-end  mt-2">
                                            <!--Price-->
                                            <div class="flex flex items-center">
                                                <img class=" sm:h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                <!--Offer value-->
                                                <span class="sm:text-lg text-medium font-semibold">
                                                    {roundNum(bigIntToFloat(BigInt(activity.price)),5)}
                                                </span>
                                            </div>
                                            <!--Date-->
                                            <span class="sm:text-sm text-sm ">
                                                {timeAgo(activity.date)} 
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {:else if activities.length ===0}
                        <div class="xl:hidden flex flex-col rounded-md text-left shadowm-md bg-darkCard w-full py-[15px] sm:px-4 px-4 sm:ml-[20px] ml-[0px] gap-[20px]">
                            <span class="text-xl text-lightGray">
                                There are no activities yet
                            </span>
                        </div>
                    {/if}
                {/if}
                <!---->
                <!--Offers Made Table-->
                {#if pagenition ==="offersMade"}
                    {#if offers.length !==0}
                        <div class="flex flex-col text-white rounded-md text-left shadow-md bg-darkCard w-full py-[15px] lg:px-12 px-4">
                            <!--Header-->
                            <div class="lg:flex hidden text-lightGray text-base pb-[12px] w-full  border-darkGray" >
                                <div class="rounded-tr-sm  w-[30%]">Item</div>
                                <div class="rounded-tr-sm  w-[30%]">Price</div>
                                
                                <div class="rounded-tr-sm  w-[25%]">Date</div>
                                <div class="rounded-tr-sm  w-[15%]"></div>
                            </div>
                            <!--Body-->
                            <div class="rounded-b-sm">
                                <!--Row-->
                                {#each offers as offer}
                                    <div class="flex lg:items-center lg:justify-center justify-between hover:text-buttonHover py-[15px] border-t border-grayBorder">
                                        
                                        <!--Items + Price + From Address-->
                                        <div class="flex lg:flex-row flex-col lg:items-center lg:w-[60%]   lg:gap-0 gap-4 text-inherit">
                                            <!--Items-->
                                            <div class="flex lg:w-[50%] items-center text-inherit">
                                                <!--Items image-->
                                                <img class="h-[60px]  inline-block mr-[5px] rounded-full" src="{config.rpcUrl}/cdn/nft/{offer.collection}/{offer.id}/200/200" alt="NFT"/>
                                                <!--Items name-->
                                                <div class="flex flex-col font-semibold text-inherit">
                                                <span class="text-lg text-inherit text-blue"> {collectionNames[offer.collection]}</span>
                                                <span class="text-lg font-thin text-lightGray"> #{offer.id}</span>
                                                </div>
                                            </div>
                                            <!--PC screen Price-->
                                            <div class="lg:flex hidden lg:w-[50%]  flex items-center">
                                                <img class="lg:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                <!--Offer value-->
                                                <span class="text-lg font-semibold">{roundNum(bigIntToFloat(BigInt(offer.price)),9)}</span>
                                            </div>
                                        </div>
                                        <!--Date Offer + Button-->
                                        <div class="flex lg:flex-row flex-col  lg:items-center lg:w-[40%] gap-2  ">
                                            <!--Mobile screen price-->
                                            <div class="lg:hidden flex  flex items-center">
                                                <img class="lg:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                <!--Offer value-->
                                                <span class="text-lg font-semibold">{roundNum(bigIntToFloat(BigInt(offer.price)),9)}</span>
                                            </div>
                                            <!--Date Offer-->
                                            <div class="  lg:w-[62.5%] lg:order-1 order-2 ">
                                                {timeAgo(offer.date)}
                                            </div>
                                            <!--Button-->
                                            {#if address === userAddress}
                                                <button class="bg-yellowButton text-white  p-2 font-semibold rounded-lg lg:w-[37.5%] lg:order-2 order-1 hover:bg-yellowHover "
                                                on:click={()=>{removeOffer(offer.collection, offer.id)}}>
                                                    Cancel
                                                </button>
                                            {:else}
                                                <div class=" p-2 lg:w-[37.5%] lg:order-2 order-1">
                                                </div>
                                            {/if}
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {:else if loadingOfferMade === false || offers.length !==0}
                        <div class="flex flex-col text-white rounded-md text-left shadow-md bg-darkCard w-full py-[15px] lg:px-12 px-4">
                            <span class="text-xl text-lightGray">
                                No offer has been made yet
                            </span>
                        </div>
                    {:else if loadingOfferMade === true }
                        <div class="flex flex-col text-white loading rounded-md text-left shadow-md bg-darkCard w-full py-[15px] lg:px-12 px-4">
                            <span class="text-xl text-lightGray">
                                loading
                            </span>
                        </div>
                    {/if}
                {/if}
                <!--Offers Received Table-->
                {#if pagenition ==="offersReceived"}
                    <!---->
                    {#if offersReceived.length === 0}
                        <div class="flex flex-col text-white rounded-md text-left bg-darkCard shadow-md w-full py-[15px] lg:px-12 px-4 text-white">
                            <span class="text-xl text-lightGray">
                                No offer has been made yet
                            </span>
                        </div>
                    <!---->
                    {:else}
                        <div class="flex flex-col text-white rounded-md text-left bg-darkCard shadow-md w-full py-[15px] lg:px-12 px-4">
                            <!--Header-->
                            <div class="lg:flex hidden text-lightGray text-base pb-[12px] w-full  border-darkGray" >
                                <div class="rounded-tr-sm  w-[25%]">Item</div>
                                <div class="rounded-tr-sm  w-[25%]">Price</div>
                                <div class="rounded-tr-sm   w-[20%]">From</div>
                                <div class="rounded-tr-sm  w-[20%]">Date</div>
                                <div class="rounded-tr-sm  w-[10%]"></div>
                            </div>
                            <!--Body-->
                            <div class="rounded-b-sm">
                                {#each offersReceived as offerReceived}
                                    <!--Row-->
                                    <div class="flex lg:items-center lg:justify-center justify-between hover:text-buttonHover py-[15px] border-t border-grayBorder">
                                        
                                        <!--Items + Price + From Address-->
                                        <div class="flex lg:flex-row flex-col lg:items-center lg:w-[70%]   lg:gap-0 gap-4">
                                            <!--Items-->
                                            <div class="flex lg:w-[35%] items-center">
                                                <!--Items image-->
                                                <img class="h-[60px]  inline-block mr-[5px] rounded-full" 
                                                    src={`${config.rpcUrl}/cdn/nft/${offerReceived.collection}/${offerReceived.id}/350/350`} alt="NFT">
                                                <!--Items name-->
                                                <div class="flex flex-col font-semibold text-blue">
                                                <span class="text-lg">{collectionNames[offerReceived.collection]}</span>
                                                <span class="text-lg font-thin text-lightGray"> #{offerReceived.id}</span>
                                                </div>
                                            </div>
                                            <!--PC screen Price-->
                                            <div class="lg:flex hidden lg:w-[35%]  flex items-center">
                                                <img class="lg:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                <!--Offer value-->
                                                <span class="text-lg font-semibold">
                                                    {roundNum(bigIntToFloat(BigInt(offerReceived.price)),7)}
                                                
                                                </span>
                                            </div>
                                            <!--From Address-->
                                            <div class="lg:w-[30%] ">
                                                <span class="text-lightGray lg:hidden flex">From</span>
                                                <span class="underline ml-[3px]">
                                                    {emitBetweenText(offerReceived.from, 10)}
                                                </span>
                                                </div>
                                        </div>
                                        <!--Date Offer + Button-->
                                        <div class="flex lg:flex-row flex-col  lg:items-center lg:w-[30%] gap-2 ">
                                            <!--Mobile screen price-->
                                            <div class="lg:hidden flex lg:w-[35%]  flex items-center">
                                                <img class="lg:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                <!--Offer value-->
                                                <span class="text-lg font-semibold">
                                                    {roundNum(bigIntToFloat(BigInt(offerReceived.price)),5)}
                                                </span>
                                            </div>
                                            <!--Date Offer-->
                                            <div class="  lg:w-[67%] lg:order-1 order-2 ">
                                                {offerReceived.date ? timeAgo(offerReceived.date) : "N/A"}
                                            </div>
                                            <!--Button-->
                                            <button 
                                                on:click={
                                                    () => acceptOffer(offerReceived.collection, offerReceived.id, offerReceived.from, offerReceived.price, offerReceived.lister, offerReceived.isSold)
                                                } 
                                                class="bg-button text-white  p-2 font-semibold rounded-lg lg:w-[33%] lg:order-2 order-1 hover:bg-buttonHover">
                                                Accept
                                            </button>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}
                {/if}
            </div>
        </div>
    </div>
</div>


{#if popUp}
    <div class="fixed font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-40 text-lightGray ">
        <div class="flex flex-col bg-darkCard max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
            <div class="flex justify-between items-center w-full py-[15px] border-b border-blue">
                <span class="font-semibold text-xl text-blue">
                    Import your NFT
                </span>
                <button on:click={() => {importError = false; popUp = false;}}>
                    <img class="h-[20px] inline-block" src="/icons/x.png" alt="close icon"/>
                </button>
            </div>
            <span class="italic">Guide</span>
            <span class="italic font-base text-sm text-white">
                Check your address on 
                <button class="underline text-yellowButton" on:click={()=>{window.open(`${config.blockExplorerUrls}/address/${address}`, "_blank")}}>
                    ${config.chainName} Explorer
                </button> 
                and find the Contract and Token ID of your NFT
            </span>
            <!--Address-->
            <span class="text-lg font-bold text-blue mb-[10px] mt-[20px]">
                Contract Address
            </span>
            <input bind:value={addCollectionAddress} class="p-1 text-normal rounded-lg bg-grayInput px-2 font-normal mb-[10px] {!addCollectionAddress && importError == true?"border border-red-700":" "}" placeholder="Enter Contract Address"/>
            <!--Token id-->
            <span class="text-lg font-bold text-blue mb-[10px]">
                Token ID
            </span>
            <input bind:value={addCollectionID} class="p-1 text-normal rounded-lg bg-grayInput px-2 font-normal mb-[10px] {!addCollectionID && importError == true?"border border-red-700":" "}" placeholder="Enter Token ID"/>
            <button on:click={async() => {
                if(addCollectionAddress && addCollectionID){
                    await addNFTToLocalList(addCollectionAddress, addCollectionID);
                    popUp = false;
                } else ( importError = true)
            }
            } 
                class="flex items-center w-full bg-button hover:bg-buttonHover py-2 rounded-lg justify-center gap-1 mt-[10px]">
                <span class="text-xl text-white">
                    Import
                </span>
            </button>
            {#if importError}
                <span class="mt-[10px] text-red-700 self-center">
                    Contract Address and Token Id must be filled
                </span>
            {/if}
        </div>
    </div>
{/if}


<!--PopUp Done -->
{#if popupDone}
    <Done/>
{/if}

<!--PopUp Loading -->
{#if popupLoading}
    <Loading/>
{/if}
