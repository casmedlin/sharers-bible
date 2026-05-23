export const legalStyles: Record<string, React.CSSProperties> = {
  wrapper: {
    display: "flex",
    flexDirection: "column",
    minHeight: "100vh",
  },
  container: {
    flex: 1,
    maxWidth: 800,
    width: "100%",
    margin: "0 auto",
    padding: "80px 32px",
  },
  title: {
    fontSize: 42,
    fontWeight: 800,
    marginBottom: 8,
  },
  lastUpdated: {
    color: "var(--text-secondary)",
    fontStyle: "italic",
    marginBottom: 32,
    fontSize: 14,
  },
  heading2: {
    fontSize: 24,
    fontWeight: 700,
    margin: "32px 0 16px",
  },
  heading3: {
    fontSize: 19,
    fontWeight: 600,
    margin: "24px 0 12px",
  },
  paragraph: {
    marginBottom: 16,
    lineHeight: 1.7,
    fontSize: 16,
  },
  list: {
    paddingLeft: 24,
    marginBottom: 16,
    lineHeight: 1.7,
  },
  listItem: {
    marginBottom: 8,
    fontSize: 16,
  },
  link: {
    color: "var(--accent-color)",
    textDecoration: "none",
  },
  backLink: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    color: "var(--accent-color)",
    textDecoration: "none",
    fontSize: 14,
    fontWeight: 600,
    marginBottom: 24,
  },
};
