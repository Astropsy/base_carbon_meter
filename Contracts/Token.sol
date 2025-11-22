// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Token.sol is our ERC-20 BaseCarbon (BC) contract.
 *
 * When the Carbon Smart Meter records verified energy usage and our
 * system calculates the corresponding offset, this contract mints
 * BaseCarbon (BC) tokens to the user’s wallet.
 *
 * Design goals:
 * - Simple, clean ERC-20 implementation
 * - Minting restricted to our authorized system (CarbonSmartMeter)
 * - Deployed on Base
 * - Acts as the on-chain representation of verified carbon offsets
 */

contract BaseCarbonToken {
    // ------------------------------------------------------------------------
    // ERC-20 metadata
    // ------------------------------------------------------------------------

    string public name = "BaseCarbon";
    string public symbol = "BC";
    uint8 public decimals = 18;

    // ------------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------------

    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    /// @notice Owner (initially deployer – we can transfer if needed)
    address public owner;

    /// @notice The authorized minter (must be the CarbonSmartMeter contract)
    address public minter;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    // ------------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    // ------------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------------

    /**
     * @notice Set or update the authorized minter.
     *
     * This must be set to the deployed CarbonSmartMeter contract.
     * The CarbonSmartMeter is the ONLY authorized minter to ensure
     * tokens can only be created as a result of verified meter data.
     */
    function setMinter(address newMinter) external onlyOwner {
        require(newMinter != address(0), "Zero address");
        emit MinterUpdated(minter, newMinter);
        minter = newMinter;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    // ------------------------------------------------------------------------
    // ERC-20 standard functions
    // ------------------------------------------------------------------------

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address _owner, address spender) external view returns (uint256) {
        return allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");

        allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);

        return true;
    }

    // ------------------------------------------------------------------------
    // Minting logic (our core feature)
    // ------------------------------------------------------------------------

    /**
     * @notice Mint new BaseCarbon tokens.
     *
     * This is ONLY callable by the authorized minter (CarbonSmartMeter).
     * We use this to ensure every BC token corresponds to verified energy
     * data and carbon impact coming from our smart meter logic.
     */
    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "Zero address");
        require(amount > 0, "Zero mint");

        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    // ------------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------------

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Zero address");
        require(balances[from] >= amount, "Insufficient balance");

        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}