contract DaoSwap {
  /*uint constant FINNEY_PER_ETHER = 1000;*/
  /*uint constant WEI_PER_FINNEY = 1000000000000000;*/

  /*uint constant THOUSAND = 1000;*/
  uint constant HUNDRED = 100; // for % fee
  uint constant WEI_PER_ETHER = 1000000000000000000;

  /*uint constant SINGLE_TOKEN_PRICE_IN_FINNEY = 1400;*/

  // 14 wei for 1000 wei tokens
  // or 1.4 Ether per 100 tokens
  // we do this since 1 wei token is 0.014 wei, which is decimal
  /*uint constant PRICE_THOUSAND_WEI_TOKENS_IN_WEI = 14;*/

  uint constant PRICE_TOKEN_IN_WEI = 14000000000000000;

  // this is to pay for this contract's execution and reward its value-add
  /*uint constant MIN_CONTRACT_FEE_IN_FINNEY = 50;*/
  uint constant PERCENT_CONTRACT_FEE = 1;
  // to prevent spamming sellers list
  // i.e. 10 * 100 tokens would be 14 ether, about 140 bucks
  /*uint constant MIN_SELLER_TOKENS = 1000;*/
  uint constant MIN_WEI_VALUE = 5000000000000000000; // 5 ether



  address constant DAO_ADDRESS = 0xbb9bc244d798123fde783fcc1c72d3bb8c189413;
  DAO TheDao;

  address owner;
  address constant exiter; // TODO = 0x...

  // map seller to number of tokens for sale
  /*mapping (address => uint) sellers;*/
  // ! needs to be FIFO
  struct Account { address addr; uint number_tokens_in_wei; }
  Account[] sellers;
  Account[] buyers;

  // cutoff for entering as buyer or seller
  uint public cutoffEntry;
  // cutoff for calling settlement on entire contract
  // i.e. sellers must have transfered tokens by this
  uint public cutoffExit;
  // this is set to true when the contract is over
  // i.e. all settlement complete
  bool public settled = false;

  modifier afterCutoffExit() { if (now >= cutoffExit) _ }
  modifier beforeCutoffEntry() { if (now < cutoffEntry) _ }

  // constructor
  function DaoSwap() {
    owner = msg.sender;
    TheDao = DAO(DAO_ADDRESS);
    /*settled = false;*/

    cutoffEntry = TheDao.closingTime;
    cutoffExit = cutoffEntry + 3 days;
  }


  // entering the contract
  function SellTokens() beforeCutoffEntry {
    if (msg.value < MIN_WEI_VALUE) { throw; }

    /*uint _number_tokens_in_wei_times_thousand = msg.value / PRICE_THOUSAND_WEI_TOKENS_IN_WEI;*/
    uint _number_tokens_in_wei = (msg.value * WEI_PER_ETHER) / PRICE_TOKEN_IN_WEI;
    /*_number_tokens_in_wei_times_thousand / THOUSAND;*/

    // require deposit
    /*if (msg.value < (_number_tokens * SINGLE_TOKEN_PRICE_IN_FINNEY * WEI_PER_FINNEY) || _number_tokens < MIN_SELLER_TOKENS) {
      throw;
    }*/


    sellers.push(Account(msg.sender, _number_tokens_in_wei));
  }
  // almost identical to SellTokens()
  // TODO copy above when units fixed
  function BuyTokens() beforeCutoffEntry {
    // may want to make this different for buyers and sellers
    if (msg.value < MIN_WEI_VALUE) { throw; }
    /*uint _number_tokens_in_wei_times_thousand = msg.value / PRICE_THOUSAND_WEI_TOKENS_IN_WEI;*/
    /*uint _number_tokens_in_wei = _number_tokens_in_wei_times_thousand / THOUSAND;*/

    uint _number_tokens_in_wei = (msg.value * WEI_PER_ETHER) / PRICE_TOKEN_IN_WEI;
    buyers.push(Account(msg.sender, _number_tokens_in_wei));
  }

  // the owner of this contract can execute the trades
  // after expiry.
  // Run FIFO accross buyers and sellers till either one
  // is empty. Reimburse remaining
  // exported
  function CallExpiry() afterCutoffExit {
    // allowing anyone to call this
    /*if (msg.sender != owner) { throw; }*/

    // backward indexing for FIFO
    _index_sellers = 0; //sellers.length - 1;
    _index_buyers = 0; // buyers.length - 1;
    bool success;
    while (_index_sellers < sellers.length && _index_buyers < buyers.length) {
      // case 1: buyer and seller values match
      if (sellers[_index_sellers].number_tokens_in_wei == buyers[_index_buyers].number_tokens_in_wei) {
        // for this to work, this contract must have been authorised for said amount
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, buyers[_index_buyers].number_tokens_in_wei);
        if (success) {
          // return seller's deposit, and transfer ether revenue to them
          sendSeller(sellers[_index_sellers].addr, sellers[_index_sellers].number_tokens_in_wei);
          _index_buyers++;
        }
        _index_sellers++; // decrement regardless

      // case 2: buyer > seller
      // note we're always sending the min number_tokens between seller and buyer
      } else if (buyers[_index_buyers].number_tokens_in_wei > sellers[_index_sellers].number_tokens_in_wei) {
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, sellers[_index_sellers].number_tokens_in_wei);
        if (success) {
          sendSeller(sellers[_index_sellers].addr, sellers[_index_sellers].number_tokens_in_wei);
          buyers[_index_buyers].number_tokens_in_wei -= sellers[_index_sellers].number_tokens_in_wei;
          // don't decrement buyer regardless - they have more to buy
        }
        _index_sellers++;

      // case 3: buyer < seller
      } else {
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, buyers[_index_buyers].number_tokens_in_wei);
        if (success) {
          // first refund the amount so far
          sellers[_index_sellers].number_tokens_in_wei -= buyers[_index_buyers].number_tokens_in_wei;
          sendSeller(sellers[_index_sellers].addr, buyers[_index_buyers].number_tokens_in_wei);
          _index_buyers++;
        } else {
          // only decrement if we're skipping them because they failed
          _index_sellers++;
        }
      }
    }

    // clear remaining buyers or sellers
    /*if (_index_sellers < sellers.length) { reimburseRemaining(sellers, _index_sellers); }*/
    /*if (_index_buyers < buyers.length) { reimburseRemaining(buyers, _index_buyers); }*/
    reimburseRemaining(sellers, _index_sellers);
    reimburseRemaining(buyers, _index_buyers);

    // finally mark contract as settled
    settled = true;
  }



  /*
    Private methods
  */

  // send revenue - fee
  function sendSeller(address addr, uint number_tokens_in_wei) {
    uint amount_before_fee = weiTokensToWei(number_tokens_in_wei);
    uint fee = (amount_before_fee * PERCENT_CONTRACT_FEE) / HUNDRED;


    addr.send(amount_before_fee - fee);
  }

  // reimburse full amount
  function reimburseRemaining(Account[] accounts, uint index) {
    // first sellers then buyers
    for(uint i = index; i < accounts.length; i++) {
      accounts[i].send(weiTokensToWei(accounts[i].number_tokens_in_wei));
    }
  }

  function weiTokensToWei(uint wei_tokens) returns (uint wei) {
    return (wei_tokens * PRICE_TOKEN_IN_WEI) / WEI_PER_FINNEY;
  }

  // destructor
  function kill() {
    // allow anyone
    /*if (msg.sender != owner) { throw; }*/
    if (!settled) { throw; }

    suicide(exiter);
  }

}
