// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "src/utils/PureSplitHelpers.sol";

contract PureHelpersTest is Test, PureHelpers {
    address[] uniqAddresses;

    function setUp() public {}

    /// -----------------------------------------------------------------------
    /// correctness tests
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// correctness tests - basic
    /// -----------------------------------------------------------------------

    function testCan_sortAddresses() public pure {
        address[] memory randAddresses = new address[](5);
        randAddresses[0] = address(0);
        randAddresses[1] = address(1);
        randAddresses[2] = address(5);
        randAddresses[3] = address(4);
        randAddresses[4] = address(1);

        address[] memory sortedAddresses = _sortAddresses(randAddresses);

        for (uint256 i = 1; i < sortedAddresses.length; i++) {
            assert(sortedAddresses[i - 1] <= sortedAddresses[i]);
        }
    }

    function testCan_uniqArrays() public {
        address[] memory sortedAddresses = new address[](5);
        sortedAddresses[0] = address(0);
        sortedAddresses[1] = address(0);
        sortedAddresses[2] = address(1);
        sortedAddresses[3] = address(2);
        sortedAddresses[4] = address(2);

        address[] memory _uniqAddresses = new address[](3);
        _uniqAddresses[0] = address(0);
        _uniqAddresses[1] = address(1);
        _uniqAddresses[2] = address(2);

        assertEq(_uniqueAddresses(sortedAddresses), _uniqAddresses);
    }

    function testCan_countUniqueRecipients() public {
        address[] memory sortedAddresses = new address[](5);
        sortedAddresses[0] = address(0);
        sortedAddresses[1] = address(0);
        sortedAddresses[2] = address(1);
        sortedAddresses[3] = address(2);
        sortedAddresses[4] = address(2);

        uint256 numUniq = _countUniqueRecipients(sortedAddresses);

        assertEq(numUniq, 3);
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - fuzzing
    /// -----------------------------------------------------------------------

    function testCan_sortAddresses(bytes32 seed, uint8 len) public {
        vm.assume(len > 1);

        address[] memory randAddresses = genRandAddressArray(seed, len);
        address[] memory sortedAddresses = _sortAddresses(randAddresses);

        for (uint256 i = 1; i < len; i++) {
            assert(sortedAddresses[i - 1] <= sortedAddresses[i]);
        }
    }

    function testCan_uniqArrays(
        bytes32 seed,
        uint8 len,
        uint8 _numUniq
    ) public {
        vm.assume(len > 0);

        uint8 numUniq = uint8(bound(_numUniq, 1, len));
        address[] memory randAddresses = genRandAddressArray(seed, len);
        address[] memory addressesWithDupes = new address[](
            randAddresses.length
        );
        for (uint32 i = 0; i < addressesWithDupes.length; i++) {
            addressesWithDupes[i] = address(
                uint160(randAddresses[i]) % numUniq
            );
        }

        for (uint256 i = 0; i < numUniq; i++) {
            for (uint256 j = 0; j < addressesWithDupes.length; j++) {
                if (addressesWithDupes[j] == address(uint160(i))) {
                    uniqAddresses.push(address(uint160(i)));
                    break;
                }
            }
        }
        address[] memory _uniqAddresses = uniqAddresses;
        assertEq(
            _uniqueAddresses(_sortAddresses(addressesWithDupes)),
            _uniqAddresses
        );
    }

    function testCan_countUniqueRecipients(
        bytes32 seed,
        uint8 len,
        uint8 _numUniq
    ) public {
        vm.assume(len > 0);

        uint8 numUniq = uint8(bound(_numUniq, 1, len));
        address[] memory randAddresses = genRandAddressArray(seed, len);
        address[] memory addressesWithDupes = new address[](
            randAddresses.length
        );
        for (uint32 i = 0; i < addressesWithDupes.length; i++) {
            addressesWithDupes[i] = address(
                uint160(randAddresses[i]) % numUniq
            );
        }

        for (uint256 i = 0; i < numUniq; i++) {
            for (uint256 j = 0; j < addressesWithDupes.length; j++) {
                if (addressesWithDupes[j] == address(uint160(i))) {
                    uniqAddresses.push(address(uint160(i)));
                    break;
                }
            }
        }
        assertEq(
            _countUniqueRecipients(_sortAddresses(addressesWithDupes)),
            uniqAddresses.length
        );
    }

    /// -----------------------------------------------------------------------
    /// helper fns
    /// -----------------------------------------------------------------------

    function genRandAddressArray(bytes32 seed, uint8 len)
        internal
        pure
        returns (address[] memory addresses)
    {
        addresses = new address[](len);

        bytes32 _seed = seed;
        for (uint256 i = 0; i < len; i++) {
            _seed = keccak256(abi.encodePacked(_seed));
            addresses[i] = address(bytes20(_seed));
        }
    }
}
