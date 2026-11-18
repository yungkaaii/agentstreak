/* AgentStreak frontend — static, no backend.
 * Uses ethers v6 (CDN) + the injected wallet (window.ethereum).
 * The user always confirms transactions in their own wallet.
 */

"use strict";

/* ================= CONFIG — fill in after deployment ================= */
// TODO(DEPLOY): paste the deployed AgentStreak contract address here.
const CONFIG = {
  contractAddress: "", // e.g. "0x..." — leave empty until deployed
  deployBlock: 0, // first block to scan for events; set to the deployment block after deploy
  registryAddress: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  chainId: 56, // BNB Chain mainnet
  rpcUrl: "https://bsc-rpc.publicnode.com", // read-only fallback for leaderboard/recent
  maxEventBlocks: 20000, // fallback scan window when deployBlock is 0
  chunkSize: 5000,
};
/* ====================================================================== */

const ABI = [
  "function checkIn()",
  "function isHolder(address) view returns (bool)",
  "function hasCheckedInToday(address) view returns (bool)",
  "function statsOf(address) view returns (uint64 lastCheckInDay, uint64 currentStreak, uint64 longestStreak, uint64 totalCheckIns)",
  "function liveStreak(address) view returns (uint64)",
  "function totalCheckIns() view returns (uint256)",
  "function checkInsPerDay(uint256) view returns (uint256)",
  "function currentDay() view returns (uint256)",
  "event CheckedIn(address indexed user, uint256 indexed day, uint64 streak)",
];

const $ = (id) => document.getElementById(id);
const short = (a) => a.slice(0, 6) + "…" + a.slice(-4);
const BSC_PARAMS = {
  chainId: "0x38",
  chainName: "BNB Smart Chain",
  nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
  rpcUrls: ["https://bsc-rpc.publicnode.com"],
  blockExplorerUrls: ["https://bscscan.com"],
};

let provider = null; // ethers BrowserProvider (wallet)
let signer = null;
let account = null;
let readContract = null; // read-only contract via public RPC
let writeContract = null; // wallet-connected contract

function configured() {
  return CONFIG.contractAddress && /^0x[0-9a-fA-F]{40}$/.test(CONFIG.contractAddress);
}

function initReadContract() {
  if (!configured()) return;
  const rpc = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
  readContract = new ethers.Contract(CONFIG.contractAddress, ABI, rpc);
  $("contractLabel").textContent = CONFIG.contractAddress;
  const link = $("bscscanLink");
  link.href = "https://bscscan.com/address/" + CONFIG.contractAddress;
  link.style.display = "inline";
}

async function loadPublicData() {
  if (!readContract) {
    $("leaderboard").innerHTML = '<p class="muted">Leaderboard appears once the contract is deployed.</p>';
    $("recent").innerHTML = '<p class="muted">Recent check-ins appear once the contract is deployed.</p>';
    return;
  }
  try {
    const latest = await readContract.runner.getBlockNumber();
    const fromBlock = CONFIG.deployBlock > 0
      ? CONFIG.deployBlock
      : Math.max(0, latest - CONFIG.maxEventBlocks);
    const events = [];
    for (let start = fromBlock; start <= latest; start += CONFIG.chunkSize) {
      const end = Math.min(latest, start + CONFIG.chunkSize - 1);
      const chunk = await readContract.queryFilter("CheckedIn", start, end);
      events.push(...chunk);
    }
    renderRecent(events.slice(-20).reverse());
    await renderLeaderboard(events);
  } catch (err) {
    console.error(err);
    $("leaderboard").innerHTML = '<p class="muted">Could not load on-chain data. Please refresh.</p>';
    $("recent").innerHTML = '<p class="muted">Could not load on-chain data. Please refresh.</p>';
  }
}

function renderRecent(events) {
  if (!events.length) {
    $("recent").innerHTML = '<p class="muted">No check-ins yet. Be the first.</p>';
    return;
  }
  const rows = events.map((e) => {
    const day = new Date(Number(e.args.day) * 86400 * 1000).toISOString().slice(0, 10);
    return `<tr><td class="mono">${short(e.args.user)}</td><td>${day} (UTC)</td><td>Streak ${e.args.streak}</td></tr>`;
  }).join("");
  $("recent").innerHTML = `<table><tr><th>Address</th><th>Day</th><th>Streak</th></tr>${rows}</table>`;
}

