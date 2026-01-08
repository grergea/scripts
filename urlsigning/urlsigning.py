#!/usr/bin/env python3
"""
URLSigning - CDN URL Signing Tool

CDN URL 서명을 생성하는 Python 스크립트입니다.
다양한 CDN 벤더의 URL 인증 방식(A~E, UTV 모드)을 지원합니다.

Author: Lee Sanghun (@grergea)
License: MIT
"""

import hashlib
import argparse
import time
import random
import uuid
import socket
from urllib.parse import urlencode


def mask_key(key):
    """키를 마스킹하여 보안 유지"""
    if len(key) > 4:
        return key[:2] + '*' * (len(key) - 4) + key[-2:]
    return '****'


def generate_signature(data, hash_type='md5', key=None, verbose=False):
    """해시 서명 생성"""
    if verbose:
        masked_data = data.replace(key, mask_key(key)) if key else data
        print(f"[DEBUG] Signing string (masked): {masked_data}")
    if hash_type.lower() == 'md5':
        hash_result = hashlib.md5(data.encode()).hexdigest()
    elif hash_type.lower() == 'sha256':
        hash_result = hashlib.sha256(data.encode()).hexdigest()
    else:
        raise ValueError("Invalid hash type. Choose 'md5' or 'sha256'.")
    if verbose:
        print(f"[DEBUG] Generated {hash_type.upper()} hash: {hash_result}")
    return hash_result


def get_uid(uid_type='mac', custom_uid=None, verbose=False):
    """
    다양한 UID 소스 지원

    Args:
        uid_type: UID 생성 방식 ('mac', 'random', 'zero', 'hostname')
        custom_uid: 사용자 지정 UID (지정 시 uid_type 무시)
        verbose: 디버그 출력 여부

    Returns:
        str: 생성된 UID 문자열
    """
    # 사용자 지정 UID가 있으면 바로 반환
    if custom_uid:
        if verbose:
            print(f"[DEBUG] Using custom UID: {custom_uid}")
        return custom_uid

    if uid_type == 'mac':
        try:
            mac = uuid.getnode()
            mac_uid = str(mac)
            if verbose:
                print(f"[DEBUG] MAC-based UID: {hex(mac)} -> {mac_uid}")
            return mac_uid
        except Exception as e:
            if verbose:
                print(f"[DEBUG] MAC address unavailable ({e}), falling back to random")
            uid_type = 'random'  # fallback

    if uid_type == 'random':
        # 랜덤 UUID (요청마다 다름)
        random_uid = str(uuid.uuid4().int)[:16]
        if verbose:
            print(f"[DEBUG] Random UID: {random_uid}")
        return random_uid

    if uid_type == 'zero':
        # 고정값 0 (테스트/호환성용)
        if verbose:
            print(f"[DEBUG] Zero UID: 0")
        return "0"

    if uid_type == 'hostname':
        # 호스트명 기반 해시
        try:
            hostname = socket.gethostname()
            hostname_uid = str(abs(hash(hostname)) % (10 ** 16))
            if verbose:
                print(f"[DEBUG] Hostname-based UID: {hostname} -> {hostname_uid}")
            return hostname_uid
        except Exception as e:
            if verbose:
                print(f"[DEBUG] Hostname unavailable ({e}), falling back to zero")
            return "0"

    # 알 수 없는 타입이면 zero 반환
    if verbose:
        print(f"[DEBUG] Unknown uid_type '{uid_type}', using zero")
    return "0"


