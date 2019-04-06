var Auction = artifacts.require("./Token.sol");

module.exports = function(deployer) {
  deployer.deploy(Auction);
};
