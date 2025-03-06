<script>
    import { slide } from 'svelte/transition';
    import { fade } from 'svelte/transition'; 
    import { goto } from '$app/navigation';
    import { onMount, onDestroy } from 'svelte';
    import { ethers } from "ethers";
    import {emitBetweenText} from '$lib/index.js';
    import config from "$lib/config.js";
    
    let chainChoose = false;
    let searchList = [];
    let searchText = "";
    let searchedList = [];

    let navMenu = false;
    let isLogin = false;
    let showLoginPanel= false;
    let searchMenu = false;

    let connectToMetamask;

    let address = "";

    onMount(() => {
        // Connect to metamask
		connectToMetamask = async function() {
            // Handle the case where user might not have a Electroneum wallet installed
            if (!window.ethereum) {
                window.open("https://chromewebstore.google.com/detail/metamask/nkbihfbeogaeaoehlefnkodbefgpgknn", "_blank");
                return;
            }

			// Switch network to Electroneum
            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: config.chainId }],
                });
            } catch (error) {
                if (error.code === 4902) {
                    // Electroneum has not been added, we will add here
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
            console.log("log in")
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

        (async function getSearchList() {
            const response = await fetch(config.rpcUrl, {
				method: "POST",
				body: JSON.stringify({
					method: "getSearchList",
					params: {}
				}),
				headers: {
					"Content-Type": "application/json"
				}
			});
            
            if (response.ok) {
                const responseBody = await response.json();

                searchList = responseBody.payload.searchlist;


            } else {
				const responseBody = await response.json();

				if (responseBody.error && responseBody.error.message) {
					throw new Error(responseBody.error.message);
				}
			}
        })();
    });

    let dropdown;

    function handleClickOutside(event) {
        if (!dropdown.contains(event.target)) {
            searchedList = [];
        }
    }

    onMount(() => {
        document.addEventListener("click", handleClickOutside);

        return () => {
            // Cleanup function that removes the event listener
            document.removeEventListener("click", handleClickOutside);
        };
    });

    function levenshtein(str1, str2) {
        const m = str1.length;
        const n = str2.length;
    
        const dp = new Array(m + 1).fill(null).map(() => new Array(n + 1).fill(0));
    
        // Initialize the first row 
        // and column of the matrix
        for (let i = 0; i <= m; i++) {
            dp[i][0] = i;
        }
        for (let j = 0; j <= n; j++) {
            dp[0][j] = j;
        }
        
        for (let i = 1; i <= m; i++) {
            for (let j = 1; j <= n; j++) {
                if (str1[i - 1] === str2[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1];
                } else {
                    dp[i][j] = 1 + Math.min(
                        // Insert
                        dp[i][j - 1],
                        Math.min(
                            // Remove
                            dp[i - 1][j],
                            // Replace
                            dp[i - 1][j - 1]
                        )
                    );
                }
            }
        }
        return dp[m][n];
    }

    function search(text, searchList) {
        const points = {};
    
        if (text.startsWith("0x")) {
            for (const item of searchList) {
                points[item.address] = 0;

                for (let index = 0; index < text.length; index++) {
                    if (item.address.toLowerCase()[index] === text.toLowerCase()[index]) {
                        points[item.address]++;
                    } else {
                        break;
                    }
                }
            }

            return searchList.sort((a, b) => {
                if (points[a.address] > points[b.address]) return -1;
                if (points[a.address] < points[b.address]) return 1;
                return 0;
            }).slice(0, 5);
        } else {
            const maxLength = Math.max(...searchList.map(item => item.name.length));

            for (const item of searchList) {
                points[item.address] = levenshtein(text.toLowerCase(), item.name.toLowerCase().padEnd(maxLength, " "));
            }

            return searchList.sort((a, b) => {
                if (points[a.address] < points[b.address]) return -1;
                if (points[a.address] > points[b.address]) return 1;
                return 0;
            }).slice(0, 5);
        }
    }

</script>

