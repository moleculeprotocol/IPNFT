// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EscrowUpgradeable} "@openzeppelin/contracts-upgradeable/utils/escrow/EscrowUpgradeable.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { isContract } from "./helpers/IsContract.sol";
import { IIPSeedCurve, TradeType } from "./curves/IIPSeedCurve.sol";
import {IPToken} from "./IPToken.sol";

struct MarketData {
    /// who created this token
    address sourcer;
    /// who receives token trading fees
    address beneficiary;
    /// the curve that this token is traded on
    IIPSeedCurve priceCurve;
    //byte encoded curve parameters, handed over to the curve for computation
    bytes32 curveParameters;
}

struct Fees {
    uint16 protocolBuyFee;
    uint16 protocolSellFee;
    uint16 sourcerBuyFee;
    uint16 sourcerSellFee;
}

error UnauthorizedAccess();
error TokenAlreadyExists();
error UntrustedCurve();
error InvalidTokenId();
error TradeSizeTooSmall();
error InsufficientPayment();
error PriceDriftTooHigh(uint256 tolerated, uint256 actual);
error BalanceTooLow();
error CurveParametersOutOfBounds();
error FeesOutOfBounds();

/**
 * @title IPSeedMarket
 * @author molecule.to
 * @notice IP seeds are ERC1155 tokens that are traded along a bonding curve and represent governance and interest signals for a preliminary piece of IP.
 * @dev this contract is upgradeable in order to be able to add new features in the future
 * @custom:security-contact info@molecule.to
 */
