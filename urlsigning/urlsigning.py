#!/usr/bin/env python3
import hashlib
import argparse
import time
import random
import uuid
import socket
from urllib.parse import urlencode, urlparse


def mask_key(key):
    """키를 마스킹하여 보안 유지"""
    if len(key) > 4:
        return key[:2] + "*" * (len(key) - 4) + key[-2:]
    return "****"


def generate_signature(data, hash_type="md5", key=None, verbose=False):
    if verbose:
        masked_data = data.replace(key, mask_key(key)) if key else data
        print(f"[DEBUG] Signing string (masked): {masked_data}")
    if hash_type.lower() == "md5":
        hash_result = hashlib.md5(data.encode()).hexdigest()
    elif hash_type.lower() == "sha256":
        hash_result = hashlib.sha256(data.encode()).hexdigest()
    else:
        raise ValueError("Invalid hash type. Choose 'md5' or 'sha256'.")
    if verbose:
        print(f"[DEBUG] Generated {hash_type.upper()} hash: {hash_result}")
    return hash_result


def get_uid(uid_type="mac", custom_uid=None, verbose=False):
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

    if uid_type == "mac":
        try:
            mac = uuid.getnode()
            mac_uid = str(mac)
            if verbose:
                print(f"[DEBUG] MAC-based UID: {hex(mac)} -> {mac_uid}")
            return mac_uid
        except Exception as e:
            if verbose:
                print(f"[DEBUG] MAC address unavailable ({e}), falling back to random")
            uid_type = "random"  # fallback

    if uid_type == "random":
        # 랜덤 UUID (요청마다 다름)
        random_uid = str(uuid.uuid4().int)[:16]
        if verbose:
            print(f"[DEBUG] Random UID: {random_uid}")
        return random_uid

    if uid_type == "zero":
        # 고정값 0 (테스트/호환성용)
        if verbose:
            print("[DEBUG] Zero UID: 0")
        return "0"

    if uid_type == "hostname":
        # 호스트명 기반 해시
        try:
            hostname = socket.gethostname()
            hostname_uid = str(abs(hash(hostname)) % (10**16))
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


def build_sign_string(path, key, time_str, sign_order):
    tokens = {"p": path, "k": key, "t": time_str}
    return "".join(tokens[c] for c in sign_order)


def generate_signed_url(
    mode,
    scheme,
    host,
    path,
    key,
    start_time,
    hex_time=False,
    hash_type="md5",
    utv_time_offset=3600,
    utv_time_param="px-time",
    utv_hash_param="px-hash",
    uid=None,
    uid_type="mac",
    sign_order="path-key-time",
    verbose=False,
):
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
        print(
            f"[DEBUG] Mode: {mode}, Scheme: {scheme}, Host: {host}, Path: {path}, Key: {mask_key(key)}, Time: {time_str}, Hash: {hash_type}"
        )

    if mode == "A":
        signed_key = generate_signature(
            build_sign_string(path, key, time_str, sign_order), hash_type, key, verbose
        )
        return f"{scheme}://{host}/{time_str}/{signed_key}{path}"
    elif mode == "B":
        signed_key = generate_signature(
            build_sign_string(path, key, time_str, sign_order), hash_type, key, verbose
        )
        return f"{scheme}://{host}/{signed_key}/{time_str}{path}"
    elif mode == "C":
        signed_key = generate_signature(
            build_sign_string(path, key, time_str, sign_order), hash_type, key, verbose
        )
        params = urlencode({"key": signed_key, "time": time_str})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == "D":
        signed_key = generate_signature(
            build_sign_string(path, key, time_str, sign_order), hash_type, key, verbose
        )
        params = urlencode({"time": time_str, "key": signed_key})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == "E":
        rand = "".join(
            random.choices("0123456789", k=9)
        )  # Generate a random 9-digit string
        user_uid = get_uid(uid_type, uid, verbose)  # 다양한 UID 소스 지원
        signing_string = f"{path}-{time_str}-{rand}-{user_uid}-{key}"
        signed_key = generate_signature(signing_string, hash_type, key, verbose)
        params = urlencode({"auth_key": f"{time_str}-{rand}-{user_uid}-{signed_key}"})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == "UTV":
        if hex_time:
            utv_time = hex(int(time_str, 16) + utv_time_offset)[2:]
        else:
            utv_time = str(int(time_str) + utv_time_offset)
        if verbose:
            print(
                f"[DEBUG] UTV mode: original time {time_str} -> adjusted time {utv_time} (+{utv_time_offset} seconds)"
            )
            print(
                f"[DEBUG] UTV parameters: time_param='{utv_time_param}', hash_param='{utv_hash_param}'"
            )
        signed_key = generate_signature(
            build_sign_string(path, key, utv_time, sign_order), hash_type, key, verbose
        )
        params = urlencode({utv_time_param: utv_time, utv_hash_param: signed_key})
        return f"{scheme}://{host}{path}?{params}"
    else:
        raise ValueError("Invalid mode selected. Choose A, B, C, D, E, or UTV.")


