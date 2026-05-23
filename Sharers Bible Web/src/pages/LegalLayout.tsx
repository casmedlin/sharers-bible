import type { ReactNode } from "react";
import { Link } from 'react-router-dom';
import { legalStyles as styles } from "./legalStyles";

export function LegalLayout({
  title,
  lastUpdated,
  children,
}: {
  title: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <div style={styles.wrapper}>
      <div style={styles.container}>
        <Link to="/" style={styles.backLink}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Back to Bible
        </Link>
        <h1 style={styles.title}>{title}</h1>
        <p style={styles.lastUpdated}>Last updated: {lastUpdated}</p>
        {children}
      </div>
    </div>
  );
}
