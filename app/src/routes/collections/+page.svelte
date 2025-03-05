<script>
    import Seo from '$lib/Seo.svelte';
    import { slide } from 'svelte/transition';
    import { goto } from '$app/navigation';
    import Nav from "../Nav.svelte";
    import { erc721ABI, erc721Bytecode } from "$lib/contract.config.js";
    import { onMount } from 'svelte';
    import { ethers } from "ethers";
    import config from "$lib/config.js";

    let dropdownFilter = "Highest volume";
    let dropdownFilterClicked = false;
    let loading = true;
    let collections = [];
    
    let loadingCollections=[{},{},{},{},{},{},{},{},{},{}];
    
    onMount(() => {
        (async function getCollections() {
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

                await getCollectionsInfo(responseBody.payload.featuredList.filter(el => el));
            } else {
                const responseBody = await response.json();

                if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
				}
            }
        })();

        async function getCollectionsInfo(addresses) {
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
                
                collections = responseBody.payload.collectionInfos;

                loading = false;
			} else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
                    throw new Error(responseBody.error.message);
				}
			}
        }
    });

    function bigIntToFloat(number) {
        const natural = number / 10n ** 18n;
        const decimal = number % 10n ** 18n;

        return parseFloat(natural.toString() + "." + decimal.toString().padStart(18, "0"));
    }
    //loading image
    let imgLoad = true;
</script>

