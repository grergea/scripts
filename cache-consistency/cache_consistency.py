#!/usr/bin/env python3
"""
CDN 캐시 정합성 점검 스크립트
S3 오리진과 CDN 엣지 캐시 간의 객체 일치 여부를 검증합니다.
"""

import argparse
import hashlib
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse, urljoin
from typing import Dict, List, Tuple, Optional
import requests
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

# ANSI 색상 코드
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
RESET = '\033[0m'


class CacheConsistencyChecker:
    def __init__(self, args):
        self.bucket = args.bucket
        self.endpoint = args.endpoint
        self.region = args.region
        self.prefix = args.prefix
        self.origin = args.origin
        self.origin_host = args.origin_host or urlparse(args.origin).hostname
        self.cdn = args.cdn
        self.workers = args.workers
        self.output = args.output
        self.timeout = args.timeout
        self.md5_check = args.md5

        # S3 클라이언트 초기화
        try:
            self.s3_client = boto3.client(
                's3',
                endpoint_url=self.endpoint,
                region_name=self.region
            )
        except NoCredentialsError:
            print(f"{RED}[ERROR]{RESET} AWS 인증 정보가 설정되지 않았습니다.")
            print("환경변수를 설정하세요:")
            print("  export AWS_ACCESS_KEY_ID='your-access-key'")
            print("  export AWS_SECRET_ACCESS_KEY='your-secret-key'")
            sys.exit(1)

    def list_objects(self) -> List[str]:
        """S3 버킷에서 객체 목록을 조회합니다."""
        print(f"[INFO] S3 버킷 '{self.bucket}' 에서 객체 조회 중...")

        try:
            paginator = self.s3_client.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=self.bucket, Prefix=self.prefix)

            objects = []
            for page in pages:
                if 'Contents' in page:
                    for obj in page['Contents']:
                        objects.append(obj['Key'])

            print(f"[INFO] {len(objects)}개 객체 발견")
            return objects

        except ClientError as e:
            print(f"{RED}[ERROR]{RESET} S3 객체 조회 실패: {e}")
            sys.exit(1)

    def fetch_headers(self, url: str, host: Optional[str] = None) -> Dict:
        """HTTP HEAD 요청으로 메타데이터를 가져옵니다."""
        try:
            headers = {}
            if host:
                headers['Host'] = host

            response = requests.head(url, headers=headers, timeout=self.timeout, allow_redirects=True)

            return {
                'status': response.status_code,
                'content_length': response.headers.get('Content-Length', 'N/A'),
                'last_modified': response.headers.get('Last-Modified', 'N/A'),
                'etag': response.headers.get('ETag', 'N/A').strip('"')
            }
        except requests.RequestException as e:
            return {
                'status': 'ERROR',
                'error': str(e),
                'content_length': 'N/A',
                'last_modified': 'N/A',
                'etag': 'N/A'
            }

    def fetch_md5(self, url: str, host: Optional[str] = None) -> str:
        """HTTP GET 요청으로 콘텐츠를 다운로드하고 MD5 해시를 계산합니다."""
        try:
            headers = {}
            if host:
                headers['Host'] = host

            response = requests.get(url, headers=headers, timeout=self.timeout, stream=True)

            if response.status_code != 200:
                return f"ERROR_{response.status_code}"

            md5_hash = hashlib.md5()
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    md5_hash.update(chunk)

            return md5_hash.hexdigest()

        except requests.RequestException as e:
            return f"ERROR_{str(e)[:20]}"

    def check_object(self, object_key: str) -> Dict:
        """단일 객체의 오리진과 CDN 정합성을 검사합니다."""
        # URL 구성
        origin_url = urljoin(self.origin + '/', object_key)
        cdn_url = urljoin(self.cdn + '/', object_key)

        # 헤더 정보 수집
        origin_meta = self.fetch_headers(origin_url, self.origin_host)
        cdn_meta = self.fetch_headers(cdn_url)

        result = {
            'file': object_key,
            'origin_cl': origin_meta['content_length'],
            'cdn_cl': cdn_meta['content_length'],
            'origin_lm': origin_meta['last_modified'],
            'cdn_lm': cdn_meta['last_modified'],
            'origin_status': origin_meta['status'],
            'cdn_status': cdn_meta['status']
        }

        # MD5 체크가 활성화된 경우
        if self.md5_check:
            if origin_meta['status'] == 200 and cdn_meta['status'] == 200:
                origin_md5 = self.fetch_md5(origin_url, self.origin_host)
                cdn_md5 = self.fetch_md5(cdn_url)
                result['origin_md5'] = origin_md5[:16] + '...' if len(origin_md5) > 16 else origin_md5
                result['cdn_md5'] = cdn_md5[:16] + '...' if len(cdn_md5) > 16 else cdn_md5
                result['status'] = 'MATCH' if origin_md5 == cdn_md5 else 'MISMATCH'
            else:
                result['origin_md5'] = 'N/A'
                result['cdn_md5'] = 'N/A'
                result['status'] = 'ERROR'
        else:
            # 헤더만 비교
            if origin_meta['status'] == 200 and cdn_meta['status'] == 200:
                if (origin_meta['content_length'] == cdn_meta['content_length'] and
                    origin_meta['last_modified'] == cdn_meta['last_modified']):
                    result['status'] = 'MATCH'
                else:
                    result['status'] = 'MISMATCH'
            else:
                result['status'] = 'ERROR'

        return result

    def run(self):
        """정합성 검사를 실행합니다."""
        objects = self.list_objects()

        if not objects:
            print(f"{YELLOW}[WARNING]{RESET} 검사할 객체가 없습니다.")
            return

        print(f"[INFO] 정합성 검사 진행중... ({self.workers} workers)")
        print()

        results = []

        # 병렬 처리
        with ThreadPoolExecutor(max_workers=self.workers) as executor:
            futures = {executor.submit(self.check_object, obj): obj for obj in objects}

            for future in as_completed(futures):
                result = future.result()
                results.append(result)

        # 결과 출력
        self.print_results(results)

        # CSV 출력 (옵션)
        if self.output:
            self.write_csv(results)

    def print_results(self, results: List[Dict]):
        """결과를 테이블 형태로 출력합니다."""
        # 헤더
        if self.md5_check:
            header = f"{'FILE':<40} | {'ORIGIN_CL':<10} | {'CDN_CL':<10} | {'ORIGIN_LM':<20} | {'CDN_LM':<20} | {'ORIGIN_MD5':<18} | {'CDN_MD5':<18} | STATUS"
        else:
            header = f"{'FILE':<40} | {'ORIGIN_CL':<10} | {'CDN_CL':<10} | {'ORIGIN_LM':<20} | {'CDN_LM':<20} | STATUS"

        print(header)
        print('-' * len(header))

        # 통계
        match_count = 0
        mismatch_count = 0
        error_count = 0

        for r in results:
            # 파일명 길이 제한 (표시용)
            file_display = r['file'][-38:] if len(r['file']) > 38 else r['file']

            # 상태별 색상
            status_colored = r['status']
            if r['status'] == 'MATCH':
                status_colored = f"{GREEN}✓ MATCH{RESET}"
                match_count += 1
            elif r['status'] == 'MISMATCH':
                status_colored = f"{RED}✗ MISMATCH{RESET}"
                mismatch_count += 1
            else:
                status_colored = f"{YELLOW}! ERROR{RESET}"
                error_count += 1

            if self.md5_check:
                print(f"{file_display:<40} | {str(r['origin_cl']):<10} | {str(r['cdn_cl']):<10} | {str(r['origin_lm']):<20} | {str(r['cdn_lm']):<20} | {r.get('origin_md5', 'N/A'):<18} | {r.get('cdn_md5', 'N/A'):<18} | {status_colored}")
            else:
                print(f"{file_display:<40} | {str(r['origin_cl']):<10} | {str(r['cdn_cl']):<10} | {str(r['origin_lm']):<20} | {str(r['cdn_lm']):<20} | {status_colored}")

        print()
        print(f"총 {len(results)}개 객체 | 일치: {match_count} | 불일치: {mismatch_count} | 오류: {error_count}")

    def write_csv(self, results: List[Dict]):
        """결과를 CSV 파일로 저장합니다."""
        import csv

        try:
            with open(self.output, 'w', newline='', encoding='utf-8') as f:
                if self.md5_check:
                    fieldnames = ['file', 'origin_cl', 'cdn_cl', 'origin_lm', 'cdn_lm', 'origin_md5', 'cdn_md5', 'status']
                else:
                    fieldnames = ['file', 'origin_cl', 'cdn_cl', 'origin_lm', 'cdn_lm', 'status']

                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()

                for r in results:
                    row = {k: r.get(k, 'N/A') for k in fieldnames}
                    writer.writerow(row)

            print(f"[INFO] 결과 저장됨: {self.output}")

        except Exception as e:
            print(f"{RED}[ERROR]{RESET} CSV 저장 실패: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='CDN 캐시 정합성 점검 도구 - S3 오리진과 CDN 엣지 캐시 간의 객체 일치 여부를 검증합니다.',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    # 필수 파라미터
    parser.add_argument('--bucket', required=True, help='S3 버킷명')
    parser.add_argument('--endpoint', required=True, help='S3 엔드포인트 URL (예: https://s3-jp-east-1.wcsapi.com)')
    parser.add_argument('--region', required=True, help='S3 리전 (예: jp-east-1)')
    parser.add_argument('--prefix', required=True, help='S3 디렉터리 경로 (prefix)')
    parser.add_argument('--origin', required=True, help='오리진 도메인 URL (예: http://bucket.wcscdn55.v1.wcsapi.com)')
    parser.add_argument('--cdn', required=True, help='CDN 서비스 도메인 URL (예: https://example.com)')

    # 선택 파라미터
    parser.add_argument('--origin-host', help='오리진 요청 시 Host 헤더 (기본값: origin URL에서 추출)')
    parser.add_argument('--workers', type=int, default=5, help='동시 요청 수 (기본값: 5)')
    parser.add_argument('--output', help='결과 CSV 파일 경로 (선택)')
    parser.add_argument('--timeout', type=int, default=10, help='HTTP 요청 타임아웃 초 (기본값: 10)')
    parser.add_argument('--md5', action='store_true', help='콘텐츠 다운로드 후 MD5 해시 비교 활성화 (기본: 헤더만 비교)')

    args = parser.parse_args()

    # 인증 정보 확인
    if not os.getenv('AWS_ACCESS_KEY_ID') or not os.getenv('AWS_SECRET_ACCESS_KEY'):
        print(f"{YELLOW}[WARNING]{RESET} AWS 인증 환경변수가 설정되지 않았을 수 있습니다.")
        print("필요 시 다음과 같이 설정하세요:")
        print("  export AWS_ACCESS_KEY_ID='your-access-key'")
        print("  export AWS_SECRET_ACCESS_KEY='your-secret-key'")
        print()

    checker = CacheConsistencyChecker(args)
    checker.run()


if __name__ == '__main__':
    main()
