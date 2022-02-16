pragma solidity >=0.4.24;
contract LUKTokenStore {
    /** 精度，推荐是 8 */
    uint8 public decimals = 8;
    /** 代币总量 */
    uint256 public totalSupply;
    /** 查看某一地址代币余额 */
    mapping (address => uint256) private tokenAmount;
    /** 代币交易代理人授权列表 */
    mapping (address => mapping (address => uint256)) private allowanceMapping;
    //合约所有者
    address private owner;
    //写授权
    mapping (address => bool) private authorization;
    
    /**
     * Constructor function
     * 
     * 初始合约
     * @param initialSupply 代币总量
     */
    constructor (uint256 initialSupply) public {
        //** 是幂运算
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        tokenAmount[msg.sender] = totalSupply;                // Give the creator all initial tokens
        owner = msg.sender;
    }
    
    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    modifier checkWrite() {
        require(authorization[msg.sender] == true,"Illegal operation.");
        _;
    }
    
    //写授权，合约调用合约时调用者为父合约地址
    function writeGrant(address _address) public onlyOwner {
        authorization[_address] = true;
    }
    function writeRevoke(address _address) public onlyOwner {
        authorization[_address] = false;
    }
    
    /**
     * 设置代币消费代理人，代理人可以在最大可使用金额内消费代币
     *
     * @param _from 资金所有者地址
     * @param _spender 代理人地址
     * @param _value 最大可使用金额
     */
    function approve(address _from,address _spender, uint256 _value) public checkWrite returns (bool) {
        allowanceMapping[_from][_spender] = _value;
        return true;
    }
    
    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowanceMapping[_from][_spender];
    }
    
    /**
     * Internal transfer, only can be called by this contract
     */
    function transfer(address _from, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");

        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;

        return true;
    }
    
    function transferFrom(address _from,address _spender, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_from != address(0x0),"Invalid address");
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        
        // Check if the sender has enough
        require(allowanceMapping[_from][_spender] >= _value,"Insufficient credit limit.");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");
        
        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;
        
        allowanceMapping[_from][_spender] -= _value; 
    }
    
    function balanceOf(address _owner) public view returns (uint256){
        require(_owner != address(0x0),"Address can't is zero.");
        return tokenAmount[_owner] ;
    }
}
pragma solidity >=0.4.24;
//ERC20 标准代币 https://eips.ethereum.org/EIPS/eip-20
import "./store.sol";

contract LUKToken {
    /** ERC20 代币名字 */
    string public name = "Lucky Coin";
    /** ERC20 代币符号 */
    string public symbol = "LUK";
    
    //MUST trigger when tokens are transferred, including zero value transfers.
    event Transfer(address indexed from, address indexed to, uint256 value);
    //MUST trigger on any successful call to approve(address _spender, uint256 _value).
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    //合约所有者
    address private owner;
    //代币仓库
    LUKTokenStore private tokenStore;
    /** 黑名单列表 */
    mapping (address => bool) private blackList;

    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    /**
     * Constructor function
     * @param storeAddr HITokenStore 布署地址
     */
    constructor (address storeAddr) public {
        owner = msg.sender;
        tokenStore = LUKTokenStore(storeAddr);
    }

    /**合约默认回退函数，当没配配的函数时会调用此函数，当发送没有附加数据的以太时会调用此函数 */
    function () external payable{
    }
    
    /** ERC20 精度，推荐是 8 */
    function decimals() public view returns (uint8){
        return tokenStore.decimals();
    }
    /** ERC20 代币总量 */
    function totalSupply() public view returns (uint256){
        return tokenStore.totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        balance = tokenStore.balanceOf(_owner);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transfer(msg.sender,_to,_value);
        emit Transfer(msg.sender, _to, _value);
        
        success = true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom (address _from, address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[_from],"Prohibit trading.");
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transferFrom(_from,msg.sender,_to,_value);
        emit Transfer(_from, _to, _value);

        success = true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (tokenStore.approve(msg.sender,_spender,_value)){
            emit Approval(msg.sender,_spender,_value); 
            success = true;
        } else {
            success = false;
        }
    }

    function allowance(address _from, address _spender) public view returns (uint256 remaining) {
        remaining = tokenStore.allowance(_from,_spender);
    }
    
    /**
      * 将一个地址添加到黑名单，被添加到黑名单的地址将不能够转出
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function addToBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = true;
        success = true;
    }

    /**
      * 从黑名单中移出一个地址
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function removeFromBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = false;
        success = true;
    }
}
pragma solidity >=0.4.24;
contract LUKTokenStore {
    /** 精度，推荐是 8 */
    uint8 public decimals = 8;
    /** 代币总量 */
    uint256 public totalSupply;
    /** 查看某一地址代币余额 */
    mapping (address => uint256) private tokenAmount;
    /** 代币交易代理人授权列表 */
    mapping (address => mapping (address => uint256)) private allowanceMapping;
    //合约所有者
    address private owner;
    //写授权
    mapping (address => bool) private authorization;
    
    /**
     * Constructor function
     * 
     * 初始合约
     * @param initialSupply 代币总量
     */
    constructor (uint256 initialSupply) public {
        //** 是幂运算
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        tokenAmount[msg.sender] = totalSupply;                // Give the creator all initial tokens
        owner = msg.sender;
    }
    
    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    modifier checkWrite() {
        require(authorization[msg.sender] == true,"Illegal operation.");
        _;
    }
    
    //写授权，合约调用合约时调用者为父合约地址
    function writeGrant(address _address) public onlyOwner {
        authorization[_address] = true;
    }
    function writeRevoke(address _address) public onlyOwner {
        authorization[_address] = false;
    }
    
    /**
     * 设置代币消费代理人，代理人可以在最大可使用金额内消费代币
     *
     * @param _from 资金所有者地址
     * @param _spender 代理人地址
     * @param _value 最大可使用金额
     */
    function approve(address _from,address _spender, uint256 _value) public checkWrite returns (bool) {
        allowanceMapping[_from][_spender] = _value;
        return true;
    }
    
    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowanceMapping[_from][_spender];
    }
    
    /**
     * Internal transfer, only can be called by this contract
     */
    function transfer(address _from, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");

        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;

        return true;
    }
    
    function transferFrom(address _from,address _spender, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_from != address(0x0),"Invalid address");
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        
        // Check if the sender has enough
        require(allowanceMapping[_from][_spender] >= _value,"Insufficient credit limit.");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");
        
        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;
        
        allowanceMapping[_from][_spender] -= _value; 
    }
    
    function balanceOf(address _owner) public view returns (uint256){
        require(_owner != address(0x0),"Address can't is zero.");
        return tokenAmount[_owner] ;
    }
}
pragma solidity >=0.4.24;
//ERC20 标准代币 https://eips.ethereum.org/EIPS/eip-20
import "./store.sol";