async function renderLeaderboard(events) {
  const counts = new Map();
  for (const e of events) {
    counts.set(e.args.user, (counts.get(e.args.user) || 0) + 1);
  }
  const users = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 100);
  if (!users.length) {
    $("leaderboard").innerHTML = '<p class="muted">No check-ins yet. Be the first.</p>';
    return;
  }
  const stats = await Promise.all(users.map(async ([user]) => {
    try {
      const s = await readContract.statsOf(user);
      const live = await readContract.liveStreak(user);
      return { user, longest: Number(s.longestStreak), live: Number(live), total: Number(s.totalCheckIns) };
    } catch {
      return { user, longest: 0, live: 0, total: counts.get(user) };
    }
  }));
  stats.sort((a, b) => b.longest - a.longest || b.total - a.total);
  const rows = stats.slice(0, 20).map((s, i) =>
    `<tr><td>${i + 1}</td><td class="mono">${short(s.user)}${s.user === account ? " (you)" : ""}</td>` +
    `<td>${s.longest}</td><td>${s.live}</td><td>${s.total}</td></tr>`).join("");
  $("leaderboard").innerHTML =
    `<table><tr><th>#</th><th>Address</th><th>Longest</th><th>Live streak</th><th>Check-ins</th></tr>${rows}</table>`;
}

async function refreshAccount() {
  if (!account || !writeContract) return;
  $("accountLabel").textContent = account;
  try {
    const holder = await writeContract.isHolder(account);
    const pill = $("holderPill");
    if (holder) {
      pill.textContent = "Agent ID holder ✓";
      pill.className = "pill good";
      $("holderNote").textContent = "Your address holds an Agent ID. You can check in.";
    } else {
      pill.textContent = "No Agent ID found";
      pill.className = "pill bad";
      $("holderNote").textContent = "This address does not hold an Agent ID. Check-ins require holding an Agent ID (claimed in the Binance app).";
    }
    const s = await writeContract.statsOf(account);
    const live = await writeContract.liveStreak(account);
    const total = await writeContract.totalCheckIns();
    $("statStreak").textContent = live;
    $("statLongest").textContent = s.longestStreak;
    $("statTotal").textContent = s.totalCheckIns;
    $("statGlobal").textContent = total;
    const done = await writeContract.hasCheckedInToday(account);
    const btn = $("checkinBtn");
    btn.disabled = !holder || done;
    $("checkinStatus").textContent = done
      ? "Already checked in today — come back tomorrow (UTC)."
      : holder ? "" : "Check-in is limited to Agent ID holders.";
  } catch (err) {
    console.error(err);
    $("holderNote").textContent = "Could not read contract state. Check your network and refresh.";
  }
}

async function connect() {
  if (!window.ethereum) {
    $("accountLabel").textContent = "No injected wallet found. Open this page in a wallet browser (e.g. Binance Wallet).";
    return;
  }
  provider = new ethers.BrowserProvider(window.ethereum);
  const accounts = await provider.send("eth_requestAccounts", []);
  account = accounts[0];
  signer = await provider.getSigner();
  const net = await provider.getNetwork();
  updateNetworkPill(Number(net.chainId));
  if (Number(net.chainId) !== CONFIG.chainId) {
    $("switchBox").style.display = "block";
  } else {
    $("switchBox").style.display = "none";
  }
  if (configured()) {
    writeContract = new ethers.Contract(CONFIG.contractAddress, ABI, signer);
    $("statusCard").style.display = "block";
    await refreshAccount();
  }
  window.ethereum.on("accountsChanged", () => location.reload());
  window.ethereum.on("chainChanged", () => location.reload());
}

function updateNetworkPill(chainId) {
  const pill = $("networkPill");
  if (chainId === CONFIG.chainId) {
    pill.textContent = "Network: BNB Chain ✓";
    pill.className = "pill good";
  } else {
    pill.textContent = "Network: chain " + chainId;
    pill.className = "pill bad";
  }
}

async function switchNetwork() {
  try {
    await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: BSC_PARAMS.chainId }] });
  } catch (err) {
    if (err && err.code === 4902) {
      await window.ethereum.request({ method: "wallet_addEthereumChain", params: [BSC_PARAMS] });
    } else {
      throw err;
    }
  }
}

async function checkIn() {
  if (!writeContract) return;
  const btn = $("checkinBtn");
  btn.disabled = true;
  $("checkinStatus").textContent = "Waiting for your confirmation in the wallet…";
  try {
    const tx = await writeContract.checkIn();
    $("checkinStatus").textContent = "Transaction sent: " + tx.hash + " — waiting for confirmation…";
    await tx.wait();
    $("checkinStatus").textContent = "Checked in! Streak updated.";
    await refreshAccount();
    await loadPublicData();
  } catch (err) {
    console.error(err);
    $("checkinStatus").textContent = err && err.code === "ACTION_REJECTED"
      ? "Transaction rejected in the wallet. Nothing was sent."
      : "Transaction failed: " + (err && err.reason ? err.reason : "see console");
    btn.disabled = false;
  }
}

$("connectBtn").addEventListener("click", () => connect().catch((e) => {
  console.error(e);
  $("accountLabel").textContent = "Connection failed: " + (e && e.message ? e.message : e);
}));
$("switchBtn").addEventListener("click", () => switchNetwork().catch((e) => {
  console.error(e);
  alert("Could not switch network: " + (e && e.message ? e.message : e));
}));
$("checkinBtn").addEventListener("click", checkIn);

if (!configured()) $("deployNotice").style.display = "block";
initReadContract();
loadPublicData();
