export function Placeholder({ title, detail }: { title: string; detail: string }) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{detail}</p>
    </section>
  );
}