def main():
    parser = argparse.ArgumentParser(
        description="Generate signed URL using MD5 or SHA256"
    )
    parser.add_argument(
        "-m",
        "--mode",
        choices=["A", "B", "C", "D", "E", "UTV"],
        required=True,
        help="Signing mode (A, B, C, D, E, UTV)",
    )
    parser.add_argument(
        "-s",
        "--scheme",
        choices=["http", "https"],
        default="https",
        help="Scheme (http or https)",
    )
    parser.add_argument(
        "-u",
        "--url",
        default=None,
        help="Full URL to sign (parses scheme/host/path; overrides -s/-r/-p)",
    )
    parser.add_argument("-r", "--host", default=None, help="Resource hostname")
    parser.add_argument("-p", "--path", default=None, help="File path of resource")
    parser.add_argument("-k", "--key", required=True, help="URL signing key")
    parser.add_argument(
        "-t",
        "--start_time",
        type=int,
        default=int(time.time()),
        help="Starting time of the URL (Unix timestamp)",
    )
    parser.add_argument(
        "--hex-time",
        action="store_true",
        help="Convert start_time to hexadecimal format",
    )
    parser.add_argument(
        "--hash",
        choices=["md5", "sha256"],
        default="md5",
        help="Hash algorithm (md5 or sha256)",
    )
    parser.add_argument(
        "--utv-time-offset",
        type=int,
        default=3600,
        help="Time offset in seconds to add for UTV mode (default: 3600)",
    )
    parser.add_argument(
        "--utv-time-param",
        default="px-time",
        help="Parameter name for time in UTV mode (default: px-time)",
    )
    parser.add_argument(
        "--utv-hash-param",
        default="px-hash",
        help="Parameter name for hash in UTV mode (default: px-hash)",
    )
    parser.add_argument(
        "--uid", default=None, help="Custom UID for mode E (overrides --uid-type)"
    )
    parser.add_argument(
        "--uid-type",
        choices=["mac", "random", "zero", "hostname"],
        default="mac",
        help="UID generation method for mode E (default: mac)",
    )
    parser.add_argument(
        "--sign-order",
        default="pkt",
        help="Signing string order for modes A/B/C/D/UTV using k(ey), p(ath), t(ime) tokens (default: pkt = path+key+time, e.g. kpt = key+path+time)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable debug output (keys are masked)",
    )

    args = parser.parse_args()

    if args.url:
        parsed = urlparse(args.url)
        if parsed.scheme:
            args.scheme = parsed.scheme
        if parsed.netloc:
            args.host = parsed.netloc
        if parsed.path:
            args.path = parsed.path

    if not args.host:
        parser.error("Provide -r/--host or -u/--url with a hostname")
    if not args.path:
        parser.error("Provide -p/--path or -u/--url with a path")

    if sorted(args.sign_order) != ["k", "p", "t"]:
        parser.error(
            "--sign-order must contain exactly 'k', 'p', 't' each once (e.g., pkt, kpt, ktp)"
        )

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
        args.sign_order,
        args.verbose,
    )
    print("Signed URL:", signed_url)


if __name__ == "__main__":
    main()
