/*
Basic account, used by the DAO contract to separately manage both the rewards
and the extraBalance accounts.
*/

contract ManagedAccountInterface {
    // The only address with permission to withdraw from this account
    address public owner;
    // If true, only the owner of the account can receive ether from it
    bool public payOwnerOnly;
    // The sum of ether (in wei) which has been sent to this contract
    uint public accumulatedInput;

    /// @notice Sends `_amount` of wei to _recipient
    /// @param _amount The amount of wei to send to `_recipient`
    /// @param _recipient The address to receive `_amount` of wei
    /// @return True if the send completed
    function payOut(address _recipient, uint _amount) returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}


contract ManagedAccount is ManagedAccountInterface{

    // The constructor sets the owner of the account
    function ManagedAccount(address _owner, bool _payOwnerOnly);

    function payOut(address _recipient, uint _amount) returns (bool);
}



/// @title Standard Token Contract.

contract TokenInterface {
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    /// Total amount of tokens
    uint256 public totalSupply;

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`
    /// @param _from The address of the origin of the transfer
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success);

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    /// its behalf
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _amount) returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    /// to spend
    function allowance(
        address _owner,
        address _spender
    ) constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
    );
}


contract Token is TokenInterface {
    // Protects users by preventing the execution of method calls that
    // inadvertently also transferred ether
    modifier noEther() {}

    function balanceOf(address _owner) constant returns (uint256 balance);

    function transfer(address _to, uint256 _amount) noEther returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) noEther returns (bool success);

    function approve(address _spender, uint256 _amount) returns (bool success);

    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
}


contract TokenCreationInterface {

    // End of token creation, in Unix time
    uint public closingTime;
    // Minimum fueling goal of the token creation, denominated in tokens to
    // be created
    uint public minTokensToCreate;
    // True if the DAO reached its minimum fueling goal, false otherwise
    bool public isFueled;
    // For DAO splits - if privateCreation is 0, then it is a public token
    // creation, otherwise only the address stored in privateCreation is
    // allowed to create tokens
    address public privateCreation;
    // hold extra ether which has been sent after the DAO token
    // creation rate has increased
    ManagedAccount public extraBalance;
    // tracks the amount of wei given from each contributor (used for refund)
    mapping (address => uint256) weiGiven;

    /// @dev Constructor setting the minimum fueling goal and the
    /// end of the Token Creation
    /// @param _minTokensToCreate Minimum fueling goal in number of
    ///        Tokens to be created
    /// @param _closingTime Date (in Unix time) of the end of the Token Creation
    /// @param _privateCreation Zero means that the creation is public.  A
    /// non-zero address represents the only address that can create Tokens
    /// (the address can also create Tokens on behalf of other accounts)
    // This is the constructor: it can not be overloaded so it is commented out
    //  function TokenCreation(
        //  uint _minTokensTocreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );

    /// @notice Create Token with `_tokenHolder` as the initial owner of the Token
    /// @param _tokenHolder The address of the Tokens's recipient
    /// @return Whether the token creation was successful
    function createTokenProxy(address _tokenHolder) returns (bool success);

    /// @notice Refund `msg.sender` in the case the Token Creation did
    /// not reach its minimum fueling goal
    function refund();

    /// @return The divisor used to calculate the token creation rate during
    /// the creation phase
    function divisor() constant returns (uint divisor);

    event FuelingToDate(uint value);
    event CreatedToken(address indexed to, uint amount);
    event Refund(address indexed to, uint value);
}



contract TokenCreation is TokenCreationInterface, Token {
    function TokenCreation(
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation);

    function createTokenProxy(address _tokenHolder) returns (bool success);

    function refund() noEther;
    function divisor() constant returns (uint divisor);
}





contract DAOInterface {

    // The amount of days for which people who try to participate in the
    // creation by calling the fallback function will still get their ether back
    uint constant creationGracePeriod = 40 days;
    // The minimum debate period that a generic proposal can have
    uint constant minProposalDebatePeriod = 2 weeks;
    // The minimum debate period that a split proposal can have
    uint constant minSplitDebatePeriod = 1 weeks;
    // Period of days inside which it's possible to execute a DAO split
    uint constant splitExecutionPeriod = 27 days;
    // Period of time after which the minimum Quorum is halved
    uint constant quorumHalvingPeriod = 25 weeks;
    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    uint constant executeProposalPeriod = 10 days;
    // Denotes the maximum proposal deposit that can be given. It is given as
    // a fraction of total Ether spent plus balance of the DAO
    uint constant maxDepositDivisor = 100;

    // Proposals to spend the DAO's ether or to choose a new Curator
    Proposal[] public proposals;
    // The quorum needed for each proposal is partially calculated by
    // totalSupply / minQuorumDivisor
    uint public minQuorumDivisor;
    // The unix time of the last time quorum was reached on a proposal
    uint  public lastTimeMinQuorumMet;

    // Address of the curator
    address public curator;
    // The whitelist: List of addresses the DAO is allowed to send ether to
    mapping (address => bool) public allowedRecipients;

    // Tracks the addresses that own Reward Tokens. Those addresses can only be
    // DAOs that have split from the original DAO. Conceptually, Reward Tokens
    // represent the proportion of the rewards that the DAO has the right to
    // receive. These Reward Tokens are generated when the DAO spends ether.
    mapping (address => uint) public rewardToken;
    // Total supply of rewardToken
    uint public totalRewardToken;

    // The account used to manage the rewards which are to be distributed to the
    // DAO Token Holders of this DAO
    ManagedAccount public rewardAccount;

    // The account used to manage the rewards which are to be distributed to
    // any DAO that holds Reward Tokens
    ManagedAccount public DAOrewardAccount;

    // Amount of rewards (in wei) already paid out to a certain DAO
    mapping (address => uint) public DAOpaidOut;

    // Amount of rewards (in wei) already paid out to a certain address
    mapping (address => uint) public paidOut;
    // Map of addresses blocked during a vote (not allowed to transfer DAO
    // tokens). The address points to the proposal ID.
    mapping (address => uint) public blocked;

    // The minimum deposit (in wei) required to submit any proposal that is not
    // requesting a new Curator (no deposit is required for splits)
    uint public proposalDeposit;

    // the accumulated sum of all current proposal deposits
    uint sumOfProposalDeposits;

    // Contract that is able to create a new DAO (with the same code as
    // this one), used for splits
    DAO_Creator public daoCreator;

    // A proposal with `newCurator == false` represents a transaction
    // to be issued by this DAO
    // A proposal with `newCurator == true` represents a DAO split
    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted
        // or if `newCurator` is true, the proposed Curator of
        // the new DAO).
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        uint amount;
        // A plain text description of the proposal
        string description;
        // A unix timestamp, denoting the end of the voting period
        uint votingDeadline;
        // True if the proposal's votes have yet to be counted, otherwise False
        bool open;
        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        bool proposalPassed;
        // A hash to check validity of a proposal
        bytes32 proposalHash;
        // Deposit in wei the creator added when submitting their proposal. It
        // is taken from the msg.value of a newProposal call.
        uint proposalDeposit;
        // True if this proposal is to assign a new Curator
        bool newCurator;
        // Data needed for splitting the DAO
        SplitData[] splitData;
        // Number of Tokens in favor of the proposal
        uint yea;
        // Number of Tokens opposed to the proposal
        uint nay;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
        // Address of the shareholder who created the proposal
        address creator;
    }

    // Used only in the case of a newCurator proposal.
    struct SplitData {
        // The balance of the current DAO minus the deposit at the time of split
        uint splitBalance;
        // The total amount of DAO Tokens in existence at the time of split.
        uint totalSupply;
        // Amount of Reward Tokens owned by the DAO at the time of split.
        uint rewardToken;
        // The new DAO contract created at the time of split.
        DAO newDAO;
    }

    // Used to restrict access to certain functions to only DAO Token Holders
    modifier onlyTokenholders {}

    /// @dev Constructor setting the Curator and the address
    /// for the contract able to create another DAO as well as the parameters
    /// for the DAO Token Creation
    /// @param _curator The Curator
    /// @param _daoCreator The contract able to (re)create this DAO
    /// @param _proposalDeposit The deposit to be paid for a regular proposal
    /// @param _minTokensToCreate Minimum required wei-equivalent tokens
    ///        to be created for a successful DAO Token Creation
    /// @param _closingTime Date (in Unix time) of the end of the DAO Token Creation
    /// @param _privateCreation If zero the DAO Token Creation is open to public, a
    /// non-zero address means that the DAO Token Creation is only for the address
    // This is the constructor: it can not be overloaded so it is commented out
    //  function DAO(
        //  address _curator,
        //  DAO_Creator _daoCreator,
        //  uint _proposalDeposit,
        //  uint _minTokensToCreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );

    /// @notice Create Token with `msg.sender` as the beneficiary
    /// @return Whether the token creation was successful
    function () returns (bool success);


    /// @dev This function is used to send ether back
    /// to the DAO, it can also be used to receive payments that should not be
    /// counted as rewards (donations, grants, etc.)
    /// @return Whether the DAO received the ether successfully
    function receiveEther() returns(bool);

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
    /// `_recipient` with the transaction data `_transactionData`. If
    /// `_newCurator` is true, then this is a proposal that splits the
    /// DAO and sets `_recipient` as the new DAO's Curator.
    /// @param _recipient Address of the recipient of the proposed transaction
    /// @param _amount Amount of wei to be sent with the proposed transaction
    /// @param _description String describing the proposal
    /// @param _transactionData Data of the proposed transaction
    /// @param _debatingPeriod Time used for debating a proposal, at least 2
    /// weeks for a regular proposal, 10 days for new Curator proposal
    /// @param _newCurator Bool defining whether this proposal is about
    /// a new Curator or not
    /// @return The proposal ID. Needed for voting on the proposal
    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID);

    /// @notice Check that the proposal with the ID `_proposalID` matches the
    /// transaction which sends `_amount` with data `_transactionData`
    /// to `_recipient`
    /// @param _proposalID The proposal ID
    /// @param _recipient The recipient of the proposed transaction
    /// @param _amount The amount of wei to be sent in the proposed transaction
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposal ID matches the transaction data or not
    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) constant returns (bool _codeChecksOut);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    /// @return The vote ID.
    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders returns (uint _voteID);

    /// @notice Checks whether proposal `_proposalID` with transaction data
    /// `_transactionData` has been voted for or rejected, and executes the
    /// transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposed transaction has been executed or not
    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) returns (bool _success);

    /// @notice ATTENTION! I confirm to move my remaining ether to a new DAO
    /// with `_newCurator` as the new Curator, as has been
    /// proposed in proposal `_proposalID`. This will burn my tokens. This can
    /// not be undone and will split the DAO into two DAO's, with two
    /// different underlying tokens.
    /// @param _proposalID The proposal ID
    /// @param _newCurator The new Curator of the new DAO
    /// @dev This function, when called for the first time for this proposal,
    /// will create a new DAO and send the sender's portion of the remaining
    /// ether and Reward Tokens to the new DAO. It will also burn the DAO Tokens
    /// of the sender.
    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) returns (bool _success);

    /// @dev can only be called by the DAO itself through a proposal
    /// updates the contract of the DAO by sending all ether and rewardTokens
    /// to the new DAO. The new DAO needs to be approved by the Curator
    /// @param _newContract the address of the new contract
    function newContract(address _newContract);


    /// @notice Add a new possible recipient `_recipient` to the whitelist so
    /// that the DAO can send transactions to them (using proposals)
    /// @param _recipient New recipient address
    /// @dev Can only be called by the current Curator
    /// @return Whether successful or not
    function changeAllowedRecipients(address _recipient, bool _allowed) external returns (bool _success);


    /// @notice Change the minimum deposit required to submit a proposal
    /// @param _proposalDeposit The new proposal deposit
    /// @dev Can only be called by this DAO (through proposals with the
    /// recipient being this DAO itself)
    function changeProposalDeposit(uint _proposalDeposit) external;

    /// @notice Move rewards from the DAORewards managed account
    /// @param _toMembers If true rewards are moved to the actual reward account
    ///                   for the DAO. If not then it's moved to the DAO itself
    /// @return Whether the call was successful
    function retrieveDAOReward(bool _toMembers) external returns (bool _success);

    /// @notice Get my portion of the reward that was sent to `rewardAccount`
    /// @return Whether the call was successful
    function getMyReward() returns(bool _success);

    /// @notice Withdraw `_account`'s portion of the reward from `rewardAccount`
    /// to `_account`'s balance
    /// @return Whether the call was successful
    function withdrawRewardFor(address _account) internal returns (bool _success);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this
    /// getMyReward() is called.
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferWithoutReward(address _to, uint256 _amount) returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`. Prior to this getMyReward() is called.
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _amount
    ) returns (bool success);

    /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
    /// achieved in 52 weeks
    /// @return Whether the change was successful or not
    function halveMinQuorum() returns (bool _success);

    /// @return total number of proposals ever created
    function numberOfProposals() constant returns (uint _numberOfProposals);

    /// @param _proposalID Id of the new curator proposal
    /// @return Address of the new DAO
    function getNewDAOAddress(uint _proposalID) constant returns (address _newDAO);

    /// @param _account The address of the account which is checked.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function isBlocked(address _account) internal returns (bool);

    /// @notice If the caller is blocked by a proposal whose voting deadline
    /// has exprired then unblock him.
    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function unblockMe() returns (bool);

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        bool newCurator,
        string description
    );
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result, uint quorum);
    event NewCurator(address indexed _newCurator);
    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

