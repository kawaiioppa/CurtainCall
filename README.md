# CurtainCall

## 프로젝트 소개

**공연이 끝나도, 이야기는 계속돼요.**

CurtainCall은 공연을 본 사람들이 감상과 여운을 함께 나누는 공간을 목표로 개발 중인 iOS 앱입니다. 이메일 인증과 공연 탐색을 구현하고 있으며, 회차별 방과 채팅을 순서대로 연결하고 있습니다.

## 주요 기능

- **이메일 회원가입**: 이메일, 비밀번호, 닉네임을 입력해 가입하고 입력값을 검증합니다.
- **이메일 인증**: 인증 링크를 통해 이메일을 확인하며, 인증 메일 재전송과 대기 시간을 안내합니다.
- **로그인 및 로그아웃**: 이메일과 비밀번호로 로그인하고 현재 기기에서 로그아웃합니다.
- **인증 상태에 따른 화면 전환**: 세션 복원 중에는 로딩 화면을, 인증 여부에 따라 로그인 화면 또는 홈 화면을 표시합니다.
- **공연 탐색**: Supabase에 저장된 공연을 검색하고 지역·관람 날짜로 필터링합니다. 목록은 20개씩 조회하며 새로고침과 오류 재시도를 지원합니다.
- **공연 상세·회차 선택**: 포스터·장소·기간과 등록된 회차를 표시합니다. 회차 시간은 한국 시간으로 표시하며 종료 시간이 없으면 미정으로 안내합니다.

Apple·Google 로그인은 연동 코드가 준비되어 있으나 현재 버튼은 비활성화되어 있습니다. 채팅 기능은 아직 구현되지 않았습니다.

공연 목록은 실제 데이터베이스를 조회합니다. KOPIS 수집 연결 전이거나 운영자가 공연·회차를 등록하지 않았다면 빈 목록이 표시됩니다. 샘플 공연을 실제 데이터로 넣지 않습니다.

## 개발 및 검증

`supabase/migrations`는 실제 Postgres 스키마의 기준입니다. 공연·회차는 공개 조회를 허용하고, 일반 앱 사용자의 생성·수정·삭제는 차단합니다. 서버 또는 운영자가 데이터를 관리합니다. 이전 Spring/MySQL 문서는 현재 iOS 데이터 계약이 아닙니다.

```sh
xcodebuild test -project CurtainCall.xcodeproj -scheme CurtainCall \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:CurtainCallTests
```

2026-09-13: 인증·공연 검색 단위 테스트 9개 통과. `supabase/tests/catalogue_access.sql`을 실제 DB에서 실행해 익명 조회 및 일반 사용자 수정 차단을 확인했습니다. SQL 테스트 데이터는 트랜잭션 종료 시 롤백합니다. 전체 방·채팅 및 화면 자동화 검증은 진행 중입니다.

## 기술 스택

| 구분 | 기술 |
| --- | --- |
| 플랫폼 | iOS |
| 언어 | Swift |
| UI | SwiftUI |
| 상태 관리 | Observation (`@Observable`), SwiftUI `@State` |
| 비동기 처리 | Swift Concurrency (`async/await`) |
| 인증 | Supabase Auth, supabase-swift 2.55.2 |
| 의존성 관리 | Swift Package Manager |
| 테스트 | Swift Testing, XCTest · XCUITest |
| 개발 도구 | Xcode |
