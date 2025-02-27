<script>
    import Seo from '$lib/Seo.svelte';
    import { crossfade } from 'svelte/transition';
    import { fly } from 'svelte/transition';
    import { slide, fade } from 'svelte/transition';
    import { goto } from '$app/navigation';
    import {timeAgo} from '$lib/index.js';
    import {emitRightText} from '$lib/index.js';
    import Nav from "./Nav.svelte";
    import Footer from "./Footer.svelte"
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import config from "$lib/config.js";
    import {bigIntToFloat} from "$lib/index.js"


    let loadingTable = false;
    let loadingTableLefts=[{},{},{},{},{}];
    let loadingFeaturePages=[{},{},{}];
    let loading = true;
    //effect first load
    let effectFirst = false;
    
    //ex
    let topCollections = [];
    let mainPageCollections = [];
    let mintCollections = [];
    let loadingMintCollections =[{},{},{},{},{}]
    let firstFiveMainPageCollections = mainPageCollections.slice(0, 5);
    let secondFiveMainPageCollections = mainPageCollections.slice(5, 10);
    

    let pageTimer, fillAnimation;
    let navigationFeaturePage = 1;
    let xFlyPage = 300;
    
    function navigateRightPage(){
        xFlyPage = 300;
        navigationFeaturePage = navigationFeaturePage +1;
        if(navigationFeaturePage > topCollections.length){
            navigationFeaturePage = 1;
        }
        resetTimer();
    }
    function navigateLeftPage(){
        xFlyPage = 300;
        navigationFeaturePage = navigationFeaturePage -1;
        if(navigationFeaturePage < 1){
            navigationFeaturePage = topCollections.length;

        }
        resetTimer();
    }
    //Function auto navigate to next page + reset time
    function resetTimer() {
        fillAnimation = true;
        clearInterval(pageTimer);
        pageTimer = setInterval(
            ()=>{
                fillAnimation = false;
                navigateRightPage();
            },
            10000);
    }
    //Auto navigate to next page
    $:if(loading === false){
        resetTimer();
    }
 

    //scroll mint
    let scrollContainer;

    function scrollLeft() {
        // Calculate the new scroll position
        const newScrollPosition = scrollContainer.scrollLeft - 330; 
        // Smoothly scroll to the new position
        scrollContainer.scrollTo({ left: newScrollPosition, behavior: 'smooth' });
    }

    function scrollRight() {
        // Calculate the new scroll position
        const newScrollPosition = scrollContainer.scrollLeft + 330; 
        // Smoothly scroll to the new position
        scrollContainer.scrollTo({ left: newScrollPosition, behavior: 'smooth' });
    }


    onMount(() => {
        effectFirst = true;
        (async function getTopCollections() {
            const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getTopCollections",
					params: {}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

            if (response.ok) {
                const responseBody = await response.json();

                const collections = responseBody.payload.featuredList.filter(collection => collection);
                await getTopCollectionsInfo(collections);
            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
				}
            }

            loading = false;
        })();

        async function getTopCollectionsInfo(addresses) {       
            // Get collections' description
            const description = {};

            const response1 = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getNFTsInfo",
					params: {
						nfts: addresses.map(address => ({ collectionAddress: address, id: 1 })),
                        exclude: [ "listingDetails", "owner", "collectionName", "offers" ]
					}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

            if (response1.ok) {
                const responseBody = await response1.json();
                console.log(responseBody, "responseBody")
                try {
                    for (const nft of responseBody.payload.nftInfos) {
                        description[nft.collection] = nft.metadata.description;
                    }
                } catch (e) {}
            }

            // Get collections' info
            const response2 = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getCollectionsInfo",
					params: {
						addresses
					}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

            if (response2.ok) {
                const responseBody = await response2.json();
                console.log("responseBody123", responseBody)
                topCollections = responseBody.payload.collectionInfos.map((collection => {
                    return {
                        address: collection.address,
                        collectionName: collection.name,
                        verified: true,
                        pageLink: `/collections/${collection.address}`,
                        bannerLink: `${config.rpcUrl}/banner/${collection.address}`,
                        avaLink: `${config.rpcUrl}/logo/${collection.address}/200/200`,
                        description: description[collection.address] || "",
                        floorPrice: collection.floorPrice,
                        volume: collection.volume
                    }
                }));
                topCollections = [...topCollections];
                console.log(topCollections,"topCollections")
            }
        }

        (async function getMainPageCollections() {
            loadingTable = true;
            const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getMainPageCollections",
					params: {}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

            if (response.ok) {
                const responseBody = await response.json();

                const collections = responseBody.payload.featuredList.filter(collection => collection);

                await getMainPageCollectionsInfo(collections);

                loadingTable = false;
                firstFiveMainPageCollections = mainPageCollections.slice(0, 5);
                secondFiveMainPageCollections = mainPageCollections.slice(5, 10);
            } else {
                loadingTable = false;
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
				}
            }
        })();

        async function getMainPageCollectionsInfo(addresses) {
			const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getCollectionsInfo",
					params: {
						addresses
					}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});

			if (response.ok) {
				const responseBody = await response.json();

                mainPageCollections = responseBody.payload.collectionInfos.map((collection => {
                    return {
                        collectionName: collection.name,
                        verified: true,
                        pageLink: `/collections/${collection.address}`,
                        avaLink: `${config.rpcUrl}/logo/${collection.address}/200/200`,
                        floorPrice: collection.floorPrice,
                        volumn: collection.volume,
                        address: collection.address,
                    }
                }));
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
				}
			}
        }

        (async function getMintFeaturedCollections() {
            const response = await fetch(config.rpcUrl, {
                method: "POST",
                body: JSON.stringify({
                    method: "getMintFeaturedCollections",
                    params: {}
                }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (response.ok) {
                const responseBody = await response.json();
                const featuredList = responseBody.payload.featuredList.filter(item => item);

                // Fetch all collection data in parallel
                const collectionPromises = featuredList.map(async (address) => {
                    try {
                        const [name, mintDuration] = await Promise.all([
                            getCollectionName(address),
                            getMintDuration(address)
                        ]);

                        return {
                            address,
                            name,
                            mintDuration,
                            status: "ENDED" // Default status
                        };
                    } catch (error) {
                        console.error(`Error fetching data for collection ${address}:`, error);
                        return null;
                    }
                });
                // Wait for all collections to be fetched
                const collections = (await Promise.all(collectionPromises)).filter(item => item);

                // Create a single interval for all collections
                const updateStatuses = () => {
                    const currentTime = Date.now();
                    
                    // Create a new array with updated statuses
                    const updatedCollections = collections.map(collection => {
                        const duration = collection.mintDuration;
                        
                        const isFreemintActive = currentTime >= duration.freemintDuration[0] && 
                                               currentTime <= duration.freemintDuration[1];
                        
                        const isWhitelistActive = currentTime >= duration.whitelistMintDuration[0] && 
                                                currentTime <= duration.whitelistMintDuration[1];
                        
                        const isPublicActive = currentTime >= duration.publicMintDuration[0] && 
                                             currentTime <= duration.publicMintDuration[1];

                        // Determine the earliest start time and latest end time
                        const startTimes = [
                            duration.freemintDuration[0],
                            duration.whitelistMintDuration[0],
                            duration.publicMintDuration[0]
                        ].filter(time => time > 0);

                        const endTimes = [
                            duration.freemintDuration[1],
                            duration.whitelistMintDuration[1],
                            duration.publicMintDuration[1]
                        ].filter(time => time > 0);

                        const earliestStart = Math.min(...startTimes);
                        const latestEnd = Math.max(...endTimes);

                        let newStatus;
                        if (isFreemintActive || isWhitelistActive || isPublicActive) {
                            newStatus = "LIVE";
                        } else if (currentTime < earliestStart) {
                            newStatus = "UPCOMING";
                        } else if (currentTime > latestEnd) {
                            newStatus = "ENDED";
                        } else {
                            newStatus = "UPCOMING";
                        }

                        return {
                            ...collection,
                            status: newStatus,
                            timeLeft: latestEnd - currentTime,
                            timeToStart: earliestStart - currentTime
                        };
                    });

                    // Force Svelte reactivity by creating a new array reference
                    mintCollections = [...updatedCollections];
                };

                updateStatuses();

                // Set up interval for status updates
                const intervalId = setInterval(updateStatuses, 1000);

                // Return cleanup function
                return () => clearInterval(intervalId);
            } else {
                const responseBody = await response.json();
                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
                }
            }
        })();
        
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

        async function getMintDuration(address) {
			// Initiate file upload and get the file key
			const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getMintDuration",
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

                return responseBody.payload;

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
		}
    });

    let mintTopShow = [
            "0xfE8c448f0326c7371Fe5475bdedFb4d5553b49D5",
            "0xd58a4eec13424B0510589eCAA9393e51c1c9C2CE"
    ]

    function handleNavigateTopCollection(collectionAddess) {
        if (mintTopShow.includes(collectionAddess)) {
           goto(`/mint/${collectionAddess}`)
        } else {
            goto(`/collections/${collectionAddess}`)
        }
    }

