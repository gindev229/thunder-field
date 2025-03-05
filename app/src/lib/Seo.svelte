<script>
  import { page } from '$app/stores';
  import { derived } from 'svelte/store';

  // Default values
  let defaultTitle = "Thunder Field - Electroneum NFT Marketplace";
  let defaultDescription = "Thunder Field is a Marketplace, Launchpad and PvP game for NFTs on Electroneum";
  let defaultKeyword = "Electroneum NFT Marketplace, Electroneum NFT Launchpad, AI"
  // Base URL for your site
  const baseUrl = "https://thunderfield.xyz";

  // Derive the full URL for the current page
  const url = derived(page, $page => `${baseUrl}${$page.url.pathname}`);

  // Reactive variables for SEO
  export let title;
  export let description;
  export let keywords;
  // Update values based on the page
  $: {
    title = title || defaultTitle;
    description = description || defaultDescription;
    keywords  = keywords || defaultKeyword;
  }
</script>

<svelte:head>
  <!-- Canonical Tag -->
  <link rel="canonical" href={$url} />

  <!-- Primary Meta Tags -->
  <title>{title}</title>
  <meta name="title" content={title} />
  <meta name="description" content={description} />
</svelte:head>

