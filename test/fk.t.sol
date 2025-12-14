// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BarryBerry} from "../src/GhostClaws.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Mock Token";
    }

    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract GhostClawsTest is Test {
    BarryBerry public token;
    address public owner = address(1);
    address public user = address(2);
    address public bot = address(3);

    function setUp() public {
        vm.prank(owner);
        token = new BarryBerry();
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), token.TOTAL_SUPPLY());
        assertEq(token.balanceOf(owner), token.TOTAL_SUPPLY());
    }

    function testNameAndSymbol() public view {
        assertEq(token.name(), "Barry Berry");
        assertEq(token.symbol(), "BB BERRY");
    }

    function testLaunch() public {
        // Create mock LP token
        MockERC20 lpToken = new MockERC20();
        uint256 lpAmount = 1000;
        
        // Give LP tokens to the token contract (contract will burn them)
        lpToken.mint(address(token), lpAmount);

        vm.prank(owner);
        token.launch(address(lpToken), lpAmount);

        assertTrue(token.tradingOpen());
        assertEq(token.launchTime(), block.timestamp);
        assertEq(lpToken.balanceOf(address(0xdead)), lpAmount);
    }

    function testCannotLaunchTwice() public {
        // Create mock LP token
        MockERC20 lpToken = new MockERC20();
        uint256 lpAmount = 1000;
        
        // Give LP tokens to the token contract (contract will burn them)
        lpToken.mint(address(token), lpAmount);

        vm.prank(owner);
        token.launch(address(lpToken), lpAmount);

        // After renounce, owner is no longer owner, so expect Unauthorized
        vm.expectRevert();
        vm.prank(owner);
        token.launch(address(lpToken), lpAmount);
    }
}

