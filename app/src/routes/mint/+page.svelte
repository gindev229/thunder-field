<script>
    import Seo from '$lib/Seo.svelte';
    import { fade } from 'svelte/transition';
    import Nav from "../Nav.svelte";
    import Footer from "../Footer.svelte";
    import config from "$lib/config.js";
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';

    let items = [{}, {}, {}, {}, {}];
    let loadingFeatured = true;
    let startPublic;
    let deadlinePublic;
    let publicMintDuration;
    let startFreemint;
    let deadlineFreemint;
    let startWhitelist;
    let deadlineWhitelist;

    
    let publicTimeLeft;
    let publicTimeStart;

    onMount(() => {
        const cleanup = (async function() {
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
            }

            async function getMintDuration(address) {
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
                } else {
                    const responseBody = await response.json();
                    if (responseBody.error && responseBody.error.message) {
                        throw new Error(responseBody.error.message);
                    }
                }
            }

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
                            status: "ENDED"
                        };
                    } catch (error) {
                        console.error(`Error fetching data for collection ${address}:`, error);
                        return null;
                    }
                });

                const collections = (await Promise.all(collectionPromises)).filter(item => item);

                const updateStatuses = () => {
                    dateNow = Date.now();
                    const currentTime = dateNow;
                    
                    // Create a new array with updated statuses
                    const updatedCollections = collections.map(collection => {
                        const duration = collection.mintDuration;
                        
                        const isFreemintActive = currentTime >= duration.freemintDuration[0] && 
                                               currentTime <= duration.freemintDuration[1];
                        
                        const isWhitelistActive = currentTime >= duration.whitelistMintDuration[0] && 
                                                currentTime <= duration.whitelistMintDuration[1];
                        
                        const isPublicActive = currentTime >= duration.publicMintDuration[0] && 
                                             currentTime <= duration.publicMintDuration[1];

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

                    items = updatedCollections;
                };

                updateStatuses();

                const intervalId = setInterval(updateStatuses, 1000);

                return () => clearInterval(intervalId);
            }
        })();

        return () => cleanup.then(cleanupFn => cleanupFn && cleanupFn());
    });

    let dateNow;
    setInterval(() => {
        dateNow = Date.now();
    }, 1000);


</script>

