// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/Utils.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract XERC20 is ERC20, IDapp {
  address public owner;

  IGateway public gatewayContract;
  
  uint64 public _destGasLimit;
  
  mapping(string => bytes) public ourContractOnChains;


  constructor(address payable gatewayAddress, string memory feePayerAddress) ERC20("CrossChain Token", "CCT") {
    gatewayContract = IGateway(gatewayAddress);
    owner = msg.sender;

    _mint(msg.sender, 20);

    gatewayContract.setDappMetadata(feePayerAddress);
  }


  function setDappMetadata(string memory feePayerAddress) external {
    require(msg.sender == owner, "Only owner can do this transaction!");
    gatewayContract.setDappMetadata(feePayerAddress);
  }


  function setGateway(address gateway) external {
    require(msg.sender == owner, "Only owner can do this transaction!");
    gatewayContract = IGateway(gateway);
  }


  function mint(address account, uint256 amount) external {
    require(msg.sender == owner, "Only owner can do this transaction!");
    _mint(account, amount);
  }


  function setContractOnChain(string memory chainId, address contractAddress) external {
    require(msg.sender == owner, "Only owner can do this transaction!");
    ourContractOnChains[chainId] = toBytes(contractAddress);
  }


  function transferCrossChain(uint256 amount, string calldata destChainId, string calldata recipient, bytes calldata requestMetadata) public payable {
    require(keccak256(ourContractOnChains[destChainId]) != keccak256(toBytes(address(0))), "Contract on Destination Chain is not set!");

    require(balanceOf(msg.sender) >= amount, "The Amount cannot be greater than the balance!");

    _burn(msg.sender, amount);

    bytes memory packet = abi.encode(recipient, amount);
    bytes memory requestPacket = abi.encode(ourContractOnChains[destChainId], packet);

    gatewayContract.iSend{ value: msg.value }( 1, 0, string(""), destChainId, requestMetadata, requestPacket);
  }


  function getRequestMetadata(uint64 destGasLimit, uint64 destGasPrice, uint64 ackGasLimit, uint64 ackGasPrice, uint128 relayerFees, uint8 ackType, bool isReadCall, string calldata asmAddress) public pure returns (bytes memory) {
    bytes memory requestMetadata = abi.encodePacked(destGasLimit, destGasPrice, ackGasLimit, ackGasPrice, relayerFees, ackType, isReadCall, asmAddress);
    return requestMetadata;
  }


  function iReceive(string memory requestSender, bytes memory packet, string memory srcChainId) external override returns (bytes memory) {
    require(msg.sender == address(gatewayContract), "only gateway");
    require(keccak256(ourContractOnChains[srcChainId]) == keccak256(bytes(requestSender)));

    (bytes memory recipient, uint256 amount) = abi.decode(packet,(bytes, uint256));

    _mint(toAddress(recipient), amount);

    return abi.encode(srcChainId);
  }


  function iAck(uint256 requestIdentifier, bool execFlag, bytes memory execData) external override {}


  function toBytes(address a) public pure returns (bytes memory b) {
    assembly {
      let m := mload(0x40)
      a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
      mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
      mstore(0x40, add(m, 52))
      b := m
    }
  }


  function toAddress(bytes memory _bytes) internal pure returns (address addr) {
    bytes20 srcTokenAddress;
    assembly {
      srcTokenAddress := mload(add(_bytes, 0x20))
    }
    addr = address(srcTokenAddress);
  }
}