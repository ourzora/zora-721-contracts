// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Test} from "forge-std/test.sol";

import {DropsSplitter} from "../../src/splitter/DropsSplitter.sol";
import {SplitRegistry} from "../../src/splitter/SplitRegistry.sol";
import {ISplitRegistry} from "../../src/splitter/interfaces/ISplitRegistry.sol";
import {IDropsSplitter} from "../../src/splitter/interfaces/IDropsSplitter.sol";
import {SafeSender} from "../../src/utils/SafeSender.sol";

contract TestingSplitterImpl is DropsSplitter {
    constructor(ISplitRegistry _splitRegistry) DropsSplitter(_splitRegistry) {
    }
    function setup(
        Share[] memory _userShares,
        uint96 _userDenominator,
        Share[] memory _platformShares,
        uint96 _platformDenominator
    ) external {
        _setupSplit(_userShares, _userDenominator, _platformShares, _platformDenominator);
    }

    function setup(SplitSetupParams memory _params) internal {
        _setupSplit(_params);
    }

    function setPrimaryBalance(uint256 _primaryBalance) external {
        _setPrimaryBalance(_primaryBalance);
    }

    function _authorizeSplitUpdate() override internal {
        // pass, by default authorize upgrade for testing
    }
}

/// @notice Test for drops splitter
contract DropsSplitterTest is Test {
    using SafeSender for address payable;
    SplitRegistry public registry;
    TestingSplitterImpl public splitter;

    function setUp() public {
        registry = new SplitRegistry();
        splitter = new TestingSplitterImpl(registry);
    }

    function test_Init() public {
        IDropsSplitter.Share[] memory userShares = new IDropsSplitter.Share[](
            2
        );
        userShares[0].user = payable(address(0x123));
        userShares[0].numerator = 1;
        userShares[1].user = payable(address(0x124));
        userShares[1].numerator = 1;

        IDropsSplitter.Share[]
            memory platformShares = new IDropsSplitter.Share[](0);

        splitter.setup(userShares, 2, platformShares, 0);
        address payable sender = payable(address(0x03));
        vm.deal(sender, 2 ether);
        vm.prank(sender);
        // only safe in tests
        payable(address(splitter)).safeSendETH(1 ether);

        // test withdraw ETH
        splitter.withdrawETH();
    }

    function test_UpdateUser() public {
        IDropsSplitter.Share[] memory userShares = new IDropsSplitter.Share[](
            2
        );
        userShares[0].user = payable(address(0x123));
        vm.label(userShares[0].user, "user share 0");
        userShares[0].numerator = 1;
        userShares[1].user = payable(address(0x124));
        vm.label(userShares[1].user, "user share 1");
        userShares[1].numerator = 1;

        IDropsSplitter.Share[]
            memory platformShares = new IDropsSplitter.Share[](0);

        splitter.setup(userShares, 2, platformShares, 0);
        address payable sender = payable(address(0x03));
        vm.deal(sender, 2 ether);
        vm.prank(sender);

        // only safe in tests
        payable(address(splitter)).safeSendETH(1 ether);

        // test withdraw ETH
        splitter.withdrawETH();

        userShares[0].numerator = 2;
        splitter.updateUserSplit(userShares, 3);

        vm.prank(sender);

        // only safe in tests
        payable(address(splitter)).transfer(1 ether);

        // test withdraw ETH
        splitter.withdrawETH();
    }

    function test_UpdatePlatform() public {
        IDropsSplitter.Share[] memory userShares = new IDropsSplitter.Share[](
            0
        );

        IDropsSplitter.Share[]
            memory platformShares = new IDropsSplitter.Share[](1);

        platformShares[0].user = payable(address(0x0323));
        vm.label(platformShares[0].user, "platform user");
        platformShares[0].numerator = 1;

        splitter.setup(userShares, 0, platformShares, 1);

        address payable sender = payable(address(0x03));
        vm.deal(sender, 2 ether);
        vm.prank(sender);
        // only safe in tests
        payable(address(splitter)).safeSendETH(1 ether);

        splitter.setPrimaryBalance(1 ether);

        // test withdraw ETH
        splitter.withdrawETH();
    }

    function test_TransferSplitNFT() public {
        IDropsSplitter.Share[] memory userShares = new IDropsSplitter.Share[](
            2
        );
        userShares[0].user = payable(address(0x123));
        userShares[0].numerator = 1;
        vm.label(userShares[0].user, "original recipient 1");
        userShares[1].user = payable(address(0x124));
        vm.label(userShares[1].user, "original recipient 2");
        userShares[1].numerator = 1;

        IDropsSplitter.Share[]
            memory platformShares = new IDropsSplitter.Share[](0);

        splitter.setup(userShares, 2, platformShares, 0);

        vm.label(address(0x999), "new nft recipient");

        vm.prank(userShares[1].user);
        registry.transferFrom(
            userShares[1].user,
            address(0x999),
            // this is the address shifted to the left 96 bits appended to the index of the split
            11015061303681644283183956932350962241103292912371396810468013215899229093889
        );

        address payable sender = payable(address(0x03));
        vm.deal(sender, 2 ether);
        vm.prank(sender);

        payable(address(splitter)).safeSendETH(1 ether);

        // test withdraw ETH
        splitter.withdrawETH();
    }
}
