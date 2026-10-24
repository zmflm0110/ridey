import { ListSourceForm } from "@/app/components/list-source-form";
import { RoutePlanner } from "@/app/components/route-planner";
import { requireStaff } from "@/lib/auth/requireStaff";
import { loadWorkBikes } from "@/lib/ops-data";

export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ source?: string; day?: string }>;
}) {
  const profile = await requireStaff();
  const query = await searchParams;
  let problem: string | null = null;
  let work: Awaited<ReturnType<typeof loadWorkBikes>> | null = null;
  try {
    work = await loadWorkBikes(query);
  } catch {
    problem = "경로에 쓸 목록을 읽지 못했어요.";
  }
  return (
    <section className="stack">
      <h1>경로</h1>
      <p>남은 근무 시간 안에 막을 헛걸음이 가장 많은 대여소 순서예요. 순위대로 가장 짧게 도는 경우와 비교해요.</p>
      {problem ? <p role="alert">{problem}</p> : null}
      {work ? (
        <>
          <div className="print-hide">
            <ListSourceForm source={work.source} day={work.day} days={work.days} />
          </div>
          <RoutePlanner bikes={work.bikes} districts={profile.districts} source={work.source} day={work.day} />
        </>
      ) : null}
    </section>
  );
}
