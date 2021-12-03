//SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWagmiRouter {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint[] memory amounts);
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint amountA, uint amountB, uint liquidity);
}

interface IWagmiMasterchef {
    function deposit(uint256 _pid, uint256 _amount, bool _withdrawRewards) external;
    function claim(uint256 _pid) external;
    function emergencyWithdraw(uint256 _pid) external;
}

contract FAMBUSD_Compounder {
    address public owner;
    address public admin;
    IERC20 public BUSD = IERC20(0xacc6cbB7611eF52D287183ad1050eD1949fDEcaf);
    IERC20 public WLP = IERC20(0xA3B82D4C50868CE45968Cf1B4FFd10D7cb63c28c);
    IERC20 public FAM = IERC20(0x53cBA17b4159461a8f9bc0Ed5785654370549b7D);
    IERC20 public GMI = IERC20(0x8750F5651AF49950b5419928Fecefca7c82141E3);
    uint256 public pid = 6;

    IWagmiRouter public Router = IWagmiRouter(0x06FDB55031a0924789107bD97E366a27bbB3d422);
    IWagmiMasterchef public Masterchef = IWagmiMasterchef(0xf046e84439813BB0a26fB26944001C7bb4490771);

    constructor(address _admin) {
        owner = msg.sender;
        admin = _admin;

        WLP.approve(address(Masterchef), 2**256 - 1);
        FAM.approve(address(Router), 2**256 - 1);
        BUSD.approve(address(Router), 2**256 - 1);
        GMI.approve(address(Router), 2**256 - 1);
    }

    modifier onlyOwner {
        require(owner == msg.sender, "Compounder: Caller is not the deployer.");
        _;
    }

    modifier onlyAdmin {
        require(owner == msg.sender || admin == msg.sender, "Compounder: caller is not the owner nor an admin address");
        _;
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function deposit() public onlyOwner {
        require(WLP.balanceOf(address(owner)) > 0, "Compounder: Insufficient WLP Balance.");
        Masterchef.deposit(pid, WLP.balanceOf(address(owner)), true);
    }

    function harvest() public onlyOwner {
        Masterchef.claim(pid);
    }

    function withdraw() external onlyOwner {
        Masterchef.claim(pid);
        GMI.transfer(address(owner), GMI.balanceOf(address(this)));
        Masterchef.emergencyWithdraw(pid);
        WLP.transfer(address(owner), WLP.balanceOf(address(this)));
    }

    function compound() external onlyOwner {
        harvest();
        address[] memory path = new address[](3);
        path[0] = address(GMI);
        path[1] = address(0x985458E523dB3d53125813eD68c274899e9DfAb4);
        path[2] = address(FAM);
        // GMI -> FAM
        //      /     \
        //     USDC  BUSD

        Router.swapExactTokensForTokens(
            GMI.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp + 1200
        );

        address[] memory fambusd = new address[](2);
        fambusd[0] = address(FAM);
        fambusd[1] = address(BUSD);

        Router.swapExactTokensForTokens(
            FAM.balanceOf(address(this))/2,
            0,
            fambusd,
            address(this),
            block.timestamp + 1200
        );

        if ((FAM.balanceOf(address(this)) > 0) && (BUSD.balanceOf(address(this)) > 0)) {
            Router.addLiquidity(
                address(FAM),
                address(BUSD),
                FAM.balanceOf(address(this)),
                BUSD.balanceOf(address(this)),
                0, 0,
                address(this),
                block.timestamp + 1200
            );
        }

        Masterchef.deposit(pid, WLP.balanceOf(address(this)), true);

    }

}
