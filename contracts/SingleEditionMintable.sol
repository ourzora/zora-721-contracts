// SPDX-License-Identifier: GPL-3.0

/**

    █▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
    █░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

    ▀█ █▀█ █▀█ ▄▀█
    █▄ █▄█ █▀▄ █▀█

 */

pragma solidity ^0.8.10;


import {SharedNFTLogic} from "./SharedNFTLogic.sol";
import {ZoraMediaBase} from "./ZoraMediaBase.sol";

/**
    This is a smart contract for handling dynamic contract minting.

    @dev This allows creators to mint a unique serial edition of the same media within a custom contract
    @author iain nash
    Repository: https://github.com/ourzora/nft-editions
*/
/*
contract SingleEditionMintable 
{

    // metadata
    string public description;

    // Media Urls
    // animation_url field in the metadata
    string private animationUrl;
    // Hash for the associated animation
    bytes32 private animationHash;
    // Image in the metadata
    string private imageUrl;
    // Hash for the associated image
    bytes32 private imageHash;

    // NFT rendering logic contract
    SharedNFTLogic private immutable sharedNFTLogic;

    // Global constructor for factory
    constructor(SharedNFTLogic _sharedNFTLogic, uint16 feeBps) ZoraMediaBase(feeBps) {
        sharedNFTLogic = _sharedNFTLogic;
        
    }

    //   @param _owner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    //   @param _name Name of edition, used in the title as "$NAME NUMBER/TOTAL"
    //   @param _symbol Symbol of the new token contract
    //   @param _description Description of edition, used in the description field of the NFT
    //   @param _imageUrl Image URL of the edition. Strongly encouraged to be used, if necessary, only animation URL can be used. One of animation and image url need to exist in a edition to render the NFT.
    //   @param _imageHash SHA256 of the given image in bytes32 format (0xHASH). If no image is included, the hash can be zero.
    //   @param _animationUrl Animation URL of the edition. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
    //   @param _animationHash The associated hash of the animation in sha-256 bytes32 format. If animation is omitted the hash can be zero.
    //   @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
    //   @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    //   @dev Function to create a new edition. Can only be called by the allowed creator
    //        Sets the only allowed minter to the address that creates/owns the edition.
    //        This can be re-assigned or updated later
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) public initializer {

        description = _description;
        animationUrl = _animationUrl;
        animationHash = _animationHash;
        imageUrl = _imageUrl;
        imageHash = _imageHash;
        editionSize = _editionSize;
        royaltyBPS = _royaltyBPS;
    }


    //   @dev Allows for updates of edition urls by the owner of the edition.
    //        Only URLs can be updated (data-uris are supported), hashes cannot be updated.
    function updateEditionURLs(
        string memory _imageUrl,
        string memory _animationUrl
    ) public onlyOwner {
        imageUrl = _imageUrl;
        animationUrl = _animationUrl;
    }

    /// Returns the number of editions allowed to mint (max_uint256 when open edition)
    function numberCanMint() public view override returns (uint256) {
        // Return max int if open edition
        if (editionSize == 0) {
            return type(uint256).max;
        }
        // atEditionId is one-indexed hence the need to remove one here
        return editionSize + 1 - atEditionId.current();
    }

        // @param tokenId Token ID to burn
        // User burn function for token id 
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        _burn(tokenId);
    }

    //   @dev Get URIs for edition NFT
    //   @return imageUrl, imageHash, animationUrl, animationHash
    function getURIs()
        public
        view
        returns (
            string memory,
            bytes32,
            string memory,
            bytes32
        )
    {
        return (imageUrl, imageHash, animationUrl, animationHash);
    }

        // @dev Get royalty information for token
        // @param _salePrice Sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (owner() == address(0x0)) {
            return (owner(), 0);
        }
        return (owner(), (_salePrice * royaltyBPS) / 10_000);
    }

        // @dev Get URI for given token id
        // @param tokenId token id to get uri for
        // @return base64-encoded json metadata object
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "No token");

        return
            sharedNFTLogic.createMetadataEdition(
                name(),
                description,
                imageUrl,
                animationUrl,
                tokenId,
                editionSize
            );
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            ERC721Upgradeable.supportsInterface(interfaceId);
    }
}

*/