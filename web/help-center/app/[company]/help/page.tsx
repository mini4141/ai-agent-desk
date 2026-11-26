import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChatWidget } from "@/components/ChatWidget";
import { listArticles } from "@/lib/api";

type Props = { params: Promise<{ company: string }>; searchParams: Promise<{ q?: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { company } = await params;
  const data = await listArticles(company);
  if (!data) return {};
  const ja = data.company.locale === "ja";
  return {
    title: ja ? `${data.company.name} ヘルプセンター` : `${data.company.name} Help Center`,
    description: ja ? `${data.company.name}のよくあるご質問・サポート情報` : `Answers to common questions about ${data.company.name}`,
    openGraph: { title: `${data.company.name} Help` },
  };
}

export default async function HelpCenter({ params, searchParams }: Props) {
  const { company } = await params;
  const { q } = await searchParams;
  const data = await listArticles(company, q);
  if (!data) notFound();
  const ja = data.company.locale === "ja";

  return (
    <>
      <header className="site">
        <div className="inner">
          <h1>{ja ? `${data.company.name} ヘルプセンター` : `${data.company.name} Help Center`}</h1>
          <form className="search" action={`/${company}/help`}>
            <input name="q" defaultValue={q} placeholder={ja ? "キーワードで検索" : "Search articles"} />
            <button type="submit">{ja ? "検索" : "Search"}</button>
          </form>
        </div>
      </header>
      <div className="page" lang={data.company.locale}>
        <ul className="articles">
          {data.articles.map((a) => (
            <li key={a.id}>
              <Link href={`/${company}/help/${a.id}`}>{a.title}</Link>
              <p>{a.excerpt}</p>
            </li>
          ))}
        </ul>
        {data.articles.length === 0 && <p>{ja ? "該当する記事はありません。" : "No matching articles."}</p>}
      </div>
      <ChatWidget publicKey={data.company.public_key} />
    </>
  );
}