contract LUKToken {
    /** ERC20 代币名字 */
    string public name = "Lucky Coin";
    /** ERC20 代币符号 */
    string public symbol = "LUK";
    
    //MUST trigger when tokens are transferred, including zero value transfers.
    event Transfer(address indexed from, address indexed to, uint256 value);
    //MUST trigger on any successful call to approve(address _spender, uint256 _value).
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    //合约所有者
    address private owner;
    //代币仓库
    LUKTokenStore private tokenStore;
    /** 黑名单列表 */
    mapping (address => bool) private blackList;

    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    /**
     * Constructor function
     * @param storeAddr HITokenStore 布署地址
     */
    constructor (address storeAddr) public {
        owner = msg.sender;
        tokenStore = LUKTokenStore(storeAddr);
    }

    /**合约默认回退函数，当没配配的函数时会调用此函数，当发送没有附加数据的以太时会调用此函数 */
    function () external payable{
    }
    
    /** ERC20 精度，推荐是 8 */
    function decimals() public view returns (uint8){
        return tokenStore.decimals();
    }
    /** ERC20 代币总量 */
    function totalSupply() public view returns (uint256){
        return tokenStore.totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        balance = tokenStore.balanceOf(_owner);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transfer(msg.sender,_to,_value);
        emit Transfer(msg.sender, _to, _value);
        
        success = true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom (address _from, address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[_from],"Prohibit trading.");
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transferFrom(_from,msg.sender,_to,_value);
        emit Transfer(_from, _to, _value);

        success = true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (tokenStore.approve(msg.sender,_spender,_value)){
            emit Approval(msg.sender,_spender,_value); 
            success = true;
        } else {
            success = false;
        }
    }

    function allowance(address _from, address _spender) public view returns (uint256 remaining) {
        remaining = tokenStore.allowance(_from,_spender);
    }
    
    /**
      * 将一个地址添加到黑名单，被添加到黑名单的地址将不能够转出
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function addToBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = true;
        success = true;
    }

    /**
      * 从黑名单中移出一个地址
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function removeFromBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = false;
        success = true;
    }
}
pragma solidity >=0.4.24;
contract LUKTokenStore {
    /** 精度，推荐是 8 */
    uint8 public decimals = 8;
    /** 代币总量 */
    uint256 public totalSupply;
    /** 查看某一地址代币余额 */
    mapping (address => uint256) private tokenAmount;
    /** 代币交易代理人授权列表 */
    mapping (address => mapping (address => uint256)) private allowanceMapping;
    //合约所有者
    address private owner;
    //写授权
    mapping (address => bool) private authorization;
    
    /**
     * Constructor function
     * 
     * 初始合约
     * @param initialSupply 代币总量
     */
    constructor (uint256 initialSupply) public {
        //** 是幂运算
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        tokenAmount[msg.sender] = totalSupply;                // Give the creator all initial tokens
        owner = msg.sender;
    }
    
    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    modifier checkWrite() {
        require(authorization[msg.sender] == true,"Illegal operation.");
        _;
    }
    
    //写授权，合约调用合约时调用者为父合约地址
    function writeGrant(address _address) public onlyOwner {
        authorization[_address] = true;
    }
    function writeRevoke(address _address) public onlyOwner {
        authorization[_address] = false;
    }
    
    /**
     * 设置代币消费代理人，代理人可以在最大可使用金额内消费代币
     *
     * @param _from 资金所有者地址
     * @param _spender 代理人地址
     * @param _value 最大可使用金额
     */
    function approve(address _from,address _spender, uint256 _value) public checkWrite returns (bool) {
        allowanceMapping[_from][_spender] = _value;
        return true;
    }
    
    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowanceMapping[_from][_spender];
    }
    
    /**
     * Internal transfer, only can be called by this contract
     */
    function transfer(address _from, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");

        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;

        return true;
    }
    
    function transferFrom(address _from,address _spender, address _to, uint256 _value) public checkWrite returns (bool) {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_from != address(0x0),"Invalid address");
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0),"Invalid address");
        
        // Check if the sender has enough
        require(allowanceMapping[_from][_spender] >= _value,"Insufficient credit limit.");
        // Check if the sender has enough
        require(tokenAmount[_from] >= _value,"Not enough balance.");
        // Check for overflows
        require(tokenAmount[_to] + _value > tokenAmount[_to],"Target account cannot be received.");
        
        // 转账
        // Subtract from the sender
        tokenAmount[_from] -= _value;
        // Add the same to the recipient
        tokenAmount[_to] += _value;
        
        allowanceMapping[_from][_spender] -= _value; 
    }
    
    function balanceOf(address _owner) public view returns (uint256){
        require(_owner != address(0x0),"Address can't is zero.");
        return tokenAmount[_owner] ;
    }
}
pragma solidity >=0.4.24;
//ERC20 标准代币 https://eips.ethereum.org/EIPS/eip-20
import "./store.sol";

