<script>
    import { fly } from 'svelte/transition';
    import { fade } from 'svelte/transition'; 
    import Nav from "../../../Nav.svelte";
    import {roundNum} from '$lib/index.js';
    import { emitBetweenText } from '$lib/index.js';
    import {timeAgo} from '$lib/index.js';
    import { erc721ABI, erc721Bytecode, marketplaceAddress, marketplaceABI } from "$lib/contract.config.js";
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import { page } from '$app/stores';
    import { get } from "svelte/store";
    import { goto } from '$app/navigation';
    import config from "$lib/config.js";
    import Loading from "$lib/Loading.svelte";
    import Done from "$lib/Done.svelte";


    let isOfferTableClick = true;
    let isHistoryTableClick = false;

    const tokens = $page.url.pathname.split("/");
    const id = tokens.at(-1);
    const address = tokens.at(-2);

    // Royalty
    let royalty = 1;

    // Get NFT info
    let collectionName = "Loading collection...", tokenURI = "", metadata = { description: "Loading description..." }, owner = "", offers = [], price = "-1", lister = " ", topOffer = 0n;
    // More detailed NFT info
    let attributes = [];
    // User info
    let userAddress = "";
    // Page switches
    let popupSend = false;
    let popupList = false;
    let popupLoading = false;
    let popupDone = false;
    let popupChangePrice = false;
    let popupOffer = false;
    let popupOfferAccept = false;
    // Make functions callable from outside
    let sendNFT, listNFT, purchaseNFT, changePriceNFT, unlistNFT, offer, acceptOffer, removeOffer;
    // Inputs
    let addressInput = "", priceInput = "", changePriceInput = "";
    let isSold = false;
    
    let loading = true;

    let attributePoints = {}; // attribute type -> attribute -> amount
    let totalAttributePoints = {}; // attribute type -> amount
    let nftPoints = {};
    onMount(() => {
        let provider;
        let signer;
        let marketplace;


        (async () => {
            try {
                if (typeof window.ethereum !== 'undefined') {
                    const accounts = await window.ethereum.request({ 
                        method: 'eth_accounts'  // This checks for already connected accounts
                    });
                    
                    if (accounts.length > 0) {
                        provider = new ethers.providers.Web3Provider(window.ethereum);
                        signer = provider.getSigner();
                        userAddress = await signer.getAddress();
                        marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, signer);
                    } else {
                        // No wallet connected - set up read-only provider
                        provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                        marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
                    }
                } else {
                    // MetaMask not installed - set up read-only provider
                    provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                    marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
                }
            } catch (error) {
                console.log("Provider setup error:", error);
                // Fallback to read-only provider
                provider = new ethers.providers.JsonRpcProvider(config.ethRpcUrl);
                marketplace = new ethers.Contract(marketplaceAddress, marketplaceABI, provider);
            }
        })();

        
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
            }

			const { chainId } = await provider.getNetwork();

			// Only continue when network is correcr
            if (chainId !== parseInt(config.chainId)) throw new Error(`Network must be ${config.chainName}`);
		}

        (async function getRarity() {
            const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getRarityPoints",
					params: {
                        contract: address
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

                console.log(responseBody);
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
				}
			}
        })();

        (async function getNFTInfo() {
        	const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getNFTInfo",
					params: {
						address,
						id,
                        onchain: true,
					}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

			if (response.ok) {
				const responseBody = await response.json();

				const getResult = responseBody.payload;
                console.log(getResult, "getResult")
                //New
                tokenURI = getResult.tokenURI,
                metadata = getResult.metadata, 
                owner = getResult.owner,
                console.log(owner, "owner")
                price = getResult.price;
                lister = getResult.lister;
                isSold = getResult.isSold;
                collectionName = getResult.collectionName;
                


                for (const proposer in offers) {
                    if (typeof offers[proposer] === "string") {
                        if (BigInt(offers[proposer]) > topOffer) {
                            topOffer = BigInt(offers[proposer]);
                        }
                    } else if (typeof offers[proposer] === "object") {
                        if (BigInt(offers[proposer].price) > topOffer) {
                            topOffer = BigInt(offers[proposer].price);
                        }
                    }
                }

                // Flag to check if user's offer is already found
                let userMadeOffer = false;

                // Get a list of offers
                for (const offeror in getResult.offers) {
                    let price, date;

                    if (typeof getResult.offers[offeror] === "string") {
                        price = getResult.offers[offeror];
                    } else if (typeof getResult.offers[offeror] === "object") {
                        price = getResult.offers[offeror].price;
                        date = getResult.offers[offeror].date
                    }

                    offers.push({ price, date, from: offeror, lister, isSold });
                
                    if (offeror === userAddress) {
                        userMadeOffer = true;
                    }
                }

                // Check if user account has made an offer that the server has missed
                
                //Check offer in v2 contract
                if(!userMadeOffer){
                    try {
                        const offerAmount = await marketplace.offers(address, BigInt(id), userAddress);

                        if (offerAmount.toString() !== "0") {
                            offers.push({ price: offerAmount.toString(), from: userAddress, lister, isSold });
                            
                        }
                    } catch (e) {}
                }


                offers = offers.reverse();

                // Get a list of attributes
                if (Array.isArray(metadata.attributes)) {
                    for (const attribute of metadata.attributes) {
                        attributes.push({ attribute: attribute["trait_type"], value: attribute["value"] });
                    }
                }

                attributes = attributes;
            } else {
                loading = false;

				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
				}
            }

            loading = false;
		})();

        sendNFT = async function(receiver) {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;

            try {
                await walletHelper();

                const collectionContract = new ethers.Contract(address, erc721ABI, signer);

                const tx = await collectionContract["safeTransferFrom(address,address,uint256)"](userAddress, receiver, BigInt(id));

                await tx.wait();

                await recordTransfer(tx.hash);

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

        //recoreded send nfts
        async function recordTransfer(hash) {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "recordTransfer",
                    params: {
                        hash
                    }
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!response.ok) {
                // Fail
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);   
                }
            }
        }
        unlistNFT = async function() {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;

            try {
                await walletHelper();

                const tx = await marketplace.unlist(address, id);

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

        changePriceNFT = async function(price) {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;

            try {
                await walletHelper();

                const tx = await marketplace.changePrice(address, id, ethers.utils.parseEther(price));

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

        listNFT = async function(price) {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;

            try {
                await walletHelper();

                const nftContract = new ethers.Contract(address, erc721ABI, signer);

                const tx = await nftContract.approve(marketplace.address, id);

                await tx.wait();

                const tx2 = await marketplace.list(address, id, ethers.utils.parseEther(price));

                await tx2.wait();

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

        // Accept offer
        acceptOffer = async function(address, proposer, price, lister, isSold) {
            popupLoading = true;
            
            let offerAmount = await marketplace.offers(address, BigInt(id), proposer);
            console.log(offerAmount,marketplace.address, "offerAmount");
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

        /*removeOffer = async function(collectionAddress, id) {
            popupLoading = true;
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
        }*/

        removeOffer = async function(collectionAddress, id) {
            popupLoading = true;
            let offerAmount = await marketplace.offers(collectionAddress, BigInt(id), userAddress);
            
            console.log(userAddress,offerAmount,"asdassadas" )
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

        purchaseNFT = async function() {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;

            try {
                await walletHelper();

                const tx = await marketplace.buy(address, id, { value: BigInt(price) });

                await tx.wait();

                addNFTToLocalList(address, id);

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



        //Set offer
        offer = async function(collectionAddress, id, price) {
            popupLoading = true;
            popupSend = false;
            popupList = false;
            popupChangePrice = false;
            popupOffer = false;
            
            
            try {
                await walletHelper();

                const tx = await marketplace.offer(collectionAddress, id, { value: ethers.utils.parseEther(price) });

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

        function addNFTToLocalList(collectionAddress, id) {
            const nftList = JSON.parse(localStorage.nftList || "[]");

            let check = true;

            for (const nft of nftList) {
                // Prevent duplication
                if (nft.collectionAddress === collectionAddress && nft.id === id) {
                    check = false;
                    break;
                }
            }

            if (check) nftList.push({ collectionAddress, id });

            localStorage.nftList = JSON.stringify(nftList);
        }

        async function getListingInfo(collection, id) {
            try {
                isSold = await marketplace.sold(collection, id);
                lister = await marketplace.ownerOf(collection, id);
                price = (await marketplace.priceOf(collection, id)).toString();
            } catch (e) {}
        }
    });

    //item cctivities
    
    //collection activities
    let activities = [];

    async function getCollectionActivityPageIndex(collectionAddress) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getCollectionActivityPageIndex",
                params: {
                    collectionAddress
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            // Success
            const responseBody = await response.json();

            return responseBody.payload.nftPageIndex;
        } else {
            // Fail
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }
        }
    }

    async function getCollectionActivityPage(collectionAddress, pageIndex, filterOptions) {
        console.log(collectionAddress, pageIndex);

        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getCollectionActivityPage",
                params: {
                    collection: collectionAddress,
                    pageIndex,
                    filterOptions
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            // Success
            const responseBody = await response.json();

            console.log(responseBody.payload);

            return responseBody.payload.nftPage;
        } else {
            // Fail
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }
        }
    
    }

    async function getNFTActivities() {
        const nftPageIndex = await getCollectionActivityPageIndex(address);
        activities = [
            ...await getCollectionActivityPage(address, nftPageIndex, {
                ids: [ id ]
            })
        ].reverse();
    }

    //image load
    let imgLoad = true;

    //Bigint to Float
    function bigIntToFloat(number) {
        const natural = number / 10n ** 18n;
        const decimal = number % 10n ** 18n;

        return parseFloat(natural.toString() + "." + decimal.toString().padStart(18, "0"));
    }

    //error
    let errorFrontCode = "";
    setInterval(()=>{if(errorFrontCode != ""){errorFrontCode = ""}}, 2000);
</script>



<div class="flex bg-black w-full min-h-screen text-white">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <div class="flex flex-col">
            <Nav/>
            <!--Stick-->
            <div class ="grid md:grid-cols-2 grid-cols-1 mt-[30px] h-fit">
                <!--Img container-->
                <div class="parent md:sticky h-fit top-0 col-span-1 flex md:pr-[50px] items-start">
                    <div class="flex flex-col w-full overflow-hidden {imgLoad? "loading":""}">
                        <img src={`${config.rpcUrl}/cdn/nft/${address}/${id}/800/800`} 
                        class="object-contain shrink-on-hover w-full max-h-[680px] lg:min-h-[680px] md:min-h-[500px] min-h-[400px] min-h-[300px]"
                        on:load={()=>{imgLoad = false}} alt="banner"/>
                    </div>
                </div>
                <!--Detail containers-->
                <div class="flex  flex-col col-span-1 gap-[10px]">
                    <!--Item name-->
                    <span class="text-4xl font-bold text-blue ">
                        {collectionName} #{id}
                    </span>
                    <!---->
                    <div class="flex justify-between mt-[20px] text-lg  ">
                        <!--From collection-->
                        <div class="flex font-semibold items-center">
                            <span class="text-darkGray">from </span>
                            <button on:click={()=>{goto(`../../collections/${address}`)}} class="pl-2 pr-1">{collectionName}</button>
                            <img class="h-4 inline-block" src="/icons/verified.svg" alt="verified icon"/>
                        </div>
                        <!--From address-->
                        <span class="font-semibold">
                            <span class="text-darkGray">owner: </span>
                            {#if owner === userAddress || (lister === userAddress && !isSold)}
                                <span class="text-blue">you</span>
                            {:else}
                                <button class="pl-2 underline" on:click={()=> goto(`../../${price === "-1" || isSold ? owner : lister}`)}>
                                    { emitBetweenText(price === "-1" || isSold ? owner : lister, 10) }
                                </button>
                            {/if}   
                        </span>
                    </div>
                    <!--Price container-->
                    <div class={`flex flex-col text-white border rounded-lg px-[15px] py-[15px] gap-[15px] ${loading ? "loading" : ""}`}>
                        <span class="font-thin text-darkGray">Price</span>
                        <div class="flex items-center gap-[10px] pb-[10px]">
                            <img class="h-[50px]" src="/icons/ETN.png" alt="coin icon"/>
                            <!--display price -->
                            <!--Only display old value of NFT for ther owner-->
 
                            {#if (price === "-1" || isSold )}
                                <!--Price value-->
                                <span class="text-4xl font-bold text-darkGray">
                                    {loading ? "Loading price..." : "Unlisted"} 
                                 </span>

                            {:else}
                                <!--Price value-->
                                <span class="text-4xl font-bold">
                                    { bigIntToFloat(BigInt(price)) } 
                                </span>
                            {/if}
                        </div>


                        <!--Button container-->
                        {#if !isSold && price !== "-1" && userAddress !== lister}
                            <div class="flex gap-[10px] items-center text-2xl font-semibold my-[5px]">
                                <button on:click={() => purchaseNFT()} class="py-[10px] flex flex-grow bg-darkGreen hover:bg-greenHover rounded-xl justify-center parent">
                                    <span class="shrink-on-hover">Purchase</span>
                                </button>
                                <button class="py-[10px]  flex items-center px-[15px] gap-[5px] text-white rounded-xl parent border-[2px] hover:bg-yellowHover border-yellowHover px-[30px] "
                                on:click={() => {popupOffer = true }}>
                                    <span class="shrink-on-hover">Offer</span>
                                </button>
                            </div>
                        <!--When you own this NFT and havent list-->
                        {:else if (isSold || price === "-1") && userAddress === owner}
                            <div class="flex gap-[10px] items-center text-2xl font-semibold my-[5px]">
                                <button on:click={() => { popupList = true; }} class="py-[10px] flex flex-grow bg-darkGreen hover:bg-greenHover rounded-xl justify-center parent">
                                    <span class="shrink-on-hover">List for sale</span>
                                </button>
                                <button on:click={() => { popupSend = true; }} class="py-[10px]  flex bg-yellowButton hover:bg-yellowHover px-[30px] rounded-xl parent">
                                    <span class="shrink-on-hover">Send NFT</span>
                                </button>
                                <!--<button class="py-[10px]  flex items-center px-[15px] gap-[5px] text-darkGray border-2 rounded-xl border-darkGray parent ">
                                    <span class="shrink-on-hover">Add</span>
                                    <img class="h-[30px] inline-block shrink-on-hover" src="/icons/shopCart.svg" alt="verified"/>
                                </button>-->
                            </div>
                        <!--When you own and list this NFT-->
                        {:else if !isSold && userAddress === lister}
                            <div class="flex gap-[10px] items-center text-2xl font-semibold my-[5px]">
                                <button on:click={() => { popupChangePrice = true; }} class="py-[10px] flex flex-grow bg-darkGreen hover:bg-greenHover rounded-xl justify-center parent">
                                    <span class="shrink-on-hover">Change price</span>
                                </button>
                                <button on:click={() => { unlistNFT(); }} class="py-[10px]  flex bg-red-700 hover:bg-red-800 px-[30px] rounded-xl parent">
                                    <span class="shrink-on-hover">Unlist</span>
                                </button>
                            </div>
                        {:else if !(owner === userAddress || (lister === userAddress && !isSold)) && loading === false}
                            <div class="flex gap-[10px] items-center text-2xl font-semibold my-[5px]">
                                <button on:click={() => {popupOffer = true }} class="py-[10px]  flex flex-grow bg-yellowButton hover:bg-yellowHover px-[30px] rounded-xl justify-center parent">
                                    <span class="shrink-on-hover">Offer</span>
                                </button>
                            </div>
                        {:else if loading === true}
                            <div class="flex gap-[10px] items-center text-2xl font-semibold my-[5px]">
                                <button class="py-[10px]  flex flex-grow loading px-[30px] rounded-xl justify-center parent">
                                    <span class="shrink-on-hover py-4">
                                        
                                    </span>
                                </button>
                            </div>
                        {/if}
                    </div>

                    <!--Description container-->
                    {#if metadata.description}
                        <div class="flex flex-col gap-[5px] my-[20px]">
                            <span class="text-lg font-semibold text-blue">
                                Description
                            </span>
                            <!--Description-->
                            <span>
                                {metadata.description}
                            </span>
                        </div>
                    {/if}
                    <!--Attribute + Rarity container-->
                    <div class={`flex flex-col border-y font-semibold gap-[20px] py-[20px] ${loading ? "loading" : ""}`}>
                        <!--Rarity container-->
                        {#if nftPoints[id] }
                            <span class="text-lg font-normal">
                            <span class="text-darkGray">Rarity Score:</span>
                            <span>{ nftPoints[id] || "Loading" }</span>
                            </span>
                        {/if}

                        <div class="flex flex-wrap justify-between gap-[20px] mr-[20px]">
                            {#each attributes as attribute}
                                <!--Attribute container-->
                                <div class="flex flex-col border border-grayBorder max-w-[330px] min-w-[330px] p-2 rounded-xl">
                                    <span class="font-medium text-darkGray ">
                                        {attribute.attribute}
                                    </span>
                                    <div class="flex justify-between mt-[2px]">
                                        <span>{attribute.value}</span>
                                        <span class="mt-[2px] font-medium text-darkGray">
                                            {
                                                attributePoints[attribute.attribute] ? attributePoints[attribute.attribute][attribute.value] : "-"
                                            }/{
                                                totalAttributePoints[attribute.attribute] || "-"
                                            }
                                        </span>
                                    </div>

                                </div>
                            {/each}
                        </div>
                    </div>
                    <!--Info-->
                    <!--Info Header-->
                    <span class="text-lg font-semibold text-blue mt-[10px]">
                        Information
                    </span>
                    <!--Info Container-->
                    <div class="flex flex-col pt-[10px] pb-[25px] font-semibold gap-[10px] rounded-lg"> 
                        <div class="flex justify-between">
                            <span class="text-darkGray font-medium">Royalties</span>
                            <span>{royalty}%</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="text-darkGray font-medium">Contract address</span>
                            <button class="underline" on:click={()=>{window.open(`${config.blockExplorerUrls}/address/${address}`, "_blank")}}>
                                {emitBetweenText(address, 10)}
                            </button>
                        </div>
                        <div class="flex justify-between">
                            <span class="text-darkGray font-medium">Blockchain</span>
                            <span>{config.chainName}</span>
                        </div>
                    </div>
                </div>
            </div>
            <!--Table container-->
            <div class="flex flex-col mt-[30px] mb-[80px]">
                <!--Table button-->
                <div class="flex font-semibold gap-[10px] mb-[10px]">
                    <button class="py-1 px-4 {isOfferTableClick?"bg-buttonHover text-white":""} rounded-lg"
                    on:click={()=>{isOfferTableClick = true;isHistoryTableClick = false }}>
                        Offers
                    </button>
                    <button class="py-1 px-4  {isHistoryTableClick?"bg-buttonHover text-white":""} rounded-lg"
                    on:click={()=>{isHistoryTableClick = true;isOfferTableClick = false; getNFTActivities()}}>
                        History
                    </button>
                </div>
                <!--Offer Table-->
                {#if isOfferTableClick}
                    {#if offers.length === 0}
                        <div class="flex flex-col rounded-md text-left bg-darkCard shadow-md w-full py-[15px] lg:px-12 px-4 text-white">
                            <span class="text-md text-darkGray">
                                No offer has been made yet
                            </span>
                        </div>
                    {:else}
                        <div class="flex flex-col rounded-md text-left bg-darkCard shadow-md w-full py-[15px] sm:px-12 px-4">
                            <!--Header-->
                            <div class="sm:flex hidden text-darkGray text-base pb-[12px] w-full border-darkGray" >
                                <div class="rounded-tr-sm  w-[30%]">Price</div>
                                <div class="rounded-tr-sm   w-[30%]">From</div>
                                <div class="rounded-tr-sm  w-[30%]">Date</div>
                                <div class="rounded-tr-sm  w-[10%]"></div>
                            </div>
                            <!--Body-->
                            <div class="rounded-b-sm">
                                <!--Row-->
                                {#each offers as offer}
                                    <div class="flex sm:items-center hover:text-blue py-[15px] border-darkGray">
                                        <div class="flex sm:flex-row flex-col sm:items-center w-[60%]   sm:gap-0 gap-4">
                                            <!--Price-->
                                            <div class=" w-[45%] ">
                                                <div class="flex items-center">
                                                    <img class="sm:h-[25px] h-[30px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                    <!--Offer value-->
                                                    <span class="text-lg font-semibold text-inherit">
                                                        { bigIntToFloat(BigInt(offer.price)) }
                                                    </span>
                                                </div>
                                            </div>
                                            <!--From Address-->
                                            <button class="flex  w-[45%] underline text-inherit" on:click={()=> goto(`../../${offer.from}`)}>
                                                {emitBetweenText(offer.from, 10)}
                                            </button>
                                        </div>
                                        <div class="flex sm:flex-row flex-col sm:items-center sm:w-[40%]  sm:gap-0 gap-2">
                                            <!--Date Offer-->
                                            <div class="  sm:w-[67%] sm:order-1 order-2 text-inherit">
                                                {offer.date ? timeAgo(offer.date) : "Offer on ver 1"}
                                            </div>
                                            <!--Button-->
                                            {#if owner === userAddress || (lister === userAddress && !isSold)}
                                                <button on:click={() => acceptOffer(address, offer.from, BigInt(offer.price), offer.lister, offer.isSold) } class="bg-darkGreen p-2 font-semibold rounded-lg sm:w-[33%] sm:order-2 order-1 text-white hover:bg-greenHover">
                                                    Accept
                                                </button>
                                            {:else if offer.from === userAddress}
                                                <button on:click={() => removeOffer(address, BigInt(id)) } class="bg-red-700 p-2 font-semibold rounded-lg sm:w-[33%] sm:order-2 order-1 text-white hover:bg-buttonHover">
                                                    Decline
                                                </button>
                                            {/if}
                                        </div>
                                    </div>
                                {/each}
                                
                            </div>
                        </div>
                    {/if}
                    
                {/if}
                <!--History Table-->
                {#if isHistoryTableClick}
                    {#if activities.length === 0}
                        <div class="flex flex-col rounded-md text-left bg-darkCard shadow-md w-full py-[15px] lg:px-12 px-4 text-white">
                            <span class="text-md text-darkGray">
                                There is no activity
                            </span>
                        </div>
                    {:else}
                    <div class="flex flex-col rounded-md text-left bg-darkCard shadow-md w-full py-[15px] md:px-12 px-2">
                        <!--Header-->
                        <div class="flex text-darkGray md:text-base text-xs pb-[12px] w-full  border-darkGray" >
                            <div class="rounded-tl-sm sm:w-[15%] w-[30%]">Event</div>
                            <div class="rounded-tr-sm md:ml-[21px] sm:w-[25%] w-[40%]">Price</div>
                            <div class="rounded-tr-sm sm:w-[20%] w-[30%]">From</div>
                            <div class="rounded-tr-sm sm:w-[20%] sm:flex hidden">To  </div>
                            <div class="rounded-tr-sm w-[20%] sm:flex hidden">Date</div>
                        </div>
                        <!--Body-->
                        {#each activities as activity}
                            <div class="rounded-b-sm my-1">
                                <!--Row-->
                                <div class="flex items-center hover:text-sea pt-[15px] md:text-base text-xs">
                                    <!--Event-->
                                    <div class="font-semibold sm:w-[15%] w-[30%]">
                                        {#if activity.type === "transfer"}
                                            <img class="h-[18px]  inline-block mr-[5px]" src="/icons/transfer.svg" alt="transfer NFT icon"/>
                                        {:else if activity.type === "list"}
                                            <img class="sm:h-[18px] h-[15px]  inline-block mr-[5px]" src="/icons/listing.svg" alt="listing NFT icon"/>
                                        {:else if activity.type === "unlist"}
                                            <img class="sm:h-[18px] h-[15px] inline-block mr-[5px]" src="/icons/unlist.svg" alt="unlist NFT icon"/>
                                        {:else if activity.type === "sale"}
                                            <img class="sm:h-[18px] h-[15px] inline-block mr-[5px]" src="/icons/sale.svg" alt="sale NFT icon"/>
                                        {:else if activity.type === "mint"}
                                            <img class="sm:h-[18px] h-[15px] inline-block mr-[5px]" src="/icons/mint.svg" alt="mint NFT icon"/>
                                        {/if}
                                    </div>
                                    <!--Price-->
                                    <div class=" sm:w-[25%] w-[40%]">
                                        <div class="flex items-center">
                                            <img class="h-[25px] inline-block md:ml-[21px] mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                            <!--Offer value-->
                                            <span class=" font-semibold">
                                                {roundNum(bigIntToFloat(BigInt(activity.price)),5)} 
                                            </span>
                                        </div>
                                    </div>
                                    <!--From Address-->
                                    <button class=" flex sm:w-[20%] w-[30%] underline" on:click={()=> goto(`../../${activity.from}`)}>
                                        {emitBetweenText(activity.from, 10)}
                                    </button>
                                    <!--To Address-->
                                    <button class=" w-[20%] underline sm:flex hidden" on:click={()=> goto(`../../${activity.to}`)}>
                                        {emitBetweenText(activity.to, 10)}
                                    </button>
                                    <!--Date Offer-->
                                    <div class="  w-[20%] sm:flex hidden">
                                        {timeAgo(activity.date)} 
                                    </div>
                                </div>
                            </div>
                        {/each}
                    </div>
                    {/if}
                {/if}
            </div>
            
            <!--Popup-->
            <!--PopUp Send NFT-->
            {#if popupSend}
                <div class="fixed font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-40 text-darkGray " in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                    <div class="flex flex-col bg-darkCard max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
                        <div class="flex justify-between items-center w-full py-[15px] border-b border-darkGray">
                            <span class="font-semibold text-xl">
                                Send NFTs
                            </span>
                            <button on:click={()=>{popupSend = false}}>
                                <img class="h-[20px] inline-block" src="/icons/x.png" alt="close icon"/>
                            </button>
                        </div>
                        <!--Item name-->
                        <span class="text-xl font-bold text-blue my-[10px]">
                            {collectionName} #{id}
                        </span>
                        <span class="text-sm font-thin mb-[5px] ml-2">
                            to Address
                        </span>
                        <input bind:value={addressInput} class="p-1 text-lg rounded-lg bg-grayInput px-2 font-thin mb-[10px] border" placeholder="Enter address"/>
                        <button on:click={() => sendNFT(addressInput)} class="flex items-center w-full bg-blue hover:bg-buttonHover py-1 rounded-lg justify-center gap-1">
                            <span class="text-xl text-white">
                                Send
                            </span>
                        </button>
                    </div>
                </div>
            {/if}
            <!--PopUp Offer-->
            {#if popupOffer}
                <div class="fixed font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-40 text-darkGray " in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                    <div class="flex flex-col bg-darkCard max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
                        <div class="flex justify-between items-center w-full py-[15px] border-b border-grayBorder">
                            <span class="font-semibold text-xl text-blue">
                                Offer
                            </span>
                            <button on:click={()=>{popupOffer = false}}>
                                <img class="h-[20px] inline-block" src="/icons/x.png" alt="close icon"/>
                            </button>
                        </div>
                        <!--Item name-->
                        <span class="text-xl font-bold text-blue my-[10px]">
                            {collectionName} #{id}
                        </span>
                        <span class="text-sm font-thin mb-[5px] ml-2">
                            Price
                        </span>
                        <div class="flex items-center gap-1 rounded-lg border border-grayBorder bg-white pl-2">
                            <img class="h-[28px] inline-block mb-[2px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                            <input bind:value={priceInput} class="py-[5px] flex-grow text-lg  px-2 rounded-lg bg-white" placeholder="Price"/>
                        </div>
                        
                        <button on:click={() => offer(address, id, priceInput)}  class="flex items-center w-full bg-button hover:bg-buttonHover py-1 rounded-lg justify-center gap-1 mt-[10px] ">
                            <span class="text-xl text-white py-1">
                                Set offer
                            </span>
                        </button>
                    </div>
                </div>                
            {/if}
            <!--PopUp List NFT-->
            {#if popupList}
                <div class="fixed font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-40 text-darkGray " in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                    <div class="flex flex-col bg-darkCard max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
                        <div class="flex justify-between items-center w-full py-[15px] border-b border-darkGray">
                            <span class="font-semibold text-xl text-blue">
                                List
                            </span>
                            <button on:click={()=>{popupList = false}}>
                                <img class="h-[20px] inline-block" src="/icons/x.png" alt="close button"/>
                            </button>
                        </div>
                        <!--Item name-->
                        <span class="text-xl font-bold text-blue my-[10px]">
                            {collectionName} #{id}
                        </span>
                        <span class="text-sm font-thin mb-[5px] ml-2">
                            Price
                        </span>
                        <div class="flex items-center gap-1 rounded-lg bg-grayInput pl-2">
                            <img class="h-[28px] inline-block mb-[2px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                            <input bind:value={priceInput} class="p-1 flex-grow text-lg  px-2 rounded-lg bg-grayInput font-thin" placeholder="Set price"/>
                        </div>
                        
                        <button on:click={() => listNFT(priceInput)} class="flex items-center w-full bg-button hover:bg-buttonHover py-2 rounded-lg justify-center gap-1 mt-[10px]">
                            <span class="text-xl text-white">
                                Confirm
                            </span>
                        </button>
                    </div>
                </div>
            {/if}
            <!--PopUp Change Price-->
            {#if popupChangePrice}
            <div class="fixed font-semibold flex flex-col inset-0 bg-black bg-opacity-60 z-40 text-blue " in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                <div class="flex flex-col bg-darkCard max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
                    <div class="flex justify-between items-center w-full py-[15px] border-b border-darkGray">
                        <span class="font-semibold text-xl">
                            Change price
                        </span>
                        <button on:click={()=>{popupChangePrice = false}}>
                            <img class="h-[20px] inline-block" src="/icons/x.png" alt="close button"/>
                        </button>
                    </div>
                    <!--Item name-->
                    <span class="text-xl font-bold text-blue my-[10px]">
                        {collectionName} #{id}
                    </span>
                    <span class="text-sm font-thin mb-[5px] ml-2 text-white">
                        Price
                    </span>
                    <div class="flex items-center gap-1 rounded-lg bg-grayInput pl-2">
                        <img class="h-[28px] inline-block mb-[2px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                        <input bind:value={changePriceInput} class="p-1 flex-grow text-lg  px-2 rounded-lg bg-grayInput font-thin" placeholder="Set price"/>
                    </div>
                    
                    <button on:click={() => changePriceNFT(changePriceInput)} class="flex items-center w-full bg-button hover:bg-buttonHover py-1 rounded-lg justify-center gap-1 mt-[10px]">
                        <span class="text-xl text-white py-1">
                            Confirm
                        </span>
                    </button>
                </div>
            </div>
            {/if}
            <!--PopUp Loading -->
            {#if popupLoading}
                <Loading/>
            {/if}
            <!--PopUp Done -->
            {#if popupDone}
                <Done/>
            {/if}
            <!--PopUp Offer Accept -->
            {#if popupOfferAccept}
                <div class="fixed font-semibold flex flex-col inset-0 bg-white bg-opacity-60 z-40 text-white " in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                    <div class="flex flex-col bg-darkCard shadow-md max-w-[500px] min-w-[500px] pt-2 pb-6 px-4 mx-auto my-auto rounded-lg">
                        <div class="flex justify-between items-center w-full py-[15px] border-b border-darkGray">
                            <span class="font-semibold text-xl text-blue">
                                Accept offer
                            </span>
                            <button on:click={()=>{popupOfferAccept = false}}>
                                <img class="h-[20px] inline-block" src="/icons/x.png" alt="close icon"/>
                            </button>
                        </div>
                        <!--Item name-->
                        <span class="text-xl font-bold text-blue my-[10px]">
                            {collectionName} #{id}
                        </span>

                        <div class="flex items-center gap-1 text-2xl mb-[10px]">
                            <span>0.05</span>
                            <img class="h-[28px] inline-block mb-[6px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                            
                        </div>
                        <!--address making offers Container-->
                        <div class=" mb-[5px] gap-[10px] text-lightGray">
                            <span class="font-normal">
                                    From:
                            </span>
                            <!--Example address making offers-->
                            <button class=" underline">
                                0x8ASD...2232
                            </button> 
                            </div>
                        
                        <button class="flex items-center w-full bg-blue hover:bg-buttonHover py-1 rounded-lg justify-center gap-1 mt-[10px] ">
                            <span class="text-xl text-white">
                                Set offer
                            </span>
                        </button>
                    </div>
                </div>                
            {/if}
        </div>
    </div>
</div>

{#if errorFrontCode !=""}
    <!--Pop up Insufficient fund error-->
    <div class="fixed bottom-5 right-10 flex items-center gap-[5px] pl-2 z-10 bg-red-500 w-[300px] h-[50px] rounded-md shadow-md" in:fly={{ duration: 500, x: 300 }} out:fly={{ duration: 500, x: 300 }}>
        <img class="h-[20px]" src="/icons/warning.svg" alt="warning icon"/>
        <span class="font-semibold text-white">
            {#if errorFrontCode == "-32603"}
                Insufficient fund
            {:else if errorFrontCode == "ACTION_REJECTED"}
                Rejected by user
            {:else}
                Fail
            {/if}
        </span>
    </div>
{/if}