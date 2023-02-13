// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";

import {NFTMetadataRenderer} from "../../src/utils/NFTMetadataRenderer.sol";

contract NFTMetadataRendererTest is Test {
    function testMetadataEditionCreate() public {
        assertEq(
            NFTMetadataRenderer.createMetadataEdition(
                "testing",
                "blah",
                "ipfs://bafybbb",
                "ipfs://baffffbb",
                23,
                100
            ),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgMjMvMTAwIiwgImRlc2NyaXB0aW9uIjogImJsYWgiLCAiaW1hZ2UiOiAiaXBmczovL2JhZnliYmIiLCAiYW5pbWF0aW9uX3VybCI6ICJpcGZzOi8vYmFmZmZmYmIiLCAicHJvcGVydGllcyI6IHsibnVtYmVyIjogMjMsICJuYW1lIjogInRlc3RpbmcifX0="
        );
    }

    function test_encodeMetadataContractURIJSON() public {
        assertEq(
            NFTMetadataRenderer.encodeContractURIJSON(
                "testing",
                "testiblah",
                "ipfs://bafybbb-image",
                "ipfs://baffffbb-animation",
                10,
                address(10)
            ),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmciLCAiZGVzY3JpcHRpb24iOiAidGVzdGlibGFoIiwgInNlbGxlcl9mZWVfYmFzaXNfcG9pbnRzIjogMTAsICJmZWVfcmVjaXBpZW50IjogIjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwYSIsICJpbWFnZSI6ICJpcGZzOi8vYmFmeWJiYi1pbWFnZSIsICJhbmltYXRpb25fdXJsIjogImlwZnM6Ly9iYWZmZmZiYi1hbmltYXRpb24ifQ=="
        );
    }

    function test_createMetadataJSONNoMediaData() public {
        assertEq(
            string(
                NFTMetadataRenderer.createMetadataJSON(
                    "testing name",
                    "its a description",
                    "",
                    10,
                    40
                )
            ),
            '{"name": "testing name 10/40", "description": "its a description", "properties": {"number": 10, "name": "testing name"}}'
        );
    }

    function test_createMetadataJSONMediaData() public {
        assertEq(
            string(
                NFTMetadataRenderer.createMetadataJSON(
                    "testing name",
                    "its a description",
                    'image": "ipfs://image',
                    200,
                    10000
                )
            ),
            '{"name": "testing name 200/10000", "description": "its a description", "image": "ipfs://imageproperties": {"number": 200, "name": "testing name"}}'
        );
    }

    function test_encodeMetadataJSON() public {
        assertEq(
            NFTMetadataRenderer.encodeMetadataJSON("{}"),
            "data:application/json;base64,e30="
        );
    }
}
