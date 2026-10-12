# ssl-pfx2pem

PFX(PKCS#12) 인증서 번들을 PEM 인증서, 개인키, 체인 파일로 분리하는 스크립트. bash와 zsh 모두에서 동작한다.

## 요구사항

- openssl (3.x 권장, LibreSSL도 동작)

## 사용법

```
ssl_pfx2pem.sh <파일명>.pfx
```

실행하면 PFX 비밀번호를 묻는다. `PFXPASS` 환경변수가 설정되어 있으면 프롬프트를 건너뛴다.

```bash
ssl_pfx2pem.sh example.com.pfx
# PFX Import Password:
# example.com_cert.pem   인증서
# example.com_key.pem    개인키 (암호화 없음, 권한 600)
# example.com_chain.pem  체인 (PFX에 CA 인증서가 있을 때만 생성)
```

출력 파일은 입력 PFX와 같은 디렉터리에 만들어진다.

## 동작

- 출력 파일 3종 중 하나라도 이미 있으면 덮어쓰지 않고 중단한다.
- OpenSSL 3.x 기본 provider가 열지 못하는 구형 암호화(RC2-40-CBC, 3DES) PFX는 `-legacy`로 자동 재시도한다.
- 비밀번호가 틀리면 중간 산출물을 지우고 종료 코드 1로 끝난다.
- 개인키는 `umask 077`로 생성하며 암호화하지 않으므로 사용 후 안전하게 보관하거나 삭제한다.
