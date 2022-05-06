// SPDX-License-Identifier: MIT
//
// Interlock ERC-20 INTR Token Mint Platform
// 		(containing)
// components from OpenZeppelin v4.6.0 contract (token/ERC20/ERC20.sol)
//
// Contributors:
// blairmunroakusa
// ...

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./utils/Context.sol";
import "./POOL.sol";


 /** from oz
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 *
 * ( I believe the reason for needing atomic increase
 * is that the operation ties down allowance getter
 * preventing an allowance access before increase is complete. )
 **/

contract ERC20INTR is IERC20, Context {

	/** @dev **/

		// pools
	string[12] public poolNames = [
		"earlyvc",
		"ps1",
		"ps2",
		"ps3",
		"team",
		"ov",
		"advise",
		"reward",
		"founder",
		"partner",
		"white",
		"public" ];
	uint8 constant poolNumber = 12;

		// keeping track of pools
	struct PoolData {
		string name;
		uint32 tokens;
		uint8 payments;
		uint8 cliff;
		uint32 members; }
	PoolData[] public pool;
	mapping(address => PoolData) public poolMap;
	address[] private _pools;

		// keeping track of members
	struct MemberStatus {
		bool split;
		uint256 paid;
		uint256 share;
		address pool; }
	MemberStatus[] public status;
	mapping(address => MemberStatus) public statusMap;
	address[] private _members;
	mapping(address => address[]) _cohorts;

		// core token functionality | balance and allowance mappings
	mapping(address => uint256) private _balances;
	mapping(address => mapping(address => uint256)) public _allowances;

		// basic token data
	string private _name = "Interlock Network";
	string private _symbol = "INTR";
	uint256 private _totalSupply = 1000000000;
	address private _owner;
	// decimals = 18 by default

		// tracking time
	uint256 public lastPayout;
	uint256 public nextPayout;
	uint8 public monthsPassed; 

		// keeping track of irreversible actions
	bool public TGEtriggered = false;
	bool public supplySplit = false;
	


	/**
	* setup methods     FINISH INSTALLING GUARDS!!!
	**/
		 // owned by msg.sender
		// initializes contract
	constructor(
		uint32[poolNumber] memory poolTokens_,
		uint8[poolNumber] memory monthlyPayments_,
		uint8[poolNumber] memory poolCliffs_,
		uint32[poolNumber] memory poolMembers_
	) {
		_owner = _msgSender();
		_balances[address(this)] = 0; 

		for (uint8 i = 0; i < poolNumber; i++) {
			pool.push(
				PoolData(
					poolNames[i],
					poolTokens_[i],
					monthlyPayments_[i],
					poolCliffs_[i]++,
					poolMembers_[i]
				)
			); } }



		// creates account for each pool
	function splitSupply() public {
		
		// guard
		require(msg.sender == _owner,
			"not owner");
		require(supplySplit == false,
			"supply split alreadt happened");

		// create pool accounts and initiate
		for (uint8 i = 0; i < poolNumber; i++) {
			address Pool = address(new POOL());
			require(Pool != address(0),
				"failed to create pool");
			_pools.push(Pool);
			_balances[Pool] = 0;
			_allowances[address(this)][Pool] = 0;
			poolMap[Pool] = pool[i]; }
			//_cohorts[Pool] = new address[](pool[i].members);
	


		// this must never happen again...
		supplySplit = true; }


		  // in csv tx batches by pool
		 // which happens one member at a time
		// allocates pool supply between members
	function splitPool(uint256 share, address member, uint8 whichPool) public {

		//guards
		require(msg.sender == _owner,
			"must be owner");
		require(statusMap[member].split == false,
			"member already added");

		// intiate member  entry
		statusMap[member].paid = 0;
		statusMap[member].share = share;
		statusMap[member].pool = _pools[whichPool];
		_cohorts[_pools[whichPool]].push(member);
		_members.push(member);
		statusMap[member].split = true; }



		// generates all the tokens
	function triggerTGE() public {

		// guards
		require(supplySplit == true,
			"supply not split");
		require(msg.sender == _owner,
			"must be owner");
		require(TGEtriggered == false,
			"TGE already happened");

		// mint
		_balances[address(this)] = _totalSupply;
		_approve(address(this), msg.sender, _totalSupply);
		emit Transfer(address(0), address(this), _totalSupply);

		// start the clock for time vault pools
		nextPayout = block.timestamp + 30 days;
		monthsPassed = 0;

		// apply the initial round of token distributions
		//_poolDistribution();
		//_memberDistribution();

		// this must never happen again...
		TGEtriggered = true; }

	event Print(uint256 input);

		// distribute shares to all investor members
	function _memberDistribution() public {

		require(msg.sender == _owner,
			"must be owner");
		uint256 amount;
		for (uint8 i = 0; i < poolNumber; i++) {
			if (pool[i].cliff <= monthsPassed) {
				for (uint8 j = 0; j < pool[i].members; j++) {
					amount = 
						uint(statusMap[_cohorts[_pools[i]][j]].share) /
							pool[i].payments;
					transferFrom(
						_pools[i],
						_cohorts[_pools[i]][j],
						amount);
					statusMap[_cohorts[_pools[i]][j]].paid += amount; } } } }

						
						
			
		// distribute tokens to pools on schedule
	function _poolDistribution() public {
		require(msg.sender == _owner,
			"must be owner");
		uint256 amount;
		for (uint8 i = 0; i < poolNumber; i++) {
			if (pool[i].cliff <= monthsPassed) {
				// transfer month's distribution to pools
				amount = pool[i].tokens/pool[i].payments;
				transferFrom(
					address(this),
					_pools[i],
					amount );
				_approve(
					_pools[i],
					msg.sender,
					amount ); } } }



		// makes sure that distributions do not happen too early
	function _checkTime() internal returns (bool) {
		if (block.timestamp > nextPayout) {
			nextPayout += 30 days;
			monthsPassed++;
			return true; }
		return false; }
			


	function disown() public {
		require(msg.sender == _owner,
			"must be owner");
		_owner = address(0); }



	function changeOwner(address newOwner) public {
		require(msg.sender == _owner,
			"must be owner");
		_owner = newOwner; }
		// emit "new owner set"; }


	
	//now, as tokens are released on schedule, allowances will be incremented for all stakeholders. As they claim funds, balance will transfer and (TransferFrom) and deduct spendable allowance. This will also increase the 'circulating tokens'
		
		

	/**
	* getter methods
	**/

		// gets token name (Interlock Network)
	function name() public view override returns (string memory) {
		return _name; }



		// gets token symbol (INTR)
	function symbol() public view override returns (string memory) {
		return _symbol; }



 /* Returns the number of decimals used to get its user representation.
 *  For example, if `decimals` equals `2`, a balance of `505` tokens should
 *  be displayed to a user as `5.05` (`505 / 10 ** 2`).
 *
 *  NOTE: This information is only used for _display_ purposes: it in
 *  no way affects any of the arithmetic of the contract.
 **/



		// gets tokens minted
	function totalSupply() public view override returns (uint256) {
		return _totalSupply; }



		// gets account balance (tokens payable)
	function balanceOf(address account) public view override returns (uint256) {
		return _balances[account]; }



		// gets tokens spendable by spender from owner
	function allowance(
		address owner,
		address spender
	) public view virtual override returns (uint256) {
		return _allowances[owner][spender]; }



		// gets total tokens paid out in circulation
	function circulation() public view returns (uint256) {
		return _totalSupply - _balances[address(this)]; }



	/**
	* modifiers
	**/

		// verifies zero address was not provied
	modifier noZero(address _address) {
		require(_address != address(0),
			"zero address where it shouldn't be");
		_; }



		// verifies there exists enough token to proceed
	modifier isEnough(uint256 _available, uint256 _amount) {
		require(_available >= _amount,
			"not enough tokens available");
		_; }


	/**
	* doer methods
	**/
		   // emitting Transfer, reverting on failure
		  // where caller balanceOf must be >= amount
		 // where `to` cannot = zero  address
		// increases spender allowance
	function transfer(
		address to,
		uint256 amount
	) public override returns (bool) {
		address owner = _msgSender();
		_transfer(owner, to, amount);
		return true; }

		// internal implementation of transfer() above
	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal virtual noZero(from) noZero(to) isEnough(_balances[from], amount) {
		_beforeTokenTransfer(from, to, amount);
		unchecked {
			_balances[from] = _balances[from] - amount;}
		_balances[to] += amount;
		emit Transfer(from, to, amount);
		_afterTokenTransfer(from, to, amount); }



		  // emitting Approval, reverting on failure
		 // (=> no allownance delta when TransferFrom)
		// defines tokens available to spender from msg.sender
	function approve(
		address spender,
		uint256 amount
	) public override returns (bool) {
		address owner = _msgSender();
		_approve(owner, spender, amount);
		return true; }

		// internal implementation of approve() above 
	function _approve(
		address owner,
		address spender,
		uint256 amount
	) internal virtual noZero(owner) noZero(spender) {
		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount); }



		     // emitting Approval, reverting on failure
		    // where msg.sender allowance w/`from` must be >= amount
		   // where `from` balance must be >= amount
		  // where `from` and `to` cannot = zero address
		 // which does not update allowance if allowance = u256.max
		// pays portion of spender's allowance with owner to recipient
	function transferFrom(
		address from,
		address to,
		uint256 amount
	) public override returns (bool) {
		address spender = _msgSender();
		_spendAllowance(from, spender, amount);
		_transfer(from, to, amount);
		return true; }



		  // emitting Approval, reverting on failure
		 // where `spender` cannot = zero address
		// atomically increases spender's allowance
	function increaseAllowance(
		address spender,
		uint256 addedValue
	) public returns (bool) {
		address owner = _msgSender();
		_approve(owner, spender, allowance(owner, spender) + addedValue);
		return true; }

 /* Above and below are alternatives to {approve} that can be used
 *  as a mitigation for problems described in {IERC20-approve}.
 *
 * ?? Why is there no owner balance check for increaseAllowance() ??
 **/
		   // emitting Approval, reverting on failure
		  // where `spender` must have allowance >= `subtractedValue`
		 // where `spender` cannot = zero address
		// atomically decreases spender's allowance
	function decreaseAllowance(
		address spender,
		uint256 amount
	) public isEnough(allowance(_msgSender(), spender), amount) returns (bool) {
		address owner = _msgSender();
		unchecked {
			_approve(owner, spender, allowance(owner, spender) - amount);}
		return true; }



		   // emitting Transfer, reverting on failure
		  // where `account` must have >= burn amount
		 // where `account` cannot = zero address
		// decreases token supply by deassigning from account
	function _burn(
		address account,
		uint256 amount
	) internal noZero(account) isEnough(_balances[account], amount) {
		_beforeTokenTransfer(account, address(0), amount);
		unchecked {
			_balances[account] = _balances[account] - amount;}
		_totalSupply -= amount;
		emit Transfer(account, address(0), amount);
		_afterTokenTransfer(account, address(0), amount); }



		   // emitting Approval if finite, reverting on failure 
		  // will do nothing if infinite allowance
		 // used strictly internally
		// deducts from spender's allowance with owner
	function _spendAllowance(
		address owner,
		address spender,
		uint256 amount
	) internal isEnough(allowance(owner, spender), amount) {
		unchecked {
			_approve(owner, spender, allowance(owner, spender) - amount);}}



		    // where `from` && `to` != zero account => to be regular xfer
		   // where `from` = zero account => `amount` to be minted `to`
		  // where `to` = zero account => `amount` to be burned `from`
		 // where `from` && `to` = zero account => impossible
		// hook that inserts behavior prior to transfer/mint/burn
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal virtual {}



		    // where `from` && `to` != zero account => was regular xfer
		   // where `from` = zero account => `amount` was minted `to`
		  // where `to` = zero account => `amount` was burned `from`
		 // where `from` && `to` = zero account => impossible
		// hook that inserts behavior prior to transfer/mint/burn
	function _afterTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal virtual {}

}


