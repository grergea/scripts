# sslyze-map

sslyze 결과의 cipher suite를 IANA 표기 / OpenSSL 축약 표기 중 원하는 쪽으로 출력하는 래퍼.

## 배경

sslyze의 사람이 읽는 출력은 IANA 표기(`TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`)로 고정되어 있고 이를 바꾸는 옵션이 없다. 서버 설정 파일은 OpenSSL 축약 표기(`ECDHE-RSA-AES256-GCM-SHA384`)를 쓰기 때문에 설정과 결과를 대조할 때 매번 손으로 변환해야 한다.

sslyze의 JSON 결과에는 `name`(IANA)과 `openssl_name`(축약)이 모두 들어 있으므로, 이 래퍼는 JSON을 받아 원하는 표기만 출력한다.

## 요구사항

- [sslyze](https://github.com/nabla-c0d3/sslyze) (`pipx install sslyze`)
- jq

## 사용법

```
sslyze-map.sh [--mapping both|iana|openssl] <sslyze 옵션/대상...>
```

| 옵션 | 동작 |
|------|------|
| `--mapping both` | OpenSSL 축약 표기와 IANA 표기를 함께 출력 (기본값) |
| `--mapping openssl` | OpenSSL 축약 표기만 출력 |
| `--mapping iana` | IANA 표기만 출력 |

`--mapping` 외의 인자는 sslyze로 그대로 전달된다. 버전 플래그를 하나 이상 지정해야 cipher가 열거되며, `--mozilla_config disable`과 `--json_out -`는 자동으로 붙는다.

```bash
# 전 버전 점검
bash sslyze-map.sh --sslv2 --sslv3 --tlsv1 --tlsv1_1 --tlsv1_2 --tlsv1_3 www.example.com

# 서버 설정과 대조 (OpenSSL 표기만)
bash sslyze-map.sh --mapping openssl --tlsv1_2 --tlsv1_3 www.example.com

# CDN 엣지 IP 지정, 여러 엣지 동시 비교
bash sslyze-map.sh --mapping openssl --tlsv1_2 --tlsv1_3 \
  "img.example.com:443{61.110.192.38}" "img.example.com:443{14.0.115.251}"
```

## 출력 예시

```
$ bash sslyze-map.sh --sslv2 --tlsv1_2 --tlsv1_3 example.com

[example.com:443 -> 104.20.23.154]

SSL 2.0  (7개 시도, 전부 거부)

TLS 1.2  (156개 시도, 2개 수락)
  256  ECDHE-RSA-AES256-GCM-SHA384     TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  128  ECDHE-RSA-AES128-GCM-SHA256     TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

TLS 1.3  (5개 시도, 3개 수락)
  256  TLS_CHACHA20_POLY1305_SHA256    TLS_CHACHA20_POLY1305_SHA256
  256  TLS_AES_256_GCM_SHA384          TLS_AES_256_GCM_SHA384
  128  TLS_AES_128_GCM_SHA256          TLS_AES_128_GCM_SHA256
```

시도 개수는 sslyze가 가진 전체 목록 기준이며 서버 설정과 무관하다. TLS 1.2는 156개, TLS 1.3은 정의된 5개 전부, SSL 2.0은 7개를 시도한다.

TLS 1.3 스위트는 두 표기가 동일하므로 `both` 모드에서 같은 이름이 두 번 나오는 것이 정상이다. 표기가 갈리는 것은 TLS 1.2 이하뿐이다.

지원하지 않는 버전은 `전부 거부`로 표시된다. TLS 1.0/1.1 비활성화 작업의 검증 근거로 사용할 수 있다.
