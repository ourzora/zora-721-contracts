// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "base64-sol/base64.sol";
import "./ISerialMintable.sol";

/**
    This is a smart contract for handling dynamic contract minting.

    @dev This allows creators to mint a series 
    @author iain nash
    Repository: https://github.com/ourzora/nft-serial-contracts/
*/
contract DynamicSerialMintable is
    ISerialMintable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    IERC2981Upgradeable,
    ReentrancyGuardUpgradeable
{
    // metadata
    string private description;

    // media urls
    // animation_url field in the metadata
    string private animationUrl;
    // hash for the associated animation
    bytes32 private animationHash;
    // image in the metadata
    string private imageUrl;
    // hash for the associated image
    bytes32 private imageHash;

    // total size of serial that can be minted
    uint256 public serialSize;
    // current token id minted
    uint256 private atSerialId = 1;
    // royalty amount in bps
    uint256 royaltyBPS;
    // addresses allowed to mint serial
    address[] allowedMinters;

    /**
      @param _owner Owner of serial
      @param _name Name of serial, used in the title as "$NAME NUMBER/TOTAL"
      @param _symbol Symbol of the new token contract
      @param _description Description of serial, used in the description field of the NFT
      @param _imageUrl Image URL of the serial. Strongly encouraged to be used, if necessary, only animation URL can be used. One of animation and image url need to exist in a serial to render the NFT.
      @param _imageHash SHA256 of the given image in bytes32 format (0xHASH). If no image is included, the hash can be zero (bytes32 type)
      @param _animationUrl Animation URL of the serial. Not required, but if omitted image URL needs to be included. This follows the opensea spec for NFTs
      @param _animationHash The associated hash of the animation in sha-256 bytes32 format. If animation is omitted 
      @param _serialSize Number of serials that can be minted in total.
      @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
      @dev Function to create a new serial. Can only be called by the allowed creator
           Sets the only allowed minter to the address that creates/owns the serial.
           This can be re-assigned or updated later
     */
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _serialSize,
        uint256 _royaltyBPS
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        transferOwnership(_owner);
        __ReentrancyGuard_init();
        description = _description;
        animationUrl = _animationUrl;
        animationHash = _animationHash;
        imageUrl = _imageUrl;
        imageHash = _imageHash;
        serialSize = _serialSize;
        royaltyBPS = _royaltyBPS;
        allowedMinters.push(msg.sender);
        atSerialId=1;
    }

    /**
      @dev This helper function checks if the msg.sender is allowed to mint the
            given serial id.
     */
    function _isAllowedToMint() internal view returns (bool) {
        if (owner() == msg.sender) {
            return true;
        }
        uint256 allowedMintersCount = allowedMinters.length;
        // todo(iain): update allowed minters?
        if (allowedMintersCount == 0) {
            return true;
        }
        for (uint256 i = 0; i < allowedMintersCount; i++) {
            if (allowedMinters[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    /**
      @param to address to send the newly minted serial to
      @dev This mints one serial to the given address by an allowed minter on the serial instance.
     */
    function mintSerial(address to)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        address[] memory toMint = new address[](1);
        toMint[0] = to;
        return _mintSerials(toMint);
    }

    /**
      @param recipients list of addresses to send the newly minted serials to
      @dev This mints multiple serials to the given list of addresses.
     */
    function mintSerials(address[] memory recipients)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        return _mintSerials(recipients);
    }

    /**
      @param _allowedMinters list of addresses allowed to mint this serial
      @dev Set the allowed minters array for a given serial id
           This requires that msg.sender is the owner of the given serial id.
     */
    function setAllowedMinters(address[] memory _allowedMinters)
        public
        onlyOwner
    {
        allowedMinters = _allowedMinters;
    }

    /**
      @dev Allows for updates of serial urls by the owner of the serial.
           Only URLs can be updated (data-uris are supported), hashes cannot be updated.
     */
    function updateSerialURLs(
        string memory _imageUrl,
        string memory _animationUrl
    ) public onlyOwner {
        imageUrl = _imageUrl;
        animationUrl = _animationUrl;
    }

    /**
      @dev Private function to mint als without any access checks.
           Called by the public serial minting functions.
     */
    function _mintSerials(address[] memory recipients)
        internal
        returns (uint256)
    {
        uint256 startAt = atSerialId;
        uint256 endAt = startAt + recipients.length - 1;
        require(endAt <= serialSize, "SOLD OUT");
        while (atSerialId <= endAt) {
            _mint(recipients[atSerialId - startAt], atSerialId);
            atSerialId++;
        }
        return atSerialId;
    }

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

    function base64Encode(bytes memory args)
        public
        pure
        returns (string memory)
    {
        return Base64.encode(args);
    }

    function numberToString(uint256 value) public pure returns (string memory) {
        return StringsUpgradeable.toString(value);
    }

    function _tokenMediaData(uint256 tokenOfSerial)
        private
        view
        returns (string memory)
    {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        if (hasImage && hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        imageUrl,
                        "?id=",
                        numberToString(tokenOfSerial),
                        '", "animation_url": "',
                        animationUrl,
                        "?id=",
                        numberToString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (hasImage) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        imageUrl,
                        "?id=",
                        numberToString(tokenOfSerial),
                        '", "'
                    )
                );
        }
        if (hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'animation_url": "',
                        animationUrl,
                        "?id=",
                        numberToString(tokenOfSerial),
                        '", "'
                    )
                );
        }

        return "";
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (owner(), (_salePrice * royaltyBPS) / 10_000);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "NO TOKEN");

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    base64Encode(
                        abi.encodePacked(
                            '{"name": "',
                            name(),
                            " ",
                            StringsUpgradeable.toString(tokenId),
                            "/",
                            StringsUpgradeable.toString(serialSize),
                            '", "',
                            'description": "',
                            description,
                            '", "',
                            _tokenMediaData(tokenId),
                            'properties": {"number": ',
                            StringsUpgradeable.toString(tokenId),
                            "}}"
                        )
                    )
                )
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
