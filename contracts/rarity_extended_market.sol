//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IrERC721.sol";
import "./interfaces/IRarity.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface WFTM is IERC20 {
    function deposit() external payable returns (uint256);
}

interface Vault {
    function deposit(uint256 amount, address recipient) external returns (uint256);
}

contract rarity_extended_market {

    IRarity public _rm = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
    WFTM public wftm = WFTM(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public EXTENDED;
    Vault public vault;
    uint public merchantSummoner;
    uint public lastReferral = 0;
    uint public lastOffer = 0;
    uint constant public feeToReferral = 10000; //100% == 1000000 || 1% == 10000
    mapping(uint => Offer) public offerings;
    mapping(uint => Referral) public referrals;

    event ReferralRegistered(address owner, bool sendToVault, uint referral);
    event ReferralUpdated(address owner, bool sendToVault, uint referral);
    event ItemListed(uint offerId, address tokenContract, uint tokenId, uint price, address sender, uint referral);
    event ItemDelisted(uint offerId);
    event ItemBought(uint offerId, uint referral);

    modifier onlyExtended() {
		require (msg.sender == EXTENDED, "!owner");
		_;
	}

    enum Status {
        Open,
        Executed,
        Cancelled
    }

    struct Referral {
        address owner;
        bool sendToVault;
    }

    struct Offer {
        uint from; // NFT SELLER
        uint to; // NFT BUYER
        address nftAddress; //ADDRESS OF THE NFT CONTRACT
        uint nftTokenID; //TOKEN ID OF THE NFT TO EXCHANGE
        uint wantAmount; //AMOUNT OF THE ERC20 TO EXCHANGE
        uint listingReferral; //REFERRAL FOR LIST ITEM
        uint buyingReferral; //REFERRAL FOR BUYING ITEM
        Status status; // Open, Executed, Cancelled
    }

    constructor(Vault _vault) {
        vault = _vault;
        merchantSummoner = _rm.next_summoner();
        _rm.summon(11);
        wftm.approve(address(_vault), type(uint).max);
        EXTENDED = msg.sender;
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

    function _sendFTMToVault(uint amount, address receiver) internal {
        wftm.deposit{value: amount}();
        vault.deposit(amount, receiver);
    }

    function _distributeFees(Offer memory _offer) internal {
        address seller = _rm.ownerOf(_offer.from);
        Referral memory buyingReferral = referrals[_offer.buyingReferral];
        Referral memory listingReferral = referrals[_offer.listingReferral];

        //listingReferral
        if (_offer.buyingReferral == 0 && _offer.listingReferral != 0) {
            uint fee = _offer.wantAmount * feeToReferral / 1000000;
            if (listingReferral.sendToVault){
                _sendFTMToVault(fee, listingReferral.owner);
            }else{
                payable(listingReferral.owner).transfer(fee);
            }
            payable(seller).transfer(_offer.wantAmount - fee);
        }

        //buyingReferral
        if (_offer.buyingReferral != 0 && _offer.listingReferral == 0) {
            uint fee = _offer.wantAmount * feeToReferral / 1000000;
            if (buyingReferral.sendToVault){
                _sendFTMToVault(fee, buyingReferral.owner);
            }else{
                payable(buyingReferral.owner).transfer(fee);
            }
            payable(seller).transfer(_offer.wantAmount - fee);
        }

        //both
        if (_offer.buyingReferral != 0 && _offer.listingReferral != 0) {
            uint fee = _offer.wantAmount * (feeToReferral / 2) / 1000000;

            if (buyingReferral.sendToVault){
                _sendFTMToVault(fee, buyingReferral.owner);
            }else{
                payable(buyingReferral.owner).transfer(fee);
            }

            if (listingReferral.sendToVault){
                _sendFTMToVault(fee, listingReferral.owner);
            }else{
                payable(listingReferral.owner).transfer(fee);
            }

            payable(seller).transfer(_offer.wantAmount - (fee * 2));
        }

        //none
        if (_offer.buyingReferral == 0 && _offer.listingReferral == 0) {
            payable(seller).transfer(msg.value); // send the FTM to the address of the seller summoner
        }

    }

    function setVault(address _vault) external onlyExtended() {
        vault = Vault(_vault);
    }

    function registerUIReferral(bool sendToVault) external returns (uint) {
        uint _lastReferral = lastReferral;
        _lastReferral += 1;
        referrals[_lastReferral] = Referral(msg.sender, sendToVault);
        lastReferral = _lastReferral;
        emit ReferralRegistered(msg.sender, sendToVault, _lastReferral);
        return _lastReferral;
    }

    function updateUIReferral(uint referral, address receiver, bool sendToVault) external returns (uint) {
        Referral memory _referral = referrals[referral];
        require(_referral.owner == msg.sender, "!owner");
        _referral.owner = receiver;
        _referral.sendToVault = sendToVault;
        referrals[referral] = _referral;
        emit ReferralUpdated(receiver, sendToVault, referral);
        return referral;
    }

    function listItem(address _tokenContract, uint _tokenId, uint _price, uint referral) external returns (uint) {
        uint summonerOwner = IERC721(_tokenContract).ownerOf(_tokenId);
        require(_isApprovedOrOwner(summonerOwner), '!owner');
        require(_price > 0, '!zeroprice');
        uint _lastOffer = lastOffer;
        _lastOffer += 1;
        offerings[_lastOffer] = Offer(summonerOwner, 0, _tokenContract, _tokenId, _price, referral, 0, Status.Open);
        IERC721(_tokenContract).transferFrom(merchantSummoner, summonerOwner, merchantSummoner, _tokenId);
        lastOffer = _lastOffer;
        emit ItemListed(_lastOffer, _tokenContract, _tokenId, _price, msg.sender, referral);
        return _lastOffer;
    }

    function delistItem(uint _offerId) external {
        Offer memory _offer = offerings[_offerId];
        require(_isApprovedOrOwner(IERC721(_offer.nftAddress).ownerOf(_offer.nftTokenID)), '!owner');
        require(_offer.status == Status.Open, "!status");
        IERC721(_offer.nftAddress).transferFrom(merchantSummoner, merchantSummoner, _offer.from, _offer.nftTokenID);
        _offer = Offer(0,0,address(this), 0,0,0,0, Status.Open);
        offerings[_offerId] = _offer;
        emit ItemDelisted(_offerId);
    }
    
    function buy(uint _offerId, uint receiver, uint _referral) external payable {
        Offer memory _offer = offerings[_offerId];
        require(_offer.status == Status.Open, "!status");
        require(_offer.wantAmount > 0, '!zeroprice');
        require(msg.value == _offer.wantAmount, '!msg.value');
        IERC721(_offer.nftAddress).transferFrom(merchantSummoner, merchantSummoner, receiver, _offer.nftTokenID);
        _offer.status = Status.Executed; // not for sale anymore
        _offer.buyingReferral = _referral;

        _distributeFees(_offer);

        emit ItemBought(_offerId, _referral);
    }

}