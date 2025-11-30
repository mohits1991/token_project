const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Token", function () {
    let Token, token, owner, a, b, c;

    beforeEach(async () => {
        [owner, a, b, c] = await ethers.getSigners();
        Token = await ethers.getContractFactory("Token");
        token = await Token.deploy();
    });

    it("has default values", async () => {
        expect(await token.totalSupply()).to.equal(0n);
        expect(await token.balanceOf(a.address)).to.equal(0n);
    });

    it("can be minted", async () => {
        await token.connect(a).mint({ value: ethers.parseEther("1") });
        expect(await token.balanceOf(a.address)).to.equal(ethers.parseEther("1"));
    });

    it("can be burnt", async () => {
        await token.connect(a).mint({ value: ethers.parseEther("1") });
        await token.connect(a).burn(ethers.parseEther("1"));
        expect(await token.balanceOf(a.address)).to.equal(0n);
    });

    describe("once minted", () => {
        beforeEach(async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });
        });

        it("can be transferred directly", async () => {
            await token.connect(a).transfer(b.address, ethers.parseEther("1"));
            expect(await token.balanceOf(b.address)).to.equal(ethers.parseEther("1"));
        });

        it("can be transferred indirectly", async () => {
            await token.connect(a).transfer(b.address, ethers.parseEther("1"));
            await token.connect(b).transfer(c.address, ethers.parseEther("1"));
            expect(await token.balanceOf(c.address)).to.equal(ethers.parseEther("1"));
        });
    });

    describe("can record dividends", () => {
        it("and disallows empty dividend", async () => {
            await expect(token.recordDividend()).to.be.revertedWith("empty");
        });

        it("and keeps track of holders when minting and burning", async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });
            await token.connect(b).mint({ value: ethers.parseEther("1") });
            expect(await token.holdersLength()).to.equal(2);
            await token.connect(a).burn(ethers.parseEther("1"));
            expect(await token.holdersLength()).to.equal(1);
        });

        it("and keeps track of holders when transferring", async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });
            await token.connect(b).mint({ value: ethers.parseEther("1") });

            await token.connect(a).transfer(b.address, ethers.parseEther("1"));
            expect(await token.holdersLength()).to.equal(1);
        });

        it("and compounds the payouts", async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });

            await token.recordDividend({ value: ethers.parseEther("1") });
            await token.recordDividend({ value: ethers.parseEther("2") });

            expect(await token.owed(a.address)).to.equal(ethers.parseEther("3"));
        });

        it("and allows for withdrawals in-between payouts", async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });

            await token.recordDividend({ value: ethers.parseEther("1") });
            await token.connect(a).withdrawDividends();

            expect(await token.owed(a.address)).to.equal(0n);

            await token.recordDividend({ value: ethers.parseEther("2") });
            expect(await token.owed(a.address)).to.equal(ethers.parseEther("2"));
        });

        it("and allows for withdrawals even after holder relinquishes tokens", async () => {
            await token.connect(a).mint({ value: ethers.parseEther("1") });
            await token.recordDividend({ value: ethers.parseEther("1") });
            await token.connect(a).burn(ethers.parseEther("1"));
            expect(await token.owed(a.address)).to.equal(ethers.parseEther("1"));
        });
    });
});
