// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BuybackCircuitV2 — Signal Processor buyback-and-burn circuit (Uniswap V2)
/// @notice Registered at IGNIX launch as one of the Tax Distribution Vault's
///         creator-share recipients. The platform auto-pays a recipient once
///         its claimable amount exceeds $1 (no signature needed). When the
///         contract's accumulated OKB tax reaches THRESHOLD, anyone can call
///         execute(): wrap OKB to WOKB → swap to SPROC on the official
///         Uniswap V2 → send everything to the burn address.
/// @dev Security: no withdrawal backdoor, no upgrades. The deployer's only
///      privilege is a one-time setSPROC() (SPROC did not exist before the
///      processor launch, so the circuit had to be deployed first); after it
///      is set the privilege is permanently burned. Funds can only be burned.
/// @dev Taxed tokens graduate into Uniswap V2 (per IGNIX docs), so the swap
///      uses X Layer's official Uniswap V2 Router02. SPROC is a
///      fee-on-transfer token (3% buy tax), so the swap must use
///      swapExactTokensForTokensSupportingFeeOnTransferTokens; minOut is
///      quoted off-chain by the keeper as slippage protection.

interface IWOKB {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @notice Uniswap V2 Router02 (official X Layer deployment)
/// @dev Only the fee-on-transfer-safe swap is needed; SPROC's 3% buy tax
///      would break the plain swapExactTokensForTokens output check
interface IV2Router {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract BuybackCircuitV2 {
    /// @notice SPROC token address. Set once by the deployer after launch
    ///         via setSPROC(), then permanently locked
    address public sproc;
    /// @notice Deployer address: the only address that may call setSPROC(),
    ///         exactly once
    address public immutable DEPLOYER;
    /// @notice WOKB on X Layer
    address public immutable WOKB;
    /// @notice Official Uniswap V2 Router02 on X Layer
    address public immutable V2_ROUTER;
    /// @notice Trigger threshold in wei (denominated in OKB). execute()
    ///         reverts below it so tiny swaps are not eaten by gas
    uint256 public immutable THRESHOLD;

    address public constant BURN = 0x000000000000000000000000000000000000dEaD;

    event BuybackExecuted(uint256 okbIn, uint256 sprocBurned, address indexed keeper);
    event SPROCSet(address indexed sproc);

    /// @param wokb      WOKB contract address
    /// @param v2Router  Official Uniswap V2 Router02 on X Layer
    /// @param threshold Trigger threshold (wei). Initial value: 5 OKB = 5e18
    /// @dev Deploy order: BuybackCircuitV2 BEFORE the processor launch (the
    ///      vault recipient list is locked at launch), so the constructor
    ///      takes no SPROC address; the deployer sets it once afterwards.
    constructor(address wokb, address v2Router, uint256 threshold) {
        require(wokb != address(0) && v2Router != address(0), "zero addr");
        require(threshold > 0, "zero threshold");
        DEPLOYER = msg.sender;
        WOKB = wokb;
        V2_ROUTER = v2Router;
        THRESHOLD = threshold;
    }

    /// @notice Receives native OKB auto-paid by the IGNIX vault (>$1 auto-pays)
    receive() external payable {}

    /// @notice Set the SPROC address exactly once. Deployer only, and only
    ///         before the first execute(). Double-check the address — it can
    ///         never be changed afterwards.
    function setSPROC(address sproc_) external {
        require(msg.sender == DEPLOYER, "BuybackCircuitV2: not deployer");
        require(sproc == address(0), "BuybackCircuitV2: already set");
        require(sproc_ != address(0), "BuybackCircuitV2: zero addr");
        sproc = sproc_;
        emit SPROCSet(sproc_);
    }

    /// @notice Trigger the buyback-and-burn. Permissionless (keeper model).
    /// @param minOut Slippage protection: minimum SPROC expected from the
    ///               swap. Quote the V2 pair off-chain first; remember SPROC
    ///               has a 3% buy tax, so quote the after-tax net amount.
    function execute(uint256 minOut) external {
        require(sproc != address(0), "BuybackCircuitV2: sproc not set");
        uint256 bal = address(this).balance;
        require(bal >= THRESHOLD, "BuybackCircuitV2: below threshold");

        // 1. OKB → WOKB
        IWOKB(WOKB).deposit{value: bal}();
        IWOKB(WOKB).approve(V2_ROUTER, bal);

        // 2. WOKB → SPROC (Uniswap V2, fee-on-transfer-safe swap;
        //    the router handles token0/token1 ordering in the pair)
        address[] memory path = new address[](2);
        path[0] = WOKB;
        path[1] = sproc;
        IV2Router(V2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            bal,
            minOut,
            path,
            address(this),
            block.timestamp
        );

        // 3. Burn 100% of the SPROC received
        uint256 got = IERC20(sproc).balanceOf(address(this));
        require(IERC20(sproc).transfer(BURN, got), "BuybackCircuitV2: burn failed");

        emit BuybackExecuted(bal, got, msg.sender);
    }
}
