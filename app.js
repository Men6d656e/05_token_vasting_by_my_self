/**
 * @fileOverview Application logic for the Token Vesting DApp.
 */

import { CONTRACT_CONFIG } from './config.js';

let provider, signer, tokenContract, vestingContract, userAddress, contractOwner;

const connectWalletBtn = document.getElementById('connectWallet');
const dashboardView = document.getElementById('dashboard');
const welcomeMessage = document.getElementById('welcome-message');
const adminPanel = document.getElementById('admin-panel');
const schedulesContainer = document.getElementById('schedules-container');
const createScheduleForm = document.getElementById('createScheduleForm');

const customNotification = document.getElementById('custom-notification');
const notificationText = document.getElementById('notification-text');
const notificationIcon = document.getElementById('notification-icon');

function showNotification(message, type = 'error') {
    notificationText.innerText = message;
    notificationIcon.innerText = type === 'success' ? '✅' : '⚠️';
    customNotification.style.background = type === 'success' ? 'rgba(16, 185, 129, 0.9)' : 'rgba(220, 38, 38, 0.9)';
    customNotification.classList.add('show');
    setTimeout(() => customNotification.classList.remove('show'), 5000);
}

window.addEventListener('DOMContentLoaded', () => {
    if (connectWalletBtn) connectWalletBtn.addEventListener('click', connectWallet);
    if (createScheduleForm) createScheduleForm.addEventListener('submit', handleCreateSchedule);
});

async function connectWallet() {
    if (typeof window.ethereum === 'undefined') {
        showNotification("No Web3 wallet detected! Please install MetaMask.");
        return;
    }

    try {
        provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer = provider.getSigner();
        userAddress = await signer.getAddress();
        
        connectWalletBtn.innerText = `🟢 ${userAddress.substring(0, 6)}...${userAddress.substring(38)}`;
        welcomeMessage.classList.add('hidden');
        dashboardView.classList.remove('hidden');
        
        tokenContract = new ethers.Contract(CONTRACT_CONFIG.tokenAddress, CONTRACT_CONFIG.tokenAbi, signer);
        vestingContract = new ethers.Contract(CONTRACT_CONFIG.vestingAddress, CONTRACT_CONFIG.vestingAbi, signer);
        
        document.getElementById('contractNet').innerText = CONTRACT_CONFIG.network.toUpperCase();
        document.getElementById('tokenAddr').innerText = CONTRACT_CONFIG.tokenAddress;
        document.getElementById('vestingAddr').innerText = CONTRACT_CONFIG.vestingAddress;
        
        // Check if user is owner
        contractOwner = await vestingContract.owner();
        if (userAddress.toLowerCase() === contractOwner.toLowerCase()) {
            adminPanel.classList.remove('hidden');
        }

        await fetchSchedules();
        
    } catch (err) {
        console.error(err);
        showNotification("Wallet connection failed.");
    }
}

async function handleCreateSchedule(e) {
    e.preventDefault();
    const beneficiary = document.getElementById('beneficiaryInput').value;
    const amount = ethers.utils.parseUnits(document.getElementById('amountInput').value, 18);
    const start = document.getElementById('startInput').value;
    const cliff = document.getElementById('cliffInput').value;
    const duration = document.getElementById('durationInput').value;

    const btn = document.getElementById('createBtn');
    btn.innerText = "Deploying...";
    btn.disabled = true;

    try {
        // First, approve the Vesting Contract to spend the tokens
        showNotification("Requesting token approval...", "success");
        const approveTx = await tokenContract.approve(vestingContract.address, amount);
        await approveTx.wait();

        // Now deploy the schedule
        showNotification("Approval confirmed! Deploying schedule...", "success");
        const tx = await vestingContract.createVestingSchedule(beneficiary, start, cliff, duration, amount);
        showNotification("Transaction submitted. Waiting for confirmation...", "success");
        await tx.wait();
        
        showNotification("Vesting Schedule Deployed!", "success");
        createScheduleForm.reset();
        await fetchSchedules();
    } catch (err) {
        console.error(err);
        showNotification(err.reason || err.message || "Failed to create schedule.");
    } finally {
        btn.innerText = "Deploy Schedule";
        btn.disabled = false;
    }
}

async function fetchSchedules() {
    try {
        const count = await vestingContract.getSchedulesCount();
        schedulesContainer.innerHTML = '';
        let found = false;

        for (let i = 0; i < count; i++) {
            const scheduleId = await vestingContract.scheduleIds(i);
            const schedule = await vestingContract.getVestingSchedule(scheduleId);
            
            // Show if user is beneficiary OR user is owner
            if (schedule.beneficiary.toLowerCase() === userAddress.toLowerCase() || userAddress.toLowerCase() === contractOwner.toLowerCase()) {
                found = true;
                const releasable = await vestingContract.calculateReleasableAmount(schedule);
                
                const card = document.createElement('div');
                card.className = 'schedule-card';
                card.innerHTML = `
                    <div class="schedule-header">
                        <span class="schedule-id">${scheduleId.substring(0, 10)}...</span>
                        <span class="badge ${releasable.gt(0) ? 'badge-active' : 'badge-idle'}">
                            ${releasable.gt(0) ? 'Claimable' : 'Locked'}
                        </span>
                    </div>
                    <div class="schedule-stats">
                        <p><strong>Beneficiary:</strong> <span class="address-small">${schedule.beneficiary.substring(0,6)}...${schedule.beneficiary.substring(38)}</span></p>
                        <p><strong>Total Amount:</strong> ${ethers.utils.formatUnits(schedule.totalAmount, 18)} VTT</p>
                        <p><strong>Released:</strong> ${ethers.utils.formatUnits(schedule.releasedAmount, 18)} VTT</p>
                        <p><strong>Available:</strong> <span style="color:var(--accent-glow)">${ethers.utils.formatUnits(releasable, 18)} VTT</span></p>
                    </div>
                    <button class="btn claim-btn" data-id="${scheduleId}" ${releasable.eq(0) ? 'disabled' : ''} style="width:100%; margin-top:1rem; padding: 0.5rem;">
                        ${releasable.gt(0) ? 'Claim Tokens' : 'Nothing to Claim'}
                    </button>
                `;
                schedulesContainer.appendChild(card);
            }
        }

        if (!found) {
            schedulesContainer.innerHTML = `<div style="text-align: center; padding: 2rem; color: var(--text-secondary); width: 100%;">No active schedules found for your address.</div>`;
        } else {
            // Attach claim listeners
            document.querySelectorAll('.claim-btn').forEach(btn => {
                btn.addEventListener('click', async (e) => {
                    const id = e.target.getAttribute('data-id');
                    e.target.innerText = "Claiming...";
                    e.target.disabled = true;
                    try {
                        const tx = await vestingContract.claimTokens(id);
                        showNotification("Claim submitted. Waiting for confirmation...", "success");
                        await tx.wait();
                        showNotification("Tokens claimed successfully!", "success");
                        await fetchSchedules();
                    } catch (err) {
                        console.error(err);
                        showNotification(err.reason || "Claim failed.");
                        e.target.innerText = "Claim Tokens";
                        e.target.disabled = false;
                    }
                });
            });
        }
    } catch (err) {
        console.error("Error fetching schedules", err);
    }
}
