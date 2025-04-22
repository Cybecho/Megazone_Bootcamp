# 온프레미스 3티어 구축

### 시나리오 기반 프로젝트 설명: 1티어 과부하 해결 및 3티어 아키텍처 구축

> 상황: 기존 1티어 아키텍처에서 애플리케이션 서버 과부하 발생, 서비스 응답 지연 및 장애 발생 가능성 증가. 특히 트래픽이 몰리는 특정 시간대에 문제가 심각해지는 상황.

> 목표:
>
> 애플리케이션 서버(WAS)를 이중화하여 트래픽 부하를 분산시키고 안정성을 확보.
> 
> 향후 웹 서버(Web)의 확장을 고려하여 WAS 앞단에 로드 밸런서(LB)를 도입, 확장성을 확보.
> 
> 데이터베이스(DB) 서버를 분리하여 전체 시스템의 성능 및 안정성 향상.
> 
> CI/CD 파이프라인을 구축하여 애플리케이션 배포 자동화 및 신속한 문제 해결 지원.

> 구현:
> 
> 3티어 아키텍처 구축: Web(Nginx LB) - WAS(Apache+PHP 이중화) - DB(MariaDB) 분리 구축.
> 
> WAS 이중화: Apache+PHP로 구성된 WAS 서버를 2대로 구성, 트래픽 분산 및 고가용성 확보. Redis를 활용하여 WAS 서버 간 세션 공유 구현.
> 
> 로드 밸런서 도입: Nginx를 LB로 사용하여 WAS 서버에 트래픽을 분산, 향후 Web 서버 확장 용이하도록 설계.
> 
> Vagrant를 활용한 VM 자동화: 전체 인프라 환경 구성을 Vagrant를 통해 자동화, 환경 일관성 확보 및 구축 시간 단축.
> 
> CI/CD 파이프라인 구축: Jenkins와 Docker를 활용하여 애플리케이션 빌드, 테스트, 배포 과정을 자동화.
> 
> 통합 SSH 터널링 툴 개발: Bastion Host를 통한 안전한 서버 접근 환경 구축 및 관리 편의성 증대.

> 해결:
> 
> 기존 1티어 환경에서 발생하던 애플리케이션 서버 과부하 문제를 WAS 이중화 및 로드 밸런서 도입을 통해 해결했습니다. DB 서버 분리를 통해 데이터 처리 성능을 향상시키고, CI/CD 파이프라인 구축을 통해 애플리케이션 배포 속도를 높였습니다. 또한, 통합 SSH 터널링 툴 개발로 서버 접근 및 관리 편의성을 높여 운영 효율성을 개선했습니다.

### 작동 방식 요약
```
WEB 서버 (프론트엔드): 192.168.1.10
→ Apache2 컨테이너가 실행되며, WAS 서버로 요청을 프록시합니다.
WAS 1 서버: 192.168.2.10
→ PHP/Apache 기반 WAS 컨테이너가 실행되고, DB 연결 시 192.168.3.10을 사용하며, Redis 세션은 192.168.1.10의 Redis 서버를 참조합니다.
WAS 2 서버: 192.168.2.20
→ WAS 1과 동일한 설정으로, 부하분산을 위해 추가 배치합니다.
DB 서버: 192.168.3.10
→ MariaDB 컨테이너가 실행되며, 데이터는 호스트에 바인드 마운트됩니다.
```

#### 물리 구성도
![물리 구성도](https://github.com/Cybecho/Megazone_Bootcamp/blob/main/on_premises_3tier_project/4%EC%B0%A8%20%EC%A0%9C%EC%95%88%EC%84%9C%20%EA%B0%9C%EC%9D%B8%20%EB%AC%BC%EB%A6%AC%EA%B5%AC%EC%84%B1%EB%8F%84.png?raw=true)

#### 논리 구성도
![논리 구성도](https://github.com/Cybecho/Megazone_Bootcamp/blob/main/on_premises_3tier_project/4%EC%B0%A8%20%EC%A0%9C%EC%95%88%EC%84%9C%20%EA%B0%9C%EC%9D%B8%20%EB%85%BC%EB%A6%AC%EA%B5%AC%EC%84%B1%EB%8F%84.png?raw=true)

#### CI/CD 논리 구성도
![CICD 논리 구성도](https://github.com/Cybecho/Megazone_Bootcamp/blob/main/on_premises_3tier_project/4%EC%B0%A8%20%EC%A0%9C%EC%95%88%EC%84%9C%20%EA%B0%9C%EC%9D%B8%20%EB%85%BC%EB%A6%AC%EA%B5%AC%EC%84%B1%EB%8F%84%20CICD.png?raw=true)


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

CI/CD 는 완전히 자동화되지 않았습니다!

[해당 가이드](https://github.com/Cybecho/Megazone_Bootcamp/blob/main/1%EC%B0%A8%20%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8%20%EA%B0%80%EC%9D%B4%EB%93%9C.md)를 따라 WAS 1 & 2 부분에 컨테이너 감지 데몬을 설정해주어야하고

CI/CD 서버 설정도 수동으로 설정해줘야합니다.

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