</script>
<Seo title={""} description={""} keywords={""}/>
<div class="flex text-black font-Oxanium bg-black w-full min-h-screen">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto pb-[60px]">
        <div class="flex flex-col">
            <div class="sm:px-[33px] px-[10px]">
                <Nav/>
            </div>
            <!---->
            <div class="relative flex flex-col">
                <!--Featured collection page-->
                    <div class="flex flex-col relative justify-center sm:order-1 order-2 "  >
                        <!--Loading Feature page-->
                        {#if loading}
                            {#each loadingFeaturePages as loadingFeaturePage, index}
                                {#if index+1 === navigationFeaturePage}
                                    <div class="overflow-hidden loading w-full object-cover h-[470px] rounded-md "></div>
                                {/if}
                            {/each}
                        {:else}
                        <!--Feature Page Container-->
                            {#each topCollections as topCollection, index}
                                <!--Feature page-->
                                {#if index+1 === navigationFeaturePage}
                                    <!--Large screen-->
                                    <!--link collection-->
                                    
                                    <div class="flex flex-col relative justify-start h-[470px]" >
                                        <!--Banner img-->
                                        {#if loading}
                                            <div class="loading w-full h-[470px] object-cover h-full rounded-md overflow-hidden"></div>
                                        {:else}
                                            <img class="w-full object-cover h-full rounded-md overflow-hidden" src={`${topCollection.bannerLink}`} alt="banner of NFT collection"/>
                                            <!--Featured Collections Card-->
                                            <div class="left-0 bottom-0 absolute self-end flex flex-col bg-gradient-black-fade shadow-xl bg-opacity-90 h-[280px] xl:min-w-[60%]  max-w-[100%] min-w-[100%] px-4 py-4 sm:gap-[10px] gap-0">
                                                <div class="flex flex-col gap-[10px] ">
                                                    <div class="flex gap-[10px] ml-2">
                                                        <div class="flex flex-col">
                                                            <div class="flex items-center gap-[10px]">
                                                                <!--Collection Name-->
                                                                <div class="font-semibold sm:text-3xl text-2xl text-white">
                                                                    {topCollection.collectionName}
                                                                </div>
                                                                <!--Verified-->
                                                                {#if topCollection.verified}
                                                                    <img class="h-[20px] inline-block" src="/icons/verified.svg" alt="verified icon"/>
                                                                {/if}
                                                            </div>
                                                            <!--Collection Description-->
                                                            <span class="text-sm mt-[10px] ml-2">
                                                                {emitRightText(topCollection.description,200)}
                                                            </span>
                                                        </div> 
                                                    </div>
                                                </div>
                                                    <!--Featured Collections Info-->
                                                <div class="flex flex-wrap text-white sm:text-lg text-sm w-full justify-start lg:gap-[40px] sm:gap-[20px] gap-[15px]">
                                                    <div class="flex flex-col">
                                                        <span class="text-lightGray">
                                                            Floor price
                                                        </span>
                                                        <span>
                                                            {bigIntToFloat(BigInt(topCollection.floorPrice)).toFixed(4)} ETN
                                                        </span>
                                                    </div>
                                                    <div class="flex flex-col">
                                                        <span class="text-lightGray">
                                                            Volume
                                                        </span>
                                                        <span>
                                                            {bigIntToFloat(BigInt(topCollection.volume)).toFixed(4)} ETN
                                                        </span>
                                                    </div>
                                                    <button class="flex gap-1 self-end bg-button hover:bg-buttonHover h-fit py-[4px] px-[6px] rounded-md"
                                                    on:click={()=>{handleNavigateTopCollection(topCollection.address)}}>
                                                        <span>View</span>
                                                        <span class="sm:flex hidden">collections</span>
                                
                                                    </button>
                                                </div>
                                            </div>
                                        {/if}
                                    </div>
                             
                                {/if}
                            {/each}
                            <div bind:this={scrollContainer} class="absolute bottom-[20px] left-[20px] flex xl:gap-[15px] lg:gap-10 gap-4 overflow-x-scroll custom-scrollbar mt-[10px] ">
                                <!--All top cards-->
                                {#each topCollections as topCollection}    
                                    <!--Cards-->
                                    <button on:click={()=>{handleNavigateTopCollection(topCollection.address)}}
                                    class="relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-white shadow-xl min-h-[100px] max-h-[100px] hover:border-blue hover:border-2">
                                        <!--Card img-->
                                        <div class="flex items-center min-w-[200px] max-w-[200px] min-h-[100px] max-h-[100px] bg-black rounded-t-xl overflow-hidden">
                                            <img src={`${topCollection.bannerLink}`}
                                            class="shrink-on-hover object-cover rounded-t-xl min-w-[322px] max-w-[322px]" alt="test"/>
                                        </div>
                                        <div class="absolute flex justify-start w-full h-full overflow-hidden bg-gradient-black-fade py-2">
                                            <div class="flex items-center gap-1 h-fit">
                                                <!--Ava-->
                                                <div class="w-full overflow-hidden max-h-[40px] min-w-[40px] max-w-[40px] bg-black rounded-full z-10 ml-1">
                                                    <img src={`${topCollection.avaLink}`}  class="object-contain  w-full max-h-[40px] min-h-[40px]" alt="avatar of NFT collection"/> 
                                                </div> 
                                                <div class="font-semibold text-sm text-white">
                                                    {topCollection.collectionName}
                                                </div>
                                            </div>
                                        </div>
                                    </button>
                                {/each}
                            </div>

                        {/if}
                    </div>
                <!--Navigate page button-->
                <!--
                <div class="absolute flex gap-[20px] mt-[15px] justify-center w-full sm:order-2 order-1 mt-[35px] z-10" >
                    <button class="w-[15%] h-[8px] shadow-xl {navigationFeaturePage ===1 && !loading?" timerIndicator":"bg-[#FDFAE5]"} rounded-xl" on:click={()=>{navigationFeaturePage = 1}}>
                    </button>
                    {#if topCollections.length > 1}
                        <button class="w-[15%] h-[8px] shadow-xl {navigationFeaturePage ===2 && !loading?" timerIndicator":"bg-[#FDFAE5]"} rounded-xl" on:click={()=>{navigationFeaturePage = 2}}>
                        </button>
                    {/if}
                    {#if topCollections.length > 2}
                        <button class="w-[15%] h-[8px] shadow-xl {navigationFeaturePage ===3 && !loading?" timerIndicator":"bg-[#FDFAE5]"} rounded-xl" on:click={()=>{navigationFeaturePage = 2}}>
                        </button>
                    {/if}
                </div>-->
            </div>
            <div class="relative flex flex-col flex-grow bg-darkBlue px-2 py-2 shadow-md">
                <!--Table-->
                <div class="grid md:grid-cols-2 grid-cols-1 mt-[10px] rounded-md md:min-h-[384px] sm:pb-4 pb-10">
                    <!--Table left-->
                    <div class="flex flex-col text-sm rounded-md text-left w-full md:pr-4">
                        <!--Header-->
                        <div class="flex justify-between text-xs text-lightGray pb-[12px] w-full border-darkGray" >
                            <div class="flex  flex-grow   w-[50%]">
                                <span class="ml-[18px]">Collections</span>
                            </div>
                            <div class="lg:flex hidden text-xs   flex-grow   lg:w-[25%]">Floor price</div>
                            <div class="flex  flex-grow md:justify-start  justify-end   w-[25%]">Volume</div>
                        </div>
                        <!--Loading table left-->
                        {#if loadingTable}
                            <div class="rounded-b-sm" in:slide={{ duration: 300, y: 300 }}>
                                {#each loadingTableLefts as loadingTableLeft, index}
                                    <!--Row-->
                                    <div class="flex justify-between items-center hover:text-yellow-500 py-[5px]">
                                        <!--Collections-->
                                        <button class="flex  flex-grow items-center md:w-[50%]">
                                            <!--Index-->
                                            <span class="text-lightGray">
                                                {index + 1}
                                            </span>
                                            <!--Items image-->
                                            <div class="loading h-[50px] w-[50px]  inline-block ml-[15px] rounded-full"></div>
                                            <!--Collection name-->
                                            <span class="font-semibold ml-[10px]">
                                            </span>
                                        </button>
                                        <!--Floor price-->
                                        <div class="lg:flex hidden flex-grow hidden items-center lg:w-[25%]">
                                            <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                            <!--Offer value-->
                                            <span class=" font-semibold">
                                            </span>
                                        </div>
                                        <!--Volume-->
                                        <div class="flex md:justify-start  justify-end  flex-grow items-center md:w-[25%]">
                                            <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        <!--table left-->
                        {:else}
                            <!--Body-->
                            <div class="flex flex-col gap-[10px] rounded-b-sm">
                                {#each firstFiveMainPageCollections as firstFiveMainPageCollection, index}
                                    <!--Row-->
                                    <div class="flex justify-between items-center hover:text-yellow-500 py-[5px]">
                                        <!--Collections-->
                                        <button class="flex  flex-grow items-center md:w-[50%]" on:click={()=>{goto(`${firstFiveMainPageCollection.pageLink}`)}}>
                                            <!--Index-->
                                            <span class="text-lightGray">
                                                {index + 1}
                                            </span>
                                            <!--Items image-->
                                            <img class="h-[50px]  inline-block ml-[15px] rounded-full" src={`${firstFiveMainPageCollection.avaLink}`} alt="avatar of NFT collections"/>
                                            <!--Collection name-->
                                            <span class="font-semibold ml-[10px] text-white">
                                                {emitRightText(firstFiveMainPageCollection.collectionName,15)}
                                            </span>
                                            <!--Verified-->
                                            {#if firstFiveMainPageCollection.verified}
                                                <img src="/icons/verified.svg" class="h-[20px] ml-[5px]" alt="verified icon"/>
                                            {/if}
                                        </button>
                                        <!--Floor price-->
                                        <div class="lg:flex hidden flex-grow hidden items-center lg:w-[25%]">
                                            <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                            <!--Offer value-->
                                            <span class=" font-semibold text-white">
                                                {bigIntToFloat(BigInt(firstFiveMainPageCollection.floorPrice)).toFixed(4)}
                                                
                                            </span>
                                        </div>
                                        <!--Volume-->
                                        <div class="flex md:justify-start  justify-end  flex-grow items-center md:w-[25%]">
                                            <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                            <!--Volume value-->
                                            <span class="sm:text-base text-sm font-semibold text-white ">
                                                {bigIntToFloat(BigInt(firstFiveMainPageCollection.volumn)).toFixed(5)}
                                            </span>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {/if}
                    </div>
                        <!--Loading table right-->
                        {#if loadingTable}
                            <div class="rounded-b-sm mt-[25px]" in:slide={{ duration: 300, y: 300 }}>
                                {#each loadingTableLefts as loadingTableLeft, index}
                                    <!--Row-->
                                    <div class="flex justify-between items-center hover:text-yellow-500 py-[5px]">
                                        <!--Collections-->
                                        <button class="flex  flex-grow items-center md:w-[50%]">
                                            <!--Index-->
                                            <span class="text-darkGray">
                                                {index + 1}
                                            </span>
                                            <!--Items image-->
                                            <div class="loading h-[50px] w-[50px]  inline-block ml-[15px] rounded-full"></div>
                                            <!--Collection name-->
                                            <span class="font-semibold ml-[10px] text-white">
                                            </span>
                                        </button>
                                        <!--Floor price-->
                                        <div class="lg:flex hidden flex-grow hidden items-center lg:w-[25%]">
                                            <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                            <!--Offer value-->
                                            <span class=" font-semibold">
                                            </span>
                                        </div>
                                        <!--Volume-->
                                        <div class="flex md:justify-start  justify-end  flex-grow items-center md:w-[25%]">
                                            <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        <!--table right-->
                        {:else}
                            {#if secondFiveMainPageCollections.length > 0}
                                <div class="flex flex-col text-sm rounded-md text-left w-full md:pl-4">
                                    <!--Header-->
                                    <div class="md:flex hidden justify-between text-xs text-darkGray pb-[12px] w-full border-darkGray" >
                                        <div class="flex  flex-grow   w-[50%]">
                                            <span class="ml-[18px]">Collections</span>
                                        </div>
                                        <div class="lg:flex hidden text-xs   flex-grow   lg:w-[25%]">Floor price</div>
                                        <div class="flex  flex-grow md:justify-start  justify-end   w-[25%]">Volume</div>
                                    </div>
                                    {#if loadingTable}
                                        <!--Loading table right-->
                                        <div class="rounded-b-sm">
                                            {#each loadingTableLefts as loadingTableLeft, index}
                                                <!--Row-->
                                                <div class="flex justify-between items-center hover:text-yellow-500 py-[5px]">
                                                    <!--Collections-->
                                                    <button class="flex  flex-grow items-center md:w-[50%]">
                                                        <!--Index-->
                                                        <span class="text-darkGray">
                                                            {index + 6}
                                                        </span>
                                                        <!--Items image-->
                                                        <div class="loading h-[50px] w-[50px]  inline-block ml-[15px] rounded-full"></div>
                                                        <!--Collection name-->
                                                        <span class="font-semibold ml-[10px]">
                                                        </span>
                                                    </button>
                                                    <!--Floor price-->
                                                    <div class="lg:flex hidden flex-grow hidden items-center lg:w-[25%]">
                                                        <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                                        <!--Offer value-->
                                                        <span class=" font-semibold">
                                                        </span>
                                                    </div>
                                                    <!--Volume-->
                                                    <div class="flex md:justify-start  justify-end  flex-grow items-center md:w-[25%]">
                                                        <div class="loading h-[25px] w-[25px] rounded-full  inline-block mr-[5px]" ></div>
                                                    </div>
                                                </div>
                                            {/each}
                                        </div>
                                    {:else}
                                        <!--Body-->
                                        <div class="rounded-b-sm">
                                            {#each secondFiveMainPageCollections as secondFiveMainPageCollection, index}
                                                <!--Row-->
                                                <div class="flex justify-between items-center hover:text-yellow-500 py-[5px]">
                                                    <!--Collections-->
                                                    <button class="flex  flex-grow items-center md:w-[50%]" on:click={()=>{goto(`${secondFiveMainPageCollection.pageLink}`)}}>
                                                        <!--Index-->
                                                        <span class="text-darkGray">
                                                            {index + 6}
                                                        </span>
                                                        <!--Items image-->
                                                        <img class="h-[50px]  inline-block ml-[15px] rounded-full" src={`${secondFiveMainPageCollection.avaLink}`} alt="avatar of NFT collections" />
                                                        <!--Collection name-->
                                                        <span class="font-semibold ml-[10px] text-white">
                                                            {emitRightText(secondFiveMainPageCollection.collectionName,15)}
                                                        </span>
                                                        <!--Verified-->
                                                        {#if secondFiveMainPageCollection.verified}
                                                            <img src="/icons/verified.svg" class="h-[20px] ml-[5px]" alt="verified icon"/>
                                                        {/if}
                                                    </button>
                                                    <!--Floor price-->
                                                    <div class="lg:flex hidden flex-grow hidden items-center lg:w-[25%]">
                                                        <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                        <!--Offer value-->
                                                        <span class=" font-semibold text-white">
                                                            {bigIntToFloat(BigInt(secondFiveMainPageCollection.floorPrice))}
                                                        </span>
                                                    </div>
                                                    <!--Volume-->
                                                    <div class="flex md:justify-start  justify-end  flex-grow items-center md:w-[25%]">
                                                        <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                                        <!--Volume value-->
                                                        <span class=" font-semibold">
                                                            {bigIntToFloat(BigInt(secondFiveMainPageCollection.volumn)).toFixed(5)}
                                                        </span>
                                                    </div>
                                                </div>
                                            {/each}
                                        </div>
                                    {/if}
                                </div>
                            {/if}
                        {/if}
                </div>
                <!--See all button-->
                <button class="absolute bottom-0 right-0 mb-[-20px] text-base p-2 bg-button hover:bg-buttonHover shadow-xl text-white font-semibold rounded-md w-[200px]" on:click={()=>{goto(`./collections`)}} >
                    See all
                </button>
            </div>
            <h1 class="text-white  text-2xl font-semibold sm:mt-[50px] mt-[20px] mb-[10px]">
                NFT Arena
            </h1>

            <button class="relative justify-center flex flex-col flex-grow bg-black px-2 py-2 shadow-md overflow-hidden rounded-xl border-[10px] border-buttonHover" on:click={()=>{window.open("/nftarena")}}>
                <div class="relative w-full overflow-hidden md:h-[20vw] sm:h-[30vw]">
                    <!-- Added absolute positioning and centering for both horizontal and vertical -->
                    <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 relative flex flex-col justify-center h-[45vw] w-[100vw]">
                        <img class="absolute" alt="background" src="/game/load/bgLoad.webp"/>
                        
                        <!--Catto-->
                        <img alt="catto nft" class="absolute left-[5vw] bottom-[21vw] z-10 h-[15vw] w-auto object-contain floating" src="/game/load/catto.png"/>
                        
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
                                <img alt="random nft" class="absolute z-10 h-[16vw] w-auto object-contain floating4" src="/game/load/wukong.png"/>                 
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
                    </div>
                </div>
                <div class="absolute self-center text-white hover:text-blue md:w-[15vw] md:h-[15vw] h-[20vw] w-[20vw] gap-[0.5vw] flex flex-col justify-center items-center bg-black z-20 rounded-full bg-opacity-90 glow-border-run">
                    <span class="md:text-[1.8vw] text-[2vw] mt-[1vw] font-geo font-semibold">
                        PLAY NOW
                    </span>
                </div>
                <div class="absolute flex w-full justify-center z-20 md:bottom-[0.8vw] bottom-[8vw]">
                    <span class=" z-[20] text-[1.6vw] font-bold text-linearYellow">
                        Battle with any ERC721 NFT in a PvP Game
                    </span>
                </div>
            </button>

            <!--Mint header-->
            <h1 class="text-white text-2xl font-semibold mt-[60px] gap-[6px]">Launchpad</h1>
            <!--Mint feature event-->
            <div class="relative flex justify-between mb-[20px] mt-2">
                <!--<div class="absolute flex w-full justify-between items-center self-center z-10">
                    <button class="sm:ml-[-15px]" on:click={scrollLeft} >
                        <img class="h-[40px] inline-block" src="/icons/leftButton.svg" alt="left button icon"/>
                    </button>
                    <button class="sm:mr-[-15px]" on:click={scrollRight}>
                        <img class="h-[40px] inline-block" src="/icons/rightButton.svg" alt="right button icon"/>
                    </button>
                </div>-->
                <!--All cards containers-->
                <div bind:this={scrollContainer} class="flex xl:gap-[33px] lg:gap-10 gap-4 overflow-x-scroll custom-scrollbar">
                    {#if mintCollections.length === 0}
                            <!--Loading All minting cards-->
                            {#each loadingMintCollections as item}    
                                <!--Cards-->
                                <button  
                                class="relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-white shadow-lg  min-h-[170px] max-h-[170px] px-2 py-2 hover:border-greenHover hover:border">
                                    <!--Card img-->
                                    <div class="flex items-center min-w-[322px] max-w-[322px] min-h-[95px] max-h-[95px] bg-black rounded-t-xl overflow-hidden">
                                        <div class="loading shrink-on-hover object-cover rounded-t-xl min-h-[95px] min-w-[322px] max-w-[322px]"></div>
                                    </div>
                                    <!--Card Info-->
                                    <div class="flex flex-col gap-[5px] w-full">
                                        <div class="flex flex-wrap w-full justify-between mt-[10px]">
                                            <div class="flex items-center  gap-1 text-base w-[105px] h-[18px] loading rounded-md">
                                            </div>

                                            
                                        <div class="flex items-center gap-[5px]">
                                            <!--Item status-->
                                            <div class="loading px-4 py-0.5 rounded-md w-[55px] h-[18px]">

                                            </div>
                                        </div>
                                        </div>
                                    </div>
                                    <!---->
                                    <div class="flex items-center w-full justify-between ml-[0px] text-sm bottom-0">
                                    </div>
                                </button>
                            {/each}
                    {:else}
                        <!--All minting cards-->
                        {#each mintCollections as item}    
                            <!--Cards-->
                            <button on:click={()=>{goto(`./mint/${item.address}`)}} 
                            class="relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-white shadow-xl  min-h-[170px] max-h-[170px] px-2 py-2 hover:border-blue hover:border-2">
                                <!--Card img-->
                                <div class="flex items-center min-w-[322px] max-w-[322px] min-h-[95px] max-h-[95px] bg-black rounded-t-xl overflow-hidden">
                                    <img src={`${config.rpcUrl}/banner/${item.address}`}
                                    class="shrink-on-hover object-cover rounded-t-xl min-w-[322px] max-w-[322px]" alt="test"/>
                                </div>
                                <!--Card Info-->
                                <div class="flex flex-col gap-[5px] w-full">
                                    <div class="flex flex-wrap w-full justify-between mt-[10px]">
                                        <div class="flex items-center font-bold text-darkBlue gap-1 text-base">
                                            <span>{item.name}</span>
                                            <img class="h-[15px] inline-block" src="/icons/verified.svg" alt="verified icon"/>
                                        </div>

                                        
                                    <div class="flex items-center gap-[5px]">
                                            
                                        <div class="flex items-center justify-center gap-1 px-4 py-0.5 border border-darkGray rounded-m font-semibold text-xs rounded-md">
                                            {item.status} 
                                            {#if item.status === "UPCOMING"}
                                                <div class="w-[13px] h-[13px] bg-[#EBB733] rounded-full">

                                                </div>
                                            {:else if item.status === "LIVE"}
                                                <div class="w-[13px] h-[13px] bg-[#5DEF38] rounded-full">

                                                </div>
                                            {:else}
                                                <div class="w-[13px] h-[13px] bg-[#635F55] rounded-full">

                                                </div>
                                            {/if}
                                        </div>
                                    </div>
                                    </div>
                                </div>
                                <!---->
                                <div class="flex items-center w-full justify-between ml-[0px] text-sm bottom-0">
                                    <!--<div class="flex gap-1">
                                        <span class="text-darkGray">Supply:</span>
                                        <span class="">{item.supply}</span>
                                    </div>-->
                                    

                                </div>
                            </button>
                        {/each}
                    {/if}
                </div>
            </div>
        </div>
    </div>
</div>

<div class="flex bg-darkBlue w-full">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <Footer/>
    </div>
</div>
