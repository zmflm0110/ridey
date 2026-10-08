-- 실시간 보정 층 (자동 생성: tools/retrain.py --deploy). supabase/live.sql 다음에 적용.
-- logit(q) = a + b·logit(p) + c·[연쇄 3명+], 화면의 확률·순서에만 (최소 M대 90% 보장은 원래 확률로). 아직 기준을 넘지 않아 그대로(p) — 2026-10-08 시험: 로그 손실 −1.1~−1.8% (기준 −2%).
create or replace function live.p_cal(p float8, chain float8) returns float8 language sql immutable as 'select p';
