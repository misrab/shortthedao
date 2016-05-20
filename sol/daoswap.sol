


import "./DAO.sol";

contract DaoSwap {
  /*address owner1, owner2, owner3;*/

  uint constant FINNEY_PER_ETHER = 1000;
  uint constant WEI_PER_FINNEY = 1000000000000000;
  uint constant SINGLE_TOKEN_PRICE_IN_FINNEY = 1400;
  // this is to pay for this contract's execution and reward its value-add
  uint constant CONTRACT_FEE_IN_FINNEY = 50;
  // to prevent spamming sellers list
  // i.e. 10 * 100 tokens would be 14 ether, about 140 bucks
  uint constant MIN_SELLER_TOKENS = 1000;


  address constant DAO_ADDRESS = 0xbb9bc244d798123fde783fcc1c72d3bb8c189413;
  DAO TheDao;

  address owner;

  // map seller to number of tokens for sale
  /*mapping (address => uint) sellers;*/
  // ! needs to be FIFO
  struct Account { address addr; uint number_tokens; }
  Account[] sellers;
  Account[] buyers;

  // expiry date
  uint public expiryDate;

  // constructor
  function DaoSwap() {
    owner = msg.sender;
    TheDao = DAO(DAO_ADDRESS);
    /*DaoToken = Token(DAO_TOKEN);
    DaoTokenCreation = TokenCreation(DAO_TOKEN_CREATION);*/
    expiryDate = TheDao.closingTime + 1 days;

  }


  // entering the contract
  function SellTokens(uint _number_tokens) {
    // require deposit
    if (msg.value < (_number_tokens * SINGLE_TOKEN_PRICE_IN_FINNEY * WEI_PER_FINNEY + CONTRACT_FEE_IN_FINNEY) || _number_tokens < MIN_SELLER_TOKENS) {
      throw;
    }

    sellers.push(Account(msg.sender, _number_tokens));
  }
  // almost identical to SellTokens()
  function BuyTokens(uint _number_tokens) {
    // require deposit
    if (msg.value < _number_tokens * SINGLE_TOKEN_PRICE_IN_FINNEY * WEI_PER_FINNEY) {
      throw;
    }

    buyers.push(Account(msg.sender, _number_tokens));
  }

  // the owner of this contract can execute the trades
  // after expiry.
  // Run FIFO accross buyers and sellers till either one
  // is empty. Reimburse remaining
  modifier afterExpiry() { if (now >= expiryDate) _ }
  // exported
  function CallExpiry() afterExpiry {
    if (msg.sender != owner) { throw; }

    // backward indexing for FIFO
    _index_sellers = 0; //sellers.length - 1;
    _index_buyers = 0; // buyers.length - 1;
    bool success;
    while (_index_sellers < sellers.length && _index_buyers < buyers.length) {
      // case 1: buyer and seller values match
      if (sellers[_index_sellers].number_tokens == buyers[_index_buyers].number_tokens) {
        // for this to work, this contract must have been authorised for said amount
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, buyers[_index_buyers].number_tokens);
        if (success) {
          // return seller's deposit, and transfer ether revenue to them
          sendSeller(sellers[_index_sellers].addr, sellers[_index_sellers].number_tokens, true);
          _index_buyers++;
        }
        _index_sellers++; // decrement regardless

      // case 2: buyer > seller
      // note we're always sending the min number_tokens between seller and buyer
      } else if (buyers[_index_buyers].number_tokens > sellers[_index_sellers].number_tokens) {
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, sellers[_index_sellers].number_tokens);
        if (success) {
          sendSeller(sellers[_index_sellers].addr, sellers[_index_sellers].number_tokens, true);
          buyers[_index_buyers].number_tokens -= sellers[_index_sellers].number_tokens;
          // don't decrement buyer regardless - they have more to buy
        }
        _index_sellers++;

      // case 3: buyer < seller
      } else {
        success = TheDao.transferFrom(sellers[_index_sellers].addr, buyers[_index_buyers].addr, buyers[_index_buyers].number_tokens);
        if (success) {
          // first refund the amount so far
          sellers[_index_sellers].number_tokens -= buyers[_index_buyers].number_tokens;
          sendSeller(sellers[_index_sellers].addr, buyers[_index_buyers].number_tokens, false);
          _index_buyers++;
        } else {
          // only decrement if we're skipping them because they failed
          _index_sellers++;
        }
      }
    }

    // clear remaining buyers or sellers
    if (_index_sellers < sellers.length) { reimburseRemaining(sellers, _index_sellers); }
    if (_index_buyers < buyers.length) { reimburseRemaining(buyers, _index_buyers); }
  }
  // matches a buyer to a seller
  function sendSeller(address addr, uint number_tokens, bool sendDepositBool) {
    uint amount = number_tokens * SINGLE_TOKEN_PRICE_IN_FINNEY * WEI_PER_FINNEY;
    if (sendDepositBool) { amount *= 2; }

    addr.send(amount);
  }



  /*
    Private methods
  */
  function reimburseRemaining(Account[] accounts, uint index) {
    // first sellers then buyers
    for(uint i = index; i < accounts.length; i++) {
      a[i].send(a[i].number_tokens * SINGLE_TOKEN_PRICE_IN_FINNEY * WEI_PER_FINNEY);
    }
  }

}
