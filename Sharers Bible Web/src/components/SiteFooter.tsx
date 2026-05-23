import { Link } from 'react-router-dom';

const footerStyle: React.CSSProperties = {
  borderTop: "1px solid var(--border-color)",
  padding: "40px 32px",
  textAlign: "center",
  fontSize: 13,
  color: "var(--text-secondary)",
};

const linkStyle: React.CSSProperties = {
  color: "var(--accent-color)",
  textDecoration: "none",
};

export default function SiteFooter() {
  return (
    <footer style={footerStyle}>
      <Link to="/privacy" style={linkStyle}>Privacy Policy</Link>
      {" \u00b7 "}
      <Link to="/terms" style={linkStyle}>Terms &amp; Conditions</Link>
      {" \u00b7 "}
      <Link to="/contact" style={linkStyle}>Contact</Link>
    </footer>
  );
}
