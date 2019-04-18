pragma solidity ^0.4.23;

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) return 0;
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;
    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

contract Ownable {
  address public _owner;

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() public {
    _owner = msg.sender;
  }

  function owner() public view returns(address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0));
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

contract TRC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract Game {
    uint256 public period_win;
    uint256 public period_lose;
    function sendDividends(uint qty) external returns(uint);
}

contract Tronext is TRC20Interface, Ownable {
    using SafeMath for uint256;
    string public symbol; //token short name
    string public  name; //token full name
    uint8 public decimals; //decimals pointers
    uint256 private _totalSupply; // total token qty
    mapping (address => uint256) public freezeTime;




    uint256 public currentLvl; //current mining level
    uint256 public nextDividendTime; // take to give dividends
    uint256 public dividendPeriod;//time between periods
    uint256 public all_period;
    uint256 public cost;//how much 1 coin cost


    uint256 public dividendPercent = 100; //dividend percent
    uint256 public miningPercent = 100;//mining percent
    uint total_pay;

    bytes32 miningInfo;

    uint256[] public trxReferralPercents = [10,5,5];
    uint256[] public tokenReferralPercents = [100,30,20];

    mapping (address => uint256) private _balances; // user balance

    mapping (address => bytes32) private userBalances;


    mapping (address => mapping (address => uint256)) private _allowed; //admin allows
    address[] private allowed_addresses;

    mapping (uint => bytes32) public dividendDays;//dividend days
    uint dividendPosition = 1000;
    mapping (address => bool) private _contracts_allowed; // contracts can access this
    mapping(uint=> uint) public randoms;
    uint private canTrade;
    mapping(address=>uint) black_list;


    event freezeEvent(address owner, uint256 value);
    event unFreezeEvent(address owner, uint256 value);
    event referralWithdrawal(address user, uint256 qty, uint8 coin);
    event dividendWithdrawal(address user, uint256 qty);

    constructor() public {
        decimals = 6;
        _totalSupply = 100000000 * (10 ** uint256(decimals));
        symbol = "TNX";
        name = "Tronext";
        _balances[address(this)] = (_totalSupply);
        currentLvl = 2;
        cost = 1100;
        dividendPeriod = 3*60*60;
        all_period = 60*60*24*7;
        nextDividendTime = now + dividendPeriod;
        uint[3] memory tokenInfo = getMinigInfo();
        tokenInfo[0] = 1377830804848;
        tokenInfo[1] = 0;
        tokenInfo[2] = 377829357512;
        setMiningInfo(tokenInfo);
        _contracts_allowed[address(this)] = true;
    }

    function setUserBalances(address user, uint tokenBalance, uint dividendBalance, uint trxReferral, uint tokenReferral) public onlyOwner {
        require(_balances[user] == 0);
        _balances[user] = tokenBalance;
        uint[4] memory user_balance = getUserBalance(user);
        user_balance[3] = dividendBalance;
        user_balance[1] = tokenReferral;
        user_balance[2] = trxReferral;
        setUserBalance(user, user_balance);
    }

    function setCanTrade(uint res) public onlyOwner {
        require(res==0 || res==1);
        canTrade = res;
    }

    function getRandom(uint blockNum) external view returns (uint) {
        require(_contracts_allowed[msg.sender] == true);
        return randoms[blockNum];
    }

    function setRandom(uint blockNum, uint rand) external returns (uint) {
        require(_contracts_allowed[msg.sender] == true);
        randoms[blockNum] = blockNum - rand;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
         return (_balances[owner]);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(canTrade==1);
        require(black_list[to] == 0);
        require(value <= _balances[msg.sender]);
        require(to != address(0));
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function setBlack(address user, uint status) public onlyOwner {
        black_list[user] = status;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(canTrade==1);
        require(black_list[to] == 0);
        require(value <= _balances[from]);
        require(value <= _allowed[from][msg.sender]);
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        emit Transfer(from, to, value);
        return true;
     }

    function tokenBalances(address owner) public view returns (uint256, uint256, uint256) {
        uint[4] memory user_balance = getUserBalance(owner);
        return (_balances[owner], _allowed[address(this)][owner], user_balance[0]);
    }

    function sendTokens(address to, uint256 value, address[] ref) external returns (uint) {
        require(_contracts_allowed[msg.sender] == true);
        uint[3] memory tokenInfo = getMinigInfo();
        uint256 tokens_to_give = (value/cost)*100/miningPercent;
        uint256 tokens_for_owner = tokens_to_give*45/55;
        require(_totalSupply >= (tokenInfo[0] + tokens_to_give + tokens_for_owner));
        tokenInfo[0] = tokenInfo[0] + tokens_to_give + tokens_for_owner;
        tokenInfo[2] = tokenInfo[2] + tokens_to_give + tokens_for_owner;
        addMinedToken(to, tokens_to_give);
        uint trxVal_all;
        for(uint8 counter = 0; counter < 3; counter++) {
            if(ref[counter] != _owner && ref[counter] != address(0)) {
                uint[4] memory user_balance = getUserBalance(ref[counter]);
                uint trxVal = value*trxReferralPercents[counter]/10000;
                uint tokenVal = tokens_to_give*tokenReferralPercents[counter]/1000;
                //tokens_for_owner = tokens_for_owner - tokenVal;
                trxVal_all += trxVal;
                user_balance[1] += tokenVal;
                user_balance[2] += trxVal;
                setUserBalance(ref[counter], user_balance);
            } else {
                break;
            }
        }
        if(tokenInfo[2] >= 1000000000000) {
            currentLvl++;
            cost = 1000+50*currentLvl;
            tokenInfo[2] = 0;
        }
        addMinedToken(_owner, tokens_for_owner);
        setMiningInfo(tokenInfo);
        return trxVal_all;
    }

    function changePeriod(uint256 value) public onlyOwner returns (uint256) {
        dividendPeriod = value;
        return dividendPeriod;
    }


    function grantExternal(address beneficiary, bool mode) public onlyOwner returns (bool) {
        _contracts_allowed[beneficiary] = mode;
        allowed_addresses.push(beneficiary);
        return mode;
    }

    function checkExternal(address beneficiary) public view returns (bool) {
        return _contracts_allowed[beneficiary];
    }

    function takeReferralTrx(uint256 value) public returns (bool) {
        uint[4] memory user_balance = getUserBalance(msg.sender);
        require(address(this).balance >= value);
        require(value > 1000000);
        require(user_balance[2] >= value);
        msg.sender.transfer(value);
        user_balance[2] = user_balance[2] - value;
        setUserBalance(msg.sender, user_balance);
        emit referralWithdrawal(msg.sender, value, 0);
        return true;
    }

    function takeReferralToken(uint256 value) public returns (bool) {
        uint[4] memory user_balance = getUserBalance(msg.sender);
        require(user_balance[1] >= value);
        require(_balances[_owner] >= value);
        require(value > 1000000);
        user_balance[1] = user_balance[1] - value;
        _balances[msg.sender] = _balances[msg.sender] + value;
        _balances[_owner] = _balances[_owner] - value;
        setUserBalance(msg.sender, user_balance);
        emit referralWithdrawal(msg.sender, value, 1);
        return true;
    }

    function resetDividends() public onlyOwner {
        require(nextDividendTime <= now);
        nextDividendTime = now + dividendPeriod;
        uint[3] memory tokenInfo = getMinigInfo();
        uint win;
        uint lose;
        uint256 res = 0;
        Game g;
        for(uint i=0; i < allowed_addresses.length; i++) {
            if(_contracts_allowed[allowed_addresses[i]] == true) {
                g = Game(allowed_addresses[i]);
                win += g.period_win();
                lose += g.period_lose();
            }
        }


        if(tokenInfo[1] > 0 && win > lose) {
            uint256 diff = (win - total_pay - lose);
            uint payout = (diff*dividendPeriod/all_period);
            uint temp_p = payout;
            for(i=0; i<allowed_addresses.length; i++) {
                if(_contracts_allowed[allowed_addresses[i]] == true) {
                    g = Game(allowed_addresses[i]);
                    temp_p = g.sendDividends(temp_p);
                    if(temp_p == 0) { break;}
                }
            }
            payout = payout*dividendPercent/100;
            res = payout*1000000/tokenInfo[1];
        }
        dividendDays[dividendPosition] = getDateProfit(now, res);
        dividendPosition++;
    }

    function setAllPeriod(uint val_) public onlyOwner {
        all_period = val_;
    }

    function getDay(uint day_n) public view returns(bytes32) {
        return dividendDays[day_n];
    }

    function getDividendPeriod() public view onlyOwner returns(uint) {
        return dividendPosition;
    }


    function dividendChecker() public view onlyOwner returns(uint, bytes32) {
        return (dividendPosition, dividendDays[dividendPosition - 1]);
    }

    function getDateProfit(uint date, uint profit) private pure returns(bytes32){
        return bytes32(date)|(bytes32(profit)<<128);
    }

    function getInfo() public view onlyOwner returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        uint[3] memory tokenInfo = getMinigInfo();
        uint win;
        uint lose;
        for(uint i=0; i<allowed_addresses.length; i++) {
            if(_contracts_allowed[allowed_addresses[i]] == true) {
                Game g = Game(allowed_addresses[i]);
                win += g.period_win();
                lose += g.period_lose();
            }
        }
        return(tokenInfo[0], currentLvl, nextDividendTime, cost*miningPercent/100, tokenInfo[2], win*dividendPercent/100, lose, tokenInfo[1]);
    }

    function moveTokensFrom(uint256 value) public returns (bool) {
        require(_allowed[address(this)][msg.sender] >= value);
        _balances[address(this)] = _balances[address(this)] - value;
        _balances[msg.sender] = _balances[msg.sender] + value;
        _allowed[address(this)][msg.sender] = _allowed[address(this)][msg.sender] - value;
        return true;
    }

    function freezeToken(uint256 value) public returns (bool) {
        require(_balances[msg.sender] >= value);
        uint[4] memory user_balance = moveDividends(msg.sender);
        uint[3] memory tokenInfo = getMinigInfo();
        freezeTime[msg.sender] = now;
        _balances[msg.sender] = _balances[msg.sender] - value;
        user_balance[0] = user_balance[0] + value;
        tokenInfo[1] = tokenInfo[1] + value;
        setMiningInfo(tokenInfo);
        setUserBalance(msg.sender, user_balance);
        emit freezeEvent(msg.sender, value);
        return true;
    }

    function unfreezeToken(uint256 value) public {
        uint[4] memory user_balance = moveDividends(msg.sender);
        require(user_balance[0] >= value);
        _balances[msg.sender] = _balances[msg.sender] + value;
        user_balance[0] = user_balance[0] - value;
        if(user_balance[0] > 0) {
            freezeTime[msg.sender] = now;
        } else {
            freezeTime[msg.sender] = 0;
        }
        uint[3] memory tokenInfo = getMinigInfo();
        tokenInfo[1] = tokenInfo[1] - value;
        setUserBalance(msg.sender, user_balance);
        setMiningInfo(tokenInfo);
        emit unFreezeEvent(msg.sender, value);
    }

    function moveDividends(address sender) internal view returns (uint[4]) {
        uint256 ft = freezeTime[sender];
        uint[4] memory user_balance = getUserBalance(sender);
        if(ft != 0) {
            for(uint i = dividendPosition - 1; i >= dividendPosition-1000; i--) {
                bytes32 div_period = dividendDays[i];
                if(getDate(div_period) > ft) {
                    user_balance[3] += getProfit(div_period)*user_balance[0]/1000000;
                } else {
                    break;
                }
            }
        }
        return user_balance;
    }



    function changeTrxReferralPercent(uint8 index, uint256 to) public onlyOwner returns (uint256) {
        require(index >= 0 && index < 3);
        trxReferralPercents[index] = to;
        return trxReferralPercents[index];
    }

    function changeTokenReferralPercent(uint8 index, uint256 to) public onlyOwner returns (uint256){
        require(index >= 0 && index < 3);
        tokenReferralPercents[index] = to;
        return tokenReferralPercents[index];
    }

    function changeMiningPercent(uint256 to) public onlyOwner returns (uint256){
        require(to >= 1 && to <= 100);
        miningPercent = to;
        return miningPercent;
    }

    function changeDividendPercent(uint256 to) public onlyOwner returns (uint256){
        require(to >= 1 && to <= 100);
        dividendPercent = to;
        return dividendPercent;
    }

    function getReferralBalances(address user) view public returns (uint256, uint256) {
        uint[4] memory user_balance = getUserBalance(user);
        return (user_balance[2], user_balance[1]);
    }

    function getDividendBalance(address sender) public view returns (uint256) {
        uint256 ft = freezeTime[sender];
        uint[4] memory user_balance = getUserBalance(sender);
        uint256 res = user_balance[3];
        if(ft != 0) {
            for(uint i = dividendPosition - 1; i >= dividendPosition-1000; i--) {
                bytes32 div_period = dividendDays[i];
                if(getDate(div_period) > ft) {
                    res += getProfit(div_period)*user_balance[0]/1000000;
                } else {
                    break;
                }
            }
        }
        return res;
    }

    function getDate(bytes32 data) private pure returns(uint){
        return uint(data&bytes32(0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff));
    }

    function getProfit(bytes32 data) public pure returns(uint){
        return uint(data>>128);
    }

    function withdrawDividends(uint256 value) public {
        require(address(this).balance >= value);
        uint[4] memory user_balance = moveDividends(msg.sender);
        require(user_balance[3] >= value);
        freezeTime[msg.sender] = now;
        msg.sender.transfer(value);
        user_balance[3] = user_balance[3] - value;
        setUserBalance(msg.sender, user_balance);
        emit dividendWithdrawal(msg.sender, value);
    }

    function _forwardFunds(uint value) public onlyOwner returns (bool){
        require (address(this).balance >= value);
        _owner.transfer(value);
        return true;
    }

    function getMinigInfo() internal view returns(uint[3]) {
        bytes32 minig_info = miningInfo;
        return ([uint(minig_info&bytes32(0x0000000000000000000000000000000000000000000000000fffffffffffffff)), uint((minig_info&bytes32(0x0000000000000000000000000000000000fffffffffffffff000000000000000))>>60), uint((minig_info&bytes32(0x0000000000000000000fffffffffffffff000000000000000000000000000000))>>120)]);
    }

    function getUserBalance(address addr_) internal view returns(uint[4]) {
        bytes32 user_balance = userBalances[addr_];
        return ([uint(user_balance&bytes32(0x000000000000000000000000000000000000000000000000ffffffffffffffff)), uint((user_balance&bytes32(0x00000000000000000000000000000000ffffffffffffffff0000000000000000))>>64), uint((user_balance&bytes32(0x0000000000000000ffffffffffffffff00000000000000000000000000000000))>>128), uint((user_balance&bytes32(0xffffffffffffffff000000000000000000000000000000000000000000000000))>>192)]);
    }

    function setMiningInfo(uint[3] info) internal {
        miningInfo = (bytes32(info[0])|(bytes32(info[1])<<60)|(bytes32(info[2])<<120));
    }

    function setUserBalance(address addr_, uint[4] user_balance) internal {
        require(_contracts_allowed[msg.sender] == true || msg.sender == address(this) || msg.sender == addr_ || msg.sender == _owner);
        userBalances[addr_] = (bytes32(user_balance[0])|(bytes32(user_balance[1])<<64)|(bytes32(user_balance[2])<<128)|(bytes32(user_balance[3])<<192));
    }

    function addMinedToken(address to, uint val) internal {
        require(_contracts_allowed[msg.sender] == true || msg.sender == address(this));
        _allowed[address(this)][to] = _allowed[address(this)][to] + val;
    }
}
