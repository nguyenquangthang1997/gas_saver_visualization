/* Copyright (C) 2020 NexusMutual.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */

pragma solidity 0.5.7;
import "./SafeMath.sol";


contract Aggregator {
    function currentAnswer() public view returns (int); 
}


contract NXMDSValue {

    using SafeMath for uint;

    /// @dev Get ETH-USD feed from Chainlink and convert it to bytes32.
    /// @return Returns ETH-USD rate in wei. 
    function read() public view returns (bytes32)
    {
        
        // Instance to get USD feed from chainlink.
        Aggregator aggregator = Aggregator(0x79fEbF6B9F76853EDBcBc913e6aAE8232cFB9De9);
        int rate = aggregator.currentAnswer();

        // Chainlink returns value of type int256, 
        // Check is to ensure that value should always be positive integer. 
        require(rate > 0, "Rate should be positive integer only"); 
        
        // Chainlink feed return value is (rate * 10^8).
        // Multiplying by 10^10 because DSValue requires the value to be in format (rate * 10^18).
        // Chainlink feed returns int256. Converting to bytes32 to follow the DSValue format.
        return bytes32(uint(rate).mul(10**10));
    }
}

pragma solidity 0.5.7;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/* Copyright (C) 2020 NexusMutual.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */

pragma solidity 0.5.7;
import "./SafeMath.sol";


contract Aggregator {
    function currentAnswer() public view returns (int); 
}


contract NXMDSValue {

    using SafeMath for uint;

    /// @dev Get ETH-USD feed from Chainlink and convert it to bytes32.
    /// @return Returns ETH-USD rate in wei. 
    function read() public view returns (bytes32)
    {
        
        // Instance to get USD feed from chainlink.
        Aggregator aggregator = Aggregator(0x79fEbF6B9F76853EDBcBc913e6aAE8232cFB9De9);
        int rate = aggregator.currentAnswer();

        // Chainlink returns value of type int256, 
        // Check is to ensure that value should always be positive integer. 
        require(rate > 0, "Rate should be positive integer only"); 
        
        // Chainlink feed return value is (rate * 10^8).
        // Multiplying by 10^10 because DSValue requires the value to be in format (rate * 10^18).
        // Chainlink feed returns int256. Converting to bytes32 to follow the DSValue format.
        return bytes32(uint(rate).mul(10**10));
    }
}

pragma solidity 0.5.7;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/* Copyright (C) 2020 NexusMutual.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */

pragma solidity 0.5.7;
import "./SafeMath.sol";


contract Aggregator {
    function currentAnswer() public view returns (int); 
}


contract NXMDSValue {

    using SafeMath for uint;

    /// @dev Get ETH-USD feed from Chainlink and convert it to bytes32.
    /// @return Returns ETH-USD rate in wei. 
    function read() public view returns (bytes32)
    {
        
        // Instance to get USD feed from chainlink.
        Aggregator aggregator = Aggregator(0x79fEbF6B9F76853EDBcBc913e6aAE8232cFB9De9);
        int rate = aggregator.currentAnswer();

        // Chainlink returns value of type int256, 
        // Check is to ensure that value should always be positive integer. 
        require(rate > 0, "Rate should be positive integer only"); 
        
        // Chainlink feed return value is (rate * 10^8).
        // Multiplying by 10^10 because DSValue requires the value to be in format (rate * 10^18).
        // Chainlink feed returns int256. Converting to bytes32 to follow the DSValue format.
        return bytes32(uint(rate).mul(10**10));
    }
}

pragma solidity 0.5.7;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

