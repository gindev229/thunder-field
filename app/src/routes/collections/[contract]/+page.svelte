<script>
    import Seo from '$lib/Seo.svelte';
    import { slide } from 'svelte/transition';
    import Nav from "../../Nav.svelte";
    import {roundNum} from '$lib/index.js';
    import { emitBetweenText } from '$lib/index.js';
    import {timeAgo} from '$lib/index.js';
    // import { erc721ABI, erc721Bytecode, marketplaceAddress, marketplaceABI } from "$lib/contract.config.js";
    import { onMount } from 'svelte';
    // import { ethers } from "ethers";
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import config from "$lib/config.js";

    //let items=[{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}];
    let items = [], nftIds = [], errorNFTs = {};
    let nftPoints = {};
    let attributes = {};
    let queryAttributes = {};
    let attributeCheckBoxes = {};
    let filterAttributes = {};
    let filterPrice = false;
    let filterSideBar = false;
    let nftInfoCache = {};
    let sortBy = "";

    const tokens = $page.url.pathname.split("/");
    const address = tokens.at(-1);

    let collectionName = "Loading name...", volume = "", floorPrice = "0", description = "";

    let loading = true, current = 0, done = false, queryloading = true;

    let websiteLink, twitterLink, discordLink, telegramLink;

    onMount(async () => {
        (async function getCollectionInfo() {
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
                volume = responseBody.payload.volume;
                floorPrice = responseBody.payload.floorPrice;
                collectionName = responseBody.payload.name;
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
                }
			}
		})();

        (async function getNFTDescription() {
            let { metadata } = await getNFTInfo(address, "1", [ "listingDetails", "owner", "collectionName", "offers" ]);
            description = metadata.description;
        })();

        (async function getLinks() {
            const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getLinks",
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

                websiteLink = responseBody.payload.website;
                twitterLink = responseBody.payload.twitter;
                discordLink = responseBody.payload.discord;
                telegramLink = responseBody.payload.telegram;

                // console.log(responseBody);
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
                }
			}
        })();

        (async function loadNFTIds() {
            nftIds = await queryNFTs(address, {}, true);

            queryloading = false;

            loadNFTs(); // Initial load
        })();

        (async function getAllAttributes(address) {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getAllAttributes",
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

                const attributeMap = responseBody.payload.attributeMap;

                attributes = attributeMap;

                for (const attribute in attributeMap) {
                    attributeCheckBoxes[attribute] = {};

                    for (const value in attributeMap[attribute]) {
                        attributeCheckBoxes[attribute][value] = false;
                    }
                }

                // console.log(attributes);
            } else {
                // Fail
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);   
                }
            }
        })(address);

        // Get rarity
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

                //attributePoints = responseBody.payload.attributePoints;
                //totalAttributePoints = responseBody.payload.totalAttributePoints;
                nftPoints = responseBody.payload.nftPoints;

                //console.log(responseBody);
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
				}
			}
        })();

        //Call 18 NFTS
        window.addEventListener("scroll", () => {
            if (pagenition === "activity") {
                if ((window.innerHeight + window.scrollY + 300) >= document.body.offsetHeight && !activityLoading && activitiesRendered) {
                    activityLoading = true;
                    activities.push(...activitiesInfos.slice(currentActivity, currentActivity + 18));
                    activities = activities;
                    currentActivity += 18;
                    activityLoading = false;
                }
            } else if (pagenition === "items") {
                // console.log(!loading, !done, (window.innerHeight + window.scrollY + 100), document.body.offsetHeight);

                if ((window.innerHeight + window.scrollY + 300) >= document.body.offsetHeight && !loading && !done) {
                    loadNFTs();
                }
            }
        });
    });

    //collection activities
    let activities = [], activitiesInfos = [], currentActivity = 0, activityLoading = false, activitiesRendered = false;

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

    async function getCollectionActivityPage(collectionAddress, pageIndex) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getCollectionActivityPage",
                params: {
                    collection: collectionAddress,
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

            return responseBody.payload.nftPage;
        } else {
            // Fail
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }
        }
    }

    async function getCollectionActivities() {
        const nftPageIndex = await getCollectionActivityPageIndex(address);
        activitiesInfos = [ ...await getCollectionActivityPage(address, nftPageIndex) ].reverse();
        activityLoading = true;
        activities.push(...activitiesInfos.slice(currentActivity, currentActivity + 18));
        activities = activities;
        currentActivity += 18;
        activityLoading = false;
        activitiesRendered = true;
    }

    // Query NFTs with attributes
    async function queryNFTs(address, attributes, noExtra = false) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "queryNFTs",
                params: {
                    address,
                    attributes,
                    sortBy,
                    noExtra
                }
            }),
            headers: {
                "Content-Type": "application/json"
            }
        });

        if (response.ok) {
            // Success
            const responseBody = await response.json();

            // console.log(responseBody.payload.nftIds);

            //console.log(responseBody.payload.nftIds);

            return responseBody.payload.nftIds;
        } else {
            // Fail
            const responseBody = await response.json();

            if (responseBody.error && responseBody.error.message) {
                throw new Error(responseBody.error.message);   
            }
        }
    }

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

    async function getNFTsInfo(address, ids, exclude) {
        const response = await fetch(config.rpcUrl, {
            method: "POST",
            body: JSON.stringify({
                method: "getNFTsInfo",
                params: {
                    address,
                    ids,
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

    function reducedNFTName(collection, id) {
        if (`${collection} #${id}`.length > 28) {
            return `${collection.substr(0, collection.length-3-(`${collection} #${id}`.length-28))}... #${id}`
        } else {
            return `${collection} #${id}`;
        }
    }

    /*async function loadNFTs() {
        // console.log("nft ids used", nftIds);
        // console.log("current used", current);

        loading = true;

        const ids = [];

        for (let index = current; index < current + 18; index++) {
            const id = nftIds[index];

            ids.push(id);            
        }

        try {
            if (nftInfoCache[id]) {
                items.push(nftInfoCache[id]);
            } else {
                let { offers, price, lister, isSold } = await getNFTsInfo(address, id.toString(), [ "metadata", "owner", "collectionName", "offers" ]);

                // description = metadata.description;

                const nftInfo = {
                    offers, 
                    price, 
                    lister, 
                    collection: address, 
                    id: id.toString(),
                    isSold
                };

                items.push(nftInfo);

                nftInfoCache[id] = nftInfo;
            }
        } catch (e) {
            // console.log(e);
            done = true;
            loading = false;
        }

        loading = false;
        items = items;
        current += 18;

        // console.log("items", items);
    }*/

    async function loadNFTs(a) {
        // console.log("nft ids used", nftIds);
        // console.log("current used", current);

        loading = true;

        const ids = [];

        //console.log(a, nftIds);

        for (let index = current; index < current + 18; index++) {
            const id = nftIds[index];

            ids.push(id);            
        }

        try {
            const curatedIds = ids.filter(id => typeof id !== "undefined" && id !== null);

            if (curatedIds.length !== ids.length) { done = true; }

            const nftInfos = (await getNFTsInfo(address, curatedIds, [ "metadata", "owner", "collectionName", "offers" ])).nftInfos;

            const newNfts = nftInfos.map(nft => ({ ...nft, id: nft.id }));

            items = [ ...items, ...newNfts ];
        } catch (e) {
            console.log(e);
            done = true;
            loading = false;
        }

        loading = false;
        current += 18;

        // console.log("items", items);
    }

    function bigIntToFloat(number) {
        const natural = number / 10n ** 18n;
        const decimal = number % 10n ** 18n;

        return parseFloat(natural.toString() + "." + decimal.toString().padStart(18, "0"));
    }

    let loadingItems = [{},{},{},{},{},{},{},{},{},{},{},{}]
    let pagenition = "items";

    let imgLoad = true;
    let imgItemLoad = true;


    let priceFilter = "Unsorted";
    let dropdownPriceFilterClicked = false;
</script>

<div class="flex font-Hoves bg-black w-full min-h-screen">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <div class="flex flex-col">
            <Nav/>
            
            <!--Banner container-->
            <div class="flex relative sm:h-[330px] h-[320px] overflow-hidden text-white">
                <img class="w-full object-cover h-full bg-black" src={`${config.rpcUrl}/banner/${address}`} alt ="Collection Banner"/>
                <div class="absolute flex items-start h-full w-full bottom-0">
                    <!--Collections Info container-->
                    <div class="flex flex-col pl-[20px] h-full sm:w-[600px] bg-gradient-black-fade w-full gap-[10px] shadow-lg rounded-b-lg">
                        <div class="flex justify-between mt-[10px]">
                            <!--Ava container-->
                            <div class=" flex sm:h-[125px] h-[75px] sm:w-[125px] w-[75px] overflow-hidden rounded rounded-full border-[6px] border-white z-10">
                                <img class="w-full object-cover h-full" src={`${config.rpcUrl}/logo/${address}/200/200`} alt="NFT avatar"/>
                            </div>
                        </div>

                        <!--Collection name container-->
                        <div class="flex items-center gap-[10px]">
                            <!--Collection name-->
                            <p class="text-2xl text-blue font-semibold">
                                {collectionName}
                            </p>
                            <img class="sm:h-[25px] h-[18px] mb-1 inline-block" src="/icons/verified.svg" alt="verified icon" />
                        </div>


                        <!--Collection Description-->
                        <p class="">
                            {description || ""}
                        </p>
                        <div class="flex justify-start self-start gap-[25px] rounded-l-xl">
                            <button on:click={() => { window.open(websiteLink, "_blank") }}>
                                <img class=" h-[20px] inline-block" alt="website" src="/icons/weblink.svg"/>
                            </button>
                            <button on:click={() => { window.open(twitterLink, "_blank") }}>
                                <img class=" h-[20px] inline-block" alt="Twitter"  src="/icons/twitterX.svg"/>
                            </button>
                            <button on:click={() => { window.open(discordLink, "_blank") }}>
                                <img class=" h-[20px] inline-block" alt="Discord"  src="/icons/discord.svg"/>
                            </button>
                        </div>

                        <!--Collection stats-->
                        <div class="flex mt-[10px] md:gap-[100px] sm:gap-[50px] gap-[15px] justify-start sm:mr-[50px] mr-[10px]">
                            <!--Floor price-->
                            <div class="flex flex-col gap-[5px]">
                                <span class=" text-lightGray sm:text-base text-sm">Floor price</span>
                                <div class="flex items-center sm:gap-[10px] gap-[5px]">
                                    <img class="h-[20px]  inline-block" alt="coin icon" src="/icons/ETN.png"/>
                                    <!--Price-->
                                    <span class="sm:text-base text-sm font-semibold  ">
                                        {bigIntToFloat(BigInt(floorPrice))}
                                    </span>
                                </div>
                            </div>
                            <!--Total Volume-->
                            <div class="flex flex-col gap-[5px]">
                                <span class="sm:text-base text-sm text-lightGray">Total Volume</span>
                                <div class="flex items-center sm:gap-[10px] gap-[5px]">
                                    <img class="h-[20px] inline-block" src="/icons/ETN.png" alt="coin icon"/>
                                    <!--Volume-->
                                    {#if volume == ""}
                                        <span class="sm:text-base text-sm font-semibold  ">
                                            Loading
                                        </span>
                                    {:else}
                                        <span class="sm:text-base text-sm font-semibold ">
                                            {(bigIntToFloat(BigInt(volume))).toFixed(5)}
                                        </span>
                                    {/if }
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!--PC Filter-->
            <div class="flex sm:justify-between items-center">
                <!--Rarity Filter-->
                <div class="sm:flex hidden md:gap-[20px] gap-[10px]">
                    <button class=" h-fit py-[10px]  px-[10px] bg-lightBg rounded-xl hover:fill-blue fill-black shadow-md"
                    on:click ={()=>{filterSideBar =! filterSideBar}}>
                        <svg class="sm:h-[20px] h-[15px] fill-inherit" viewBox="0 0 45 30" xmlns="http://www.w3.org/2000/svg">
                            <path class="fill-inherit" fill-rule="evenodd" clip-rule="evenodd" d="M0 2.5C0 1.1193 1.1193 0 2.5 0H42.5C43.8807 0 45 1.1193 45 2.5C45 3.8807 43.8807 5 42.5 5H2.5C1.1193 5 0 3.8807 0 2.5ZM7.5 15C7.5 13.6193 8.6193 12.5 10 12.5H35C36.3807 12.5 37.5 13.6193 37.5 15C37.5 16.3807 36.3807 17.5 35 17.5H10C8.6193 17.5 7.5 16.3807 7.5 15ZM15 27.5C15 26.1193 16.1193 25 17.5 25H27.5C28.8807 25 30 26.1193 30 27.5C30 28.8807 28.8807 30 27.5 30H17.5C16.1193 30 15 28.8807 15 27.5Z" />
                        </svg>          
                    </button>
                </div>
                 <!--Pagnition-->
                <div class="flex gap-[10px] my-[20px] font-semibold text-lg">
                    
                    <button class="py-1 px-[25px] {pagenition === "items"?"bg-blue rounded-md text-white":"text-blue"}" on:click={()=>{pagenition = "items"}}>
                        Items
                    </button>
                    <button class="py-1 px-[25px] {pagenition === "activity"?"bg-blue rounded-md text-white":"text-blue"}  rounded-md" 
                    on:click={()=>{pagenition = "activity";getCollectionActivities()}}>
                        Activity
                    </button>
                </div>
                <!--Dropdown price-->
                <div class="sm:flex hidden relative justify-between items-center rounded-xl shadow-md text-base">
                    <button class="flex z-20 justify-between items-center py-[10px] px-[18px] gap-[20px] bg-white rounded-xl shadow-md text-base"
                    on:click={()=>{dropdownPriceFilterClicked =! dropdownPriceFilterClicked}}>
                        <span>{priceFilter}</span>
                        <img class="h-[10px]" src="/icons/dropdown.svg" alt="dropdown"/>
                    </button>
                    {#if dropdownPriceFilterClicked}
                        <div class="flex flex-col right-0 z-10 border border-blue absolute min-w-[140px] gap-[10px] py-[10px] {Object.keys(nftPoints).length !== 0? "mt-[200px]" : "mt-[150px]"}  pl-[10px] bg-white rounded-md shadow-lg text-base font-semibold" in:slide={{ duration: 300, y: 100 }} out:slide={{ duration: 300, y: 300 }}>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "price-high-to-low";
                                priceFilter = "Highest price";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;

                                await loadNFTs("a");
                            }}>
                               Highest price
                            </button>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "price-low-to-high";
                                priceFilter = "Lowest price";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Lowest price
                            </button>
                            {#if Object.keys(nftPoints).length !== 0}
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "rarity-high-to-low";
                                priceFilter = "Highest rarity";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Highest rarity
                            </button>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "rarity-low-to-high";
                                priceFilter = "Lowest rarity";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Lowest rarity
                            </button>
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>

            <!--Mobi Filter-->
            <div class=" sm:hidden flex  md:flex-row flex-col gap-[20px] font-semibold text-lg">        
                <div class="flex relative justify-between items-center rounded-xl gap-[10px] text-base">
                    <button class="sm:py-[10px] py-[10px] px-[10px] bg-lightBg rounded-xl hover:fill-blue fill-black shadow-md"
                    on:click ={()=>{filterSideBar =! filterSideBar}}>
                        <svg class="sm:h-[20px] h-[20px] fill-inherit" viewBox="0 0 45 30" xmlns="http://www.w3.org/2000/svg">
                            <path class="fill-inherit" fill-rule="evenodd" clip-rule="evenodd" d="M0 2.5C0 1.1193 1.1193 0 2.5 0H42.5C43.8807 0 45 1.1193 45 2.5C45 3.8807 43.8807 5 42.5 5H2.5C1.1193 5 0 3.8807 0 2.5ZM7.5 15C7.5 13.6193 8.6193 12.5 10 12.5H35C36.3807 12.5 37.5 13.6193 37.5 15C37.5 16.3807 36.3807 17.5 35 17.5H10C8.6193 17.5 7.5 16.3807 7.5 15ZM15 27.5C15 26.1193 16.1193 25 17.5 25H27.5C28.8807 25 30 26.1193 30 27.5C30 28.8807 28.8807 30 27.5 30H17.5C16.1193 30 15 28.8807 15 27.5Z" />
                        </svg>          
                    </button>
                    
                    <button class="flex z-20 justify-between items-center py-[10px] px-[18px] w-full gap-[20px] bg-white rounded-xl shadow-md text-base"
                    on:click={()=>{dropdownPriceFilterClicked =! dropdownPriceFilterClicked}}>
                        <span>{priceFilter}</span>
                        <img class="h-[10px]" src="/icons/dropdown.svg" alt="dropdown"/>
                    </button>
                    {#if dropdownPriceFilterClicked}
                        <div class="flex flex-col right-0 z-10 border border-blue absolute w-full gap-[10px] py-[10px] mt-[10px] {Object.keys(nftPoints).length !== 0? "mt-[200px]" : "mt-[150px]"}  pl-[10px] bg-white rounded-md shadow-lg text-base font-semibold" in:slide={{ duration: 300, y: 100 }} out:slide={{ duration: 300, y: 300 }}>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "price-high-to-low";
                                priceFilter = "Highest price";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;

                                await loadNFTs("a");
                            }}>
                                Highest price
                            </button>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "price-low-to-high";
                                priceFilter = "Lowest price";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Lowest price
                            </button>
                            {#if Object.keys(nftPoints).length !== 0}
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "rarity-high-to-low";
                                priceFilter = "Highest rarity";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Highest rarity
                            </button>
                            <button class="hover:text-blue flex" on:click={async () => {
                                sortBy = "rarity-low-to-high";
                                priceFilter = "Lowest rarity";
                                dropdownPriceFilterClicked = false;

                                queryloading = true;

                                done = true;
                                nftIds = await queryNFTs(address, queryAttributes);

                                queryloading = false;

                                items = [];
                                current = 0;
                                done = false;
                                
                                await loadNFTs("a");                                
                            }}>
                                Lowest rarity
                            </button>
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>
            <div class="flex justify-between my-[10px] ">
                <!--Filter side bar-->
                {#if filterSideBar}
                <div class="flex flex-col min-w-[240px] max-w-[240px] min-h-[560px] gap-[20px] bg-darkCard rounded-xl" in:slide={{ duration: 500, x: 500 }} >
                    {#if filterPrice}
                        <!--Display price filter-->
                        <div class="flex flex-col w-full gap-4 rounded-lg">
                            <div class="flex w-full items-center justify-between">
                                <input class="flex w-[110px] bg-lightDark rounded-lg border border-darkGray py-1 px-2 text-base" placeholder="Min"/>
                                <span>to</span>
                                <input class="flex w-[110px] bg-lightDark rounded-lg border border-darkGray py-1 px-2 text-base" placeholder="Max"/>
                            </div>
                            <button class="py-1 font-semibold text-base w-full hover:bg-[#FD8900] bg-[#5960BE] rounded-lg">
                                Apply
                            </button>
                        </div>
                    {/if}

                    <!--Attribute header-->
                    <div class="flex w-full items-center text-lightGray font-semibold pt-4 pl-2">
                        <span>
                            Attribute
                        </span>
                    </div>

                    <!--Attributes-->
                    {#each Object.keys(attributes) as attribute, index }
                        <button class="flex w-full items-center justify-between font-semibold pl-2 pr-3 text-blue" 
                        on:click={()=> { filterAttributes[attribute] = !filterAttributes[attribute] }}>
                            <span>
                                {attribute}
                            </span>
                            <img class="h-[10px]" src="/icons/dropdown.svg" alt="dropdown"/>
                        </button>
                        {#if filterAttributes[attribute]}
                            {#each Object.keys(attributes[attribute]) as attributeValue, valIndex }
                                <!--Display price filter-->
                                <div class="flex w-full items-center justify-between text-sm text-white">
                                    <span>
                                        <span class="ml-4">
                                            {attributeValue}
                                        </span>
                                        <span class="text-lightGray">
                                           <!--({attributes[attribute][attributeValue]})--> 
                                        </span>
                                    </span>
                                    <input on:change={async function() {
                                        attributeCheckBoxes[attribute][attributeValue] = !attributeCheckBoxes[attribute][attributeValue];

                                        const attributes = {};

                                        for (const _attribute in attributeCheckBoxes) {
                                            for (const _attributeValue in attributeCheckBoxes[_attribute]) {
                                                if (attributeValue !== _attributeValue && attribute === _attribute) {
                                                    attributeCheckBoxes[_attribute][_attributeValue] = false;
                                                }

                                                if (attributeCheckBoxes[_attribute][_attributeValue]) {
                                                    attributes[_attribute] = _attributeValue;
                                                }
                                            }
                                        }

                                        // attributeCheckBoxes = attributeCheckBoxes;

                                        
                                        queryAttributes = attributes;

                                        //console.log(attributes);

                                        queryloading = true;

                                        done = true;
                                        nftIds = await queryNFTs(address, attributes);

                                        queryloading = false;

                                        items = [];
                                        current = 0;
                                        done = false;

                                        await loadNFTs("b");
                                    }} checked={attributeCheckBoxes[attribute][attributeValue]} type="checkbox" class="h-[20px] w-[20px] mr-3 bg-darkGray text-lightGray"/>
                                </div>
                            {/each}
                        {/if}
                    {/each}
                </div>
                {/if}
                <!--All cards containers-->
                {#if pagenition === "items"}
                    <div class="flex flex-wrap gap-5 justify-center">
                        {#if queryloading}
                            {#each loadingItems as loadItem}    
                                <!--Cards-->
                                <div class="relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-darkCard  min-h-[325px] max-h-[325px] px-2 py-2 shadow-xl">
                                    <!--Card img-->
                                    <div class="flex items-center min-w-[208px] max-w-[208px] min-h-[208px] max-h-[208px] loading rounded-t-xl overflow-hidden">
                                        <div class="shrink-on-hover object-contain rounded-t-xl min-w-[208px] max-w-[208px]" alt="test">
                                        </div>
                                    </div>
                                    <!--Card Info-->
                                    <div class="flex flex-col gap-[5px]">
                                        <div class="font-bold text-button loading min-w-[100px] min-h-[10px]">
                                            
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
                        {:else}
                            <!--All cards-->
                            {#each items as item, index}
                                <!--Cards-->
                                {#if !errorNFTs[index]}
                                    <button class="relative group parent flex flex-col gap-1 rounded-xl text-white cursor-pointer relative bg-darkCard shadow-xl  min-h-[325px] max-h-[325px] px-2 py-2 hover:border-blue hover:border-2"
                                    on:click={() => goto(`../../items/${address}/${item.id}`)}>
                                        <!--Card img-->
                                        <div class="flex items-center min-w-[208px] max-w-[208px] min-h-[208px] max-h-[208px] rounded-t-xl overflow-hidden">
                                            <img src={`${config.rpcUrl}/cdn/nft/${address}/${item.id}/350/350`} alt="NFT asset" 
                                            on:error={() => { errorNFTs[index] = true; done = true; }}
                                            class="shrink-on-hover object-contain rounded-t-xl min-w-[208px] max-w-[208px] {imgLoad? "loading":""}"/>
                                        </div>
                                        <!--Card Info-->
                                        <div class="flex flex-col gap-[5px] items-start">
                                            <span class="font-bold text-blue">
                                                {reducedNFTName(collectionName, item.id)}
                                            </span>
                                            <!--Price Containers-->
                                            <div class="flex items-center gap-[5px]">
                                                <img class="h-[20px] inline-block border-[1px] border-darkGray rounded-full" src="/icons/ETN.png" alt="coin icon"/>
                                                <span class="font-semibold">
                                                    { item.price === "-1" || item.isSold ? "Unlisted" : bigIntToFloat(BigInt(item.price)) }
                                                </span>
                                            </div>
                                            <!--Card Rarity-->
                                            {#if nftPoints[item.id] !== ""}
                                                <span class="ml-[0px] text-sm text-lightGray bottom-0 mt-1 text-sm">
                                                    { nftPoints[item.id] ? `Rarity Score: ${nftPoints[item.id]}` : "" }
                                                </span>
                                            {/if}
                                        </div>
     
                                    </button>
                                {/if}
                            {/each}
                        {/if}

                        <!--Pre loading cards-->
                        {#if loading}
                            {#each loadingItems as loadItem}    
                                <!--Cards-->
                                <div class="relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-darkCard  min-h-[325px] max-h-[325px] px-2 py-2">
                                    <!--Card img-->
                                    <div class="flex items-center min-w-[208px] max-w-[208px] min-h-[208px] max-h-[208px] loading rounded-t-xl overflow-hidden">
                                        <div class="shrink-on-hover object-contain rounded-t-xl min-w-[208px] max-w-[208px]" alt="test">
                                        </div>
                                    </div>
                                    <!--Card Info-->
                                    <div class="flex flex-col gap-[5px]">
                                        <div class="font-bold text-button loading min-w-[100px] min-h-[10px]">
                                            
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
                {#if pagenition ==="activity"}
                    {#if activities.length !==0}
                        <div class="xl:flex hidden flex-col rounded-md text-left bg-darkCard text-white w-full py-[15px] lg:px-8 px-4 ml-[20px]">
                            <!--Header-->
                            <div class="lg:flex hidden text-lightGray text-sm pb-[12px] w-full  border-darkGray" >
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
                                    <div class="text-sm flex lg:items-center lg:justify-center justify-between hover:text-yellow-500 py-[10px] border-t border-[#D4D6D3]">
                                        <!--Event-->
                                        <div class="flex lg:w-[10%]  flex items-center">
                                            {#if activity.type === "transfer"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/transfer.svg" alt="transfer NFT icon" />
                                            {:else if activity.type === "list"}
                                                <img class="h-[20px]  inline-block mr-[5px]" src="/icons/listing.svg" alt="list NFT icon"/>
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
                                            <img class="h-[60px] {imgLoad? "loading":""}  inline-block mr-[5px] rounded-full" 
                                            src="{config.rpcUrl}/cdn/nft/{activity.collection}/{activity.id}/200/200"
                                            on:load={()=>{ imgItemLoad = false}} alt="NFTs"/>
                                            <!--Items name-->
                                            <div class="flex flex-col font-semibold text-button">
                                                <span class="text-lightGray"> 
                                                    #{activity.id}
                                                </span>
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
                                        <button class="lg:w-[15%] " on:click={()=>{goto(`../../${activity.from}`)}} >
                                            <div class="underline ml-[3px] {activity.from?" ":""} font-semibold text-white p-2 w-fit rounded-md">
                                                {emitBetweenText(activity.from, 10)}
                                            </div>
                                        </button>
                                        <!--To Address-->
                                        <button class="lg:w-[15%]" on:click={()=>{goto(`../../${activity.to}`)}} >
                                            <div class="underline ml-[3px] {activity.to?" ":""} font-semibold text-white p-2 w-fit rounded-md">
                                                {emitBetweenText(activity.to, 10)}
                                            </div>
                                        </button>
                                        <!--Date Offer-->
                                        <button class="  lg:w-[10%] lg:order-1 order-2 ">
                                            {timeAgo(activity.date)} 
                                        </button>

                                    </div>
                                {/each}
                            </div>
                        </div>
                    {:else}
                        <div class="xl:flex hidden flex-col rounded-md text-left shadow-md bg-darkCard w-full py-[15px] lg:px-8 px-4 ml-[20px]">
                            <span class="text-lg text-white">
                                This collection has no activity yet
                            </span>
                        </div>
                    {/if}
                {/if}
                <!--Activity Small screen-->
                {#if pagenition ==="activity"}
                    {#if activities.length !==0}
                        <div class="xl:hidden flex flex-col rounded-md text-left shadow-xl bg-darkCard text-white w-full py-[15px] sm:px-4 px-4 sm:ml-[20px] ml-[0px] gap-[20px]">
                            {#each activities as activity}
                                <div class="flex flex-col mt-[20px]">
                                    <!--Status-->
                                    <div class="flex lg:w-[10%] items-center">
                                        {#if activity.type === "transfer"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/transfer.svg" alt="transfer NFT icon"/>
                                        {:else if activity.type === "list"}
                                            <img class="h-[20px]  inline-block mr-[5px]" src="/icons/listing.svg" alt="list NFT icon"/>
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
                                                <img class="sm:h-[100px] h-[50px] inline-block mr-[5px] rounded-full" src="{config.rpcUrl}/cdn/nft/{activity.collection}/{activity.id}/200/200" alt="NFT"/>
                                            </button>
                                            <!--Collection Name + From + To-->
                                            <div class="flex  flex-col">
                                                <!--Collection Name-->
                                                <span class="sm:text-xl text-sm text-blue font-bold mb-[10px]"> 
                                                    <!--Id-->
                                                    <span>#{activity.id}</span>
                                                </span>
                                                <div class="flex gap-1">
                                                    <span class="sm:text-medium text-sm mr-1 text-lightGray">From</span>
                                                    <!--From Address-->
                                                    <button class="sm:text-medium text-sm underline " on:click={()=>{goto(`../../${activity.from}`)}} >
                                                        {emitBetweenText(activity.from, 10)}
                                                    </button>
                                                </div>
                                                <div class="flex gap-1">
                                                    <span class="sm:text-medium text-sm mr-1 text-lightGray">To</span>
                                                    <!--To Address-->
                                                    <button class="sm:text-medium text-sm underline " on:click={()=>{goto(`../../${activity.to}`)}}>
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
                    {:else}
                        <div class="xl:hidden flex flex-col rounded-md text-left shadow-md bg-darkCard w-full py-[15px] sm:px-4 px-4 sm:ml-[20px] ml-[0px] gap-[20px]">
                            <span class="text-lg text-white">
                                This collection has no activity yet
                            </span>
                        </div>
                    {/if}
                {/if}
            </div>
        </div>
    </div>
</div>
