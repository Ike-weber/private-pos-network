from web3 import Web3
import json
import time
import os
import glob

w3 = Web3(Web3.HTTPProvider('http://localhost:8541'))

# Standard deposit contract ABI (only the deposit function)
abi = [{
    "inputs": [
        {"internalType": "bytes", "name": "pubkey", "type": "bytes"},
        {"internalType": "bytes", "name": "withdrawal_credentials", "type": "bytes"},
        {"internalType": "bytes", "name": "signature", "type": "bytes"},
        {"internalType": "bytes32", "name": "deposit_data_root", "type": "bytes32"}
    ],
    "name": "deposit",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
}]

contract = w3.eth.contract(address='0x4242424242424242424242424242424242424242', abi=abi)

# Anvil default account #0
acct = w3.eth.account.from_key('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
w3.eth.default_account = acct.address

DEPOSIT_DIR = 'deposit_data_9'

def send_deposit_for_file(path):
    with open(path) as f:
        d = json.load(f)

    pubkey = bytes.fromhex(d['pubkey'])
    withdrawal_credentials = bytes.fromhex(d['withdrawal_credentials'])
    signature = bytes.fromhex(d['signature'])
    deposit_data_root = bytes.fromhex(d['deposit_data_root'])
    amount_gwei = int(d['value'])
    value_wei = amount_gwei * 10**9

    print(f'Sending deposit from {os.path.basename(path)}: pubkey={pubkey.hex()[:20]}... amount={amount_gwei} gwei')

    nonce = w3.eth.get_transaction_count(acct.address)
    tx = contract.functions.deposit(
        pubkey,
        withdrawal_credentials,
        signature,
        deposit_data_root
    ).build_transaction({
        'from': acct.address,
        'value': value_wei,
        'nonce': nonce,
        'gas': 200000,
        'maxFeePerGas': 10000000000,
        'maxPriorityFeePerGas': 1000000000,
        'chainId': 12345
    })

    signed = w3.eth.account.sign_transaction(tx, acct.key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'  Tx hash: {tx_hash.hex()}')
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)
    print(f'  Status: {receipt.status}, Block: {receipt.blockNumber}, Gas used: {receipt.gasUsed}')
    return receipt

# Wait for Geth RPC
print('Waiting for Geth RPC at http://localhost:8541...')
for _ in range(30):
    if w3.is_connected():
        print('Geth connected')
        break
    time.sleep(1)
else:
    raise RuntimeError('Geth RPC not available')

print(f'Sender balance: {w3.eth.get_balance(acct.address)} wei')

# Send deposits for node2..node9 (node1 is already in genesis as bootstrap)
files = sorted(glob.glob(f'{DEPOSIT_DIR}/deposit_data_[2-9].json'))
print(f'Found {len(files)} deposit files to send')

for path in files:
    send_deposit_for_file(path)
    time.sleep(1)

print('All deposits sent')
