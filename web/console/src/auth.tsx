import { createContext, useContext, useState, type ReactNode } from "react";
import { api, tokenStore } from "./api";

export interface User { id: number; email: string; name: string; role: "owner" | "admin" | "operator" }
interface AuthState { user: User | null; login: (email: string, password: string) => Promise<void>; logout: () => void }

const Ctx = createContext<AuthState>({ user: null, login: async () => {}, logout: () => {} });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(() => {
    const raw = localStorage.getItem("agent-desk-user");
    return raw && tokenStore.get() ? (JSON.parse(raw) as User) : null;
  });

  const login = async (email: string, password: string) => {
    const res = await api<{ token: string; user: User }>("/api/v1/session", { method: "POST", body: { email, password } });
    tokenStore.set(res.token);
    localStorage.setItem("agent-desk-user", JSON.stringify(res.user));
    setUser(res.user);
  };
  const logout = () => {
    tokenStore.clear();
    localStorage.removeItem("agent-desk-user");
    setUser(null);
  };
  return <Ctx.Provider value={{ user, login, logout }}>{children}</Ctx.Provider>;
}

export const useAuth = () => useContext(Ctx);
export const isAdmin = (u: User | null) => u?.role === "owner" || u?.role === "admin";
