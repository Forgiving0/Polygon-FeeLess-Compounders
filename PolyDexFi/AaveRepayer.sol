// SPDX-License-Identifier: MIT-0
pragma solidity = 0.8.0;
pragma experimental ABIEncoderV2;

// Claim WMATIC from AAVE -> Harvest PLX Rewards -> Harvest Swap Rewards -> Swap PLX for WMATIC -> half wmatic swap for usdc, and usdt -> repay on aave

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IAaveIncentivesController {
    function claimRewards(address[] calldata assets, uint256 amount, address to) external;
}

interface IPolyDexRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(address tokenIn, address tokenOut, uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

interface IQuickswapRouter {
    
}

interface IPolyChefV2 {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IPolyRewardMining {
    function withdraw() external returns (bool _status);
}







contract PolyDexAaveRepayer {
    address public owner;
    IERC20 public USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 public WMATIC = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 public PLP = IERC20(0xb78906c8a461d6a39A57285C129843E1937c3278);
    IERC20 public PLX = IERC20(0x4B1df511d59F5c73a420217cE58a77b462151c9E);

    IAaveIncentivesController public AaveClaim = IAaveIncentivesController(0x357D51124f59836DeD84c8a1730D72B749d8BC23);
    IPolyRewardMining public PolyFee = IPolyRewardMining(0x356209692C2430e5dFc78567a8B4eA2351063550);
    IPolyDexRouter public PolyRouter = IPolyDexRouter(0xC60aE14F2568b102F8Ca6266e8799112846DD088);
    IPolyChefV2 public PolyChef = IPolyChefV2(0xf61fdc0F479305a0E7566bBeAB46196bc0aFd997);

    address constant public admin = YOUR_ADMIN_WALLET;

    constructor() {
        owner = msg.sender;
        PLP.approve(address(PolyChef), 2**256 - 1);
    }

    modifier onlyOwner {
        require(owner == msg.sender, "GFICompounder: caller is not the owner");
        _;
    }

    modifier onlyAdmin {
        require(owner == msg.sender || admin == msg.sender, "GFICompounder: caller is not the owner nor an admin address");
        _;
    }

    function depositPLP() public onlyOwner {
        require(PLP.balanceOf(address(this)) != 0, "PolyDexAaveRepayer: No PLP tokens to stake");
        PolyChef.deposit(PLP.balanceOf(address(this)));
    }

    function harvestFromMasterChef() public {
        PolyChef.deposit(8, 0);
    }

    function harvestDirectFromMasterChef() public onlyOwner {
        PolyChef.deposit(8, 0);
        PLX.transfer(owner, PLX.balanceOf(address(this)));
    }

    function withdrawTokensFromContract(address _tokenContract) external onlyOwner {
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.transfer(owner, tokenContract.balanceOf(address(this)));
    }

    function call(address payable _to, uint256 _value, bytes calldata _data) external payable onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = _to.call{value: _value}(_data);
        require(success, "GFICompounder: external call failed");
        return result;
    }
}
