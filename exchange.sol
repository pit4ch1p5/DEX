// =================== CS251 DEX Project =================== // 
//        @authors: Simon Tao '22, Mathew Hogan '22          //
// ========================================================= //    
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../interfaces/erc20_interface.sol';
import '../libraries/safe_math.sol';
import './token.sol';


contract TokenExchange {
    using SafeMath for uint;
    address public admin;

    address tokenAddr = 0xd9145CCE52D386f254917e481eB44e9943F39138;           // TODO: Paste token contract address here.
    HankCoin private token = HankCoin(tokenAddr);                                 // TODO: Replace "Token" with your token class.             

    // Liquidity pool for the exchange
    uint public totalLiquidity;
    mapping (address => uint) public liquidityTokens;

    uint public token_reserves = 0;
    uint public eth_reserves = 0;

    // Constant: x * y = k
    uint public k;
    
    // liquidity rewards
    uint private swap_fee_numerator = 0;       // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 100;
    
    event AddLiquidity(address from, uint amount);
    event RemoveLiquidity(address to, uint amount);

    constructor() 
    {
        admin = msg.sender;
    }
    
    modifier AdminOnly {
        require(msg.sender == admin, "Only admin can use this function!");
        _;
    }

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        AdminOnly
    {
        // require pool does not yet exist
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need ETH to create pool.");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        eth_reserves = msg.value;
        token_reserves = amountTokens;
        k = eth_reserves.mul(token_reserves);
        
        totalLiquidity = msg.value;
        liquidityTokens[msg.sender] = msg.value;
       
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    /* Be sure to use the SafeMath library for all operations! */
    
    // Function priceToken: Calculate the price of your token in ETH.
    // You can change the inputs, or the scope of your function, as needed.
    function priceToken() 
        public 
        view
        returns (uint)
    {
        
         /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate how much ETH is of equivalent worth based on the current exchange rate.
        */
        
        uint tokenPrice;
        tokenPrice = eth_reserves.div(token_reserves);
        return (tokenPrice);
   
    }

    // Function priceETH: Calculate the price of ETH for your token.
    // You can change the inputs, or the scope of your function, as needed.
    function priceETH()
        public
        view
        returns (uint)
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate how much of your token is of equivalent worth based on the current exchange rate.
        */
        
        uint ethPrice;
        ethPrice = token_reserves.div(eth_reserves);
        return (ethPrice);
        
    }


    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value)
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint amountTokens) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the liquidity to be added based on what was sent in and the prices.
            If the caller possesses insufficient tokens to equal the ETH sent, then transaction must fail.
            Update token_reserves, eth_reserves, and k.
            Emit AddLiquidity event.
        */
        
        // require pool exists
        require (token_reserves > 0, "Pool does not yet exist");
        require (eth_reserves > 0, "Pool does not yet exist.");

        // require nonzero values were sent and the right ratio
        require (msg.value > 0, "Need ETH to create pool.");
        require (amountTokens > 0, "Need tokens to create pool.");
        require (msg.value.div(amountTokens) == priceToken(), "Please deposit the correct ratio.");
        
        // accept the tokens
        token.transferFrom(msg.sender, address(this), amountTokens);
        
        // give sender a share of the liquidity pool
        liquidityTokens[msg.sender].add(msg.value.div(eth_reserves).mul(totalLiquidity));
        totalLiquidity.add(liquidityTokens[msg.sender]);
        
        // revise the reserves
        eth_reserves.add(msg.value);
        token_reserves.add(amountTokens);
        k = eth_reserves.mul(token_reserves);
        
        // emit AddLiquidity(msg.sender, )
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate the amount of your tokens that should be also removed.
            Transfer the ETH and Token to the provider.
            Update token_reserves, eth_reserves, and k.
            Emit RemoveLiquidity event.
        */
        
        uint ownershipPCT = liquidityTokens[msg.sender].div(totalLiquidity); // % of the pool owned by msg.sender
        uint withdrawPCT = amountETH.div(eth_reserves); // % of the pool msg.sender wants to withdraw
        
        uint ownedETH = ownershipPCT.mul(eth_reserves); // eff ETH ownership
        uint ownedTokens = ownershipPCT.mul(token_reserves); // eff token ownership
        
        // require pool exists
        require (token_reserves > 0, "Pool does not yet exist");
        require (eth_reserves > 0, "Pool does not yet exist.");

        // require nonzero values were sent and sender owns the amount requested 
        require (amountETH > 0, "Withdrawal amt must be > 0"); 
        require (amountETH <= ownedETH, "Withdrawal amount too high");
        
        // reduce the sender's share of the liquidity pool
        liquidityTokens[msg.sender].sub(withdrawPCT.mul(totalLiquidity));
        totalLiquidity.sub(withdrawPCT.mul(totalLiquidity));
        
        // send the tokens and ETH
        token.transferFrom(address(this), msg.sender, withdrawPCT.mul(token_reserves));
        payable(msg.sender).transfer(amountETH); 

        // revise the reserves
        eth_reserves.sub(amountETH);
        token_reserves.sub(amountETH.div(eth_reserves).mul(totalLiquidity));
        k = eth_reserves.mul(token_reserves);
        
        // emit RemoveLiquidity(msg.sender, )
        
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity()
        external
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Decide on the maximum allowable ETH that msg.sender can remove.
            Call removeLiquidity().
        */
        
        removeLiquidity(liquidityTokens[msg.sender].div(totalLiquidity).mul(eth_reserves));
    }

    /***  Define helper functions for liquidity management here as needed: ***/



    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens)
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate amount of ETH should be swapped based on exchange rate.
            Transfer the ETH to the provider.
            If the caller possesses insufficient tokens, transaction must fail.
            If performing the swap would exhaust total ETH supply, transaction must fail.
            Update token_reserves and eth_reserves.

            Part 4: 
                Expand the function to take in addition parameters as needed.
                If current exchange_rate > slippage limit, abort the swap.
            
            Part 5:
                Only exchange amountTokens * (1 - liquidity_percent), 
                    where % is sent to liquidity providers.
                Keep track of the liquidity fees to be added.
        */

        // require pool exists
        require (token_reserves > 0, "Pool does not yet exist");
        require (eth_reserves > 0, "Pool does not yet exist.");
        
        uint fees;
        uint ethWithdrawn = eth_reserves.mul(fees).mul(amountTokens).div(token_reserves.add(fees.mul(amountTokens))) ;
        
        // require enough ETH and sender owns the amount requested 
        require (token.transferFrom(msg.sender, address(this), amountTokens), "You do not own enough tokens");
        require (eth_reserves > ethWithdrawn, "Insufficient ETH in pool");
       
        // send the tokens and ETH
        payable(msg.sender).transfer(ethWithdrawn);
        
        // reset reserves 
        eth_reserves.sub(ethWithdrawn);
        token_reserves.sub(amountTokens);
        k = eth_reserves.mul(token_reserves);
        
        /***************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }



    // Function swapETHForTokens: Swaps ETH for your tokens.
    // ETH is sent to contract as msg.value.
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens()
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        /* HINTS:
            Calculate amount of your tokens should be swapped based on exchange rate.
            Transfer the amount of your tokens to the provider.
            If performing the swap would exhaus total token supply, transaction must fail.
            Update token_reserves and eth_reserves.

            Part 4: 
                Expand the function to take in addition parameters as needed.
                If current exchange_rate > slippage limit, abort the swap. 
            
            Part 5: 
                Only exchange amountTokens * (1 - %liquidity), 
                    where % is sent to liquidity providers.
                Keep track of the liquidity fees to be added.
        */


        /**************************/
        // DO NOT MODIFY BELOW THIS LINE
        /* Check for x * y == k, assuming x and y are rounded to the nearest integer. */
        // Check for Math.abs(token_reserves * eth_reserves - k) < (token_reserves + eth_reserves + 1));
        //   to account for the small decimal errors during uint division rounding.
        uint check = token_reserves.mul(eth_reserves);
        if (check >= k) {
            check = check.sub(k);
        }
        else {
            check = k.sub(check);
        }
        assert(check < (token_reserves.add(eth_reserves).add(1)));
    }

    /***  Define helper functions for swaps here as needed: ***/

}
