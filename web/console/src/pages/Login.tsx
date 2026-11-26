import { useState, type FormEvent } from "react";
import { useAuth } from "../auth";
import { useI18n } from "../i18n";

export function Login() {
  const { login } = useAuth();
  const { t, lang, setLang } = useI18n();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      await login(email, password);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  return (
    <form className="login" onSubmit={submit}>
      <h1>AI Agent Desk</h1>
      <label>{t("email")}<input data-testid="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" /></label>
      <label>{t("password")}<input data-testid="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" /></label>
      {error && <p className="error">{error}</p>}
      <button type="submit" data-testid="signin">{t("signIn")}</button>
      <button type="button" className="link" onClick={() => setLang(lang === "ja" ? "en" : "ja")}>{lang === "ja" ? "English" : "日本語"}</button>
    </form>
  );
}
