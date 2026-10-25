# RIDEY Operations

직원이 고장 의심 따릉이를 보고, 순서를 정하고, 현장에서 판정하는 화면이다. 이용자 앱은 [`app/`](../app/README.md)에 있다.

로그인하지 않으면 어떤 운영 경로도 열리지 않는다. 명단에 없거나 꺼진 계정은 `/forbidden`으로 간다. 데이터베이스의 RLS가 한 번 더 막는다. 이 앱에는 secret 키를 넣지 않는다.

## 실행

```sh
cd dashboard
cp .env.example .env.local
# NEXT_PUBLIC_SUPABASE_URL 과 NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY 만 채운다.
npm ci
npm run dev
```

`npm run lint`, `npm run typecheck`, `npm test`, `npm run build` 다음에 `npx playwright test`를 돌린다.

### 둘러보기 (심사·시연용, 읽기 전용)

```sh
RIDEY_DEMO=1 npm run dev      # 또는 배포 환경 변수에 RIDEY_DEMO=1
```

로그인 없이 운영 화면이 열린다. publishable 키로 읽으므로 보이는 것은 RLS 가 이미 공개한 뷰(실시간·아침 목록·채점)뿐이다. 사람 확인·점검 기록처럼 직원만 읽는 자료는 그 칸만 비고(`–`), `/records` 는 설명만 보인다. `/field` 의 판정 버튼은 눌러도 저장하지 않는다. 실제 운영 배포에는 넣지 않는다. 배포는 아직 하지 않는다. Vercel에 올릴 때는 환경 변수 두 개만 넣고, 아래 인증 설정을 먼저 끝낸다.

우선순위와 경로는 `web/app.js`, `web/route.js`와 같은 계산이다. 대여소는 `data/stations.json`, 경로 값은 `data/route_value.json`, 시간대별 대여는 `data/busy.json`(live-data 가지의 `data/ops/busy.json`)이다.

## 화면

| 경로 | 내용 |
|---|---|
| `/overview` | 의심 대수, 강한 경보, 오늘 경보, 모델 기대값과 하한, 자료 지연, 채점 막대 |
| `/priority` | 대여소·자전거 표, 구·등급 필터, 비교, 판단 근거, 지도 |
| `/districts` | 구별 대수, 강한 경보, 기대값, 점검 수 |
| `/route` | 60·90·180분 또는 직접 입력. 현재 위치, 대여소, 상암센터. 순위 비교, 인쇄, CSV |
| `/field` | 대여소의 의심 자전거, 판정 6종, 메모, 1280px JPEG. 오프라인 대기열은 누른 시각을 유지 |
| `/records` | 최근 점검 기록, 사진 서명 주소, CSV |
| `/lists` | 날짜별 아침 목록, 채점, 웹과 같은 아침 CSV |
| `/staff` | 관리자·개발자만. 활성 전환. 계정 초대는 Supabase에서 |

낮 12시 전에는 오늘 아침 목록, 그 뒤에는 실시간 목록이 기본이다. 담당 구는 `ops.staff.districts`에서 온다. 개발자는 구 제한이 없다.

## Supabase Auth 설정

클라우드에 올리기 전에 대시보드에서 직접 한다.

1. Authentication → Providers → Email 에서 회원가입을 끈다. 계정은 Authentication → Users → Invite user 로만 만든다.
2. Authentication → URL Configuration. Site URL은 운영 주소(로컬은 `http://localhost:3000`). Redirect URLs에 그 주소와 `http://localhost:3000/**`를 넣는다.
3. Authentication → Email Templates 에서 초대 메일의 링크가 위 Site URL로 돌아오게 확인한다. 비밀번호를 잊으면 같은 화면의 복구 메일을 쓴다. 개발자 계정이 잠기면 이 앱이 아니라 데이터베이스 비밀번호로 psql에서 `ops.staff`를 고친다. developer 행은 화면에서 끌 수 없다.
4. 초대한 이메일을 먼저 명단에 넣는다. `supabase/staff_seed.example.sql`을 `psql -v developer_email=you@example.com`으로 적용한다. 실제 이메일은 저장소에 커밋하지 않는다.
5. SQL은 `schema.sql` → `staff.sql` → `model.sql` → `live.sql` → `ev.sql` → `calib.sql` 순서로, psql로 직접 적용한다.
6. 앱 환경 변수는 `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` 뿐이다. service role 키는 저장소와 배포 환경 어디에도 넣지 않는다.

적용 뒤에는 익명 키로 `rescue`·`survey` 쓰기와 `checked` 읽기가 거부되는지, 공개 뷰 네 개는 계속 읽히는지 확인한다.
