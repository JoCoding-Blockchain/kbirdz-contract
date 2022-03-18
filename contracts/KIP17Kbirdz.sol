pragma solidity ^0.5.0;

import "./KIP17.sol";
import "./KIP17Metadata.sol";
import "./KIP17Enumerable.sol";
import "./roles/MinterRole.sol";
import "./math/SafeMath.sol";
import "./utils/String.sol";
import "./MerkleProof.sol";

contract KIP17Kbirdz is KIP17, KIP17Enumerable, KIP17Metadata, MinterRole {

    // To prevent bot attack, we record the last contract call block number.
    mapping (address => uint256) private _lastCallBlockNumber;
    uint256 private _antibotInterval;

    // If someone burns NFT in the middle of minting,
    // the tokenId will go wrong, so use the index instead of totalSupply().
    uint256 private _mintIndexForSale;

    uint256 private _mintLimitPerBlock;           // Maximum purchase nft per person per block
    uint256 private _mintLimitPerSale;            // Maximum purchase nft per person per sale

    string  private _tokenBaseURI;
    uint256 private _mintStartBlockNumber;        // In blockchain, blocknumber is the standard of time.
    uint256 private _maxSaleAmount;               // Maximum purchase volume of normal sale.
    uint256 private _mintPrice;                   // 1 KLAY = 1000000000000000000

    string baseURI;
    string notRevealedUri;
    bool public revealed = false;
    bool public publicMintEnabled = false;

    function _baseURI() internal view returns (string memory) {
      return baseURI;
    }

    function _notRevealedURI() internal view returns (string memory) {
      return notRevealedUri;
    }

    function setBaseURI(string memory _newBaseURI) public onlyMinter {
      baseURI = _newBaseURI;
    }

    function setNotRevealedURI(string memory _newNotRevealedURI) public onlyMinter {
      notRevealedUri = _newNotRevealedURI;
    }

    function reveal(bool _state) public onlyMinter {
      revealed = _state;
    }

    function tokenURI(uint256 tokenId)
      public
      view
      returns (string memory)
    {
      require(
        _exists(tokenId),
        "KIP17Metadata: URI query for nonexistent token"
      );
      
      if(revealed == false) {
        string memory currentNotRevealedUri = _notRevealedURI();
        return bytes(currentNotRevealedUri).length > 0
            ? string(abi.encodePacked(currentNotRevealedUri, String.uint2str(tokenId), ".json"))
            : "";
      }
      string memory currentBaseURI = _baseURI();
      return bytes(currentBaseURI).length > 0
          ? string(abi.encodePacked(currentBaseURI, String.uint2str(tokenId), ".json"))
          : "";
    }

    constructor () public {
      //init explicitly.
      _mintIndexForSale = 1;
    }

    function withdraw() external onlyMinter{
      // This code transfers 5% of the withdraw to JoCoding as a donation.
      // =============================================================================
      0x3e944Ca8B08a0a0D3245B05ABF01586B9142f52C.transfer(address(this).balance * 5 / 100);
      // =============================================================================
      // This will transfer the remaining contract balance to the owner.
      // Do not remove this otherwise you will not be able to withdraw the funds.
      // =============================================================================
      msg.sender.transfer(address(this).balance);
      // =============================================================================
    }

    function mintingInformation() external view returns (uint256[7] memory){
      uint256[7] memory info =
        [_antibotInterval, _mintIndexForSale, _mintLimitPerBlock, _mintLimitPerSale, 
          _mintStartBlockNumber, _maxSaleAmount, _mintPrice];
      return info;
    }

    function setPublicMintEnabled(bool _state) public onlyMinter {
      publicMintEnabled = _state;
    }

    function setupSale(uint256 newAntibotInterval, 
                       uint256 newMintLimitPerBlock,
                       uint256 newMintLimitPerSale,
                       uint256 newMintStartBlockNumber,
                       uint256 newMintIndexForSale,
                       uint256 newMaxSaleAmount,
                       uint256 newMintPrice) external onlyMinter{
      _antibotInterval = newAntibotInterval;
      _mintLimitPerBlock = newMintLimitPerBlock;
      _mintLimitPerSale = newMintLimitPerSale;
      _mintStartBlockNumber = newMintStartBlockNumber;
      _mintIndexForSale = newMintIndexForSale;
      _maxSaleAmount = newMaxSaleAmount;
      _mintPrice = newMintPrice;
    }

    //Public Mint
    function publicMint(uint256 requestedCount) external payable {
      require(publicMintEnabled, "The public sale is not enabled!");
      require(_lastCallBlockNumber[msg.sender].add(_antibotInterval) < block.number, "Bot is not allowed");
      require(block.number >= _mintStartBlockNumber, "Not yet started");
      require(requestedCount > 0 && requestedCount <= _mintLimitPerBlock, "Too many requests or zero request");
      require(msg.value == _mintPrice.mul(requestedCount), "Not enough Klay");
      require(_mintIndexForSale.add(requestedCount) <= _maxSaleAmount + 1, "Exceed max amount");
      require(balanceOf(msg.sender) + requestedCount <= _mintLimitPerSale, "Exceed max amount per person");

      for(uint256 i = 0; i < requestedCount; i++) {
        _mint(msg.sender, _mintIndexForSale);
        _mintIndexForSale = _mintIndexForSale.add(1);
      }
      _lastCallBlockNumber[msg.sender] = block.number;
    }

    //Whitelist Mint
    bytes32 public merkleRoot;
    mapping(address => bool) public whitelistClaimed;
    bool public whitelistMintEnabled = false;

    function setMerkleRoot(bytes32 _merkleRoot) public onlyMinter {
      merkleRoot = _merkleRoot;
    }

    function setWhitelistMintEnabled(bool _state) public onlyMinter {
      whitelistMintEnabled = _state;
    }

    function whitelistMint(uint256 requestedCount, bytes32[] calldata _merkleProof) external payable {
      require(whitelistMintEnabled, "The whitelist sale is not enabled!");
      require(msg.value == _mintPrice.mul(requestedCount), "Not enough Klay");
      require(!whitelistClaimed[msg.sender], 'Address already claimed!');
      require(requestedCount > 0 && requestedCount <= _mintLimitPerBlock, "Too many requests or zero request");
      bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
      require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof!');

      for(uint256 i = 0; i < requestedCount; i++) {
        _mint(msg.sender, _mintIndexForSale);
        _mintIndexForSale = _mintIndexForSale.add(1);
      }

      whitelistClaimed[msg.sender] = true;
    }

    //Airdrop Mint
    function airDropMint(address user, uint256 requestedCount) external onlyMinter {
      require(requestedCount > 0, "zero request");
      for(uint256 i = 0; i < requestedCount; i++) {
        _mint(user, _mintIndexForSale);
        _mintIndexForSale = _mintIndexForSale.add(1);
      }
    }
}