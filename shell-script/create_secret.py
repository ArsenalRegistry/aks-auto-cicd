import base64
import json
# pip install pynacl requests
import requests
from nacl import encoding, public
# pip install python-dotenv
from dotenv import load_dotenv
import os

# .env 파일을 읽어옵니다.
load_dotenv(dotenv_path='config.env')

# 환경 변수를 읽어옵니다.
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
ORGANIZATION = os.getenv('GROUP_NAME')
REPO = os.getenv('PROJECT_NAME')
AZURE_URL = os.getenv('AZURE_URL')
ACR_USERNAME = os.getenv('ACR_USERNAME')
ACR_PASSWORD = os.getenv('ACR_PASSWORD')

# 해당 파일은 github organization repository에 github secret을 생성하는 코드입니다.
# 로컬에서 진행시에 python 설치되어 있어야 합니다.
# pip install pynacl requests 필요

def get_public_key():
    url = f"https://api.github.com/repos/{ORGANIZATION}/{REPO}/actions/secrets/public-key"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    try:
        response = requests.get(url, headers=headers, verify=False)  # SSL 검증 비활성화
        response.raise_for_status()
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP error occurred: {http_err}")
        raise
    except Exception as err:
        print(f"An error occurred: {err}")
        raise
    return response.json()

def encrypt_secret(public_key: str, secret_value: str) -> str:
    public_key = public.PublicKey(public_key.encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return base64.b64encode(encrypted).decode("utf-8")

def create_or_update_secret(secret_name: str, encrypted_value: str, key_id: str):
    url = f"https://api.github.com/repos/{ORGANIZATION}/{REPO}/actions/secrets/{secret_name}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {
        "encrypted_value": encrypted_value,
        "key_id": key_id
    }
    try:
        response = requests.put(url, headers=headers, data=json.dumps(data), verify=False)  # SSL 검증 비활성화
        response.raise_for_status()
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP error occurred: {http_err}")
        raise
    except Exception as err:
        print(f"An error occurred: {err}")
        raise

if __name__ == "__main__":
    try:
        public_key_data = get_public_key()
        key_id = public_key_data["key_id"]
        public_key = public_key_data["key"]

        secrets = {
            "AZURE_URL": AZURE_URL,
            "ACR_USERNAME": ACR_USERNAME,
            "ACR_PASSWORD": ACR_PASSWORD,
            "ACTION_TOKEN": GITHUB_TOKEN
        }

        for secret_name, secret_value in secrets.items():
            encrypted_value = encrypt_secret(public_key, secret_value)
            create_or_update_secret(secret_name, encrypted_value, key_id)

        print("Secrets have been created/updated successfully.")
    except requests.exceptions.HTTPError as http_err:
        print(f"HTTP error occurred: {http_err}")
    except Exception as err:
        print(f"An error occurred: {err}")
