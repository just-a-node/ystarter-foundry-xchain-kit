// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

import {VaultWrapper} from "../../VaultWrapper.sol";
import {ExtendedDSTest} from "./ExtendedDSTest.sol";
import {IVault} from "../../interfaces/IVault.sol";
import "../../interfaces/IERC4626.sol";

import {Token} from "./Token.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant vaultArtifact = "artifacts/Vault.json";

// Base fixture deploying ERC4626 vaults on two domains
contract TestFixtureCustomStrat is ExtendedDSTest {
    using SafeERC20 for IERC20;

    uint256 public domainA;
    uint256 public domainB;

    VaultAPI public vaultA;
    IVault public ivaultA;
    IERC4626 public vaultWrapperA;
    IERC20 public wantA;

    VaultAPI public vaultB;
    IVault public ivaultB;
    IERC4626 public vaultWrapperB;
    IERC20 public wantB;

    address public gov = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address public user = address(1);
    address public whale = address(2);
    address public rewards = address(3);
    address public guardian = address(4);
    address public management = address(5);
    address public strategist = address(6);
    address public keeper = address(7);

    uint256 public minFuzzAmt;
    // @dev maximum amount of want tokens deposited based on @maxDollarNotional
    uint256 public maxFuzzAmt;
    // @dev maximum dollar amount of tokens to be deposited
    uint256 public maxDollarNotional = 1_000_000;
    // @dev maximum dollar amount of tokens for single large amount
    uint256 public bigDollarNotional = 49_000_000;
    // @dev used for non-fuzz tests to test large amounts
    uint256 public bigAmount;
    // Used for integer approximation
    uint256 public constant DELTA = 10**5;

    function setUp() public virtual {
        // NOTE: skip a few seconds to avoid block.timestamp == 0
        skip(10 seconds);

        // create forks for the two domains
        domainA = vm.createFork(vm.envString("GOERLI_RPC_URL"));
        domainB = vm.createFork(vm.envString("RINKEBY_RPC_URL"));

        ////////////////// DOMAIN A SETUP //////////////////
        vm.selectFork(domainA);

        // Create want token on domainA
        Token _tokenA = new Token(uint8(18));
        wantA = IERC20(_tokenA);

        // Create vault that uses the ERC4626 interface on domainA
        address _vaultA = deployVault(
            address(wantA),
            gov,
            rewards,
            "testVaultA",
            "testVaultTokenA",
            guardian,
            management
        );
        ivaultA = IVault(_vaultA);
        vaultA = VaultAPI(_vaultA);
        VaultWrapper _vaultWrapperA = new VaultWrapper(vaultA);
        vaultWrapperA = IERC4626(_vaultWrapperA);

        ////////////////// DOMAIN B SETUP //////////////////
        vm.selectFork(domainB);

        // Create want token on domainB
        Token _tokenB = new Token(uint8(18));
        wantB = IERC20(_tokenB);

        // Create vault that uses the ERC4626 interface on domainB
        address _vaultB = deployVault(
            address(wantB),
            gov,
            rewards,
            "testVaultB",
            "testVaultTokenB",
            guardian,
            management
        );
        ivaultB = IVault(_vaultB);
        vaultB = VaultAPI(_vaultB);
        VaultWrapper _vaultWrapperB = new VaultWrapper(vaultB);
        vaultWrapperB = IERC4626(_vaultWrapperB);

        // NOTE: assume Token is priced to 1 for simplicity
        minFuzzAmt = 10**vaultA.decimals() / 10;
        maxFuzzAmt = uint256(maxDollarNotional) * 10**vaultA.decimals();
        bigAmount = uint256(bigDollarNotional) * 10**vaultA.decimals();

        vm.label(address(vaultA), "VaultA");
        vm.label(address(wantA), "WantA");
        vm.label(address(vaultWrapperA), "VaultWrapperA");
        vm.label(address(vaultB), "VaultB");
        vm.label(address(wantB), "WantB");
        vm.label(address(vaultWrapperB), "VaultWrapperB");
        vm.label(gov, "Gov");
        vm.label(user, "User");
        vm.label(whale, "Whale");
        vm.label(rewards, "Rewards");
        vm.label(guardian, "Guardian");
        vm.label(management, "Management");
        vm.label(strategist, "Strategist");
        vm.label(keeper, "Keeper");
    }

    // Deploys a vault
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm.prank(_gov);
        address _vaultAddress = deployCode(vaultArtifact);
        IVault _vault = IVault(_vaultAddress);

        vm.prank(_gov);
        _vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        vm.prank(_gov);
        _vault.setDepositLimit(type(uint256).max);

        return address(_vault);
    }
}
