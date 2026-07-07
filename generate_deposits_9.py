import os
import sys
import json

# ethstaker-deposit-cli is installed editable at /tmp/ethstaker-deposit-cli.
# Its intl files are relative to the repo root, so run from there.
ETHSTAKER_DIR = '/tmp/ethstaker-deposit-cli'
if os.path.isdir(ETHSTAKER_DIR):
    sys.path.insert(0, ETHSTAKER_DIR)
    os.chdir(ETHSTAKER_DIR)
else:
    raise RuntimeError(f'ethstaker-deposit-cli not found at {ETHSTAKER_DIR}. Run: python3 -m venv /tmp/ethstaker-venv && /tmp/ethstaker-venv/bin/pip install -e {ETHSTAKER_DIR}')

from ethstaker_deposit.settings import get_devnet_chain_setting
from ethstaker_deposit.credentials import CredentialList
from ethstaker_deposit.key_handling.key_derivation.mnemonic import get_mnemonic

NUM_VALIDATORS = 9
AMOUNT = 32000000000  # 32 ETH in Gwei
FOLDER = '/home/harsh/eth-pos/private-pos/deposit_data_9'
PASSWORD = 'password'

# Devnet chain setting matching config.yaml
# GENESIS_FORK_VERSION: 0x20000089
# EXIT_FORK_VERSION: 0x20000094 (Electra)
# Minimum deposit amount: 1 ETH
# Minimum activation amount: 32 ETH
CHAIN_SETTING = get_devnet_chain_setting(
    network_name='private-pos-12345',
    genesis_fork_version='0x20000089',
    exit_fork_version='0x20000094',
    genesis_validator_root=None,
    multiplier=1,
    min_activation_amount=32,
    min_deposit_amount=1,
)

# Generate a fresh mnemonic
words_path = os.path.join(ETHSTAKER_DIR, 'ethstaker_deposit/key_handling/key_derivation/word_lists')
mnemonic = get_mnemonic(language='english', words_path=words_path)
mnemonic_password = ''

os.makedirs(FOLDER, exist_ok=True)
keystore_folders = [os.path.join(FOLDER, f'node{i}') for i in range(1, NUM_VALIDATORS + 1)]
for kf in keystore_folders:
    os.makedirs(kf, exist_ok=True)

amounts = [AMOUNT] * NUM_VALIDATORS

cl = CredentialList.from_mnemonic(
    mnemonic=mnemonic,
    mnemonic_password=mnemonic_password,
    num_keys=NUM_VALIDATORS,
    amounts=amounts,
    chain_setting=CHAIN_SETTING,
    start_index=0,
    hex_withdrawal_address=None,
    compounding=False,
    use_pbkdf2=False,
)

# Export keystores for each node
for i, cred in enumerate(cl.credentials):
    cred.save_signing_keystore(PASSWORD, keystore_folders[i], timestamp=0.0)

# Save mnemonic
with open(os.path.join(FOLDER, 'mnemonic.txt'), 'w') as f:
    f.write(mnemonic)

# Export aggregate deposit_data JSON
aggregate_file = os.path.join(FOLDER, 'deposit_data_all.json')
with open(aggregate_file, 'w') as f:
    json.dump([cred.deposit_datum_dict for cred in cl.credentials], f, default=lambda x: x.hex() if isinstance(x, bytes) else str(x))

# Export bootstrap genesis deposit (first validator in standard staking-deposit-cli format)
bootstrap_file = os.path.join(FOLDER, 'deposit_data_bootstrap.json')
with open(bootstrap_file, 'w') as f:
    json.dump([cl.credentials[0].deposit_datum_dict], f, default=lambda x: x.hex() if isinstance(x, bytes) else str(x))

print(f'Generated {NUM_VALIDATORS} validators in {FOLDER}')
print(f'Aggregate deposit data: {aggregate_file}')
print(f'Genesis bootstrap deposit: {bootstrap_file}')
print(f'Mnemonic saved to {FOLDER}/mnemonic.txt')

# Also create individual deposit JSONs matching send_deposit_new.py format
for i, cred in enumerate(cl.credentials):
    d = cred.deposit_datum_dict
    single = {
        'account': f"m/12381/3600/{i}/0/0",
        'deposit_data_root': d['deposit_data_root'].hex(),
        'pubkey': d['pubkey'].hex(),
        'signature': d['signature'].hex(),
        'value': str(AMOUNT),
        'version': 1,
        'withdrawal_credentials': d['withdrawal_credentials'].hex(),
    }
    with open(os.path.join(FOLDER, f'deposit_data_{i+1}.json'), 'w') as f:
        json.dump(single, f, indent=2)

print('Done')
