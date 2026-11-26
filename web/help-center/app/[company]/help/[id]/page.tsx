import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChatWidget } from "@/components/ChatWidget";
import { getArticle } from "@/lib/api";

type Props = { params: Promise<{ company: string; id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { company, id } = await params;
  const data = await getArticle(company, id);
  if (!data) return {};
  const first = data.article.sections[0];
  return {
    title: `${data.article.title} | ${data.company.name}`,
    description: first ? `${first[0]} ${first[1] ?? ""}`.slice(0, 150) : undefined,
    alternates: { canonical: `/${company}/help/${id}` },
  };
}

export default async function ArticlePage({ params }: Props) {
  const { company, id } = await params;
  const data = await getArticle(company, id);
  if (!data) notFound();
  const ja = data.company.locale === "ja";

  return (
    <div className="page" lang={data.company.locale}>
      <Link className="back" href={`/${company}/help`}>← {ja ? "ヘルプセンターへ戻る" : "Back to help center"}</Link>
      <article>
        <h1>{data.article.title}</h1>
        {data.article.sections.map(([question, answer], i) => (
          <section key={i}>
            <h2>{question}</h2>
            {answer && <p>{answer}</p>}
          </section>
        ))}
      </article>
      <ChatWidget publicKey={data.company.public_key} />
    </div>
  );
}
