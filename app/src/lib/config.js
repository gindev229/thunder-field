const mode = "mainnet";

export default {
    rpcUrl: mode === "mainnet" ? "https://api.thunderfield.xyz" : "",
    indexerUrl: mode === "mainnet" ? "https://indexer.thunderfield.xyz" : "",
    chainId: mode === "mainnet" ? "0xcb2e" : "",
    ethRpcUrl: mode === "mainnet" ? "https://rpc.electroneum.com/" : "",
    chainName: mode === "mainnet" ? "Electroneum" : "Electroneum Testnet",
    nativeCurrency: {
        name: "ETN",
        symbol: "ETN",
        decimals: 18
    },
    blockExplorerUrls: "https://blockexplorer.electroneum.com/",
    site: "https://thunderfield.xyz",
    twitter: "https://x.com/thunder_field_x"
}


