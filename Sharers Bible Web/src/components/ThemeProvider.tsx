import { useEffect, type ReactNode } from "react";

export default function ThemeProvider({ children }: { children: ReactNode }) {
  useEffect(() => {
    const saved = localStorage.getItem("selectedTheme") || "System";
    document.documentElement.setAttribute("data-theme", saved.toLowerCase());
  }, []);

  return <>{children}</>;
}
