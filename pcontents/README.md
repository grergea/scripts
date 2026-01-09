# pcontents - Parallel Contents Checker

여러 CDN 노드에 병렬로 요청을 보내 콘텐츠 일관성을 검증하는 스크립트입니다.

## 목적

하나의 URL에 대해 여러 CDN 노드(서버)로 동시에 요청을 보내고, 각 노드의 응답(HTTP 헤더, 콘텐츠 MD5 등)을 비교하여 일관성 문제를 진단합니다. 캐시 서버별로 콘텐츠가 다른 경우나 특정 노드에서만 오류가 발생하는 경우를 신속하게 파악할 수 있습니다.

## 주요 기능

- **병렬 요청**: GNU Parallel을 사용하여 지정된 모든 노드에 동시에 curl 요청
- **상세 정보 비교**: HTTP 응답 코드, 서버 IP, Content-Type, Last-Modified, Cache-Control, MD5 등
- **색상 표시**: 응답 코드와 다운로드 시간에 색상 적용으로 문제 직관적 인지
- **유연한 옵션**: 노드 목록 지정, 커스텀 헤더, 병렬 작업 수 조절

## 의존성

```bash
curl parallel md5sum column awk
```

## 사용법

```bash
# 기본 노드 목록으로 URL 검사
./pcontents.sh -o https://www.example.com/image.jpg

# 특정 노드들만 지정하여 검사
./pcontents.sh -l "1.1.1.1, 8.8.8.8" https://www.example.com/

# 커스텀 헤더와 함께 5개 병렬 작업으로 실행
./pcontents.sh -H "Host: assets.example.com" -P 5 -l "1.1.1.1" https://www.example.com/
```

## 옵션

| 옵션 | 설명 |
|------|------|
| `-o` | 기본 노드 목록 사용 |
| `-l <nodes>` | 검사할 노드 목록 지정 (쉼표 또는 공백 구분) |
| `-H <header>` | 커스텀 헤더 추가 (예: "Host: example.com") |
| `-P <jobs>` | 병렬 작업 수 (기본값: 3) |

## 출력 결과

| 컬럼 | 설명 |
|------|------|
| **CODE** | HTTP 응답 코드 (200/206 외 빨간색) |
| **Remote_IP** | 응답 서버 IP |
| **Version** | HTTP 버전 (H/1.1, H/2.0) |
| **Content-Type** | 콘텐츠 MIME 타입 |
| **Last-Modified** | 마지막 수정 시각 |
| **Cache-Control** | 캐시 제어 지시자 |
| **DL_Size** | 다운로드 크기 (바이트) |
| **DL_Time** | 다운로드 시간 (초, 임계값 초과 시 색상 표시) |
| **X-Px** | 캐시 HIT/MISS 헤더 |
| **Server** | 응답 서버 정보 |
| **MD5** | 콘텐츠 MD5 체크섬 (노드 간 동일해야 함) |

## 색상 기준

- **응답 코드**: 200/206 = 초록, 그 외 = 빨강
- **다운로드 시간**: 3초 이상 = 노랑, 10초 이상 = 빨강

## License

MIT License