contract IPSeedMarket is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    address payable public protocolFeeBeneficiary;
    Fees public fees;

    /// @dev the escrow contract holds protocol & sourcer fees to allow pulling over pushing
    EscrowUpgradeable private feeEscrow;

    mapping(address => bool) private trustedCurves;
    
    Tokenizer public tokenizer;

    mapping(address => MarketData) private marketData;

    uint16 public constant BASIS_POINTS = 10000;

    /// @dev required to prevent minting free tokens due to precision losses at very low collateralizations
    uint256 public constant MINIMUM_TRADE_SIZE = 0.00001 ether;

    event Traded(
        address indexed trader,
        IPToken indexed ipToken,
        TradeType indexed tradeType,
        uint256 shareAmount,
        uint256 grossEthAmount,
        uint256 newSupply,
        uint256 sourcerFees,
        uint256 protocolFees
    );

    event SaleStarted(uint256 indexed ipnftId, address indexed ipt, address indexed initiator, MarketData marketData);
    event FeesUpdated(Fees newFees);
    event ProtocolBeneficiaryUpdated(address indexed newBeneficiary);
    event CurveTrustChanged(address indexed curve, bool trusted);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payable _protocolFeeBeneficiary, Tokenizer _tokenizer) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_msgSender());
        __ReentrancyGuard_init();
        tokenizer = _tokenizer;
        protocolFeeBeneficiary = _protocolFeeBeneficiary;

        fees = Fees(500, 500, 500, 500);
        feeEscrow = new EscrowUpgradeable();

        emit FeesUpdated(fees);

        // note: address(this) indeed refers to the proxy contract here.
        feeEscrow.initialize(address(this));
    }

    modifier onlySourcer(uint256 tokenId) {
        if (_msgSender() != tokenMeta[tokenId].sourcer) {
            revert UnauthorizedAccess();
        }
        _;
    }

    function setProtocolFeesBeneficiary(address payable _feeDestination) external onlyOwner {
        protocolFeeBeneficiary = _feeDestination;
        emit ProtocolBeneficiaryUpdated(_feeDestination);
    }

    function setFees(Fees memory newFees) external onlyOwner {
        // [L-03]
        if (newFees.protocolBuyFee > 1000 || newFees.protocolSellFee > 1000 || newFees.sourcerBuyFee > 1000 || newFees.sourcerSellFee > 1000) {
            revert FeesOutOfBounds();
        }

        fees = newFees;
        emit FeesUpdated(newFees);
    }

    function trustCurve(address curve, bool trust) external onlyOwner {
        if (!isContract(curve)) {
            revert UntrustedCurve();
        }
        trustedCurves[curve] = trust;
        emit CurveTrustChanged(curve, trust);
    }

    /**
     * @notice anchors a new token id on the contract. Doesn't mint any tokens.
     *
     * @dev in the future we might consider nailing down some curve deployments / parameter sets that we control so no one can use custom ones without forking
     *
     * @param ipToken ipt token to start seeding
     * @param projectId the orbis project id (usually a base36 encoded ceramic stream id)
     * @param curve an IIPSeedCurve implementation address
     * @param curveParameters the fixed parameters that define the curve's shape, encoded as bytes32
     */
    function start(IPToken ipToken, IIPSeedCurve curve, bytes32 curveParameters, address sourcer) public {
        // ERC1155's `exists` function checks for totalSupply > 0, which is not what we want here
        if (address(marketData[ipToken].curve) != address(0)) {
            revert TokenAlreadyExists();
        }

        if (!trustedCurves[address(curve)]) {
            revert UntrustedCurve();
        }

        if (!curve.areParametersInRange(curveParameters)) {
            revert CurveParametersOutOfBounds();
        }
        if (ipToken.totalSupply() > 0) {
            revert "can only seed tokens with 0 supply";
        }
        ipToken.stopTransfers();

        MarketData memory _marketData = MarketData(sourcer, sourcer, curve, curveParameters);
        marketData[ipToken] = _marketData;
        emit SaleStarted(tokenId, sourcer, _marketData);
    }

    /**
     * @notice buy tokens on the token's bonding curve. This requires the user to send the exact amount of ETH that can be queried by calling `getBuyPrice` -> `gross`
     *         users can send more ETH than required, the surplus will be refunded
     * @param tokenId token id
     * @param amount the amount of tokens to buy
     */
    function mint(address ipToken, uint256 amount) external payable nonReentrant {
        if (amount < MINIMUM_TRADE_SIZE) {
            revert TradeSizeTooSmall();
        }

        //when buying, gross > net
        (uint256 gross, uint256 net, uint256 protocolFee, uint256 sourcerFee) = getBuyPrice(ipToken, amount);

        if (net == 0) {
            revert TradeSizeTooSmall();
        }

        if (msg.value < gross) {
            revert InsufficientPayment();
        }

        escrowFees(protocolFee, tokenMeta[tokenId].beneficiary, sourcerFee);

        emit Traded(_msgSender(), tokenId, TradeType.Buy, amount, gross, totalSupply(tokenId) + amount, sourcerFee, protocolFee);
        ipToken.issue(_msgSender(), amount);
        //refund surplus; that might help against frontrunners blocking trades by pushing the price up only by a tiny bit
        if (msg.value > gross) {
            Address.sendValue(payable(_msgSender()), msg.value - gross);
        }
    }

    /**
     * @notice sell tokens on the token's bonding curve by burning them. Fees are deducted and escrowed from the returned value
     * @param tokenId token id
     * @param amount the amount of tokens to burn
     * @param minOutNetAmount the minimum net amount of ETH that the user is willing to accept.
     *        Set to 0 if you don't care about slippage (exposes you to frontrunners!)
     */
    function burn(address ipToken, uint256 amount, uint256 minOutNetAmount) external virtual nonReentrant {
        uint256 currentBalance = ipToken.balanceOf(_msgSender());

        if (currentBalance < amount) {
            revert BalanceTooLow();
        }
        //allow selling exactly to 0
        if (
            amount < MINIMUM_TRADE_SIZE
            //don't allow selling below the minimum trade size (the remainder would compute to 0)
            || currentBalance > amount && currentBalance - amount < MINIMUM_TRADE_SIZE
        ) {
            revert TradeSizeTooSmall();
        }

        //when selling, gross < net
        (uint256 gross, uint256 net, uint256 protocolFee, uint256 sourcerFee) = getSellPrice(ipToken, amount);

        if (net < minOutNetAmount) {
            revert PriceDriftTooHigh(minOutNetAmount, net);
        }

        emit Traded(_msgSender(), TradeType.Sell, amount, gross, ipToken.totalSupply() - amount, sourcerFee, protocolFee);

        ipToken.burnFrom(_msgSender(), amount);

        escrowFees(protocolFee, tokenMeta[tokenId].beneficiary, sourcerFee);
        Address.sendValue(payable(_msgSender()), net);
    }

    function endSeeding() public {

    }

    
    /**
     * @notice withdraws the protocol fees that have accumulated for the caller
     *         this function is deliberately completely open and unconditional right now but will be successively restricted while the protocol matures
     */
    function withdrawFees() external nonReentrant {
        feeEscrow.withdraw(payable(_msgSender()));
    }

    /**
     * @notice returns price details that users need to pay to buy `want` tokens.
     * @return gross the amount of ETH that needs to be sent to the contract, including fees
     * @return net the amount of ETH that's actually collateralized
     */
    function getBuyPrice(IPToken ipToken, uint256 want) public view returns (uint256 gross, uint256 net, uint256 protocolFee, uint256 sourcerFee) {
        net = marketData[iptToken].priceCurve.getBuyPrice(ipToken.totalSupply()), want, marketData[ipToken].curveParameters);

        (protocolFee, sourcerFee) = computeFees(net, TradeType.Buy);
        gross = net + protocolFee + sourcerFee;
    }

    /**
     * @notice returns details on how much users will receive when selling `sell` amount of tokens
     * @return gross the amount of ETH that will removed from the curve (this amount includes fees)
     * @return net the amount of ETH that the user will receive after deducting fees
     */
    function getSellPrice(IPToken ipToken, uint256 sell) public view returns (uint256 gross, uint256 net, uint256 protocolFee, uint256 sourcerFee) {
        gross = marketData[ipToken].priceCurve.getSellPrice(ipToken.totalSupply(), sell, marketData[ipToken].curveParameters);
        (protocolFee, sourcerFee) = computeFees(gross, TradeType.Sell);
        net = gross - protocolFee - sourcerFee;
    }

    /**
     * @dev the total amount of collateral that's currently locked on token id's bonding curve
     */
    function collateral(address ipToken) external view returns (uint256) {
        return marketData[tokenId].priceCurve.getBuyPrice(0, tokenId.totalSupply(), marketData[ipToken].curveParameters);
    }

    /**
     * @return amount of Eth fees currently deposited for `payee`
     */
    function depositsOf(address payee) public view returns (uint256) {
        return feeEscrow.depositsOf(payee);
    }

    /**
     * @dev convenience function that returns all fees as wei
     * @return protocolFee
     * @return sourcerFee
     */
    function computeFees(uint256 value, TradeType tradeType) private view returns (uint256 protocolFee, uint256 sourcerFee) {
        uint16 protocolFeeBps = tradeType == TradeType.Buy ? fees.protocolBuyFee : fees.protocolSellFee;
        uint16 sourcerFeeBps = tradeType == TradeType.Buy ? fees.sourcerBuyFee : fees.sourcerSellFee;

        protocolFee = (value * protocolFeeBps) / BASIS_POINTS;
        sourcerFee = (value * sourcerFeeBps) / BASIS_POINTS;
    }

    /**
     * @param protocolFee protocol fee
     * @param sourcer the beneficiary of the sourcer fee
     * @param sourcerFee sourcer fee
     */
    function escrowFees(uint256 protocolFee, address sourcer, uint256 sourcerFee) private {
        feeEscrow.deposit{ value: protocolFee }(protocolFeeBeneficiary);
        feeEscrow.deposit{ value: sourcerFee }(sourcer);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    { }

}
