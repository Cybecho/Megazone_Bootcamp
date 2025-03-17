# 온프레미스 3티어 구축

WEB 서버 (프론트엔드): 192.168.1.10
→ Apache2 컨테이너가 실행되며, WAS 서버로 요청을 프록시합니다.
WAS 1 서버: 192.168.2.10
→ PHP/Apache 기반 WAS 컨테이너가 실행되고, DB 연결 시 192.168.3.10을 사용하며, Redis 세션은 192.168.1.10의 Redis 서버를 참조합니다.
WAS 2 서버: 192.168.2.20
→ WAS 1과 동일한 설정으로, 부하분산을 위해 추가 배치합니다.
DB 서버: 192.168.3.10
→ MariaDB 컨테이너가 실행되며, 데이터는 호스트에 바인드 마운트됩니다.

## 사용법

> 그냥 `Vagrant up` 해주면 됩니다

---

### WEB 서버 설정


**설치 명령:**  
```bash
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/main/on_premises_3tier_project/config_server_web.sh | sudo bash
```

> 이 스크립트에서는 Apache2 Dockerfile 내 BalancerMember 설정을 통해 WAS 서버(192.168.2.10, 192.168.2.20)로 트래픽을 프록시하도록 구성되어 있습니다.

---

### WAS 1 서버 설정


**설치 명령:**  
```bash
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/main/on_premises_3tier_project/config_server_was1.sh | sudo bash
```

> 이 스크립트에서는 PHP 웹 소스(index.php) 내에서 DB 연결(host=192.168.3.10) 및 Redis 세션 저장 경로(tcp://192.168.1.10:6379?auth=root)를 설정하여, WAS 1 서버로서의 역할을 수행합니다.

---

### WAS 2 서버 설정

**설치 명령:**  
```bash
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/main/on_premises_3tier_project/config_server_was2.sh | sudo bash
```

> WAS 2도 WAS 1과 동일한 구성을 사용하며, 부하분산 환경에서 함께 동작합니다.

---

### DB 서버 설정


**설치 명령:**  
```bash
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/main/on_premises_3tier_project/config_server_db.sh | sudo bash
```

> 이 스크립트에서는 MariaDB 컨테이너를 실행하며, 초기화 SQL과 호스트 바인드 마운트(/root/docker/volumes)를 통해 데이터가 192.168.3.10에서 안전하게 저장되도록 설정합니다.

---

### CI/CD 서버 설정

**설치 명령:**  
```bash
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/refs/heads/main/on_premises_3tier_project/config_server_cicd.sh | sudo bash
```

> 위 스크립트는 CI/CD 환경 구축에 필요한 기본 설정을 진행하며, Jenkins 서버가 Docker 명령어를 실행할 수 있도록 Docker 그룹 권한 부여, 워크스페이스 구성, Docker Registry 실행 등과 같은 작업을 자동으로 처리합니다.

---

### 요약

각 서버는 아래와 같이 구성됩니다:

- **WEB (192.168.1.10):** Apache2 컨테이너 (WAS 서버로 프록시)
- **WAS 1 (192.168.2.10) & WAS 2 (192.168.2.20):** PHP/Apache WAS 컨테이너 (DB 연결: 192.168.3.10, Redis 세션: 192.168.1.10)
- **DB (192.168.3.10):** MariaDB 컨테이너

제공된 각 URL의 스크립트를 해당 서버에서 실행하면, curl 명령어 한 줄로 자동 설치가 진행됩니다. 이를 통해 온프레미스 환경에서 3티어 아키텍처가 자동으로 설정됩니다.

### 도커 재설치

```
curl -fsSL https://raw.githubusercontent.com/Cybecho/Megazone_Bootcamp/main/on_premises_3tier_project/reinstall_docker.sh | sudo bash
```