// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {UriEncode} from "sol-uriencode/UriEncode.sol";
import {MetadataBuilder} from "micro-onchain-metadata-utils/MetadataBuilder.sol";
import {MetadataJSONKeys} from "micro-onchain-metadata-utils/MetadataJSONKeys.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";
import {INounsCoasterMetadataRendererTypes} from "../interfaces/INounsCoasterMetadataRendererTypes.sol";
import {Ownable2Step} from "../utils/ownable/Ownable2Step.sol";

import "forge-std/console.sol";

/// @notice NounsCoasterMetadataRenderer
contract NounsCoasterMetadataRenderer is IMetadataRenderer, INounsCoasterMetadataRendererTypes, Ownable2Step, MetadataRenderAdminCheck {
    /// @notice The metadata renderer settings
    Settings public settings;

    /// @notice The background properties chosen from upon generation
    /// [
    ///   background
    ///   title
    ///   corner tag
    ///   ride
    /// ]
    Property[] public properties;

    /// @notice the variant dependent properties for nouns
    /// [
    ///   0: body variant 1
    ///   1: body variant 2
    ///   2: body variant 3
    ///   3: body variant 4
    ///   4: accessories variant 1
    ///   5: accessories variant 2
    ///   6: accessories variant 3
    ///   7: accessories variant 4
    ///   8: head
    ///   9: expression
    ///   10: glasses
    /// ]
    mapping(uint16 => Property[]) public nounProperties;

    /// @notice The IPFS data of all property items
    IPFSGroup[] public ipfsData;

    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a property is added
    event PropertyAdded(uint256 id, string name);

    /// @notice Emitted when the contract image is updated
    event ContractImageUpdated(string prevImage, string newImage);

    /// @notice Emitted when the renderer base is updated
    event RendererBaseUpdated(string prevRendererBase, string newRendererBase);

    /// @notice Emitted when the collection description is updated
    event DescriptionUpdated(string prevDescription, string newDescription);

    /// @notice Emitted when the collection uri is updated
    event WebsiteURIUpdated(string lastURI, string newURI);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the caller isn't the token contract
    error ONLY_TOKEN();

    /// @dev Reverts if querying attributes for a token not minted
    error TOKEN_NOT_MINTED(uint256 tokenId);

    /// @dev Reverts if the founder does not include both a property and item during the initial artwork upload
    error ONE_PROPERTY_AND_ITEM_REQUIRED();

    /// @dev Reverts if an item is added for a non-existent property
    error INVALID_PROPERTY_SELECTED(uint256 selectedPropertyId);

    ///
    error TOO_MANY_PROPERTIES();

    ///
    error PREVIOUS_PROPERITIES_REQUIRED();

    constructor(bytes memory _initStrings, address _token, address _owner) Ownable2Step(_owner) {
        // Decode the token initialization strings
        (, , string memory _description, string memory _contractImage, string memory _projectURI, string memory _rendererBase) = abi.decode(
            _initStrings,
            (string, string, string, string, string, string)
        );

        // Store the renderer settings
        settings.projectURI = _projectURI;
        settings.description = _description;
        settings.contractImage = _contractImage;
        settings.rendererBase = _rendererBase;
        settings.projectURI = _projectURI;
        settings.token = _token;
    }

    /// @notice Adds properties and/or items to be pseudo-randomly chosen from during token minting
    /// @param _names The names of the properties to add
    /// @param _items The items to add to each property
    /// @param _ipfsGroup The IPFS base URI and extension
    function addProperties(string[] calldata _names, ItemParam[] calldata _items, IPFSGroup calldata _ipfsGroup) external onlyOwner {
        _addProperties(_names, _items, _ipfsGroup);
    }

    function _addProperties(string[] calldata _names, ItemParam[] calldata _items, IPFSGroup calldata _ipfsGroup) internal {
        // Cache the existing amount of IPFS data stored
        uint256 dataLength = ipfsData.length;

        // Add the IPFS group information
        ipfsData.push(_ipfsGroup);

        // Cache the number of existing properties
        uint256 numStoredProperties = properties.length;

        // Cache the number of new properties
        uint256 numNewProperties = _names.length;

        // Cache the number of new items
        uint256 numNewItems = _items.length;

        // If this is the first time adding metadata:
        if (numStoredProperties == 0) {
            // Ensure at least one property and one item are included
            if (numNewProperties == 0 || numNewItems == 0) {
                revert ONE_PROPERTY_AND_ITEM_REQUIRED();
            }
        }

        unchecked {
            // Check if not too many items are stored
            if (numStoredProperties + numNewProperties > 15) {
                revert TOO_MANY_PROPERTIES();
            }

            // For each new property:
            for (uint256 i = 0; i < numNewProperties; ++i) {
                // Append storage space
                properties.push();

                // Get the new property id
                uint256 propertyId = numStoredProperties + i;

                // Store the property name
                properties[propertyId].name = _names[i];

                emit PropertyAdded(propertyId, _names[i]);
            }

            // For each new item:
            for (uint256 i = 0; i < numNewItems; ++i) {
                // Cache the id of the associated property
                uint256 _propertyId = _items[i].propertyId;

                // Offset the id if the item is for a new property
                // Note: Property ids under the hood are offset by 1
                if (_items[i].isNewProperty) {
                    _propertyId += numStoredProperties;
                }

                // Ensure the item is for a valid property
                if (_propertyId >= properties.length) {                    
                    revert INVALID_PROPERTY_SELECTED(_propertyId);
                }

                // Get the pointer to the other items for the property
                Item[] storage items = properties[_propertyId].items;

                // Append storage space
                items.push();

                // Get the index of the new item
                // Cannot underflow as the items array length is ensured to be at least 1
                uint256 newItemIndex = items.length - 1;

                // Store the new item
                Item storage newItem = items[newItemIndex];

                // Store the new item's name and reference slot
                newItem.name = _items[i].name;
                newItem.referenceSlot = uint16(dataLength);
            }
        }
    }


    // function addMoreProperties(uint16 nounId, string[] calldata _names, ItemParam[] calldata _items, IPFSGroup calldata _ipfsGroup) external onlyOwner {
    //     // Cache the noun property
    //     Property[] storage _properties = nounProperties[_nounId];

    //     // Cache the number of existing properties
    //     uint256 numStoredProperties = _properties.length;

    //     // revert of no properties have been stored before calling this function
    //     if (numStoredProperties == 0) {
    //         revert PREVIOUS_PROPERITIES_REQUIRED();
    //     }        

    //     // Cache the number of new properties
    //     uint256 numNewProperties = _names.length;

    //     // Cache the number of new items
    //     uint256 numNewItems = _items.length;

    //     // Ensure at least one property and one item are included
    //     if (numNewProperties == 0 || numNewItems == 0) {
    //         revert ONE_PROPERTY_AND_ITEM_REQUIRED();
    //     }


    //     unchecked {
    //         // Check if not too many items are stored
    //         if (numStoredProperties + numNewProperties > 15) {
    //             revert TOO_MANY_PROPERTIES();
    //         }
    //     }
    // }

    function addNounProperties(uint16 _nounId, string[] calldata _names, ItemParam[] calldata _items, IPFSGroup calldata _ipfsGroup) external onlyOwner {
        _addNounProperties(_nounId, _names, _items, _ipfsGroup);
    }

    function _addNounProperties(uint16 _nounId, string[] calldata _names, ItemParam[] calldata _items, IPFSGroup calldata _ipfsGroup) internal {
        // Cache the existing amount of IPFS data stored
        uint256 dataLength = ipfsData.length;

        // Add the IPFS group information
        ipfsData.push(_ipfsGroup);

        // Cache the noun property
        Property[] storage _properties = nounProperties[_nounId];

        // Cache the number of existing properties
        uint256 numStoredProperties = _properties.length;

        // Cache the number of new properties
        uint256 numNewProperties = _names.length;

        // Cache the number of new items
        uint256 numNewItems = _items.length;

        // console.log("num new properties", numNewProperties);
        // console.log("num new items", _items.length);


        // If this is the first time adding metadata:
        if (numStoredProperties == 0) {
            // Ensure at least one property and one item are included
            if (numNewProperties == 0 || numNewItems == 0) {
                revert ONE_PROPERTY_AND_ITEM_REQUIRED();
            }
        }

        unchecked {
            // Check if not too many items are stored
            if (numStoredProperties + numNewProperties > 15) {
                revert TOO_MANY_PROPERTIES();
            }

            // For each new property:
            for (uint256 i = 0; i < numNewProperties; ++i) {
                // Append storage space
                _properties.push();

                // Get the new property id
                uint256 propertyId = numStoredProperties + i;

                // console.log("whats the propertyid", propertyId);

                // Store the property name
                _properties[propertyId].name = _names[i];

                emit PropertyAdded(propertyId, _names[i]);
            }

            // For each new item:
            for (uint256 i = 0; i < numNewItems; ++i) {
                // Cache the id of the associated property
                uint256 _propertyId = _items[i].propertyId;


                // // Offset the id if the item is for a new property
                // // Note: Property ids under the hood are offset by 1
                // if (_items[i].isNewProperty) {
                //     _propertyId += numStoredProperties;
                // }

                // Ensure the item is for a valid property
                if (_propertyId >= _properties.length) {
                    revert INVALID_PROPERTY_SELECTED(_propertyId);
                }

                // Get the pointer to the other items for the property
                Item[] storage items = _properties[_propertyId].items;

                // Append storage space
                items.push();

                // Get the index of the new item
                // Cannot underflow as the items array length is ensured to be at least 1
                uint256 newItemIndex = items.length - 1;

                // Store the new item
                Item storage newItem = items[newItemIndex];

                // Store the new item's name and reference slot
                newItem.name = _items[i].name;
                newItem.referenceSlot = uint16(dataLength);
            }
        }
    }

    ///                                                          ///
    ///                     ATTRIBUTE GENERATION                 ///
    ///                                                          ///

    function _getAttributeIndicesForTokenId(uint256 _tokenId) internal view returns (uint16[16] memory) {
        uint16[16] memory attributes;

        uint256 seed = _tokenId;

        // First, add the background properties
        // Note: Background properties are always the first 4 properties
        unchecked {
            // For each bg property:
            for (uint256 i = 0; i < 4; ++i) {
                // Get the number of items to choose from
                uint256 numItems = properties[i].items.length;

                // Use the token's seed to select an item
                attributes[i] = uint16(seed % numItems);

                // console.log("layer - index - numItems: ", i, attributes[i], numItems);

                // Adjust the seed
                seed >>= 16;
            }
        }
        return attributes;
    }

    /// @notice The properties and query string for a generated token
    /// @param _tokenId The ERC-721 token id
    function getAttributes(uint256 _tokenId) public view returns (string memory resultAttributes, string memory queryString) {
        // Get the token's query string
        queryString = string.concat("?contractAddress=", Strings.toHexString(uint256(uint160(address(this))), 20), "&tokenId=", Strings.toString(_tokenId));

        // console.log("token qs", queryString);

        // Get the token's generated attributes
        uint16[16] memory tokenAttributes = _getAttributeIndicesForTokenId(_tokenId);

        // Get an array to store the token's generated attribtues
        MetadataBuilder.JSONItem[] memory arrayAttributesItems = new MetadataBuilder.JSONItem[](24);

        unchecked {
            // For each of the token's background properties:
            for (uint256 i = 0; i < 4; ++i) {
                // Get its name and list of associated items
                Property memory property = properties[i];

                // Get the randomly generated index of the item to select for this token
                uint256 attribute = tokenAttributes[i];

                // Get the associated item data
                Item memory item = property.items[attribute];
                // console.log(property.name, ":", item.name);

                // Store the encoded attributes and query string
                MetadataBuilder.JSONItem memory itemJSON = arrayAttributesItems[i];

                itemJSON.key = property.name;
                itemJSON.value = item.name;
                itemJSON.quote = true;

                queryString = string.concat(queryString, "&images=", _getItemImage(item, property.name));
            }

            // console.log("bg qs", queryString);

            // Next, select the attributes for each noun
            uint256 seed = _tokenId;

            // For each noun
            for (uint16 i = 0; i < 4; ++i) {
                // Cache the properties for this noun.
                Property[] memory _properties = nounProperties[i];
                uint16 variant = uint16(seed % 4);
                seed >>= 16;

                // console.log("noun-variant", i, variant);

                // we know that for each noun, there are 5 total properties that need to be added
                // properties 1 and 2 are variant dependant, and 3,4,5 are independent
                uint256 numBodyProperties = _properties[0 + variant].items.length;
                uint16 bodyIndex = uint16(seed % numBodyProperties);

                // console.log("numBodyProps-index", numBodyProperties, bodyIndex);

                // Get the associated itemData
                Item memory item = _properties[0 + variant].items[bodyIndex];

                // console.log("item.name", item.name);

                // Store the encoded attributes and query string
                MetadataBuilder.JSONItem memory itemJSON = arrayAttributesItems[4 + (i * 5)];
                itemJSON.key = _properties[0 + variant].name;
                itemJSON.value = item.name;
                itemJSON.quote = true;

                queryString = string.concat(queryString, "&images=", _getItemImage(item, _properties[0 + variant].name));

                // ok, bump the seed and move to property 2
                seed >>= 16;

                uint256 numAccProperties = _properties[4 + variant].items.length;
                uint16 accIndex = uint16(seed % numAccProperties);

                item = _properties[4 + variant].items[accIndex];

                // Store the encoded attributes and query string
                itemJSON = arrayAttributesItems[5 + (i * 5)];
                itemJSON.key = _properties[4 + variant].name;
                itemJSON.value = item.name;
                itemJSON.quote = true;

                queryString = string.concat(queryString, "&images=", _getItemImage(item, _properties[4 + variant].name));

                // Ok, now that the variant dependent items are out of the way, let's loop through the remaining 3 properties
                for (uint16 j = 0; j < 3; j++) {
                    seed >>= 16;
                    uint256 numProperties = _properties[8 + j].items.length;
                    uint16 index = uint16(seed % numProperties);

                    item = _properties[8 + j].items[index];

                    itemJSON = arrayAttributesItems[5 + (i * 5)];
                    itemJSON.key = _properties[4 + variant].name;
                    itemJSON.value = item.name;
                    itemJSON.quote = true;

                    queryString = string.concat(queryString, "&images=", _getItemImage(item, _properties[8 + j].name));
                }
            }

            // console.log("FINAL", queryString);

            resultAttributes = MetadataBuilder.generateJSON(arrayAttributesItems);
        }
    }

    /// @dev Encodes the reference URI of an item
    function _getItemImage(Item memory _item, string memory _propertyName) private view returns (string memory) {
        return
            UriEncode.uriEncode(
                string(abi.encodePacked(ipfsData[_item.referenceSlot].baseUri, _propertyName, "/", _item.name, ipfsData[_item.referenceSlot].extension))
            );
    }

    ///                                                          ///
    ///                            URIs                          ///
    ///                                                          ///

    /// @notice Internal getter function for token name
    function _name() internal view returns (string memory) {
        return ERC721(settings.token).name();
    }

    /// @notice The contract URI
    function contractURI() external view override returns (string memory) {
        MetadataBuilder.JSONItem[] memory items = new MetadataBuilder.JSONItem[](4);

        items[0] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyName, value: _name(), quote: true});
        items[1] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyDescription, value: settings.description, quote: true});
        items[2] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyImage, value: settings.contractImage, quote: true});
        items[3] = MetadataBuilder.JSONItem({key: "external_url", value: settings.projectURI, quote: true});

        return MetadataBuilder.generateEncodedJSON(items);
    }

    /// @notice The token URI
    /// @param _tokenId The ERC-721 token id
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        (string memory _attributes, string memory queryString) = getAttributes(_tokenId);

        MetadataBuilder.JSONItem[] memory items = new MetadataBuilder.JSONItem[](4);

        items[0] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyName, value: string.concat(_name(), " #", Strings.toString(_tokenId)), quote: true});
        items[1] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyDescription, value: settings.description, quote: true});
        items[2] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyImage, value: string.concat(settings.rendererBase, queryString), quote: true});
        items[3] = MetadataBuilder.JSONItem({key: MetadataJSONKeys.keyProperties, value: _attributes, quote: false});

        return MetadataBuilder.generateEncodedJSON(items);
    }

    ///                                                          ///
    ///                       METADATA SETTINGS                  ///
    ///                                                          ///

    /// @notice The associated ERC-721 token
    function token() external view returns (address) {
        return settings.token;
    }

    /// @notice The contract image
    function contractImage() external view returns (string memory) {
        return settings.contractImage;
    }

    /// @notice The renderer base
    function rendererBase() external view returns (string memory) {
        return settings.rendererBase;
    }

    /// @notice The collection description
    function description() external view returns (string memory) {
        return settings.description;
    }

    /// @notice The collection description
    function projectURI() external view returns (string memory) {
        return settings.projectURI;
    }

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        // noop
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the contract image
    /// @param _newContractImage The new contract image
    function updateContractImage(string memory _newContractImage) external onlyOwner {
        emit ContractImageUpdated(settings.contractImage, _newContractImage);

        settings.contractImage = _newContractImage;
    }

    /// @notice Updates the renderer base
    /// @param _newRendererBase The new renderer base
    function updateRendererBase(string memory _newRendererBase) external onlyOwner {
        emit RendererBaseUpdated(settings.rendererBase, _newRendererBase);

        settings.rendererBase = _newRendererBase;
    }

    /// @notice Updates the collection description
    /// @param _newDescription The new description
    function updateDescription(string memory _newDescription) external onlyOwner {
        emit DescriptionUpdated(settings.description, _newDescription);

        settings.description = _newDescription;
    }

    function updateProjectURI(string memory _newProjectURI) external onlyOwner {
        emit WebsiteURIUpdated(settings.projectURI, _newProjectURI);

        settings.projectURI = _newProjectURI;
    }
}
