// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {EditionOptimizedMetadataRenderer} from "../../src/metadata/EditionOptimizedMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";
import {DropMockBase} from "./DropMockBase.sol";
import {IERC721Drop} from "../../src/interfaces/IERC721Drop.sol";
import {Test} from "forge-std/Test.sol";

contract IERC721OnChainDataMock {
    IERC721Drop.SaleDetails private saleDetailsInternal;
    IERC721Drop.Configuration private configInternal;

    constructor(uint256 totalMinted, uint256 maxSupply) {
        saleDetailsInternal = IERC721Drop.SaleDetails({
            publicSaleActive: false,
            presaleActive: false,
            publicSalePrice: 0,
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000,
            maxSalePurchasePerAddress: 0,
            totalMinted: totalMinted,
            maxSupply: maxSupply
        });

        configInternal = IERC721Drop.Configuration({
            metadataRenderer: IMetadataRenderer(address(0x0)),
            editionSize: 12,
            royaltyBPS: 1000,
            fundsRecipient: payable(address(0x163))
        });
    }

    function saleDetails() external returns (IERC721Drop.SaleDetails memory) {
        return saleDetailsInternal;
    }

    function config() external returns (IERC721Drop.Configuration memory) {
        return configInternal;
    }
}

contract EditionOptimizedMetadataRendererTest is Test {
    address public constant mediaContract = address(123456);
    EditionOptimizedMetadataRenderer public immutableEditionRenderer = new EditionOptimizedMetadataRenderer();

    function test_ImmutableEditionMetadataInits() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}');
        immutableEditionRenderer.initializeWithData(data);
        string memory template = immutableEditionRenderer.tokenDataWithIdReplaced(address(0x123), "3");
        assertEq(template, '{"name": "testing 3", "description": "Token Description", "properties": {"number": "3"}}');
    }

    function test_UpdateTemplateAllowed() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode('{"name": "testing__TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}');
        immutableEditionRenderer.initializeWithData(data);

        immutableEditionRenderer.updateTemplate(address(0x123), '{"name": "BaSic"}');
        string memory template = immutableEditionRenderer.tokenDataWithIdReplaced(address(0x123), "3");
        assertEq(template, '{"name": "BaSic"}');
    }

    function test_NormalEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 10, maxSupply: 200});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(
            abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}')
        );
        assertEq(
            immutableEditionRenderer.tokenURI(4),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgNC8yMDAiLCAiZGVzY3JpcHRpb24iOiAiVG9rZW4gRGVzY3JpcHRpb24iLCAicHJvcGVydGllcyI6IHsibnVtYmVyIjogIjQvMjAwIn19"
        );
    }

    function test_ImmutableEditionOpenEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 10, maxSupply: type(uint64).max});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(
            abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}')
        );
        assertEq(
            immutableEditionRenderer.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgMSIsICJkZXNjcmlwdGlvbiI6ICJUb2tlbiBEZXNjcmlwdGlvbiIsICJwcm9wZXJ0aWVzIjogeyJudW1iZXIiOiAiMSJ9fQ=="
        );
    }

    function test_ContractURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 20, maxSupply: 10});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description"}'));
        // {"name": "testing 1", "description": "Token Description"}}
        assertEq(
            immutableEditionRenderer.contractURI(),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgMSIsICJkZXNjcmlwdGlvbiI6ICJUb2tlbiBEZXNjcmlwdGlvbiJ9fQ=="
        );
    }

    function test_Create2LongMetadata() public {
        immutableEditionRenderer.initializeWithData(
            abi.encode(
                0,
                unicode'{"name":"Stand with Crypto 1","description":"The Stand with Crypto commemorative NFT is a symbol of unity for the crypto community seeking sensible crypto policy. The NFT features a blue shield, representing a collective stand to protect and promote the potential of crypto. The blue shield not only shows your support for the cause but also that you’re part of a growing community who believes in the future of crypto. This is a purely commemorative NFT with an open mint and has no intended utility or value.\n \n\nWe stand united with the crypto community in our effort to advocate for sensible crypto policy. \n\nShow your support for the cause and become a part of a growing community that believes in the future of crypto:\n\nStep 1: Mint your free Stand with Crypto commemorative NFT\n\nStep 2: Add a shield emoji next to your Twitter display name 🛡️\n\nStep 3: Sign up to become a Crypto435 advocate: https://actnow.io/z31xN5P\n\nAny mint fees associated with the Stand With Crypto NFT collection will be donated to vetted organizations through a Crypto Advocacy Round with Gitcoin. Mint unlimited NFTs and raise more funds to support crypto advocacy.","image":"ipfs://bafybeifotzvqpbeaxvstc763cchyfwrashayy5qkrgq7dbgabhnl4zbifi","properties":{"number":1,"name":"Stand with Crypto"}}'
            )
        );
        assertEq(
            immutableEditionRenderer.contractURI(),
            "data:application/json;base64,eyJuYW1lIjoiU3RhbmQgd2l0aCBDcnlwdG8gMSIsImRlc2NyaXB0aW9uIjoiVGhlIFN0YW5kIHdpdGggQ3J5cHRvIGNvbW1lbW9yYXRpdmUgTkZUIGlzIGEgc3ltYm9sIG9mIHVuaXR5IGZvciB0aGUgY3J5cHRvIGNvbW11bml0eSBzZWVraW5nIHNlbnNpYmxlIGNyeXB0byBwb2xpY3kuIFRoZSBORlQgZmVhdHVyZXMgYSBibHVlIHNoaWVsZCwgcmVwcmVzZW50aW5nIGEgY29sbGVjdGl2ZSBzdGFuZCB0byBwcm90ZWN0IGFuZCBwcm9tb3RlIHRoZSBwb3RlbnRpYWwgb2YgY3J5cHRvLiBUaGUgYmx1ZSBzaGllbGQgbm90IG9ubHkgc2hvd3MgeW91ciBzdXBwb3J0IGZvciB0aGUgY2F1c2UgYnV0IGFsc28gdGhhdCB5b3XigJlyZSBwYXJ0IG9mIGEgZ3Jvd2luZyBjb21tdW5pdHkgd2hvIGJlbGlldmVzIGluIHRoZSBmdXR1cmUgb2YgY3J5cHRvLiBUaGlzIGlzIGEgcHVyZWx5IGNvbW1lbW9yYXRpdmUgTkZUIHdpdGggYW4gb3BlbiBtaW50IGFuZCBoYXMgbm8gaW50ZW5kZWQgdXRpbGl0eSBvciB2YWx1ZS4KIAoKV2Ugc3RhbmQgdW5pdGVkIHdpdGggdGhlIGNyeXB0byBjb21tdW5pdHkgaW4gb3VyIGVmZm9ydCB0byBhZHZvY2F0ZSBmb3Igc2Vuc2libGUgY3J5cHRvIHBvbGljeS4gCgpTaG93IHlvdXIgc3VwcG9ydCBmb3IgdGhlIGNhdXNlIGFuZCBiZWNvbWUgYSBwYXJ0IG9mIGEgZ3Jvd2luZyBjb21tdW5pdHkgdGhhdCBiZWxpZXZlcyBpbiB0aGUgZnV0dXJlIG9mIGNyeXB0bzoKClN0ZXAgMTogTWludCB5b3VyIGZyZWUgU3RhbmQgd2l0aCBDcnlwdG8gY29tbWVtb3JhdGl2ZSBORlQKClN0ZXAgMjogQWRkIGEgc2hpZWxkIGVtb2ppIG5leHQgdG8geW91ciBUd2l0dGVyIGRpc3BsYXkgbmFtZSDwn5uh77iPCgpTdGVwIDM6IFNpZ24gdXAgdG8gYmVjb21lIGEgQ3J5cHRvNDM1IGFkdm9jYXRlOiBodHRwczovL2FjdG5vdy5pby96MzF4TjVQCgpBbnkgbWludCBmZWVzIGFzc29jaWF0ZWQgd2l0aCB0aGUgU3RhbmQgV2l0aCBDcnlwdG8gTkZUIGNvbGxlY3Rpb24gd2lsbCBiZSBkb25hdGVkIHRvIHZldHRlZCBvcmdhbml6YXRpb25zIHRocm91Z2ggYSBDcnlwdG8gQWR2b2NhY3kgUm91bmQgd2l0aCBHaXRjb2luLiBNaW50IHVubGltaXRlZCBORlRzIGFuZCByYWlzZSBtb3JlIGZ1bmRzIHRvIHN1cHBvcnQgY3J5cHRvIGFkdm9jYWN5LiIsImltYWdlIjoiaXBmczovL2JhZnliZWlmb3R6dnFwYmVheHZzdGM3NjNjY2h5ZndyYXNoYXl5NXFrcmdxN2RiZ2FiaG5sNHpiaWZpIiwicHJvcGVydGllcyI6eyJudW1iZXIiOjEsIm5hbWUiOiJTdGFuZCB3aXRoIENyeXB0byJ9fQ=="
        );
    }

    function test_CreateCompressedMetadata() public {
        immutableEditionRenderer.initializeWithData(
            abi.encode(
                1298,
                hex"8d54cd6ed430107e9551ced556cbb654caad42821315a2957ae9c54926c950c776fd936db6aac41b70461c106fc1f3f002f008cc38dd6dab42e114271e7f7f33ce4d61d48045599c46651a5853ece1959f5cb4b02cf68a0643edc945b2866bce7a84a775b51d061cac5791468493d7674001148469a8ac06db4232142768ad87c800f5fda97923205e92e9f86902557a57e1aca67a5a80b00a6a8b2a268f825de984107a42ddec8147c75fd14401510cac35d6594bc85a05cadbc8df405e793df05bd6e278c1e7549639d3ce7c0f08c0d808d66816dadb7580c9260f2139677dbc37a552e053892974b0fc494529fcf1f1b36716c5954ca0a0f3762d2aefcdaf7b0b156ac2918d91c9606d129f8f2571a43955c73b2ce569e6b923ca8075686020339bed5560fd0ccc3e1b6c2045d242cbb247c51e1717062ecc8539df8625aaf0aebf7fec166b9400b06dc53f6fa966b4b5e240258bbff550384e39bee7d213fa0a9909c5e73399e574ff155a9929233a5896f056f2c8d4adc7ff9ae1dde917251c378dccf33c0d5cf581c0e075369f31cf1829a2878682d36a02b951f0ebeb976f3fbf7fdae1ac4a38a5ce4072726ee773e63f581dee722ca18fd185727f5fd5d1d8f582ecfe66b5bc3e397c2760c7669adbdba25c85106c4dea51cb6677e70fdcc97c6caf85355ca9352b80c69a7c922b468cb2b2be5386364aca0283799bba7ea792831089f504ef6dda06f886626dc92ce68c93d134e40962ce905bea157173395be9916982d06d07e06e4ad41dee82ff3834a84efe47e45ac9a052ed5421b5366ec62b57a1ba1e43ac8f5eaeeaba9fdab557a157d3747875e9bbaba3a6ea54d51b7db0a9a82506e3bbeed047c250943785494385be28977b7ffde915b7b7bf01"
            )
        );
        assertEq(
            immutableEditionRenderer.contractURI(),
            "data:application/json;base64,eyJuYW1lIjoiU3RhbmQgd2l0aCBDcnlwdG8gMSIsImRlc2NyaXB0aW9uIjoiVGhlIFN0YW5kIHdpdGggQ3J5cHRvIGNvbW1lbW9yYXRpdmUgTkZUIGlzIGEgc3ltYm9sIG9mIHVuaXR5IGZvciB0aGUgY3J5cHRvIGNvbW11bml0eSBzZWVraW5nIHNlbnNpYmxlIGNyeXB0byBwb2xpY3kuIFRoZSBORlQgZmVhdHVyZXMgYSBibHVlIHNoaWVsZCwgcmVwcmVzZW50aW5nIGEgY29sbGVjdGl2ZSBzdGFuZCB0byBwcm90ZWN0IGFuZCBwcm9tb3RlIHRoZSBwb3RlbnRpYWwgb2YgY3J5cHRvLiBUaGUgYmx1ZSBzaGllbGQgbm90IG9ubHkgc2hvd3MgeW91ciBzdXBwb3J0IGZvciB0aGUgY2F1c2UgYnV0IGFsc28gdGhhdCB5b3XigJlyZSBwYXJ0IG9mIGEgZ3Jvd2luZyBjb21tdW5pdHkgd2hvIGJlbGlldmVzIGluIHRoZSBmdXR1cmUgb2YgY3J5cHRvLiBUaGlzIGlzIGEgcHVyZWx5IGNvbW1lbW9yYXRpdmUgTkZUIHdpdGggYW4gb3BlbiBtaW50IGFuZCBoYXMgbm8gaW50ZW5kZWQgdXRpbGl0eSBvciB2YWx1ZS5cbiBcblxuV2Ugc3RhbmQgdW5pdGVkIHdpdGggdGhlIGNyeXB0byBjb21tdW5pdHkgaW4gb3VyIGVmZm9ydCB0byBhZHZvY2F0ZSBmb3Igc2Vuc2libGUgY3J5cHRvIHBvbGljeS4gXG5cblNob3cgeW91ciBzdXBwb3J0IGZvciB0aGUgY2F1c2UgYW5kIGJlY29tZSBhIHBhcnQgb2YgYSBncm93aW5nIGNvbW11bml0eSB0aGF0IGJlbGlldmVzIGluIHRoZSBmdXR1cmUgb2YgY3J5cHRvOlxuXG5TdGVwIDE6IE1pbnQgeW91ciBmcmVlIFN0YW5kIHdpdGggQ3J5cHRvIGNvbW1lbW9yYXRpdmUgTkZUXG5cblN0ZXAgMjogQWRkIGEgc2hpZWxkIGVtb2ppIG5leHQgdG8geW91ciBUd2l0dGVyIGRpc3BsYXkgbmFtZSDwn5uh77iPXG5cblN0ZXAgMzogU2lnbiB1cCB0byBiZWNvbWUgYSBDcnlwdG80MzUgYWR2b2NhdGU6IGh0dHBzOi8vYWN0bm93LmlvL3ozMXhONVBcblxuQW55IG1pbnQgZmVlcyBhc3NvY2lhdGVkIHdpdGggdGhlIFN0YW5kIFdpdGggQ3J5cHRvIE5GVCBjb2xsZWN0aW9uIHdpbGwgYmUgZG9uYXRlZCB0byB2ZXR0ZWQgb3JnYW5pemF0aW9ucyB0aHJvdWdoIGEgQ3J5cHRvIEFkdm9jYWN5IFJvdW5kIHdpdGggR2l0Y29pbi4gTWludCB1bmxpbWl0ZWQgTkZUcyBhbmQgcmFpc2UgbW9yZSBmdW5kcyB0byBzdXBwb3J0IGNyeXB0byBhZHZvY2FjeS4iLCJpbWFnZSI6ImlwZnM6Ly9iYWZ5YmVpZm90enZxcGJlYXh2c3RjNzYzY2NoeWZ3cmFzaGF5eTVxa3JncTdkYmdhYmhubDR6YmlmaSIsInByb3BlcnRpZXMiOnsibnVtYmVyIjoxLCJuYW1lIjoiU3RhbmQgd2l0aCBDcnlwdG8ifX0="
        );
    }
}
