//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IrERC721.sol";
import "./interfaces/IRarity.sol";

contract rarity_extended_market {

    IRarity public _rm = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    uint public merchantSummoner;
    uint public lastReferral = 0;
    uint constant public feeToReferral = 10000; //100% == 1000000 || 1% == 10000
    mapping(address => mapping(uint => uint)) public listing; //mapping(_tokenContract => mapping(_tokenId => _price))
    mapping(uint => address) public referrals;

    constructor() {
        merchantSummoner = _rm.next_summoner();
        _rm.summon(11);
    }

    function _isApprovedOrOwner(uint _summoner) internal view returns (bool) {
        return (
            _rm.getApproved(_summoner) == msg.sender ||
            _rm.ownerOf(_summoner) == msg.sender ||
            _rm.isApprovedForAll(_rm.ownerOf(_summoner), msg.sender)
        );
    }
    
    function _isApprovedOrOwnerOfItem(uint256 _tokenID, address _source, uint _operator) internal view returns (bool) {
        return (
            IERC721(_source).ownerOf(_tokenID) == _operator ||
            IERC721(_source).getApproved(_tokenID) == _operator ||
            IERC721(_source).isApprovedForAll(_tokenID, _operator)
        );
    }

    function registerUIReferral() external {
        lastReferral += 1;
        require(referrals[lastReferral] == address(0), "registered");
        referrals[lastReferral] = msg.sender;
    }

    function listItem(address _tokenContract, uint _tokenId, uint _price) external {
        require(_isApprovedOrOwnerOfItem(_tokenId, _tokenContract, merchantSummoner), "!tokenIdOwner");
        require(_isApprovedOrOwner(IERC721(_tokenContract).ownerOf(_tokenId)), '!owner');
        require(_price > 0, '!zeroprice');
        listing[_tokenContract][_tokenId] = _price;
    }

    function delistItem(address _tokenContract, uint _tokenId) external {
        require(_isApprovedOrOwnerOfItem(_tokenId, _tokenContract, merchantSummoner), "!tokenIdOwner");
        require(_isApprovedOrOwner(IERC721(_tokenContract).ownerOf(_tokenId)), '!owner');
        listing[_tokenContract][_tokenId] = 0;
    }
    
    function buy(address _tokenContract, uint _tokenId, uint _receiver, uint _referral) external payable {
        uint price = listing[_tokenContract][_tokenId];
        require(price > 0, '!zeroprice');
        require(msg.value == price, '!msg.value');
        
        uint seller = IERC721(_tokenContract).ownerOf(_tokenId);
        address sellerAddr = _rm.ownerOf(seller);
        IERC721(_tokenContract).transferFrom(merchantSummoner, seller, _receiver, _tokenId);
        listing[_tokenContract][_tokenId] = 0; // not for sale anymore
        if (_referral == 0) {
            //No referral (No fee)
            payable(sellerAddr).transfer(msg.value); // send the FTM to the seller
        }else{
            uint fee = price * feeToReferral / 1000000;
            payable(referrals[_referral]).transfer(fee);
            payable(sellerAddr).transfer(price - fee);
        }
    }

}