import { FieldDesk } from "@/app/components/field-desk";
import { loadWorkBikes } from "@/lib/ops-data";

export default async function Page() {
  let bikes: Awaited<ReturnType<typeof loadWorkBikes>>["bikes"] = [];
  let problem: string | null = null;
  try {
    bikes = (await loadWorkBikes({})).bikes;
  } catch {
    problem = "의심 자전거 목록을 읽지 못했어요. 번호는 직접 적을 수 있어요.";
  }
  return (
    <section className="stack">
      <h1>현장</h1>
      <p>대여소에 서 있는 자전거를 보고 판정해요. 인터넷이 끊겨도 누른 시각 그대로 이 브라우저에 남았다가 다시 보내요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      <FieldDesk bikes={bikes} />
    </section>
  );
}
