import { NavLink, Navigate, Route, Routes } from "react-router-dom";
import { isAdmin, useAuth } from "./auth";
import { useI18n } from "./i18n";
import { ConversationView } from "./pages/ConversationView";
import { Inbox } from "./pages/Inbox";
import { Knowledge } from "./pages/Knowledge";
import { Latency } from "./pages/Latency";
import { Login } from "./pages/Login";
import { Metrics } from "./pages/Metrics";
import { Settings } from "./pages/Settings";
import { Tools } from "./pages/Tools";

export function App() {
  const { user, logout } = useAuth();
  const { t, lang, setLang } = useI18n();
  if (!user) return <Login />;
  const admin = isAdmin(user);
  return (
    <div className="shell">
      <aside>
        <h1>AI Agent Desk</h1>
        <nav>
          <NavLink to="/inbox">{t("inbox")}</NavLink>
          <NavLink to="/knowledge">{t("knowledge")}</NavLink>
          {admin && <NavLink to="/tools">{t("tools")}</NavLink>}
          {admin && <NavLink to="/latency">{t("latency")}</NavLink>}
          {admin && <NavLink to="/metrics">{t("metrics")}</NavLink>}
          {admin && <NavLink to="/settings">{t("settings")}</NavLink>}
        </nav>
        <div className="who">
          <div data-testid="whoami">{user.name} · {user.role}</div>
          <button onClick={() => setLang(lang === "ja" ? "en" : "ja")}>{lang === "ja" ? "EN" : "日本語"}</button>
          <button onClick={logout}>{t("signOut")}</button>
        </div>
      </aside>
      <main>
        <Routes>
          <Route path="/" element={<Navigate to="/inbox" replace />} />
          <Route path="/inbox" element={<Inbox />} />
          <Route path="/inbox/:id" element={<ConversationView />} />
          <Route path="/knowledge" element={<Knowledge />} />
          <Route path="/tools" element={<Tools />} />
          <Route path="/latency" element={<Latency />} />
          <Route path="/metrics" element={<Metrics />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </main>
    </div>
  );
}
