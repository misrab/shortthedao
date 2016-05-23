/// @title A contract to trade DAO tokens from the DAO crowdsale
/// before the crowdsale is over. See shortthedao.com and daohub.org
contract DaoSwap {

  uint constant HUNDRED = 100; // for % fee
  uint constant WEI_PER_ETHER = 1000000000000000000;
  uint constant PRICE_TOKEN_IN_WEI = 13000000000000000;
  uint constant PERCENT_CONTRACT_FEE = 1;
  uint constant MIN_WEI_VALUE = 5000000000000000000; // 5 ether
  uint constant DEPOSIT_PERCENT = 30; // % deposit required
  uint constant BUYER_FORFEITED_DEPOSIT_STAKE = 80;


  /*address constant DAO_ADDRESS = 0xbb9bc244d798123fde783fcc1c72d3bb8c189413;*/
  // address constants
  DAO TheDao = DAO(0xbb9bc244d798123fde783fcc1c72d3bb8c189413);

  address constant exiter = 0; // TODO = 0x...

  struct Account { address addr; uint number_tokens_in_wei; }
  Account[] sellers;
  Account[] buyers;

  /// @notice Buyers and sellers must entered into the contract by this date
  uint public cutoffEntry;
  /// @notice Sellers must have transfered their tokens by this date
  /// to avoid forfeiting deposits, by calling approve(...) on the Dao contract
  /// the usual way
  uint public cutoffExit;
  /// @notice This is set to true when the contract is over and
  /// all accounts have been settled
  bool public settled = false;

  uint public swap_ether_balance;
  uint public forfeited_deposits;

  /// @dev For special case where seller needs to go through many buyers
  /// to settle; we want to refund their true deposit, not the last settlement
  /// value
  mapping (address => uint) pending_deposits;

  modifier afterCutoffExit() { if (now >= cutoffExit) _ }
  modifier beforeCutoffEntry() { if (now < cutoffEntry) _ }

  // constructor
  function DaoSwap() {
    cutoffEntry = TheDao.closingTime();
    cutoffExit = cutoffEntry + 3 days;
  }

  /// @notice Enter into a contract with `msg.value` amount of
  /// deposit. E.g. If the `DEPOSIT_PERCENT` is 10, this means 10 Ether would
  /// represet a desire to sell 100 Ether equivalent of tokens minus micro-fees.
  /// If no match is found, the deposit is returned after `cutoffExit` when
  /// `CallExpiry` is called by anybody
  function SellTokens() beforeCutoffEntry {
    if (msg.value < MIN_WEI_VALUE) { throw; }
    swap_ether_balance += msg.value;

    uint _number_tokens_in_wei = (HUNDRED / DEPOSIT_PERCENT) * (msg.value * WEI_PER_ETHER) / PRICE_TOKEN_IN_WEI;

    sellers.push(Account(msg.sender, _number_tokens_in_wei));
  }

  /// @notice Enter into a conctract to purchase `msg.value` worth of tokens
  /// at this contract's price of `PRICE_TOKEN_IN_WEI` minus micro-fees. If no
  /// match found, the amount will be returned after `cutoffExit` when
  /// `CallExpiry` is called by anybody
  function BuyTokens() beforeCutoffEntry {
    if (msg.value < MIN_WEI_VALUE) { throw; }
    swap_ether_balance += msg.value;

    uint _number_tokens_in_wei = (msg.value * WEI_PER_ETHER) / PRICE_TOKEN_IN_WEI;
    buyers.push(Account(msg.sender, _number_tokens_in_wei));
  }

  // the owner of this contract can execute the trades
  // after expiry.
  // Run FIFO accross buyers and sellers till either one
  // is empty. Reimburse remaining
  // exported
  function CallExpiry() afterCutoffExit {

    // FIFO indexing
    uint _index_sellers = 0;
    uint _index_buyers = 0;
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
          // make sure we remember the seller's true deposit amount for
          // later reimbursement
          if (pending_deposits[sellers[_index_sellers].addr] == 0) {
            pending_deposits[sellers[_index_sellers].addr] = sellers[_index_sellers].number_tokens_in_wei;
          }

          // refund the amount so far
          sendSeller(sellers[_index_sellers].addr, buyers[_index_buyers].number_tokens_in_wei);
          sellers[_index_sellers].number_tokens_in_wei -= buyers[_index_buyers].number_tokens_in_wei;
          _index_buyers++;
        } else {
          // only increment if we're skipping them because they failed
          _index_sellers++;
        }
      }

      // keep track of amount of forfeited deposits
      // for later distribution
      if (!success) {
        forfeited_deposits += weiTokensToWei(sellers[_index_sellers].number_tokens_in_wei);
      }
    }

    // clear remaining buyers or sellers
    reimburseRemaining(sellers, _index_sellers);
    reimburseRemaining(buyers, _index_buyers);

    // finally mark contract as settled
    settled = true;
  }



  /*
    Private methods
  */

  /// @dev Send seller their deposit and revenue minus fee
  /// @param `addr` The address of the seller
  /// @param `number_tokens_in_wei` The number of tokens in wei units that they
  /// should receive revenue for
  function sendSeller(address addr, uint number_tokens_in_wei) internal {
    if (pending_deposits[sellers[_index_sellers].addr] > 0) {
      number_tokens_in_wei = pending_deposits[sellers[_index_sellers].addr];
    }

    uint _revenue = weiTokensToWei(number_tokens_in_wei);
    uint _deposit = (_revenue * DEPOSIT_PERCENT) / HUNDRED;
    uint _fee = ((_revenue + _deposit) * PERCENT_CONTRACT_FEE) / HUNDRED;

    uint _to_send = _revenue + _deposit - fee;

    addr.send(_to_send);
    swap_ether_balance -= _to_send;
  }

  // @dev Reimburse unmatched offers minus micro-fee for likely gas
  function reimburseRemaining(Account[] accounts, uint index) internal {
    uint _amount;
    uint _fee;
    for(uint i = index; i < accounts.length; i++) {
      _amount = weiTokensToWei(accounts[i].number_tokens_in_wei);
      _fee = (_amount * PERCENT_CONTRACT_FEE) / HUNDRED;
      accounts[i].addr.send(_amount - _fee);

      // not keeping track since contract will expire right after
      // swap_ether_balance -= (_amount - _fee);
    }
  }

  /// @dev Converts DAO tokens in wei units, into actual wei amount of
  /// Ether at given price
  function weiTokensToWei(uint wei_tokens) returns (uint amt) internal {
    return (wei_tokens * PRICE_TOKEN_IN_WEI) / WEI_PER_ETHER;
  }

  /// @dev Distribute `BUYER_FORFEITED_DEPOSIT_STAKE`% of forfeited_deposits to the buyers
  function distributeDeposits() internal {
    // this includes fees...
    uint total_amount_buyer = (forfeited_deposits * BUYER_FORFEITED_DEPOSIT_STAKE) / HUNDRED;
    uint amount_per_buyer = total_amount_buyer / buyers.length;

    for(uint i = 0; i < buyers.length; i++){
      buyers[i].addr.send(amount_per_buyer);
    }

  }

  /// @dev Destructor, allowed only after settlement is complete.
  /// Distributes forfeited deposits. Exiter on suicide is contract owner
  function kill() {
    if (!settled) { throw; }
    distributeDeposits();
    suicide(exiter);
  }

}