<Seo title={"Thunder Field - NFT Laundpad on Electroneum"} description={"Thunder Field offers a free Launchpad for NFTs on Electroneum, allowing both projects and individuals to launch their NFT collections for free"} keywords={"Electroneum NFT Launchpad , launch nft, mint nft"}/>
<div class="flex font-Hoves bg-black w-full min-h-screen text-white">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <div class="flex flex-col">
            <Nav/>
            <span class="text-2xl font-semibold mt-[20px] text-blue">
                Featured by team
            </span>
            {#if !items[0].name}
                <div class="flex relative justify-center sm:h-[318px] h-[180px] mt-[30px] parent">
                    <div class="h-[318px] w-full object-cover h-full shrink-on-hover loading rounded-xl"/>
                    <div class="absolute self-end flex flex-col bg-black bg-opacity-90 sm:min-w-[400px] min-w-[300px] rounded-md mb-[-40px] px-2 py-[10px] sm:gap-[10px] gap-0 z-10 shadow-md z-10">
                        <span class="font-semibold text-2xl ml-[12px] text-blue">
                            <span>...</span>
                        </span>
                        <div class="flex gap-[10px] sm:my-0 my-[10px] ml-[12px]">
                            <div></div>
                            <div></div>
                            <div></div>
                        </div>
                        <div class="flex justify-end items-center gap-2 font-semibold text-sm text-black">
 
                        </div>
                    </div>
                </div>
            {:else}
                <a href="/mint/{items[0]?.address}">
                    <div class="flex relative justify-center sm:h-[318px] h-[180px] mt-[30px] parent">
                        <div class="flex sm:h-[318px] h-[180px] overflow-hidden w-full rounded-xl">
                            <img class="w-full object-cover h-full shrink-on-hover" src={`${config.rpcUrl}/banner/${items[0]?.address}`} alt="NFT Banner"/>
                        </div>
                        <div class="absolute self-end flex flex-col bg-darkCard bg-opacity-90 sm:min-w-[400px] min-w-[300px] rounded-md mb-[-40px] px-2 py-[10px] sm:gap-[10px] gap-0 z-10 shadow-md">
                            <span class="font-semibold text-2xl ml-[12px] text-blue">
                                {items[0].name}
                            </span>
                            <div class="flex gap-[10px] sm:my-0 my-[10px] ml-[12px]">
                                <img class=" h-[15px] inline-block" src="/icons/weblink.svg" alt="Website icon"/>
                                <img class="h-[15px]  inline-block" src="/icons/twitterX.svg" alt="Twitter/X icon"/>
                                <img class="h-[15px]  inline-block" src="/icons/discord.svg" alt="Discord icon"/>
                            </div>
                            <div class="flex justify-end items-center gap-2 font-semibold text-sm">
                                
                                {items[0].status} 
                                {#if items[0].status === "UPCOMING"}
                                    <div class="w-[13px] h-[13px] bg-[#EBB733] rounded-full">
    
                                    </div>
                                {:else if items[0].status === "LIVE"}
                                    <div class="w-[13px] h-[13px] bg-[#5DEF38] rounded-full">
    
                                    </div>
                                {:else}
                                    <div class="w-[13px] h-[13px] bg-[#635F55] rounded-full">
    
                                    </div>
                                {/if}
                            </div>
                        </div>
                    </div>
                </a>
            {/if}


            <span class="text-2xl font-semibold mt-[40px] text-blue">
                All Projects
            </span>
            <div class="flex justify-between my-[20px]">
                <div class="flex flex-wrap xl:gap-[33px] lg:gap-10 gap-4 justify-center">
                    {#each items as item, index}
                        {#if !item.name }
                            <div class=" relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-darkCard  min-h-[170px] max-h-[170px] px-2 py-2 hover:border-blue hover:border shadow-md">
                                <div class="flex items-center min-w-[322px] max-w-[322px] min-h-[95px] max-h-[95px] loading rounded-t-xl overflow-hidden">
                                    <div class="shrink-on-hover object-cover rounded-t-xl min-w-[322px] max-w-[322px] loading" alt="loading banner">
                                    </div>
                                </div>
                                <div class="flex flex-col w-full gap-[5px] ">
                                    <div class="flex flex-wrap w-full justify-between mt-[10px]">
                                        <div class="flex items-center font-bold text-blue gap-1 text-base">
                                            <div class="loading w-[100px] py-2"></div>
                                        </div>
                                        <div class="flex items-center gap-[5px]">

                                        </div>
                                    </div>
                                </div>
                            </div>
                        {:else}
                            <button on:click={()=>{goto(`/mint/${item?.address}`)}} class=" relative group parent flex flex-col gap-1 rounded-xl cursor-pointer relative bg-darkCard min-h-[170px] max-h-[170px] px-2 py-2 hover:border-blue hover:border shadow-md">
                                <div class="flex items-center min-w-[322px] max-w-[322px] min-h-[95px] max-h-[95px] bg-black rounded-t-xl overflow-hidden">
                                    <img src={`${config.rpcUrl}/banner/${item?.address}`}
                                    on:load={()=>{loadingFeatured = false}}
                                    class="shrink-on-hover object-cover rounded-t-xl min-w-[322px] max-w-[322px] {loadingFeatured?"loading":""}" alt="NFT project's banners"/>
                                </div>
                                <div class="flex flex-col w-full gap-[5px] ">
                                    <div class="flex flex-wrap w-full justify-between mt-[10px]">
                                        <div class="flex items-center font-bold text-blue gap-1 text-base">
                                            <span>{item?.name || "Loading"}</span>
                                            <img class="h-[15px] inline-block" src="/icons/verified.svg" alt="verified icon"/>
                                        </div>
                                       
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
                                <div class="flex items-center w-full justify-between ml-[0px] text-sm bottom-0">

                                </div>
                            </button>
                        {/if}
                    {/each}
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
