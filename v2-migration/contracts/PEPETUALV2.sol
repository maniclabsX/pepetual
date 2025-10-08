// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPondManager {
    function addToPond(uint256 pepeAmount) external;
    function updateHolderEligibility(address holder, uint256 newBalance) external;
    function paused() external view returns (bool);
}

contract PEPETUAL is ERC20, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ==================== Token Configuration ====================

    uint256 public constant MAX_TAX_RATE = 1000; // 10% maximum
    uint256 public taxRate = 969; // 9.69% default
    uint256 private constant TAX_DIVISOR = 10000;

    // Fee distribution (matching original FeeHandlerV5_PEPE)
    uint256 public constant POND_BPS = 6900; // 6.9% → Pond
    uint256 public constant PEPE_BURN_BPS = 690; // 0.69% → PEPE burn
    uint256 public constant SELF_BURN_BPS = 690; // 0.69% → PEPETUAL burn
    uint256 public constant REWARDS_BPS = 690; // 0.69% → Holder rewards
    uint256 public constant DEV_BPS = 390; // 0.39% → Dev (reduced for keeper)
    uint256 public constant KEEPER_BPS = 300; // 0.3% → Keeper gas refund (in ETH)
    uint256 public constant ART_BPS = 30; // 0.03% → Art
    uint256 public constant TOTAL_BPS = 9690; // Total must equal 9690

    // ==================== Router and Trading ====================

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    IERC20 public PEPE;
    address public immutable WETH;

    mapping(address => bool) public excludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public isLimitExempt;

    // Transfer restrictions
    bool public walletToWalletTransfersDisabled = false; // Can be toggled by owner

    // Limits
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;
    bool public limitsInEffect = true;

    // Trading control
    bool public tradingEnabled = false;

    // ==================== Rewards System ====================

    struct RewardSnapshot {
        uint256 totalSupplySnapshot;
        uint256 pepePerToken;
        uint256 timestamp;
    }

    RewardSnapshot[] public rewardSnapshots;
    mapping(address => bool) public excludedFromRewards;

    uint256 private constant REWARD_MAGNITUDE = 1e18;
    uint256 public magnifiedRewardsPerShare;
    mapping(address => int256) private magnifiedRewardCorrections;
    mapping(address => uint256) public withdrawnRewards;

    uint256 public reservedPepeForRewards; // PEPE reserved for rewards
    uint256 public totalPepeDistributed;
    uint256 public totalPepeClaimed;
    uint256 public minBalanceForRewards = 100 * 10 ** 18; // 100 tokens minimum
    uint256 public rewardClaimCooldown = 3600; // 1 hour
    mapping(address => uint256) public lastRewardClaim;

    uint256 public pendingRewardsBuffer;
    address[] private rewardExclusionList;
    mapping(address => bool) private rewardExclusionTracked;

    // ==================== Pond Integration ====================

    IPondManager public pondManager;

    // ==================== Reentrancy Protection ====================

    bool private processingFees;

    // ==================== Slippage Protection ====================

    uint256 public maxSlippageBPS = 100; // 1% default (100 basis points)

    // ==================== Fee Processing ====================

    uint256 public feeProcessingThreshold = 10000; // 0.001% of supply in basis points (10000 = 0.001%)

    // ==================== Wallets ====================

    address public devWallet;
    address public artWallet;
    address public keeper;

    uint256 public pendingPondPepe;

    // ==================== Events ====================

    event TaxRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardSnapshotTaken(
        uint256 indexed snapshotId, uint256 indexed pepePerToken, uint256 totalSupply
    );
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    event FeesProcessed(uint256 indexed rewards, uint256 indexed pond, uint256 indexed operations);
    event PondManagerUpdated(address indexed oldManager, address indexed newManager);
    event RewardsExclusionUpdated(address indexed account, bool excluded);
    event ExternalPondPepeDeposited(address indexed sender, uint256 amount, uint256 forwarded);
    event ExternalRewardsPepeDeposited(address indexed sender, uint256 amount);
    event LimitExemptionUpdated(address indexed account, bool exempt);
    event TradingEnabled(uint256 timestamp);
    event KeeperRefunded(address indexed keeper, uint256 ethAmount);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);

    // ==================== Modifiers ====================

    modifier onlyKeeperOrOwner() {
        require(msg.sender == keeper || msg.sender == owner(), "Not keeper or owner");
        _;
    }

    // ==================== Constructor ====================

    constructor(
        address router_,
        address pepe_,
        address devWallet_,
        address artWallet_,
        address pondManager_
    ) ERC20("PEPETUAL", "PEPETUAL") Ownable(msg.sender) {
        require(router_ != address(0), "Invalid router");
        require(pepe_ != address(0), "Invalid PEPE token");
        require(devWallet_ != address(0), "Invalid dev wallet");
        require(artWallet_ != address(0), "Invalid art wallet");
        // Allow temporary address for deployment
        // require(pondManager_ != address(0), "Invalid pond manager");

        uint256 totalSupply_ = 1_000_000_000 * 10 ** 18; // 1 billion tokens

        // Initialize router and pair
        uniswapV2Router = IUniswapV2Router02(router_);
        WETH = uniswapV2Router.WETH();
        PEPE = IERC20(pepe_);

        // Check if pair exists first
        address pairAddress =
            IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), WETH);
        if (pairAddress == address(0)) {
            pairAddress =
                IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), WETH);
        }

        uniswapV2Pair = pairAddress;

        automatedMarketMakerPairs[uniswapV2Pair] = true;

        // Set wallets
        devWallet = devWallet_;
        artWallet = artWallet_;
        keeper = msg.sender; // Deployer is initial keeper
        pondManager = IPondManager(pondManager_);

        // Set limits (2% of total supply)
        maxTxAmount = totalSupply_ * 200 / 10000;
        maxWalletAmount = totalSupply_ * 200 / 10000;

        // Exclude from fees and rewards
        excludedFromFees[owner()] = true;
        excludedFromFees[address(this)] = true;
        excludedFromFees[devWallet] = true;
        excludedFromFees[artWallet] = true;

        isLimitExempt[owner()] = true;
        isLimitExempt[address(this)] = true;

        excludedFromRewards[owner()] = true;
        excludedFromRewards[address(this)] = true;
        excludedFromRewards[uniswapV2Pair] = true;
        excludedFromRewards[address(0xdead)] = true;
        excludedFromRewards[devWallet] = true;
        excludedFromRewards[artWallet] = true;
        if (address(pondManager) != address(0)) {
            excludedFromRewards[address(pondManager)] = true;
        }

        _addRewardExclusion(owner());
        _addRewardExclusion(address(this));
        _addRewardExclusion(uniswapV2Pair);
        _addRewardExclusion(address(0xdead));
        _addRewardExclusion(devWallet);
        _addRewardExclusion(artWallet);
        if (address(pondManager) != address(0)) {
            _addRewardExclusion(address(pondManager));
        }

        // Approve router for swaps
        _approve(address(this), router_, type(uint256).max);

        // Mint tokens to owner
        _mint(owner(), totalSupply_);

        _syncRewardExclusion(owner(), true);
        _syncRewardExclusion(address(this), true);
        _syncRewardExclusion(uniswapV2Pair, true);
        _syncRewardExclusion(address(0xdead), true);
        _syncRewardExclusion(devWallet, true);
        _syncRewardExclusion(artWallet, true);
        if (address(pondManager) != address(0)) {
            _syncRewardExclusion(address(pondManager), true);
        }
    }

    // ==================== Core Transfer Logic ====================

    function _isTransferAllowed(address from, address to) internal view returns (bool) {
        // Always allow minting, burning, contract transfers
        if (from == address(0) || to == address(0) ||
            from == address(this) || to == address(this)) return true;

        // Always allow excluded addresses (owner, router, etc.)
        if (excludedFromFees[from] || excludedFromFees[to]) return true;

        // Always allow DEX pairs
        if (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) return true;

        // Block wallet-to-wallet if disabled
        return !walletToWalletTransfersDisabled;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(!paused(), "Token transfers paused");

        // Before trading enabled, only owner and excluded can transfer
        if (!tradingEnabled) {
            require(
                from == owner() || to == owner() ||
                excludedFromFees[from] || excludedFromFees[to],
                "Trading not enabled"
            );
        }

        // Check if transfer is allowed (prevent wallet-to-wallet to force DEX usage)
        bool isAllowedTransfer = _isTransferAllowed(from, to);
        require(isAllowedTransfer, "Wallet-to-wallet transfers disabled");

        // Apply limits
        if (
            limitsInEffect && from != owner() && to != owner() && !excludedFromFees[from]
                && !excludedFromFees[to] && !isLimitExempt[from] && !isLimitExempt[to]
        ) {
            amount = _applyLimitsAndProtections(from, to, amount);
        }

        (uint256 netAmount, uint256 feeAmount, bool takeFeeFromRecipient) =
            _calculateTax(from, to, amount);

        if (feeAmount > 0 && !takeFeeFromRecipient) {
            _executeTokenTransfer(from, address(this), feeAmount);
        }

        _executeTokenTransfer(from, to, netAmount);

        if (feeAmount > 0 && takeFeeFromRecipient) {
            _executeTokenTransfer(to, address(this), feeAmount);
        }

        // Update pond manager eligibility (skip if pond is paused to prevent transfer failures)
        if (address(pondManager) != address(0) && !pondManager.paused()) {
            if (from != address(0) && from != address(this)) {
                pondManager.updateHolderEligibility(from, balanceOf(from));
            }
            if (to != address(0) && to != address(this)) {
                pondManager.updateHolderEligibility(to, balanceOf(to));
            }
        }
    }

    function _applyLimitsAndProtections(address from, address to, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (isLimitExempt[from] || isLimitExempt[to]) {
            return amount;
        }

        // Check max transaction
        require(amount <= maxTxAmount, "Transfer amount exceeds max");

        // Check max wallet (for buys)
        if (automatedMarketMakerPairs[from] && to != address(uniswapV2Router)) {
            require(balanceOf(to) + amount <= maxWalletAmount, "Wallet would exceed max");
        }

        return amount;
    }

    function _calculateTax(address from, address to, uint256 amount)
        internal
        view
        returns (uint256 netAmount, uint256 feeAmount, bool takeFeeFromRecipient)
    {
        netAmount = amount;

        if (excludedFromFees[from]) {
            return (netAmount, 0, false);
        }

        bool isBuy = automatedMarketMakerPairs[from];
        bool isSell = automatedMarketMakerPairs[to];
        if (!isBuy && !isSell) {
            return (netAmount, 0, false);
        }

        // Always use flat tax rate
        uint256 currentTaxRate = taxRate;

        feeAmount = (amount * currentTaxRate) / TAX_DIVISOR;
        if (feeAmount == 0) {
            return (netAmount, 0, false);
        }

        takeFeeFromRecipient = isBuy;
        if (!takeFeeFromRecipient) {
            netAmount = amount - feeAmount;
        }

        return (netAmount, feeAmount, takeFeeFromRecipient);
    }

    // ==================== Token Transfer Execution ====================

    function _executeTokenTransfer(address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        super._update(from, to, amount);
        _updateRewardCorrections(from, to, amount);
    }

    function _updateRewardCorrections(address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        int256 magnifiedAmount = int256(magnifiedRewardsPerShare * amount);

        if (from == address(0)) {
            magnifiedRewardCorrections[to] -= magnifiedAmount;
        } else if (to == address(0)) {
            magnifiedRewardCorrections[from] += magnifiedAmount;
        } else {
            magnifiedRewardCorrections[from] += magnifiedAmount;
            magnifiedRewardCorrections[to] -= magnifiedAmount;
        }
    }

    function _addRewardExclusion(address account) internal {
        if (account == address(0) || rewardExclusionTracked[account]) {
            return;
        }

        rewardExclusionTracked[account] = true;
        rewardExclusionList.push(account);
    }

    function _syncRewardExclusion(address account, bool excluded) internal {
        if (account == address(0)) {
            return;
        }

        if (excluded) {
            _addRewardExclusion(account);
        }

        uint256 balance = balanceOf(account);
        int256 correction = int256(magnifiedRewardsPerShare * balance);
        magnifiedRewardCorrections[account] = -correction;
        withdrawnRewards[account] = 0;
    }

    // ==================== Fee Processing ====================

    function processFees() external nonReentrant onlyKeeperOrOwner {
        require(!processingFees, "Already processing");
        uint256 contractBalance = balanceOf(address(this));
        require(contractBalance > 0, "No fees to process");
        _processFees(contractBalance);
    }

    function shouldProcessFees() external view returns (bool) {
        uint256 contractBalance = balanceOf(address(this));
        uint256 threshold = (totalSupply() * feeProcessingThreshold) / 100000000;
        return contractBalance >= threshold;
    }

    function _processFees(uint256 amount) internal {
        // Reentrancy protection
        require(!processingFees, "Already processing fees");
        processingFees = true;

        // 1. First burn SELF_BURN portion (0.69%)
        uint256 selfBurnAmount = (amount * SELF_BURN_BPS) / TOTAL_BPS;
        if (selfBurnAmount > 0) {
            super._update(address(this), 0x000000000000000000000000000000000000dEaD, selfBurnAmount);
        }

        // 2. Calculate remaining amount after burn
        uint256 toSwap = amount - selfBurnAmount;

        if (toSwap == 0) {
            processingFees = false;
            return;
        }

        // 3. Calculate portions: keeper gets ETH, rest gets PEPE
        uint256 nonSelfBurnBPS = TOTAL_BPS - SELF_BURN_BPS; // 9000
        uint256 keeperTokens = (toSwap * KEEPER_BPS) / nonSelfBurnBPS;
        uint256 toSwapForPepe = toSwap - keeperTokens;

        // 4. Swap keeper portion to ETH
        uint256 ethForKeeper = 0;
        if (keeperTokens > 0) {
            ethForKeeper = _swapTokensForETH(keeperTokens);
        }

        // 5. Swap remaining to PEPE
        uint256 pepeReceived = 0;
        if (toSwapForPepe > 0) {
            pepeReceived = _swapTokensForPepe(toSwapForPepe);
        }

        if (pepeReceived == 0 && ethForKeeper == 0) {
            processingFees = false;
            return;
        }

        // 6. Distribute PEPE according to original ratios
        // Calculate each portion from received PEPE based on non-self-burn BPS
        uint256 pondPepe = (pepeReceived * POND_BPS) / nonSelfBurnBPS; // 6.9%
        uint256 burnPepe = (pepeReceived * PEPE_BURN_BPS) / nonSelfBurnBPS; // 0.69%
        uint256 rewardsPepe = (pepeReceived * REWARDS_BPS) / nonSelfBurnBPS; // 0.69%
        uint256 devPepe = (pepeReceived * DEV_BPS) / nonSelfBurnBPS; // 0.39%
        uint256 artPepe = (pepeReceived * ART_BPS) / nonSelfBurnBPS; // 0.03%

        // 7. Distribute PEPE

        if (pondPepe > 0) {
            pendingPondPepe += pondPepe;
        }

        uint256 pondSent = _forwardPondPepe();

        // PEPE burn (0.69%)
        if (burnPepe > 0) {
            PEPE.safeTransfer(0x000000000000000000000000000000000000dEaD, burnPepe);
        }

        // Holder rewards (0.69%)
        if (rewardsPepe > 0) {
            _distributeRewards(rewardsPepe);
        }

        // Dev wallet (0.39%)
        if (devPepe > 0) {
            PEPE.safeTransfer(devWallet, devPepe);
        }

        // Art wallet (0.03%)
        if (artPepe > 0) {
            PEPE.safeTransfer(artWallet, artPepe);
        }

        emit FeesProcessed(rewardsPepe, pondSent, devPepe + artPepe);

        // 8. Refund keeper gas in ETH
        if (ethForKeeper > 0) {
            (bool success, ) = msg.sender.call{value: ethForKeeper}("");
            require(success, "Keeper ETH refund failed");
            emit KeeperRefunded(msg.sender, ethForKeeper);
        }

        // Reset reentrancy flag
        processingFees = false;
    }

    function _forwardPondPepe() internal returns (uint256 sent) {
        if (pendingPondPepe == 0) {
            return 0;
        }

        if (address(pondManager) == address(0) || pondManager.paused()) {
            return 0;
        }

        sent = pendingPondPepe;
        pendingPondPepe = 0;
        PEPE.safeTransfer(address(pondManager), sent);
        pondManager.addToPond(sent);
    }

    function _swapTokensForPepe(uint256 tokenAmount) internal virtual returns (uint256) {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = WETH;
        path[2] = address(PEPE);

        uint256 pepeBalanceBefore = PEPE.balanceOf(address(this));

        // Get expected output amount for slippage protection
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(tokenAmount, path);
        uint256 expectedPepe = amounts[2];

        // Use configurable slippage (default 1%)
        uint256 minPepe = expectedPepe - (expectedPepe * maxSlippageBPS / 10000);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount, minPepe, path, address(this), block.timestamp + 300
        );

        return PEPE.balanceOf(address(this)) - pepeBalanceBefore;
    }

    function _swapTokensForETH(uint256 tokenAmount) internal virtual returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 ethBefore = address(this).balance;

        // Get expected output amount for slippage protection
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(tokenAmount, path);
        uint256 expectedETH = amounts[1];

        // Use configurable slippage (default 1%)
        uint256 minETH = expectedETH - (expectedETH * maxSlippageBPS / 10000);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, minETH, path, address(this), block.timestamp + 300
        );

        return address(this).balance - ethBefore;
    }

    // ==================== Rewards System ====================

    function _distributeRewards(uint256 pepeAmount) internal {
        uint256 totalRewards = pepeAmount + pendingRewardsBuffer;
        if (totalRewards == 0) {
            return;
        }

        uint256 eligibleSupply = _getEligibleSupply();
        if (eligibleSupply == 0) {
            pendingRewardsBuffer = totalRewards;
            return;
        }

        pendingRewardsBuffer = 0;

        magnifiedRewardsPerShare += (totalRewards * REWARD_MAGNITUDE) / eligibleSupply;

        uint256 pepePerToken = (totalRewards * 1e18) / eligibleSupply;

        rewardSnapshots.push(
            RewardSnapshot({
                totalSupplySnapshot: eligibleSupply,
                pepePerToken: pepePerToken,
                timestamp: block.timestamp
            })
        );

        totalPepeDistributed += totalRewards;
        reservedPepeForRewards += totalRewards;

        emit RewardSnapshotTaken(rewardSnapshots.length - 1, pepePerToken, eligibleSupply);
    }

    function _getEligibleSupply() internal view returns (uint256) {
        uint256 total = totalSupply();

        for (uint256 i = 0; i < rewardExclusionList.length; i++) {
            address account = rewardExclusionList[i];
            if (excludedFromRewards[account]) {
                total -= balanceOf(account);
            }
        }

        return total;
    }

    function claimRewards() external nonReentrant {
        require(!excludedFromRewards[msg.sender], "Excluded from rewards");
        require(balanceOf(msg.sender) >= minBalanceForRewards, "Insufficient balance");
        require(
            block.timestamp >= lastRewardClaim[msg.sender] + rewardClaimCooldown,
            "Claim cooldown active"
        );

        uint256 pending = _calculatePendingRewards(msg.sender);
        require(pending > 0, "No rewards available");
        require(pending <= reservedPepeForRewards, "Insufficient PEPE reserves");

        lastRewardClaim[msg.sender] = block.timestamp;
        withdrawnRewards[msg.sender] += pending;
        totalPepeClaimed += pending;
        reservedPepeForRewards -= pending;

        PEPE.safeTransfer(msg.sender, pending);

        emit RewardsClaimed(msg.sender, pending);
    }

    function _accumulativeRewardsOf(address account) internal view returns (uint256) {
        int256 corrected = int256(magnifiedRewardsPerShare * balanceOf(account))
            + magnifiedRewardCorrections[account];
        if (corrected <= 0) {
            return 0;
        }

        return uint256(corrected) / REWARD_MAGNITUDE;
    }

    function _calculatePendingRewards(address user) internal view returns (uint256) {
        if (excludedFromRewards[user]) {
            return 0;
        }

        uint256 userBalance = balanceOf(user);
        if (userBalance < minBalanceForRewards) {
            return 0;
        }

        uint256 accumulative = _accumulativeRewardsOf(user);
        uint256 withdrawn = withdrawnRewards[user];

        if (accumulative <= withdrawn) {
            return 0;
        }

        return accumulative - withdrawn;
    }

    function pendingRewards(address user) external view returns (uint256) {
        return _calculatePendingRewards(user);
    }

    // ==================== Admin Functions ====================

    function setTaxRate(uint256 rate) external onlyOwner {
        require(rate <= MAX_TAX_RATE, "Tax rate too high");
        uint256 oldRate = taxRate;
        taxRate = rate;
        emit TaxRateUpdated(oldRate, rate);
    }

    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        excludedFromFees[account] = excluded;
    }

    function setLimitExempt(address account, bool exempt) external onlyOwner {
        isLimitExempt[account] = exempt;
        emit LimitExemptionUpdated(account, exempt);
    }

    function setExcludedFromRewards(address account, bool excluded) external onlyOwner {
        excludedFromRewards[account] = excluded;
        _syncRewardExclusion(account, excluded);
        emit RewardsExclusionUpdated(account, excluded);
    }

    function setAMM(address pair, bool value) external onlyOwner {
        automatedMarketMakerPairs[pair] = value;
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled(block.timestamp);
    }

    function removeLimits() external onlyOwner {
        limitsInEffect = false;
    }

    function setWalletToWalletTransfers(bool disabled) external onlyOwner {
        walletToWalletTransfersDisabled = disabled;
    }

    function setLimits(uint256 maxTx, uint256 maxWallet) external onlyOwner {
        require(maxTx >= totalSupply() / 1000, "Max TX too low");
        require(maxWallet >= totalSupply() / 100, "Max wallet too low");
        maxTxAmount = maxTx;
        maxWalletAmount = maxWallet;
    }

    function setMinBalanceForRewards(uint256 rewardMin) external onlyOwner {
        minBalanceForRewards = rewardMin;
    }

    function setRewardCooldown(uint256 cooldown) external onlyOwner {
        rewardClaimCooldown = cooldown;
    }

    function setPondManager(address newPondManager) external onlyOwner {
        require(newPondManager != address(0), "Invalid pond manager");
        address oldManager = address(pondManager);
        pondManager = IPondManager(newPondManager);
        emit PondManagerUpdated(oldManager, newPondManager);

        if (oldManager != address(0)) {
            excludedFromRewards[oldManager] = false;
            _syncRewardExclusion(oldManager, false);
            emit RewardsExclusionUpdated(oldManager, false);
        }

        excludedFromRewards[newPondManager] = true;
        _syncRewardExclusion(newPondManager, true);
        emit RewardsExclusionUpdated(newPondManager, true);

        if (pendingPondPepe > 0) {
            _forwardPondPepe();
        }
    }

    // ==================== Fee Processing Admin ====================

    function setMaxSlippage(uint256 newSlippageBPS) external onlyOwner {
        require(newSlippageBPS >= 10 && newSlippageBPS <= 500, "Slippage must be 0.1% to 5%");
        maxSlippageBPS = newSlippageBPS;
    }

    function setFeeProcessingThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold >= 100, "Threshold too low");
        // No upper limit - fees can accumulate indefinitely for manual processing
        feeProcessingThreshold = newThreshold;
    }

    function setDevWallet(address newDevWallet) external onlyOwner {
        require(newDevWallet != address(0), "Invalid dev wallet");
        address oldWallet = devWallet;
        devWallet = newDevWallet;

        // Update fee exclusion
        excludedFromFees[oldWallet] = false;
        excludedFromFees[newDevWallet] = true;

        excludedFromRewards[oldWallet] = false;
        _syncRewardExclusion(oldWallet, false);
        emit RewardsExclusionUpdated(oldWallet, false);

        excludedFromRewards[newDevWallet] = true;
        _syncRewardExclusion(newDevWallet, true);
        emit RewardsExclusionUpdated(newDevWallet, true);
    }

    function setArtWallet(address newArtWallet) external onlyOwner {
        require(newArtWallet != address(0), "Invalid art wallet");
        address oldWallet = artWallet;
        artWallet = newArtWallet;

        // Update fee exclusion
        excludedFromFees[oldWallet] = false;
        excludedFromFees[newArtWallet] = true;

        excludedFromRewards[oldWallet] = false;
        _syncRewardExclusion(oldWallet, false);
        emit RewardsExclusionUpdated(oldWallet, false);

        excludedFromRewards[newArtWallet] = true;
        _syncRewardExclusion(newArtWallet, true);
        emit RewardsExclusionUpdated(newArtWallet, true);
    }

    function setKeeper(address newKeeper) external onlyOwner {
        require(newKeeper != address(0), "Invalid keeper");
        address oldKeeper = keeper;
        keeper = newKeeper;
        emit KeeperUpdated(oldKeeper, newKeeper);
    }

    function setPepeToken(address newPepe) external onlyOwner {
        require(newPepe != address(0), "Invalid PEPE address");
        require(newPepe != address(this), "Cannot be self");

        PEPE = IERC20(newPepe);
    }

    function manualProcessFees() external onlyOwner {
        uint256 balance = balanceOf(address(this));
        if (balance > 0) {
            _processFees(balance);
        }
    }

    function depositExternalPondPepe(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount zero");
        require(PEPE.balanceOf(address(this)) >= amount, "PEPE not received");

        pendingPondPepe += amount;
        uint256 forwarded = _forwardPondPepe();
        emit ExternalPondPepeDeposited(msg.sender, amount, forwarded);
    }

    function depositExternalRewardsPepe(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount zero");
        require(PEPE.balanceOf(address(this)) >= amount, "PEPE not received");

        _distributeRewards(amount);
        emit ExternalRewardsPepeDeposited(msg.sender, amount);
    }

    function flushPendingPondPepe() external onlyOwner {
        require(address(pondManager) != address(0), "Pond manager not set");
        require(pendingPondPepe > 0, "No pending pond PEPE");
        require(!pondManager.paused(), "Pond manager paused");

        uint256 forwarded = _forwardPondPepe();
        require(forwarded > 0, "Forward failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================== View Functions ====================

    function getRewardSnapshots() external view returns (RewardSnapshot[] memory) {
        return rewardSnapshots;
    }

    function getRewardsReserveInfo()
        external
        view
        returns (
            uint256 totalReserved,
            uint256 totalDistributed,
            uint256 totalClaimed,
            uint256 contractPepeBalance
        )
    {
        return (
            reservedPepeForRewards,
            totalPepeDistributed,
            totalPepeClaimed,
            PEPE.balanceOf(address(this))
        );
    }

    function isProcessingFees() external view returns (bool) {
        return processingFees;
    }

    function getUserBasicStats(address user)
        external
        view
        returns (uint256 balance, uint256 pendingRewardsAmount, bool canClaim)
    {
        balance = balanceOf(user);
        pendingRewardsAmount = _calculatePendingRewards(user);
        canClaim = block.timestamp >= lastRewardClaim[user] + rewardClaimCooldown
            && pendingRewardsAmount > 0 && balance >= minBalanceForRewards;
    }

    receive() external payable { }
}
