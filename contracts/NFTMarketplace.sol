//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace1 is ERC721URIStorage{

    // address of the owner
    address payable owner;

    using Counters for Counters.Counter;

    // variable to keep track of total NFT minted
    Counters.Counter private _tokenIds;
    // variable to keep track of items sold on market place
    Counters.Counter private _itemsSold;
    // listing fee of the marketplace
    uint256 listPrice = 0.01 ether;
     
    // define constructor to initialize basic info for ERC721
    constructor() ERC721("NFTMarketplace1","NFTM"){
        owner = payable(msg.sender);
    }

    // Structure for NFT listed on the market place
    struct ListedToken{
        uint tokenId; // NFT id
        address payable owner; // owner of NFT 
        address payable seller; // seller of NFT
        uint256 price; // price of NFT
        bool currentlyListed; // flag for lisiting the NFT on marketplace
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess (
        uint256 indexed tokenId,
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed
    );

    // reverse mapping to get NFT info based on nftId
    mapping(uint256 => ListedToken) private idToListedToken;

    // update listing price for the market place
    function updateListPrice(uint256 _listPrice) public payable{
        require(owner == msg.sender, "Only owner canupdate the listing price");
        listPrice = _listPrice;
    }

    // get listing price for the marlet place
    function getListPrice() public view returns(uint256){
        return listPrice;
    }

     // get the latest Id of the NFT
    function getLatestIdToListedToken() public view returns(ListedToken memory){
        uint256 currentNFTId = _tokenIds.current();
        return idToListedToken[currentNFTId];
    }

    // get Listed NFT against a nftID
    function getListedforTokenId(uint256 nftId) public view returns(ListedToken memory){
        return idToListedToken[nftId];
    }

    // get curretn nft id
    function getCurrentToken() public view returns(uint256){
        return _tokenIds.current();
    }

    // function to create NFTs
    function createToken(string memory tokenURI, uint256 price) public payable returns(uint){
        require(msg.value == listPrice,"Send enough money to list");
        require(price > 0,"Make sure the price of Nft is not 0");
        
        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        
        _safeMint(msg.sender, currentTokenId); // safely minting the NFT, making sure the address sent by the user is correct
        _setTokenURI(currentTokenId, tokenURI);// set the tokenURI gainst the token ID

        createListedToken(currentTokenId, price); // create a listing of the minted token

        return currentTokenId ;
    }

    // function to add tokens to listing
    function createListedToken(uint256 tokenId, uint256 price) private{
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        _transfer(msg.sender, address(this), tokenId);// transfer ownership of nft to the this smart contract
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            address(this),
            msg.sender,
            price,
            true
        );
    }

    // get all NFTS
    function getAllNFTs() public view returns(ListedToken[] memory){
        
        // get the total number of nft count
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        uint256 currentIndex = 0;

        for(uint256 i=0; i < nftCount; i++){
            uint256 currentId = i+1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }

        return tokens;
    }

    // get NFTs against a specific owner
    function getMyNFTs() public view returns(ListedToken[] memory){
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // get the count of all the nfts that belong to address that called this function
        for(uint256 i = 0;i < totalItemCount;i++){
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
                itemCount += 1;
            }
        }

        // create an array for msg.sender's nft
        ListedToken[] memory items = new ListedToken[](itemCount);
        for(uint256 i = 0; i < itemCount;i++){
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
                uint currentId = i+1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    // function to execute a sale
    function executeSale(uint256 tokenId) public payable{
        // get the price of the NFT
        uint256 price = idToListedToken[tokenId].price;

        // make sure the ethers sent my the buyer is equal to the price of the nft
        require(msg.value == price, "Please send enough ethers to purchase the NFT");

        // get the seller address
        address seller = idToListedToken[tokenId].seller;

        idToListedToken[tokenId].currentlyListed = true; // for future iterations of the app, when one would like to take the NFT off the marketplace
        idToListedToken[tokenId].seller = payable(msg.sender); // change the seller's address to the address that bought the NFT

        _itemsSold.increment(); // keep track of items sold

        // transfer ownership to the person that bought the NFT
        _transfer(address(this), msg.sender, tokenId);

        // giving permission to the marketplace to approve sales on behalf of the owner
        approve(address(this), tokenId);

        // transfer the listing fee to the marketplce
        payable(owner).transfer(listPrice);

        // transfer money to the seller of the NFT
        payable(seller).transfer(price);
         
    }
}
