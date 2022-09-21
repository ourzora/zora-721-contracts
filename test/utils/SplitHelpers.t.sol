// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/utils/SplitHelpers.sol";
import "src/interfaces/ISplitMain.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SplitHelpersTest is Test {
    address constant SPLIT_MAIN =
        address(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
    address constant MOCK_NFT = address(0x1337);
    uint32 constant PERCENTAGE_SCALE = 1e6;
    SplitHelpers sh;

    address[] private uniqAddresses;

    function setUp() public {}

    /// -----------------------------------------------------------------------
    /// correctness tests
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// correctness tests - basic
    /// -----------------------------------------------------------------------

    function testCan_handleAllSingleHolder() public {
        address _nftContractAddress = MOCK_NFT;
        uint32[] memory _tokenIds = new uint32[](10);
        for (uint32 i = 0; i < _tokenIds.length; i++) {
            _tokenIds[i] = i;
        }
        vm.mockCall(
            SPLIT_MAIN,
            abi.encodeWithSelector(ISplitMain.createSplit.selector),
            abi.encode(address(1))
        );
        sh = new SplitHelpers(_nftContractAddress, _tokenIds);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            vm.mockCall(
                MOCK_NFT,
                abi.encodeWithSelector(IERC721.ownerOf.selector, _tokenIds[i]),
                abi.encode(address(uint160(_tokenIds.length)))
            );
        }
        (address[] memory recipients, uint32[] memory percentAllocations) = sh
            .getRecipientsAndAllocations();

        address[] memory expectedRecipients = new address[](1);
        expectedRecipients[0] = address(uint160(_tokenIds.length));
        uint32[] memory expectedPercentAllocations = new uint32[](1);
        expectedPercentAllocations[0] = PERCENTAGE_SCALE;

        assertEq(recipients, expectedRecipients);
        assertEq(percentAllocations, expectedPercentAllocations);
    }

    function testCan_handleAllDifferentHolders() public {
        address _nftContractAddress = MOCK_NFT;
        uint32[] memory _tokenIds = new uint32[](10);
        for (uint32 i = 0; i < _tokenIds.length; i++) {
            _tokenIds[i] = i;
        }
        vm.mockCall(
            SPLIT_MAIN,
            abi.encodeWithSelector(ISplitMain.createSplit.selector),
            abi.encode(address(1))
        );
        sh = new SplitHelpers(_nftContractAddress, _tokenIds);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            vm.mockCall(
                MOCK_NFT,
                abi.encodeWithSelector(IERC721.ownerOf.selector, _tokenIds[i]),
                abi.encode(address(uint160(i)))
            );
        }
        (address[] memory recipients, uint32[] memory percentAllocations) = sh
            .getRecipientsAndAllocations();

        address[] memory expectedRecipients = new address[](_tokenIds.length);
        for (uint256 i = 0; i < expectedRecipients.length; i++) {
            expectedRecipients[i] = address(uint160(i));
        }
        uint32 percentPerToken = uint32(
            PERCENTAGE_SCALE / expectedRecipients.length
        );
        uint32[] memory expectedPercentAllocations = new uint32[](
            _tokenIds.length
        );
        uint32 sum = 0;
        for (uint256 i = 0; i < expectedPercentAllocations.length; i++) {
            expectedPercentAllocations[i] = percentPerToken;
            sum += percentPerToken;
        }
        expectedPercentAllocations[expectedPercentAllocations.length - 1] +=
            PERCENTAGE_SCALE -
            sum;

        assertEq(recipients, expectedRecipients);
        assertEq(percentAllocations, expectedPercentAllocations);
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - fuzzing
    /// -----------------------------------------------------------------------

    function testCan_handleAllDifferentHolders(uint8 numHolders) public {
        vm.assume(numHolders > 0);

        address _nftContractAddress = MOCK_NFT;
        uint32[] memory _tokenIds = new uint32[](numHolders);
        for (uint32 i = 0; i < _tokenIds.length; i++) {
            _tokenIds[i] = i;
        }
        vm.mockCall(
            SPLIT_MAIN,
            abi.encodeWithSelector(ISplitMain.createSplit.selector),
            abi.encode(address(1))
        );
        sh = new SplitHelpers(_nftContractAddress, _tokenIds);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            vm.mockCall(
                MOCK_NFT,
                abi.encodeWithSelector(IERC721.ownerOf.selector, _tokenIds[i]),
                abi.encode(address(uint160(i)))
            );
        }
        (address[] memory recipients, uint32[] memory percentAllocations) = sh
            .getRecipientsAndAllocations();

        address[] memory expectedRecipients = new address[](_tokenIds.length);
        for (uint256 i = 0; i < expectedRecipients.length; i++) {
            expectedRecipients[i] = address(uint160(i));
        }
        uint32 percentPerToken = uint32(
            PERCENTAGE_SCALE / expectedRecipients.length
        );
        uint32[] memory expectedPercentAllocations = new uint32[](
            _tokenIds.length
        );
        uint32 sum = 0;
        for (uint256 i = 0; i < expectedPercentAllocations.length; i++) {
            expectedPercentAllocations[i] = percentPerToken;
            sum += percentPerToken;
        }
        expectedPercentAllocations[expectedPercentAllocations.length - 1] +=
            PERCENTAGE_SCALE -
            sum;

        assertEq(recipients, expectedRecipients);
        assertEq(percentAllocations, expectedPercentAllocations);
    }

    function testCan_handleSomeDupeHolders(
        bytes32 seed,
        uint8 numHolders,
        uint8 _numUniqHolders
    ) public {
        vm.assume(numHolders > 0);

        uint8 numUniqHolders = uint8(bound(_numUniqHolders, 1, numHolders));
        address[] memory randAddresses = genRandAddressArray(seed, numHolders);
        address[] memory addressesWithDupes = new address[](
            randAddresses.length
        );
        for (uint32 i = 0; i < addressesWithDupes.length; i++) {
            addressesWithDupes[i] = address(
                uint160(randAddresses[i]) % numUniqHolders
            );
        }

        address _nftContractAddress = MOCK_NFT;
        uint32[] memory _tokenIds = new uint32[](numHolders);
        for (uint32 i = 0; i < _tokenIds.length; i++) {
            _tokenIds[i] = i;
        }
        vm.mockCall(
            SPLIT_MAIN,
            abi.encodeWithSelector(ISplitMain.createSplit.selector),
            abi.encode(address(1))
        );
        sh = new SplitHelpers(_nftContractAddress, _tokenIds);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            vm.mockCall(
                MOCK_NFT,
                abi.encodeWithSelector(IERC721.ownerOf.selector, _tokenIds[i]),
                abi.encode(addressesWithDupes[i])
            );
        }
        (address[] memory recipients, uint32[] memory percentAllocations) = sh
            .getRecipientsAndAllocations();

        for (uint256 i = 0; i < numUniqHolders; i++) {
            for (uint256 j = 0; j < addressesWithDupes.length; j++) {
                if (addressesWithDupes[j] == address(uint160(i))) {
                    uniqAddresses.push(address(uint160(i)));
                    break;
                }
            }
        }
        address[] memory expectedRecipients = uniqAddresses;

        uint32 percentPerToken = uint32(PERCENTAGE_SCALE / numHolders);
        uint32[] memory expectedPercentAllocations = new uint32[](
            expectedRecipients.length
        );
        uint32 sum = 0;
        for (uint256 i = 0; i < expectedPercentAllocations.length; i++) {
            for (uint256 j = 0; j < addressesWithDupes.length; j++) {
                if (expectedRecipients[i] == addressesWithDupes[j]) {
                    expectedPercentAllocations[i] += percentPerToken;
                    sum += percentPerToken;
                }
            }
        }
        expectedPercentAllocations[expectedPercentAllocations.length - 1] +=
            PERCENTAGE_SCALE -
            sum;

        assertEq(recipients, expectedRecipients);
        assertEq(percentAllocations, expectedPercentAllocations);
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

    function assertEq(uint32[] memory a, uint32[] memory b) internal {
        assertEq(a.length, b.length);
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }
}
