pragma solidity >=0.4.22 <0.6.0;

contract SupplyChain {
    enum CompanyType { manufacturer, financialInstitution }

    struct Company {    //生产企业或者金融机构，金融机构包括银行可以认证交易
        string name;
        string location;
        bool isValid;
        CompanyType companyType;
    }

    enum ReceiptStatus { unconfirmed, confirmed, paid }

    uint receiptId;

    struct Receipt {    //应收账款
        address from;
        address to;
        string goods;
        uint amount;
        uint id;
        ReceiptStatus receiptStatus;
    }

    address public issuer;  //货币发行者，特殊的银行，也可以认证交易

    address public kernelCompany;   //核心企业，在实例中就是车企

    mapping(address => uint) public balances;   //银行账户余额

    mapping(address => Company) public companies;   //参与供应链的公司

    Receipt[] public receipts; //所有的交易

    constructor(address _kernelCompany, string memory _name, string memory _location) public {
        kernelCompany = _kernelCompany;
        addCompany(_kernelCompany, _name, _location, CompanyType.manufacturer);
        issuer = msg.sender; //合约由货币发行者部署
        receiptId = 1;
    }

    function findReceiptIndexWithReceiptId(uint _receiptId) public returns (int id) {
            for(uint i = 0; i < receipts.length; ++i) {
                if(receipts[i].id == _receiptId) 
                    return int(i);
            }
            return -1;
    }

    function issue(address receiver, uint amount) public {
        require(
            msg.sender == issuer,
            "Only issuer can issue."
        );
        balances[receiver] += amount;
    }

    function addCompany(address _company, string memory _name, string memory _location, CompanyType _ct) public {
        require(
            !companies[_company].isValid,
            "The company already exists."
        );
        companies[_company].name = _name;
        companies[_company].location = _location;
        companies[_company].isValid = true;
        companies[_company].companyType = _ct;
    }

    //1. 商品采购
    function createReceipt(address _to, string memory _goods, uint _amount) public returns (uint receiptid) {
        address _from = msg.sender;
        require(
            _from == kernelCompany,
            "Only kernel company can create receipt"
        );
        require(
            _to != _from,
            "To and From can not be the same."
        );
        receipts.push(Receipt({
            from: _from,
            to: _to,
            goods: _goods,
            amount: _amount,
            id: receiptId,
            receiptStatus: ReceiptStatus.unconfirmed
        }));
        receiptId += 1;
        return receiptId-1;
    }

    //2. 应收账款转让
    function divideReceipt(address _to, string memory _goods, uint _amount) public returns (uint receiptid) {
        address _from = msg.sender;
        require(
            (_from != kernelCompany && companies[_from].companyType == CompanyType.manufacturer),
            "Only manufacturer (except kernel company) can divide receipt."
        );
        require(
            _to != _from,
            "To and From can not be the same."
        );
        for(uint i = 0; i < receipts.length; i++) {
            if(receipts[i].to == _from) {
                require(
                    receipts[i].amount >= _amount,
                    "The amount is too large."
                );
                receipts[i].amount -= _amount;
                if(receipts[i].amount == 0) {
                    receipts[i].to = _to;
                    return receipts[i].id;
                }
                else {
                    receipts.push(Receipt({
                        from: receipts[i].from,
                        to: _to,
                        goods: _goods,
                        amount: _amount,
                        id: receiptId,
                        receiptStatus: receipts[i].receiptStatus
                    }));
                    receiptId += 1;
                    return receiptId-1;
                }
            }
        }
        return 0;
    }

    //3. 利用应收账款向金融机构融资
    function financing(address _from, uint _amount) public returns (uint receiptid) {
        address _to = msg.sender;
        require(
            companies[_to].companyType == CompanyType.financialInstitution || _to == issuer,
            "Company can only financing from financial institution or central bank."
        );
        require(
            _to != _from,
            "To and From can not be the same."
        );
        for(uint i = 0; i < receipts.length; i++) {
            if(receipts[i].to == _from) {
                require(
                    receipts[i].amount >= _amount,
                    "The amount is too large."
                );
                receipts[i].amount -= _amount;
                if(receipts[i].amount == 0) {
                    receipts[i].amount = _amount;
                    receipts[i].to = _to;
                    balances[_from] += _amount;
                    return receipts[i].id;
                }
                else {
                    receipts.push(Receipt({
                        from: receipts[i].from,
                        to: _to,
                        goods: "",
                        amount: _amount,
                        id: receiptId,
                        receiptStatus: receipts[i].receiptStatus
                    }));
                    receiptId += 1;
                    balances[_from] += _amount;
                    return receiptId-1;
                }
            }
        }
        return 0;
    }

    //4. 应收账款结算
    function settleAccounts() public returns (bool success) {
        address cur = msg.sender;
        require(
            cur == kernelCompany,
            "Only kernel company can settle accounts."
        );
        for(uint i = 0; i < receipts.length; i++) {
            require(
                    receipts[i].from == kernelCompany,
                    "From of the receipt is not kernel company."
            );
            balances[kernelCompany] -= receipts[i].amount;
            balances[receipts[i].to] += receipts[i].amount;
            receipts[i].receiptStatus = ReceiptStatus.paid;
        }
        return true;
    }

    //金融机构认证交易
    function confirmReceipt(address _from, uint _id) public returns (bool success) {
        address authenticator = msg.sender;
        require(
            (authenticator == issuer || companies[authenticator].companyType == CompanyType.financialInstitution),
            "Only issuer or finalcial institution can confirm receipts."
        );
        for(uint i = 0; i < receipts.length; i++) {
            if(receipts[i].from == _from && receipts[i].id == _id) {
                receipts[i].receiptStatus = ReceiptStatus.confirmed;
                return true;
            }
        }
        return false;
    }
}