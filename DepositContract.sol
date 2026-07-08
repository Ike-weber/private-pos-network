// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.6.11;

interface IDepositContract {
    function deposit(bytes calldata pubkey, bytes calldata withdrawal_credentials, bytes calldata signature, bytes32 deposit_data_root) external payable;
    function get_deposit_root() external view returns (bytes32);
    function get_deposit_count() external view returns (bytes memory);
}

contract DepositContract is IDepositContract {
    uint constant DEPOSIT_CONTRACT_TREE_DEPTH = 32;
    uint constant MAX_DEPOSIT_COUNT = 2 ** DEPOSIT_CONTRACT_TREE_DEPTH - 1;
    uint constant PUBKEY_LENGTH = 48;
    uint constant SIGNATURE_LENGTH = 96;
    uint constant DEPOSIT_AMOUNT = 32 ether;

    bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] private branch;
    uint256 private deposit_count;

    event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

    // Compute zero hashes for a depth-32 binary Merkle tree once and cache in memory.
    // Much cheaper than recomputing from scratch for each height.
    function get_zero_hashes() internal pure returns (bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] memory) {
        bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] memory zh;
        zh[0] = sha256(abi.encodePacked(bytes32(0), bytes32(0)));
        for (uint i = 1; i < DEPOSIT_CONTRACT_TREE_DEPTH; i++) {
            zh[i] = sha256(abi.encodePacked(zh[i - 1], zh[i - 1]));
        }
        return zh;
    }

    function get_deposit_count() external view override returns (bytes memory) {
        return to_little_endian_64(uint64(deposit_count));
    }

    function get_deposit_root() external view override returns (bytes32) {
        bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] memory zh = get_zero_hashes();
        bytes32 node;
        uint size = deposit_count;
        for (uint height = 0; height < DEPOSIT_CONTRACT_TREE_DEPTH; height++) {
            if ((size & 1) == 1) {
                node = sha256(abi.encodePacked(branch[height], node));
            } else {
                node = sha256(abi.encodePacked(node, zh[height]));
            }
            size /= 2;
        }
        return node;
    }

    function deposit(bytes calldata pubkey, bytes calldata withdrawal_credentials, bytes calldata signature, bytes32 deposit_data_root) override external payable {
        require(pubkey.length == PUBKEY_LENGTH, "DepositContract: invalid pubkey length");
        require(withdrawal_credentials.length == 32, "DepositContract: invalid withdrawal_credentials length");
        require(signature.length == SIGNATURE_LENGTH, "DepositContract: invalid signature length");
        require(msg.value == DEPOSIT_AMOUNT, "DepositContract: deposit value not 32 ether");

        emit DepositEvent(pubkey, withdrawal_credentials, to_little_endian_64(uint64(msg.value / 1 gwei)), signature, to_little_endian_64(uint64(deposit_count)));

        bytes32 pubkey_root = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 signature_root = sha256(abi.encodePacked(
            sha256(abi.encodePacked(signature[:64])),
            sha256(abi.encodePacked(signature[64:], bytes32(0)))
        ));
        bytes32 node = sha256(abi.encodePacked(
            sha256(abi.encodePacked(pubkey_root, withdrawal_credentials)),
            sha256(abi.encodePacked(to_little_endian_64(uint64(msg.value / 1 gwei)), bytes24(0), signature_root))
        ));

        require(node == deposit_data_root, "DepositContract: reconstructed deposit data root does not match supplied");

        bytes32[DEPOSIT_CONTRACT_TREE_DEPTH] memory zh = get_zero_hashes();
        uint size = deposit_count;
        for (uint height = 0; height < DEPOSIT_CONTRACT_TREE_DEPTH; height++) {
            if ((size & 1) == 1) {
                node = sha256(abi.encodePacked(branch[height], node));
            } else {
                node = sha256(abi.encodePacked(node, zh[height]));
            }
            size /= 2;
        }
        branch[DEPOSIT_CONTRACT_TREE_DEPTH - 1] = node;

        deposit_count += 1;
        require(deposit_count <= MAX_DEPOSIT_COUNT, "DepositContract: merkle tree full");
    }

    function to_little_endian_64(uint64 value) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 v = bytes8(value);
        for (uint i = 0; i < 8; i++) {
            ret[i] = v[7 - i];
        }
        return ret;
    }
}
