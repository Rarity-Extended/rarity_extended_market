const { expect } = require("chai");
const { whaleForest, forestV3, yFtmVault } = require("../registry.json");

describe("Tests", function () {

    before(async function () {
        [deployerSigner, anotherSigner] = await ethers.getSigners();

        //Deploy
        this._rarity_extended_market = await ethers.getContractFactory("rarity_extended_market");
        this.rarity_extended_market = await this._rarity_extended_market.deploy(yFtmVault);
        await this.rarity_extended_market.deployed();

        this.tokenId = 16237;
        this.summonerOwner = 2404363;

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [whaleForest],
        });

        this.whaleForestSigner = await ethers.getSigner(whaleForest);

        this.Forest = new ethers.Contract(forestV3, [
            'function approve(uint from, uint to, uint256 tokenId) external',
        ], this.whaleForestSigner);

    });

    it("Should register UI referral, without sending to vault...", async function () {
        let sendToVault = false;
        await this.rarity_extended_market.registerUIReferral(sendToVault);
        let referral = await this.rarity_extended_market.referrals(1);
        expect(referral.owner).equal(deployerSigner.address);
        expect(referral.sendToVault).equal(sendToVault);
    });

    it("Should register UI referral, sending to vault...", async function () {
        let sendToVault = true;
        await this.rarity_extended_market.registerUIReferral(sendToVault);
        let referral = await this.rarity_extended_market.referrals(2);
        expect(referral.owner).equal(deployerSigner.address);
        expect(referral.sendToVault).equal(sendToVault);
    });

    it("Should update UI referral...", async function () {
        let sendToVault = true;
        await expect(this.rarity_extended_market.connect(anotherSigner).updateUIReferral(1, anotherSigner.address, sendToVault)).to.be.revertedWith("!owner");
        await this.rarity_extended_market.updateUIReferral(1, anotherSigner.address, sendToVault);
        let referral = await this.rarity_extended_market.referrals(1);
        expect(referral.owner).equal(anotherSigner.address);
        expect(referral.sendToVault).equal(sendToVault);
    });

    it("Should list item...", async function () {
        // await expect(this.rarity_extended_market.listItem(forestV3, this.tokenId, ethers.utils.parseUnits("1"), 1)).to.be.revertedWith("!owner");
        // await this.Forest.connect(this.whaleForestSigner).approve(summonerOwner, );
        // await this.rarity_extended_market.connect(this.whaleForestSigner).listItem(forestV3, this.tokenId, ethers.utils.parseUnits("1"), 1);
    });

    it("Should delist item...", async function () {

    });

    it("Should buy item...", async function () {

    });

    it("Should set vault...", async function () {

    });

});