<!--Nav bar-->
    <div class="flex justify-between items-center lg:gap-[30px] gap-[10px] py-2 z-30 text-sm ">
        <!--Logo-->
        <button class="flex items-center gap-[5px]" on:click={() =>goto('/')}>
            <img class="h-10 inline-block" src="/logo.png"  alt="logo"/>
            <span class="font-semibold text-white">
                Thunder Field
            </span>
        </button>
        <!--Big screen items-->
        <div class="lg:flex hidden items-center  md:gap-[20px] gap-[3px]"> 
            <button class=" text-white font-semibold hover:text-buttonHover" on:click={() => goto('/collections')}>
                Collections
            </button>
            <button class=" text-white hover:text-buttonHover font-semibold" on:click={() => goto('/mint')}>
                Launchpad
            </button>
            <button class=" text-white font-semibold hover:text-buttonHover" on:click={() => goto('/nftarena')}>
                PvP Game
            </button>
        </div>
        <!--Big screen Search bar-->
        <div bind:this={dropdown} class="relative sm:flex flex-col hidden sm:flex-grow rounded-lg items-center bg-white text-black shadow-md">
            <div class="flex flex-grow w-full items-center text-white ">
                <img class="h-[20px] m-2" src="/icons/search1.svg" alt=""/>
                <input bind:value={searchText} class=" w-full py-1 px-2 text-black bg-white bg-opacity-50" placeholder="Seach by collections"
                on:input={() => {
                    if (searchText.length !== 0) {
                        searchedList = search(searchText, searchList);   
                    } else {
                        searchedList = [];
                    }
                }}
                />
            </div>
            <!--Search result-->
            <div class="absolute z-10 flex flex-col w-full bg-darkButton text-white mt-[40px] rounded-md shadow-md">
                {#each searchedList as searchResult}
                    <button on:click={() => {
                        window.open(`${config.site}/collections/${searchResult.address}`, "_blank");
                    }} class="flex items-center justify-start rounded-lg my-[5px] ml-[32px] mr-[30px] py-[7px] hover:bg-[#E8EBED] gap-[10px]">
                        <img src={`${config.rpcUrl}/logo/${searchResult.address}/200/200`} class="h-10 w-10 overflow-hidden rounded-full" alt="searched NFT"/>
                        
                        <span class="font-semibold text-button">
                            {searchResult.name}
                        </span>
                    </button>
                {/each}
            </div>
        </div>

        <!--Big screen items-->
        <div class="lg:flex hidden items-center gap-[10px] mr-[4px] font-semibold">      
            <div class="relative flex flex-col">
                <div class="bg-white font-md text-white px-4 w-[135px] rounded-md pb-[1px]">
                    <img src="/electroneum-logo-dark.svg" class="h-[25px]"/>
                </div>
            </div>
            <div class="relative flex flex-col">

            </div>
        </div>
        <!--items-->
        <div class="flex items-center sm:gap-2 gap-[5px]">
            <!--small screen Search button-->
            <button class="sm:hidden flex sm:flex-grow rounded-lg items-center " on:click={()=>{searchMenu = true}}>
                <img class="h-[20px]" src="/icons/search1.svg" alt="search icon"/>
            </button>

            
            {#if isLogin}
                <button class="flex text-darkGray pr-2 pl-4 h-fit"  on:mousemove={()=>{showLoginPanel = true}} on:mouseleave={()=>{showLoginPanel = false}}>
                    <div class={`h-[30px] w-[30px] rounded-full bg-lightYellow shadow-md`}>
                    </div>
                    <!--popup loginpanel-->
                    {#if showLoginPanel}
                        <!-- svelte-ignore a11y-no-static-element-interactions -->
                        <div class="flex flex-col gap-[10px] absolute z-30 sm:min-w-[320px] shadow-md sm:w-fit w-full right-0 bg-darkCard mr-[32px] mt-[30px] py-[10px] px-[15px] rounded-md" on:mousemove={()=>{showLoginPanel = true}} on:mouseleave={()=>{showLoginPanel = false}} in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
                            <div class="flex items-center gap-[10px]">
                                <div class={`h-[35px] w-[35px] rounded-full bg-lightYellow shadow-md`}></div>
                                <div class="flex flex-col items-start gap-[0px]">
                                    <span class="text-xs">Address</span>
                                    <span class="font-semibold text-blue"> {emitBetweenText(address, 10)}</span>
                                </div>
                            </div>
                            <!--Profile-->
                            <button class="flex items-center w-full justify-between text-white hover:text-blue mt-[5px] fill-white hover:fill-blue" on:click={()=>{goto(`/${address}`)}}>
                                <div class=" flex items-center font-semibold gap-[10px] fill-inherit">
                                    <svg class="h-[15px] ml-[16px] fill-inherit" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
                                        <path class="fill-inherit" fill-rule="evenodd" clip-rule="evenodd" d="M21.5313 23.4H4.46963C3.55132 23.4 2.8732 22.4939 3.21955 21.6606C4.82659 17.8074 8.60201 15.6 12.9998 15.6C17.3989 15.6 21.1743 17.8074 22.7814 21.6606C23.1277 22.4939 22.4496 23.4 21.5313 23.4ZM7.69167 7.79999C7.69167 4.93218 10.0737 2.59998 12.9998 2.59998C15.9272 2.59998 18.3079 4.93218 18.3079 7.79999C18.3079 10.6678 15.9272 13 12.9998 13C10.0737 13 7.69167 10.6678 7.69167 7.79999ZM25.9424 22.9268C24.9776 18.5601 21.9599 15.3374 17.9881 13.8749C20.0928 12.2148 21.3203 9.53022 20.8691 6.59092C20.3463 3.18101 17.4507 0.45237 13.9553 0.05457C9.13018 -0.49533 5.03759 3.18368 5.03759 7.79999C5.03759 10.257 6.20008 12.4462 8.01281 13.8749C4.03966 15.3374 1.02331 18.5601 0.0572312 22.9268C-0.293106 24.5141 1.0127 26 2.67016 26H23.3294C24.9882 26 26.294 24.5141 25.9424 22.9268Z"/>
                                    </svg>                   
                                    <span class="ml-1 text-inherit"> Profile </span>
                                </div>
                                <img class="h-[15px] inline-block " src="/icons/next.svg" alt="enter profile page"/>
                            </button>

                        </div>
                    {/if}
                </button>
            {:else}
                <button on:click={() => connectToMetamask()} class="flex text-white font-semibold bg-button hover:bg-buttonHover rounded-lg sm:py-[4px] py-0.5 px-2 ">
                    Connect Wallet
                </button>
            {/if}
            <button class="lg:hidden flex fill-darkGray lg:min-w-[125px]" on:click={()=>{navMenu = !navMenu}}>
                <svg class="sm:h-6 h-[20px] stroke-inherit	fill-inherit"  viewBox="0 -2 28 28">
                    <path class="stroke-inherit	fill-inherit" d="m2.61 0h22.431c1.441 0 2.61 1.168 2.61 2.61s-1.168 2.61-2.61 2.61h-22.431c-1.441 0-2.61-1.168-2.61-2.61s1.168-2.61 2.61-2.61z"/>
                    <path class="stroke-inherit	fill-inherit" d="m2.61 9.39h22.431c1.441 0 2.61 1.168 2.61 2.61s-1.168 2.61-2.61 2.61h-22.431c-1.441 0-2.61-1.168-2.61-2.61s1.168-2.61 2.61-2.61z"/>
                    <path class="stroke-inherit	fill-inherit" d="m2.61 18.781h22.431c1.441 0 2.61 1.168 2.61 2.61s-1.168 2.61-2.61 2.61h-22.431c-1.441 0-2.61-1.168-2.61-2.61s1.168-2.61 2.61-2.61z"/>
                </svg>
            </button> 
        </div>
    </div>
<!--Mobile Nav menu-->
{#if navMenu}
    <div class="absolute fixed font-semibold flex flex-col inset-0 bg-white bg-opacity-60 z-20 mt-[50px] text-black" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
        <button class=" flex text-xl py-1 bg-white  flex justify-center "  on:click={() =>goto(`/collections`)}  in:fade={{ duration: 300 }} out:fade={{ duration: 300 }}>
            Collections
        </button>
        <button class=" flex text-xl py-1 bg-white flex justify-center" on:click={() =>goto(`/nftarena`)} in:fade={{ duration: 400 }} out:fade={{ duration: 400 }}>
            PvP game
        </button> 
        <button class=" flex text-xl py-1 bg-white flex justify-center " on:click={() =>goto(`/mint`)} in:fade={{ duration: 400 }} out:fade={{ duration: 400 }}>
            Launchpad
        </button>

    </div>
{/if}


<!--Search Menu-->
{#if searchMenu}
    <div class="absolute fixed font-semibold flex flex-col inset-0 bg-greenYellow bg-opacity-60 z-30 min-h-screen" in:fade={{ duration: 200 }} out:fade={{ duration: 200 }}>
        <div class="flex flex-col sm:w-[300px] w-full min-h-screen px-4 pt-4 self-end bg-greenYellow overflow-y-scroll hide-scrollbar " in:slide={{ duration: 300, y: 300 }} out:slide={{ duration: 300, y: 300 }}>
            <div class="flex items-center justify-between w-full bg-white shadow-md rounded-lg">
                <div class="flex flex-grow rounded-lg items-center bg-white">
                    <img class="h-[20px] m-2" src="/icons/search1.svg" alt="search icon"/>
                    <input bind:value={searchText} class=" w-full bg-white text-black" placeholder="  Seach by collections/contracts"
                    on:input={() => {
                        if (searchText.length !== 0) {
                            searchedList = search(searchText, searchList);   
                        } else {
                            searchedList = [];
                        }
                    }}/>
                </div>
                <button class="px-2" on:click={()=>{searchMenu = false}}>
                    <img class="h-[15px] inline-block" src="/icons/xSM.svg" alt="small coin icon"/>
                </button>
            </div>
            <!--Search result-->
            <div class="flex flex-col w-full bg-white shadow-md rounded-md mt-[10px]">
                {#each searchedList as searchResult}
                    <button on:click={() => {
                        window.open(`${config.site}/collections/${searchResult.address}`, "_blank");
                    }} class="flex items-center justify-start rounded-lg my-[5px] ml-[32px] mr-[30px] py-[7px] hover:bg-black gap-[10px]">
                        <img src={`${config.rpcUrl}/logo/${searchResult.address}/200/200`} class="h-10 w-10 overflow-hidden rounded-full" alt="searched NFT"/>
                        
                        <span class="font-semibold text-button">
                            {searchResult.name}
                        </span>
                    </button>
                {/each}

            </div>
        </div>
    </div>
{/if}