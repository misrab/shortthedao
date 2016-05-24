
var express = require('express');
var app = express();

// web3
var Web3 = require('web3');
var web3 = new Web3();
web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

// console.log(web3);
app.get('/stats', function (req, res) {
  var result = {};

  result.accounts = web3.eth.accounts;

  res.json(result);
});

app.listen(8080, function () {
  console.log('Example app listening...');
});
