// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function WETH() external pure returns (address);
}

/// @title PEPETUAL Migration Vault
/// @notice Permits legacy PEPETUAL holders to redeem 1:1 for the new token while the vault
/// swaps incoming V1 for ETH to seed fresh liquidity.
contract CommunityRaiseVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable pepetualV1;
    IERC20 public immutable pepetualV2;
    IUniswapV2Router02 public immutable router;

    bytes32 public merkleRoot;

    // Tracks how much of their snapshot allowance an address has already redeemed
    mapping(address => uint256) public claimedAmount;

    uint256 public totalMigrated;
    uint256 public totalEthRecovered;

    uint256 public constant SWAP_DEADLINE_WINDOW = 600; // 10 minutes

    event MerkleRootUpdated(bytes32 previousRoot, bytes32 newRoot);
    event Migrated(address indexed account, uint256 amountV1, uint256 ethRecovered);
    event EthWithdrawn(address indexed to, uint256 amount);
    event V2Withdrawn(address indexed to, uint256 amount);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    constructor(address _v1, address _v2, address _router, bytes32 _merkleRoot) Ownable(msg.sender) {
        require(_v1 != address(0), "Invalid V1 token");
        require(_v2 != address(0), "Invalid V2 token");
        require(_router != address(0), "Invalid router");

        pepetualV1 = IERC20(_v1);
        pepetualV2 = IERC20(_v2);
        router = IUniswapV2Router02(_router);
        merkleRoot = _merkleRoot;
    }

    receive() external payable {
        require(msg.sender == address(router), "Direct ETH not allowed");
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        bytes32 previous = merkleRoot;
        merkleRoot = newRoot;
        emit MerkleRootUpdated(previous, newRoot);
    }

    function migrate(
        uint256 snapshotAmount,
        uint256 migrateAmount,
        bytes32[] calldata proof,
        uint256 minEthOut
    ) external whenNotPaused nonReentrant {
        require(merkleRoot != bytes32(0), "Merkle root unset");
        require(migrateAmount > 0, "Zero amount");

        // Verify address eligibility and total allowance
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, snapshotAmount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        uint256 alreadyClaimed = claimedAmount[msg.sender];
        require(snapshotAmount >= alreadyClaimed + migrateAmount, "Allowance exceeded");

        claimedAmount[msg.sender] = alreadyClaimed + migrateAmount;
        totalMigrated += migrateAmount;

        // Pull V1 tokens from user
        pepetualV1.safeTransferFrom(msg.sender, address(this), migrateAmount);

        // Swap V1 to ETH immediately
        uint256 ethBefore = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(pepetualV1);
        path[1] = router.WETH();

        SafeERC20.forceApprove(pepetualV1, address(router), 0);
        SafeERC20.forceApprove(pepetualV1, address(router), migrateAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            migrateAmount,
            minEthOut,
            path,
            address(this),
            block.timestamp + SWAP_DEADLINE_WINDOW
        );

        SafeERC20.forceApprove(pepetualV1, address(router), 0);

        uint256 ethAfter = address(this).balance;
        uint256 ethRecovered = ethAfter - ethBefore;
        require(ethRecovered >= minEthOut, "Insufficient ETH out");

        totalEthRecovered += ethRecovered;

        // Deliver new token 1:1
        require(
            pepetualV2.balanceOf(address(this)) >= migrateAmount,
            "Insufficient V2 liquidity"
        );
        pepetualV2.safeTransfer(msg.sender, migrateAmount);

        emit Migrated(msg.sender, migrateAmount, ethRecovered);
    }

    function withdrawEth(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(amount <= address(this).balance, "Insufficient ETH");

        (bool success,) = to.call{ value: amount }("");
        require(success, "ETH transfer failed");
        emit EthWithdrawn(to, amount);
    }

    function withdrawV2(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        pepetualV2.safeTransfer(to, amount);
        emit V2Withdrawn(to, amount);
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(token != address(pepetualV2), "Use withdrawV2");
        require(token != address(pepetualV1), "Reserved for migration");

        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    function pendingAllowance(address account, uint256 snapshotAmount)
        external
        view
        returns (uint256)
    {
        if (snapshotAmount < claimedAmount[account]) {
            return 0;
        }
        return snapshotAmount - claimedAmount[account];
    }

    function accountStatus(address account, uint256 snapshotAmount)
        external
        view
        returns (
            uint256 claimed,
            uint256 remaining,
            uint256 v2Balance,
            uint256 allowanceV1
        )
    {
        claimed = claimedAmount[account];
        remaining = snapshotAmount > claimed ? snapshotAmount - claimed : 0;
        v2Balance = pepetualV2.balanceOf(address(this));
        allowanceV1 = pepetualV1.allowance(account, address(this));
    }

    function quoteEthOut(uint256 amountIn) external view returns (uint256) {
        require(amountIn > 0, "Zero input");
        address[] memory path = new address[](2);
        path[0] = address(pepetualV1);
        path[1] = router.WETH();
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
