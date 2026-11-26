import Link from "next/link";

export default function Home() {
  return (
    <div className="page">
      <h1>Help centers</h1>
      <ul className="articles">
        <li><Link href="/mirai/help">ミライ電機 ヘルプセンター</Link></li>
        <li><Link href="/harbor/help">Harbor Outdoor Help Center</Link></li>
      </ul>
    </div>
  );
}
