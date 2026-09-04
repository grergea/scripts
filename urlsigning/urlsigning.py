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


def apply_time_offset(time_str, offset, hex_time):
    """time_str에 offset(초)을 더한 문자열을 반환. offset이 0이면 그대로 반환."""
    if offset == 0:
        return time_str
    if hex_time:
        return hex(int(time_str, 16) + offset)[2:]
    return str(int(time_str) + offset)


def generate_signed_url(
    mode,
    scheme,
    host,
    path,
    key,
    start_time,
    hex_time=False,
    hash_type="md5",
    time_offset=3600,
    time_param="px-time",
    hash_param="px-hash",
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
        adjusted_time = apply_time_offset(time_str, time_offset, hex_time)
        if verbose and time_offset:
            print(
                f"[DEBUG] Mode C: original time {time_str} -> adjusted time {adjusted_time} (+{time_offset} seconds)"
            )
        signed_key = generate_signature(
            build_sign_string(path, key, adjusted_time, sign_order),
            hash_type,
            key,
            verbose,
        )
        params = urlencode({"key": signed_key, "time": adjusted_time})
        return f"{scheme}://{host}{path}?{params}"
    elif mode == "D":
        adjusted_time = apply_time_offset(time_str, time_offset, hex_time)
        if verbose and time_offset:
            print(
                f"[DEBUG] Mode D: original time {time_str} -> adjusted time {adjusted_time} (+{time_offset} seconds)"
            )
        signed_key = generate_signature(
            build_sign_string(path, key, adjusted_time, sign_order),
            hash_type,
            key,
            verbose,
        )
        params = urlencode({"time": adjusted_time, "key": signed_key})
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
        utv_time = apply_time_offset(time_str, time_offset, hex_time)
        if verbose:
            print(
                f"[DEBUG] UTV mode: original time {time_str} -> adjusted time {utv_time} (+{time_offset} seconds)"
            )
            print(
                f"[DEBUG] UTV parameters: time_param='{time_param}', hash_param='{hash_param}'"
            )
        signed_key = generate_signature(
            build_sign_string(path, key, utv_time, sign_order), hash_type, key, verbose
        )
        params = urlencode({time_param: utv_time, hash_param: signed_key})
        return f"{scheme}://{host}{path}?{params}"
    else:
        raise ValueError("Invalid mode selected. Choose A, B, C, D, E, or UTV.")


MODE_TABLE = """\
Modes:
  A    /{time}/{hash}{path}
  B    /{hash}/{time}{path}
  C    {path}?key={hash}&time={time}                 (time offset applied)
  D    {path}?time={time}&key={hash}                 (time offset applied)
  E    {path}?auth_key={time}-{rand}-{uid}-{hash}     (fixed format)
  UTV  {path}?px-time={time}&px-hash={hash}           (time offset applied, param names configurable)

Examples:
  URLSigning.py -u https://cdn.example.com/video.mp4 -m C -k mysecretkey
  URLSigning.py -u https://cdn.example.com/video.mp4 -m UTV -k mysecretkey --sign-order kpt -v
  URLSigning.py -u https://cdn.example.com/video.mp4 -m C -k mysecretkey --time-offset 0

Full docs: https://github.com/grergea/scripts/tree/master/urlsigning
"""


class WideHelpFormatter(argparse.RawDescriptionHelpFormatter):
    def __init__(self, prog):
        super().__init__(prog, max_help_position=32, width=100)


def main():
    parser = argparse.ArgumentParser(
        prog="URLSigning.py",
        description="Generate a CDN signed URL using MD5 or SHA256.",
        epilog=MODE_TABLE,
        formatter_class=WideHelpFormatter,
    )

    required = parser.add_argument_group("required")
    required.add_argument(
        "-m",
        "--mode",
        choices=["A", "B", "C", "D", "E", "UTV"],
        metavar="MODE",
        required=True,
        help="signing mode: A, B, C, D, E, UTV (see Modes below)",
    )
    required.add_argument("-k", "--key", required=True, help="URL signing key")

    url_group = parser.add_argument_group("URL")
    url_group.add_argument(
        "-u",
        "--url",
        default=None,
        help="full URL to sign (parses scheme/host/path; overrides -s/-r/-p)",
    )
    url_group.add_argument(
        "-s",
        "--scheme",
        choices=["http", "https"],
        metavar="SCHEME",
        default="https",
        help="http or https (default: https)",
    )
    url_group.add_argument("-r", "--host", default=None, help="resource hostname")
    url_group.add_argument("-p", "--path", default=None, help="file path of resource")

    time_group = parser.add_argument_group("time & hash")
    time_group.add_argument(
        "-t",
        "--start_time",
        type=int,
        default=int(time.time()),
        help="starting time of the URL (Unix timestamp, default: now)",
    )
    time_group.add_argument(
        "--hex-time",
        action="store_true",
        help="convert start_time to hexadecimal format",
    )
    time_group.add_argument(
        "--hash",
        choices=["md5", "sha256"],
        metavar="ALGO",
        default="md5",
        help="md5 or sha256 (default: md5)",
    )
    time_group.add_argument(
        "--sign-order",
        default="pkt",
        metavar="ORDER",
        help="signing string token order for modes A/B/C/D/UTV: k(ey), p(ath), t(ime) "
        "(default: pkt = path+key+time, e.g. kpt = key+path+time)",
    )

    offset_group = parser.add_argument_group("time offset & UTV params (modes C/D/UTV)")
    offset_group.add_argument(
        "--time-offset",
        type=int,
        default=3600,
        metavar="SECONDS",
        help="offset in seconds added before signing, for modes C, D, UTV (default: 3600, 0 to disable)",
    )
    offset_group.add_argument(
        "--time-param",
        default="px-time",
        metavar="NAME",
        help="time parameter name for UTV mode (default: px-time)",
    )
    offset_group.add_argument(
        "--hash-param",
        default="px-hash",
        metavar="NAME",
        help="hash parameter name for UTV mode (default: px-hash)",
    )

    mode_e_group = parser.add_argument_group("mode E")
    mode_e_group.add_argument(
        "--uid", default=None, help="custom UID (overrides --uid-type)"
    )
    mode_e_group.add_argument(
        "--uid-type",
        choices=["mac", "random", "zero", "hostname"],
        metavar="TYPE",
        default="mac",
        help="mac, random, zero, or hostname (default: mac)",
    )

    debug_group = parser.add_argument_group("debug")
    debug_group.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="enable debug output (keys are masked)",
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
        args.time_offset,
        args.time_param,
        args.hash_param,
        args.uid,
        args.uid_type,
        args.sign_order,
        args.verbose,
    )
    print("Signed URL:", signed_url)


if __name__ == "__main__":
    main()