contract LUKToken {
    /** ERC20 代币名字 */
    string public name = "Lucky Coin";
    /** ERC20 代币符号 */
    string public symbol = "LUK";
    
    //MUST trigger when tokens are transferred, including zero value transfers.
    event Transfer(address indexed from, address indexed to, uint256 value);
    //MUST trigger on any successful call to approve(address _spender, uint256 _value).
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    //合约所有者
    address private owner;
    //代币仓库
    LUKTokenStore private tokenStore;
    /** 黑名单列表 */
    mapping (address => bool) private blackList;

    //定义函数修饰符，判断消息发送者是否是合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner,"Illegal operation.");
        _;
    }
    
    /**
     * Constructor function
     * @param storeAddr HITokenStore 布署地址
     */
    constructor (address storeAddr) public {
        owner = msg.sender;
        tokenStore = LUKTokenStore(storeAddr);
    }

    /**合约默认回退函数，当没配配的函数时会调用此函数，当发送没有附加数据的以太时会调用此函数 */
    function () external payable{
    }
    
    /** ERC20 精度，推荐是 8 */
    function decimals() public view returns (uint8){
        return tokenStore.decimals();
    }
    /** ERC20 代币总量 */
    function totalSupply() public view returns (uint256){
        return tokenStore.totalSupply();
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        balance = tokenStore.balanceOf(_owner);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transfer(msg.sender,_to,_value);
        emit Transfer(msg.sender, _to, _value);
        
        success = true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom (address _from, address _to, uint256 _value) public returns (bool success) {
        //被列入黑名单的不能交易
        require(!blackList[_from],"Prohibit trading.");
        require(!blackList[msg.sender],"Prohibit trading.");
        require(!blackList[_to],"Prohibit trading.");

        tokenStore.transferFrom(_from,msg.sender,_to,_value);
        emit Transfer(_from, _to, _value);

        success = true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (tokenStore.approve(msg.sender,_spender,_value)){
            emit Approval(msg.sender,_spender,_value); 
            success = true;
        } else {
            success = false;
        }
    }

    function allowance(address _from, address _spender) public view returns (uint256 remaining) {
        remaining = tokenStore.allowance(_from,_spender);
    }
    
    /**
      * 将一个地址添加到黑名单，被添加到黑名单的地址将不能够转出
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function addToBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = true;
        success = true;
    }

    /**
      * 从黑名单中移出一个地址
      * @param _addr 代币接收者.
      * @return success 是否交易成功
      */
    function removeFromBlackList(address _addr) public onlyOwner returns (bool success) {
        require(_addr != address(0x0),"Invalid address");

        blackList[_addr] = false;
        success = true;
    }
}
