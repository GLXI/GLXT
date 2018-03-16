pragma solidity 0.4.18;
/*
For details, please visit: https://glxtoken.com/
*/
// Math contract to avoid overflow and underflow of variables
contract SafeMath {

    function safeAdd(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x + y;
      assert((z >= x) && (z >= y));
      return z;
    }

    function safeSubtract(uint256 x, uint256 y) internal returns(uint256) {
      assert(x >= y);
      uint256 z = x - y;
      return z;
    }

    function safeMult(uint256 x, uint256 y) internal returns(uint256) {
      uint256 z = x * y;
      assert((x == 0)||(z/x == y));
      return z;
    }

}
// Abstract of ERC20 Token
contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


/*  Implementation of ERC20 token standard functions */
contract StandardToken is Token {

    function transfer(address _to, uint256 _value) returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}

contract Ownable {
  address public owner;

/**
* @dev The Ownable constructor sets the original `owner` of the contract to the sender
* account.
*/
function Ownable() {
  owner = msg.sender;
}
/**
* @dev Throws if called by any account other than the owner.
*/
modifier onlyOwner() {
  require(msg.sender == owner);
_;
}
/**
* @dev Allows the current owner to transfer control of the contract to a newOwner.
* @param newOwner The address to transfer ownership to.
*/
function transferOwnership(address newOwner) onlyOwner {
  if (newOwner != address(0)) {
      owner = newOwner;
  }
}

}


contract GLXToken is StandardToken,Ownable, SafeMath {

    // crowdsale parameters
    string  public constant name = "GLX";
    string  public constant symbol = "GLXT";
    uint256 public constant decimals = 18;
    string  public version = "1.0";
    address public constant ethFundDeposit= 0xeE9b66740EcF1a3e583e61B66C5b8563882b5d12;  // Deposit address for ETH
    bool public emergencyFlag;                                      //Flag to stop the sale
    uint256 public fundingStartBlock;                              //   Starting blocknumber
    uint256 public fundingEndBlock;
    uint256 public constant minTokenPurchaseAmount= .008 ether;   //     Minimum purchase
    uint256 public constant tokenSaleCap =  50 * (10**6) * 10**decimals;            // 50 million token cap for sale
    uint256 public constant tokenCreationCap =  100 * (10**6) * 10**decimals;      //  100 million token hardcap
    uint256 public constant periodOne = 126000;
    uint256 public constant periodTwo = 210000;
    uint256 public constant periodThree = 546000;
    // All calculation are done using 1 ether fair price @$800
    uint256 public constant periodOnePrice = 1334;// 1-3 week 60 cent per token
    uint256 public constant periodTwoPrice = 1000;//4-5 week  80 cent per token
    uint256 public constant periodThreePrice = 800;//6-13 week 1 dollar per token

    mapping(address=>bool) kycRegistered;


    // events
    event CreateGLX(address indexed _to, uint256 _value);// Event address of buyer and purchase token
    event Mint(address indexed _to,uint256 _value);     //  Event give  address to which we send the mint token and token assigned.
    // Constructor
    function GLXToken(){
      emergencyFlag = false;                             // Flag is false at  initialization
      fundingStartBlock = block.number;                 //  Current deploying block number is the starting block number for ICO
      fundingEndBlock=safeAdd(fundingStartBlock,periodThree);  //   Ending time depending upon the block number
    }

    /**
    * @dev creates new  tokens
    *      It is a private function it will be called by fallback function or buyToken functions.
    */
    function createTokens() private  {
      if (!kycRegistered[msg.sender]) revert();         // Revert if not a registered member.
      if (emergencyFlag) revert();                     //  Revert when the sale is over before time and emergencyFlag is true.
      if (block.number > fundingEndBlock) revert();   //   If the blocknumber exceed the ending block it will revert
      if (msg.value<minTokenPurchaseAmount)revert(); //    If someone send 0.008 ether it will fail
      uint256 tokenExchangeRate=tokenRate();        //     It will get value depending upon block number and presale cap
      uint256 tokens = safeMult(msg.value, tokenExchangeRate);//  Calculating number of token for sender
      totalSupply = safeAdd(totalSupply, tokens);            //   Add token to total supply
      if(totalSupply>tokenSaleCap)revert();                 //    Check the total supply if it is more then hardcap it will throw
      balances[msg.sender] += tokens;                      //     Adding token to sender account
      CreateGLX(msg.sender, tokens);                      //      Logs sender address and  token creation
    }

    /**
    * @dev people can access contract and choose buyToken function to get token
    *It is used by using myetherwallet
    *It is a payable function it will be called by sender.
    */
    function buyToken() payable external{
      createTokens();   // This will call the internal createToken function to get token
    }

    /**
    * @dev      it is a private function called by create function to get the amount according to the blocknumber.
    * @return   It will return the token price at a particular time.
    */
    function tokenRate() private returns (uint256 _tokenPrice){
      // It will return different price depending upon blocknumber.
      if(block.number<safeAdd(fundingStartBlock,periodOne)){
          return periodOnePrice;
        }
      if((block.number>safeAdd(fundingStartBlock,periodOne)) && (block.number<=safeAdd(fundingStartBlock,periodTwo))){
            return periodTwoPrice;
        }
      if((block.number>safeAdd(fundingStartBlock,periodTwo))&&(block.number<=fundingEndBlock)){
              return periodThreePrice;
        }

    }

    /**
    * @dev     it will  assign token to a particular address by owner only
    * @param   _to the address whom you want to send token to
    * @param   _amount the amount you want to send
    * @return  It will return true if success.
    */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
      if (emergencyFlag) revert();
      totalSupply = safeAdd(totalSupply,_amount);// Add the minted token to total suppy
      if(totalSupply>tokenCreationCap)revert();
      balances[_to] +=_amount;                 //   Adding token to the input address
      Mint(_to, _amount);                     //    Log the mint with address and token given to particular address
      return true;
    }

    /**
    * @dev     it will change the ending date of ico and access by owner only
    * @param   _newBlock enter the future blocknumber
    * @return  It will return the blocknumber
    */
    function changeEndBlock(uint256 _newBlock) external onlyOwner returns (uint256 _endblock )
    {   // we are expecting that owner will input number greater than current block.
        require(_newBlock > fundingStartBlock);
        fundingEndBlock = _newBlock;         // New block is assigned to extend the Crowd Sale time
        return fundingEndBlock;
    }


    function changeMultipleRegistrationKycStatus(address[] targets, bool isRegistered) external onlyOwner

    {
        for (uint i = 0; i < targets.length; i++) {
            kycRegistered[targets[i]] = isRegistered;

        }
    }


    function checkKycStatus(address _add) constant  returns(bool _state){

      return kycRegistered[_add];
    }
    /**
    * @dev   it will let Owner withdrawn ether at any time during the ICO
    **/
    function drain() external onlyOwner {
        if (!ethFundDeposit.send(this.balance)) revert();// It will revert if transfer fails.
    }

    /**
    * @dev  it will let Owner Stop the crowdsale and mint function to work.
    *
    */
    function emergencyToggle() external onlyOwner returns(bool Flag){
      emergencyFlag = !emergencyFlag;
      return emergencyFlag;
    }

    // Fallback function let user send ether without calling the buy function.
    function() payable {
      createTokens();

    }


}
