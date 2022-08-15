// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {TestFixtureCustomStrat} from "./utils/TestFixtureCustomStrat.sol";
import {XChainStrategy} from "../strategies/XChainStrategy.sol";
import {Token} from "./utils/Token.sol";
// import "../../script/Token.s.sol";
import "forge-std/console.sol";

contract XChainStrategyTest is TestFixtureCustomStrat {
    XChainStrategy public xStrategy;
    yieldStrategy public yieldStrategy;

    function setUp() public override {
        super.setUp();

        // setup the xchain strategy under test on DomainA
        vm.selectFork(domainA);
        vm.startPrank(strategist);
        xStrategy = new XChainStrategy(address(vaultA));
        xStrategy.setKeeper(keeper);
        vm.stopPrank();

        vm.prank(gov);
        ivaultA.addStrategy(address(strategyA), 10_000, 0, type(uint256).max, 1_000);

        // setup the yield-generating strategy on DomainB
        vm.selectFork(domainB);
        vm.startPrank(strategist);
        yieldStrategy = new yieldStrategy(address(vaultB));
        xStrategy.setKeeper(keeper);
        vm.stopPrank();

        vm.prank(gov);
        ivaultB.addStrategy(address(strategyB), 10_000, 0, type(uint256).max, 1_000);

        console.log(xStrategy.name());
        console.log(yieldStrategy.name());
    }

    function testOperation() public {
        vm.selectFork(domainA);
        console.log(vm.activeFork());
    }
}
