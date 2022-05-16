// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/***
 ****    :WARNING:
 **** This file is auto-generated from a template (MerkleData.sol.ejs).
 **** To update, update the template not the resulting test file.
 ****
 ****
 ***/

contract MerkleData {
    struct MerkleEntry {
        address user;
        uint256 maxMint;
        uint256 mintPrice;
        bytes32[] proof;
    }

    struct TestData {
        MerkleEntry[] entries;
        bytes32 root;
    }

    mapping(string => TestData) public data;

    function getTestSetByName(string memory name)
        external
        view
        returns (TestData memory)
    {
        return data[name];
    }

    constructor() {
        bytes32[] memory proof;

        data["test-3-addresses"]
            .root = 0x17fd3b63857e2260948e1b1c1eb2029cbc98e0c78713197225324a234b319cd1;

        proof = new bytes32[](2);

        proof[0] = bytes32(
            0x410850346a047658db0d67e0a2755371caf856be5b4692dd69895577f9172d5b
        );

        proof[1] = bytes32(
            0xc97b6b12a9053ef9561f3ba1a26d6f089fa77055a4a254f71094c89168ae2aaf
        );

        data["test-3-addresses"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000010,
                maxMint: 1,
                mintPrice: 10000000000000000,
                proof: proof
            })
        );

        proof = new bytes32[](2);

        proof[0] = bytes32(
            0x5466cc65fe36e24c9d6533d916f4db0096816deb47bdf805634d105ed273c8ab
        );

        proof[1] = bytes32(
            0xc97b6b12a9053ef9561f3ba1a26d6f089fa77055a4a254f71094c89168ae2aaf
        );

        data["test-3-addresses"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000011,
                maxMint: 2,
                mintPrice: 10000000000000000,
                proof: proof
            })
        );

        proof = new bytes32[](1);

        proof[0] = bytes32(
            0x0e39a7a99a7f041bb3d20ec2d4724dd9541d631fdaf2c15820def3c077c71e26
        );

        data["test-3-addresses"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000012,
                maxMint: 3,
                mintPrice: 10000000000000000,
                proof: proof
            })
        );

        data["test-2-prices"]
            .root = 0xb7d8ff9be4b222c3049431d7b5982cbd3e64e5902f0ca4a2e3527be999a12d87;

        proof = new bytes32[](1);

        proof[0] = bytes32(
            0xcd1f92f2177fa8f6c51829045204caf23439f3e448bb0b94e5134e5b9f11ea4c
        );

        data["test-2-prices"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000010,
                maxMint: 2,
                mintPrice: 100000000000000000,
                proof: proof
            })
        );

        proof = new bytes32[](1);

        proof[0] = bytes32(
            0xbabae39e08c9636595a1a4edd5850334f105c1cedb96c37659d1a9e39cb48615
        );

        data["test-2-prices"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000010,
                maxMint: 2,
                mintPrice: 200000000000000000,
                proof: proof
            })
        );

        data["test-max-count"]
            .root = 0xb7d8ff9be4b222c3049431d7b5982cbd3e64e5902f0ca4a2e3527be999a12d87;

        proof = new bytes32[](1);

        proof[0] = bytes32(
            0xcd1f92f2177fa8f6c51829045204caf23439f3e448bb0b94e5134e5b9f11ea4c
        );

        data["test-max-count"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000010,
                maxMint: 2,
                mintPrice: 100000000000000000,
                proof: proof
            })
        );

        proof = new bytes32[](1);

        proof[0] = bytes32(
            0xbabae39e08c9636595a1a4edd5850334f105c1cedb96c37659d1a9e39cb48615
        );

        data["test-max-count"].entries.push(
            MerkleEntry({
                user: 0x0000000000000000000000000000000000000010,
                maxMint: 2,
                mintPrice: 200000000000000000,
                proof: proof
            })
        );
    }
}
