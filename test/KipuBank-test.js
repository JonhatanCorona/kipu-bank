const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("KipuBank", function () {
  let KipuBank, kipuBank, owner, user1, user2;
  const withdrawalLimit = ethers.parseEther("1"); // 1 ETH
  const bankCap = ethers.parseEther("10");       // 10 ETH

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    KipuBank = await ethers.getContractFactory("KipuBank");
    kipuBank = await KipuBank.deploy(withdrawalLimit, bankCap);
  });

  it("Inicializa correctamente", async function () {
    expect(await kipuBank.withdrawalLimit()).to.equal(withdrawalLimit);
    expect(await kipuBank.bankCap()).to.equal(bankCap);
    expect(await kipuBank.totalDeposits()).to.equal(0);
    expect(await kipuBank.totalDepositCount()).to.equal(0);
    expect(await kipuBank.totalWithdrawalCount()).to.equal(0);
  });

  describe("Depósitos", function () {
    it("Permite depositar ETH dentro del bankCap", async function () {
      const amount = ethers.parseEther("2");
      await expect(
        kipuBank.connect(user1).deposit(amount, { value: amount })
      ).to.emit(kipuBank, "Deposit")
       .withArgs(user1.address, amount, amount, 1);

      const balance = await kipuBank.connect(user1).getBalance();
      expect(balance).to.equal(amount);

      const stats = await kipuBank.getBankStats();
      expect(stats[0]).to.equal(amount); // totalDepositsActual
      expect(stats[1]).to.equal(1);      // totalDepositCount
      expect(stats[2]).to.equal(0);      // totalWithdrawalCount
    });

    it("Revertir si se supera el bankCap", async function () {
      const amount1 = ethers.parseEther("10");
      const amount2 = ethers.parseEther("1");

      await kipuBank.connect(user1).deposit(amount1, { value: amount1 });
      await expect(
        kipuBank.connect(user2).deposit(amount2, { value: amount2 })
      ).to.be.revertedWithCustomError(kipuBank, "BankCapExceeded");
    });

    it("Revertir si depositas 0 ETH", async function () {
      await expect(
        kipuBank.connect(user1).deposit(0, { value: 0 })
      ).to.be.revertedWithCustomError(kipuBank, "InvalidAmount");
    });
  });

  describe("Retiros", function () {
    beforeEach(async function () {
      const amount = ethers.parseEther("2");
      await kipuBank.connect(user1).deposit(amount, { value: amount });
    });

    it("Permite retirar hasta el withdrawalLimit", async function () {
      const amount = ethers.parseEther("1");
      await expect(
        kipuBank.connect(user1).withdraw(amount)
      ).to.emit(kipuBank, "Withdrawal")
       .withArgs(user1.address, amount, amount, 1);

      const balance = await kipuBank.connect(user1).getBalance();
      expect(balance).to.equal(ethers.parseEther("1"));
    });

    it("Revertir si se intenta retirar más que el withdrawalLimit", async function () {
      const amount = ethers.parseEther("2");
      await expect(
        kipuBank.connect(user1).withdraw(amount)
      ).to.be.revertedWithCustomError(kipuBank, "WithdrawalLimitExceeded");
    });

    it("Revertir si se intenta retirar más que el balance", async function () {
      const amount = ethers.parseEther("1");
      await expect(
        kipuBank.connect(user2).withdraw(amount)
      ).to.be.revertedWithCustomError(kipuBank, "InsufficientFunds");
    });

    it("Revertir si se intenta retirar 0 ETH", async function () {
      await expect(
        kipuBank.connect(user1).withdraw(0)
      ).to.be.revertedWithCustomError(kipuBank, "InvalidAmount");
    });
  });
});
