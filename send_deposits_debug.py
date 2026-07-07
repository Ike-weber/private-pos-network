from web3 import Web3
import json
import time
import os
import glob

w3 = Web3(Web3.HTTPProvider('http://localhost:8541'))

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
acct = w3.eth.account.from_key('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
w3.eth.default_account = acct.address

print('Connected:', w3.is_connected())
print('Block:', w3.eth.block_number)
print('Balance:', w3.from_wei(w3.eth.get_balance(acct.address), 'ether'), 'ETH')

DEPOSIT_DIR = 'deposit_data_9'
files = sorted(glob.glob(f'{DEPOSIT_DIR}/deposit_data_[2-9].json'))
print(f'Found {len(files)} deposit files')

for path in files:
    with open(path) as f:
        d = json.load(f)

    pubkey = bytes.fromhex(d['pubkey'])
    withdrawal_credentials = bytes.fromhex(d['withdrawal_credentials'])
    signature = bytes.fromhex(d['signature'])
    deposit_data_root = bytes.fromhex(d['deposit_data_root'])
    amount_gwei = int(d['value'])
    value_wei = amount_gwei * 10**9

    print(f'Sending {os.path.basename(path)}: pubkey={pubkey.hex()[:20]}...')

    nonce = w3.eth.get_transaction_count(acct.address)
    print(f'  nonce={nonce}')

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
    print(f'  signed tx hash: {signed.hash.hex()}')

    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'  sent tx hash: {tx_hash.hex()}')

    try:
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=30)
        print(f'  receipt: status={receipt.status}, block={receipt.blockNumber}, gas={receipt.gasUsed}')
    except Exception as e:
        print(f'  ERROR waiting for receipt: {e}')
        break

    time.sleep(1)

print('Done')
