from web3 import Web3
import json
from eth_abi import encode

w3 = Web3(Web3.HTTPProvider('http://localhost:8541'))

with open('deposit_data_new.json') as f:
    d = json.load(f)

pubkey = bytes.fromhex(d['pubkey'])
withdrawal_credentials = bytes.fromhex(d['withdrawal_credentials'])
signature = bytes.fromhex(d['signature'])
deposit_data_root = bytes.fromhex(d['deposit_data_root'])
amount_gwei = int(d['value'])

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

acct = w3.eth.account.from_key('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
w3.eth.default_account = acct.address

# amount in Gwei -> value in wei (1 Gwei = 1e9 wei)
value_wei = amount_gwei * 10**9

print(f'Sender: {acct.address}')
print(f'Pubkey: {pubkey.hex()}')
print(f'Withdrawal credentials: {withdrawal_credentials.hex()}')
print(f'Signature: {signature.hex()}')
print(f'Deposit data root: {deposit_data_root.hex()}')
print(f'Amount (Gwei): {amount_gwei}')
print(f'Value (wei): {value_wei}')

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
print(f'Tx hash: {signed.hash.hex()}')
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
print(f'Sent: {tx_hash.hex()}')
receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)
print(f'Status: {receipt.status}')
print(f'Block: {receipt.blockNumber}')
print(f'Gas used: {receipt.gasUsed}')