// The DAO contract itself
contract DAO is DAOInterface, Token, TokenCreation {

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyTokenholders {
        if (balanceOf(msg.sender) == 0) throw;
            _
    }

    function DAO(
        address _curator,
        DAO_Creator _daoCreator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation
    ) TokenCreation(_minTokensToCreate, _closingTime, _privateCreation);


    function receiveEther() returns (bool);


    function newProposal(
        address _recipient,
        uint _amount,
        string _description,
        bytes _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders returns (uint _proposalID);


    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes _transactionData
    ) noEther constant returns (bool _codeChecksOut);

    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders noEther returns (uint _voteID);

    function executeProposal(
        uint _proposalID,
        bytes _transactionData
    ) noEther returns (bool _success);


    function closeProposal(uint _proposalID) internal;

    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) noEther onlyTokenholders returns (bool _success);

    function newContract(address _newContract);
    function retrieveDAOReward(bool _toMembers) external noEther returns (bool _success);

    function getMyReward() noEther returns (bool _success);

    function withdrawRewardFor(address _account) noEther internal returns (bool _success);


    function transfer(address _to, uint256 _value) returns (bool success);


    function transferWithoutReward(address _to, uint256 _value) returns (bool success);


    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);


    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _value
    ) returns (bool success);


    function transferPaidOut(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool success);


    function changeProposalDeposit(uint _proposalDeposit) noEther external;

    function changeAllowedRecipients(address _recipient, bool _allowed) noEther external returns (bool _success);


    function isRecipientAllowed(address _recipient) internal returns (bool _isAllowed);

    function actualBalance() constant returns (uint _actualBalance);


    function minQuorum(uint _value) internal constant returns (uint _minQuorum);


    function halveMinQuorum() returns (bool _success);

    function createNewDAO(address _newCurator) internal returns (DAO _newDAO);

    function numberOfProposals() constant returns (uint _numberOfProposals);

    function getNewDAOAddress(uint _proposalID) constant returns (address _newDAO);

    function isBlocked(address _account) internal returns (bool);
    function unblockMe() returns (bool);
}

