
var express = require('express');
var app = express();

// web3
var Web3 = require('web3');
var web3 = new Web3();
web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

var abi = [];
var address = "0x";
var daoswap = web3.eth.contract(abi).at(address);

// console.log(web3);
app.get('/stats', function (req, res) {
  var result = {};

  // result.accounts = web3.eth.accounts;
  result.seller_total_wei = seller_total_wei;
  result.buyer_total_wei = buyer_total_wei;

  res.json(result);
});

app.listen(8080, function () {
  console.log('Example app listening...');
});
