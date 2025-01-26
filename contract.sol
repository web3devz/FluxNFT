// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IERC7007 is IERC165 {
    event AigcData(uint256 indexed tokenId, bytes indexed prompt, bytes indexed aigcData, bytes proof);

    function addAigcData(
        uint256 tokenId,
        bytes calldata prompt,
        bytes calldata aigcData,
        bytes calldata proof
    ) external;

    function verify(
        bytes calldata prompt,
        bytes calldata aigcData,
        bytes calldata proof
    ) external view returns (bool success);
}

contract DynamicAIGCNFT is ERC721, IERC7007, Ownable {
    using ECDSA for bytes32;

    struct AigcContent {
        bytes prompt;
        bytes aigcData;
        bytes proof;
        uint256 transformTime; // Time for automatic transformation
        bool transformed;
    }

    mapping(uint256 => AigcContent) private _aigcContents;
    uint256 private _tokenCounter;

    constructor() ERC721("DynamicAIGCNFT", "DAI") {}

    event Transformed(uint256 indexed tokenId, bytes newAigcData);

    // Mint a new NFT
    function mintNFT(
        address to,
        bytes calldata prompt,
        bytes calldata aigcData,
        bytes calldata proof,
        uint256 transformTime
    ) external onlyOwner {
        uint256 tokenId = _tokenCounter++;
        _mint(to, tokenId);
        _aigcContents[tokenId] = AigcContent(prompt, aigcData, proof, transformTime, false);
        emit AigcData(tokenId, prompt, aigcData, proof);
    }

    // Add or update AIGC data for a token
    function addAigcData(
        uint256 tokenId,
        bytes calldata prompt,
        bytes calldata aigcData,
        bytes calldata proof
    ) external override onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        AigcContent storage content = _aigcContents[tokenId];
        content.prompt = prompt;
        content.aigcData = aigcData;
        content.proof = proof;
        emit AigcData(tokenId, prompt, aigcData, proof);
    }

    // Verify the proof for a token
    function verify(
        bytes calldata prompt,
        bytes calldata aigcData,
        bytes calldata proof
    ) external view override returns (bool success) {
        bytes32 hash = keccak256(abi.encodePacked(prompt, aigcData));
        address signer = ECDSA.recover(hash, proof);
        return signer != address(0);
    }

    // Automatically transform the NFT after the specified time
    function transformAfterTime(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        AigcContent storage content = _aigcContents[tokenId];
        require(block.timestamp >= content.transformTime, "Transformation time not reached");
        require(!content.transformed, "Already transformed");

        // Example of a new AIGC data transformation
        content.aigcData = abi.encodePacked("Transformed AI content after time");
        content.transformed = true;

        emit Transformed(tokenId, content.aigcData);
    }

    // Evolve NFT on interaction (e.g., transfer)
    function evolveOnInteraction(uint256 tokenId, bytes calldata newAigcData) internal {
        require(_exists(tokenId), "Token does not exist");
        AigcContent storage content = _aigcContents[tokenId];
        content.aigcData = newAigcData;
        emit Transformed(tokenId, newAigcData);
    }

   
    // Get the token URI, allowing dynamic updates
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        AigcContent memory content = _aigcContents[tokenId];

        // Return different metadata based on transformation status
        if (content.transformed) {
            return string(abi.encodePacked("ipfs://", content.aigcData));
        } else {
            return string(abi.encodePacked("ipfs://", content.prompt));
        }
    }

    // Burn a token and clean up its data
    function burn(uint256 tokenId) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        delete _aigcContents[tokenId];
        _burn(tokenId);
    }

    // Supports Interface function
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC7007).interfaceId || super.supportsInterface(interfaceId);
    }
}
