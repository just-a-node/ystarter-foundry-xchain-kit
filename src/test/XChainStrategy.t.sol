// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseStrategyInitializable, StrategyParams, VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import {TestFixtureCustomStrat} from "./utils/TestFixtureCustomStrat.sol";
import {XChainStrategy} from "../strategies/XChainStrategy.sol";
import {YieldStrategy} from "../strategies/YieldStrategy.sol";
import {YieldVault} from "../vaults/YieldVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IConnextHandler} from "nxtp/core/connext/interfaces/IConnextHandler.sol";
import "forge-std/console.sol";

contract XChainStrategyTest is TestFixtureCustomStrat {
    XChainStrategy public xStrategy;
    YieldStrategy public yieldStrategy;
    YieldVault public yieldVault;

    function setUp() public override {
        super.setUp();

        ============ Domain B: Strategy ============
        Set up the yield-generating strategy on the destination domain
        and register it to the vault.

        vm.selectFork(domainB);

        vm.startPrank(strategist);

        yieldStrategy = new YieldStrategy(
            address(vaultB)
        );
        vm.makePersistent(address(yieldStrategy));
        yieldStrategy.setKeeper(keeper);
        vm.stopPrank();

        vm.prank(gov);
        IVault(address(vaultB)).addStrategy(
            address(yieldStrategy), // strategy
            10_000,                 // debtRatio 
            0,                      // minDebtPerHarvest 
            type(uint256).max,      // maxDebtPerHarvest
            1_000                   // performanceFee
        );

        ============ Domain A: Strategy ============
        Set up the xchain strategy under test on the origin domain
        and register it to the vault. 

        vm.selectFork(domainA);

        vm.startPrank(strategist);
        xStrategy = new XChainStrategy(
            address(vaultA),
            originDomain,
            destinationDomain,
            IConnextHandler(originConnext),
            address(vaultB),
            address(yieldStrategy)
        );
        vm.makePersistent(address(xStrategy));
        xStrategy.setKeeper(keeper);
        vm.stopPrank();

        vm.prank(gov);
        IVault(address(vaultA)).addStrategy(
            address(xStrategy),     // strategy
            10_000,                 // debtRatio 
            0,                      // minDebtPerHarvest 
            type(uint256).max,      // maxDebtPerHarvest
            1_000                   // performanceFee
        );

        // ============ Domain B: Vault ============
        //  Set up the yield-capturing vault on the destination domain 
        //  and register the yield-generating strategy.

        vm.selectFork(domainB);

        vm.startPrank(gov);
        YieldVault yieldVault = new YieldVault(
            address(vaultWrapperB),
            originDomain,
            destinationDomain,
            IConnextHandler(destinationConnext),
            address(vaultA),
            address(xStrategy)
        );

        vm.stopPrank();

        ============ Misc ============

        vm.label(address(xStrategy), "XChainStrategy");
        vm.label(address(yieldStrategy), "YieldStrategy");
        vm.label(address(yieldVault), "YieldVault");
    }
    
    function testOperation() public {
        uint256 _amount = 100;
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        ============ Deposit to Vault A ============

        vm.selectFork(domainA);
        
        deal(address(wantA), user, _amount);

        vm.startPrank(user);
        uint256 userBalanceBefore = wantA.balanceOf(user);
        wantA.approve(address(vaultA), _amount);
        vaultA.deposit(_amount);
        assertEq(wantA.balanceOf(address(vaultA)), _amount);
        vm.stopPrank();

        // ============ Harvest ============

        // send funds to the yield strategy to simulate profit
        vm.selectFork(domainB);
        deal(address(wantB), address(yieldStrategy), _amount);

        // back to domain A to harvest
        vm.selectFork(domainA);

        vm.startPrank(strategist);
        console.log(VaultAPI(xStrategy.vault()).activation());

        // hitting an issue here where the strat activation is 0 bc we selected domainB
        // now the major problem is that vaultA and vaultB are the same
        console.log("strat activation:", xStrategy.vault().strategies(address(xStrategy)).activation);

        console.log("wantA balance of strat:", IERC20(xStrategy.vault().token()).balanceOf(address(xStrategy)));    
        console.log("wantA balance of vault:", IERC20(xStrategy.vault().token()).balanceOf(address(xStrategy.vault())));    
        console.log("vault totalAssets:", VaultAPI(xStrategy.vault()).totalAssets());
        console.log("vault depositLimit:", VaultAPI(xStrategy.vault()).depositLimit());
        console.log("vault debtRatio:", VaultAPI(xStrategy.vault()).debtRatio());
        console.log("vault totalDebt:", VaultAPI(xStrategy.vault()).totalDebt());
        console.log("vault lockedProfit:", VaultAPI(xStrategy.vault()).lockedProfit());
        console.log("strat debtRatio:", xStrategy.vault().strategies(address(xStrategy)).debtRatio);    
        console.log("strat totalDebt:", xStrategy.vault().strategies(address(xStrategy)).totalDebt);    
        console.log("strat totalGain:", xStrategy.vault().strategies(address(xStrategy)).totalGain);    
        console.log("vault creditAvailable:", VaultAPI(xStrategy.vault()).creditAvailable());
        console.log("strat estimatedTotalAssets:", xStrategy.estimatedTotalAssets());

        xStrategy.harvest(); // harvests with wantA
        vm.stopPrank();
        assert pytest.approx(xStrategy.estimatedTotalAssets(), rel=RELATIVE_APPROX) == _amount;

        // ============ Tend ============

        xStrategy.tend();

        // withdraw
        vaultA.withdraw({"from": user});
        assert (
            pytest.approx(wantA.balanceOf(user), rel=RELATIVE_APPROX) == userBalanceBefore
        )

    }
}