contract DAO_Creator {
    function createDAO(
        address _curator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime
    ) returns (DAO _newDAO);
}

/// @title A contract to trade DAO tokens from the DAO crowdsale
/// before the crowdsale is over. See shortthedao.com and daohub.org
contract DaoSwap {

  uint constant HUNDRED = 100; // for % fee
  uint constant WEI_PER_ETHER = 1000000000000000000;
  uint constant PRICE_TOKEN_IN_WEI = 13000000000000000;
  uint constant PERCENT_CONTRACT_FEE = 1;
  uint constant MIN_WEI_VALUE = 5000000000000000000; // 5 ether
  uint constant DEPOSIT_PERCENT = 100; // % deposit required
  uint constant BUYER_FORFEITED_DEPOSIT_STAKE = 80;
  uint constant BILLION = 1000000000;


  /*address constant DAO_ADDRESS = 0xbb9bc244d798123fde783fcc1c72d3bb8c189413;*/
  // address constants
  DAO TheDao = DAO(0xbb9bc244d798123fde783fcc1c72d3bb8c189413);
  // TheDao = TokenInterface(0x3C6F5633b30AA3817FA50b17e5bd30fB49BdDD95);

  address constant exiter = 0x388132fCbD1bDcE887d42EE64fc7a01eBB5Cb664; // TODO = 0x...

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
    // cutoffEntry = TheDao.closingTime();
    // cutoffExit = cutoffEntry + 3 days;
    cutoffEntry = now + 20 minutes;
    cutoffExit = now + 25 minutes;
  }

  /// @notice Enter into a contract with `msg.value` amount of
  /// deposit. E.g. If the `DEPOSIT_PERCENT` is 10, this means 10 Ether would
  /// represet a desire to sell 100 Ether equivalent of tokens minus micro-fees.
  /// If no match is found, the deposit is returned after `cutoffExit` when
  /// `CallExpiry` is called by anybody
  function SellTokens() beforeCutoffEntry {
    if (msg.value < MIN_WEI_VALUE) { throw; }
    swap_ether_balance += msg.value;

    uint _number_tokens_in_wei = (HUNDRED / DEPOSIT_PERCENT) * (msg.value * BILLION) / PRICE_TOKEN_IN_WEI;

    sellers[sellers.length++] = Account(msg.sender, _number_tokens_in_wei);
  }

  /// @notice Enter into a conctract to purchase `msg.value` worth of tokens
  /// at this contract's price of `PRICE_TOKEN_IN_WEI` minus micro-fees. If no
  /// match found, the amount will be returned after `cutoffExit` when
  /// `CallExpiry` is called by anybody
  function BuyTokens() beforeCutoffEntry {
    if (msg.value < MIN_WEI_VALUE) { throw; }
    swap_ether_balance += msg.value;

    uint _number_tokens_in_wei = (msg.value * BILLION) / PRICE_TOKEN_IN_WEI;
    buyers[buyers.length++] = Account(msg.sender, _number_tokens_in_wei);
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


  function sendSeller(address addr, uint number_tokens_in_wei) private {
    if (pending_deposits[addr] > 0) {
      number_tokens_in_wei = pending_deposits[addr];
    }

    uint _revenue = weiTokensToWei(number_tokens_in_wei);
    uint _deposit = (_revenue * DEPOSIT_PERCENT) / HUNDRED;
    uint _fee = ((_revenue + _deposit) * PERCENT_CONTRACT_FEE) / HUNDRED;

    uint _to_send = _revenue + _deposit - _fee;

    addr.send(_to_send);
    swap_ether_balance -= _to_send;
  }

  // @dev Reimburse unmatched offers minus micro-fee for likely gas
  function reimburseRemaining(Account[] accounts, uint index) private {
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
  function weiTokensToWei(uint wei_tokens) private returns (uint amt) {
    return (wei_tokens * PRICE_TOKEN_IN_WEI) / BILLION;
  }

  /// @dev Distribute `BUYER_FORFEITED_DEPOSIT_STAKE`% of forfeited_deposits to the buyers
  function distributeDeposits() {
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