<Seo title={"Thunder Field - NFT Collections on Electroneum"} description={"Discover and trade NFT collections on Thunder Field, NFT marketplace on Electroneum. Start your journey with us today!"} keywords={"Electroneum, NFT , Collections, Thunder Field"}/>
<div class="flex font-Hoves bg-black w-full min-h-screen text-white">
    <div class="flex flex-col w-full max-w-screen-2xl mx-auto sm:px-[33px] px-[10px]">
        <div class="flex flex-col gap-[10px]">
            <Nav/>
            <span class="text-4xl font-semibold mt-[40px] text-blue">
                Collections
            </span>
            <span class="text-white">
                Explore NFT collections, ranked by volume
            </span>
            <div class="flex flex-wrap justify-between gap-2">

            </div>
            <!--Table-->
            {#if loading}
                <div class="flex flex-col text-sm rounded-md text-left w-full pb-[15px]">
                    <!--Header-->
                    <div class="flex justify-between text-lightGray pb-[12px] w-full border-lightGray px-4" >
                        <div class="flex  flex-grow   w-[30%] ml-2">
                            <span class="ml-[18px]">Collections</span>
                        </div>
                        <div class="md:flex hidden  flex-grow   w-[15%]">Floor price</div>
                        <!--<div class="md:flex hidden  flex-grow w-[10%]">Items</div>-->
                        <div class="lg:flex hidden  flex-grow   w-[10%]">Listed</div>
                        <div class="flex  flex-grow sm:justify-start  justify-end   w-[15%]">Volume</div>
                    </div>
                    <!--Body-->
                    <div class="rounded-b-sm">
                        <!--Row-->
                        {#each loadingCollections as collection, index}
                            <div class="flex justify-between items-center hover:text-yellow-500 px-4 py-[10px] mb-[10px] bg-darkCard hover:bg-darkCardHover rounded-xl " in:slide={{ duration: 300, y: 300 }}>
                                <!--Collections-->
                                <button class="flex  flex-grow items-center sm:w-[30%]">
                                    <!--Index-->
                                    <span class="ml-2">
                                        {index + 1}
                                    </span>
                                    <!--Items image-->
                                    <div class="h-[50px] w-[50px] loading inline-block ml-[15px] rounded-full">
                                    </div>
                                    <!--Collection name-->
                                    <div class="font-semibold ml-[10px] ">
                                        
                                    </div>
                                    <!--Verified-->
                                    <div></div>
                                </button>
                                <!--Floor price-->
                                <div class="md:flex  flex-grow hidden items-center w-[15%]">
                                    <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                    <!--Offer value-->
                                    <span class=" font-semibold">

                                    </span>
                                </div>
                                <!--Items-->
                                <!--<div class="md:flex  flex-grow hidden items-center w-[10%]">
                                    <span class=" font-semibold">
                                        10-ex
                                    </span>
                                </div>-->
                                <!--Listed-->
                                <div class="lg:flex  flex-grow hidden items-center w-[10%] ">
                                    ...
                                </div>
                                <!--Volume-->
                                <div class="flex sm:justify-start  justify-end  flex-grow items-center sm:w-[15%]">
                                    <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                    <!--Offer value-->
                                    <span class=" font-semibold">

                                    </span>
                                </div>
                            </div>
                        {/each}
                    </div>
                </div>
            {:else}
                <div class="flex flex-col text-sm rounded-md text-left w-full pb-[15px]">
                    <!--Header-->
                    <div class="flex justify-between text-lightGray pb-[12px] w-full border-lightGray px-4" >
                        <div class="flex  flex-grow   w-[30%] ml-2">
                            <span class="ml-[18px]">Collections</span>
                        </div>
                        <div class="md:flex hidden  flex-grow   w-[15%]">Floor price</div>
                        <!--<div class="md:flex hidden  flex-grow w-[10%]">Items</div>-->
                        <div class="lg:flex hidden  flex-grow   w-[10%]">Listed</div>
                        <div class="flex  flex-grow sm:justify-start  justify-end   w-[15%]">Volume</div>
                    </div>
                    <!--Body-->
                    <div class="rounded-b-sm">
                        <!--Row-->
                        {#each collections as collection, index}
                            <div class="flex justify-between items-center hover:text-yellow-500 px-4 py-[10px] mb-[10px] bg-darkCard hover:bg-darkCardHover rounded-xl " >
                                <!--Collections-->
                                <button on:click={() => goto(`./collections/${collection.address}`)} class="flex  flex-grow items-center sm:w-[30%]">
                                    <!--Index-->
                                    <span class="ml-2">
                                        {index + 1}
                                    </span>
                                    <!--Items image-->
                                    <img class="h-[50px] w-[50px] {imgLoad? "loading":""} inline-block ml-[15px] rounded-full" src="{config.rpcUrl}/logo/{collection.address}/200/200"
                                    on:load={()=>{imgLoad = false}} alt="NFT collection's avatar"/>
                                    <!--Collection name-->
                                    <span class="font-semibold ml-[10px]">
                                        {collection.name}
                                    </span>
                                    <!--Verified-->
                                    <img src="/icons/verified.svg" class="h-[20px] ml-[5px]" alt="verified icon"/>
                                </button>
                                <!--Floor price-->
                                <div class="md:flex  flex-grow hidden items-center w-[15%]">
                                    <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                    <!--Offer value-->
                                    <span class=" font-semibold">{bigIntToFloat(BigInt(collection.floorPrice))}</span>
                                </div>
                                <!--Items-->
                                <!--<div class="md:flex  flex-grow hidden items-center w-[10%]">
                                    <span class=" font-semibold">
                                        10-ex
                                    </span>
                                </div>-->
                                <!--Listed-->
                                <div class="lg:flex  flex-grow hidden items-center w-[10%]">
                                    {collection.listed}
                                </div>
                                <!--Volume-->
                                <div class="flex sm:justify-start  justify-end  flex-grow items-center sm:w-[15%]">
                                    <img class="h-[25px]  inline-block mr-[5px]" src="/icons/ETNsm.png" alt="small coin icon"/>
                                    <!--Offer value-->
                                    
                                    
                                    {#if collection.volumn == ""}
                                        <span class=" font-semibold">
                                            Loading
                                        </span>
                                    {:else}
                                        <span class=" font-semibold">
                                            {bigIntToFloat(BigInt(collection.volume))}
                                        </span>
                                    {/if }
                                </div>
                            </div>
                        {/each}
                    </div>
                </div>
            {/if}

        </div>
    </div>
</div>