def generate_signed_url(mode, scheme, host, path, key, start_time, hex_time=False,
                        hash_type='md5', utv_time_offset=3600, utv_time_param='px-time',
                        utv_hash_param='px-hash', uid=None, uid_type='mac', verbose=False):
    """서명된 URL 생성"""
    if hex_time:
        if isinstance(start_time, int):
            time_str = hex(start_time)[2:]  # 0x 접두사 제거
        else:
            time_str = hex(int(start_time))[2:]
        if verbose:
            print(f"[DEBUG] Converting time to hex: {start_time} -> {time_str}")
    else:
        time_str = str(start_time)

    if not path.startswith("/"):
        path = "/" + path  # Make sure path always has '/'

    if verbose:
        print(f"[DEBUG] Mode: {mode}, Scheme: {scheme}, Host: {host}, "
              f"Path: {path}, Key: {mask_key(key)}, Time: {time_str}, Hash: {hash_type}")

    if mode == 'A':
        signed_key = generate_signature(f"{path}{key}{time_str}", hash_type, key, verbose)
        return f"{scheme}://{host}/{time_str}/{signed_key}{path}"
    elif mode == 'B':
        signed_key = generate_signature(f"{path}{key}{time_str}", hash_type, key, verbose)
        return f"{scheme}://{host}/{signed_key}/{time_str}{path}"
    elif mode == 'C':
        signed_key = generate_signature(f"{path}{key}{time_str}", hash_type, key, verbose)
        params = urlencode({'key': signed_key, 'time': time_str})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == 'D':
        signed_key = generate_signature(f"{path}{key}{time_str}", hash_type, key, verbose)
        params = urlencode({'time': time_str, 'key': signed_key})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == 'E':
        rand = ''.join(random.choices('0123456789', k=9))
        user_uid = get_uid(uid_type, uid, verbose)
        signing_string = f"{path}-{time_str}-{rand}-{user_uid}-{key}"
        signed_key = generate_signature(signing_string, hash_type, key, verbose)
        params = urlencode({'auth_key': f"{time_str}-{rand}-{user_uid}-{signed_key}"})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == 'UTV':
        if hex_time:
            utv_time = hex(int(time_str, 16) + utv_time_offset)[2:]
        else:
            utv_time = str(int(time_str) + utv_time_offset)
        if verbose:
            print(f"[DEBUG] UTV mode: original time {time_str} -> "
                  f"adjusted time {utv_time} (+{utv_time_offset} seconds)")
            print(f"[DEBUG] UTV parameters: time_param='{utv_time_param}', "
                  f"hash_param='{utv_hash_param}'")
        signed_key = generate_signature(f"{key}{path}{utv_time}", hash_type, key, verbose)
        params = urlencode({utv_time_param: utv_time, utv_hash_param: signed_key})
        return f"{scheme}://{host}{path}?{params}"
    else:
        raise ValueError("Invalid mode selected. Choose A, B, C, D, E, or UTV.")


def main():
    parser = argparse.ArgumentParser(
        description='Generate signed URL for CDN authentication (supports MD5/SHA256)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s -m A -r cdn.example.com -p /video.mp4 -k mykey
  %(prog)s -m E -r cdn.example.com -p /video.mp4 -k mykey --uid "SMARTTV-123"
  %(prog)s -m UTV -r cdn.example.com -p /video.mp4 -k mykey --hex-time
        '''
    )
    parser.add_argument('-m', '--mode', choices=['A', 'B', 'C', 'D', 'E', 'UTV'],
                        required=True, help='Signing mode (A, B, C, D, E, UTV)')
    parser.add_argument('-s', '--scheme', choices=['http', 'https'], default='http',
                        help='URL scheme (default: http)')
    parser.add_argument('-r', '--host', required=True,
                        help='Resource hostname (e.g., cdn.example.com)')
    parser.add_argument('-p', '--path', required=True,
                        help='File path of resource (e.g., /video.mp4)')
    parser.add_argument('-k', '--key', required=True,
                        help='URL signing secret key')
    parser.add_argument('-t', '--start_time', type=int, default=int(time.time()),
                        help='Start time as Unix timestamp (default: current time)')
    parser.add_argument('--hex-time', action='store_true',
                        help='Convert start_time to hexadecimal format')
    parser.add_argument('--hash', choices=['md5', 'sha256'], default='md5',
                        help='Hash algorithm (default: md5)')
    parser.add_argument('--utv-time-offset', type=int, default=3600,
                        help='Time offset in seconds for UTV mode (default: 3600)')
    parser.add_argument('--utv-time-param', default='px-time',
                        help='Parameter name for time in UTV mode (default: px-time)')
    parser.add_argument('--utv-hash-param', default='px-hash',
                        help='Parameter name for hash in UTV mode (default: px-hash)')
    parser.add_argument('--uid', default=None,
                        help='Custom UID for mode E (overrides --uid-type)')
    parser.add_argument('--uid-type', choices=['mac', 'random', 'zero', 'hostname'],
                        default='mac',
                        help='UID generation method for mode E (default: mac)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable debug output (keys are masked)')

    args = parser.parse_args()

    signed_url = generate_signed_url(
        args.mode,
        args.scheme,
        args.host,
        args.path,
        args.key,
        args.start_time,
        args.hex_time,
        args.hash,
        args.utv_time_offset,
        args.utv_time_param,
        args.utv_hash_param,
        args.uid,
        args.uid_type,
        args.verbose
    )
    print("Signed URL:", signed_url)


if __name__ == '__main__':
    main()
