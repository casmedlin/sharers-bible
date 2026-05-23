import { LegalLayout } from "./LegalLayout";
import { legalStyles as s } from "./legalStyles";

export default function Contact() {
  return (
    <LegalLayout title="Contact Us" lastUpdated="">
      <p style={s.paragraph}>
        Have questions, feedback, or need support? Reach out to us using the information below.
      </p>

      <h2 style={s.heading2}>Email</h2>
      <p style={s.paragraph}>
        <a href="mailto:support@wbem.org" style={s.link}>support@wbem.org</a>
      </p>

      <h2 style={s.heading2}>Bug Reports</h2>
      <p style={s.paragraph}>
        Found a bug? Report it at{" "}
        <a href="mailto:bug@wbem.org" style={s.link}>bug@wbem.org</a>.
        Please include your browser, operating system, and steps to reproduce the issue.
      </p>

      <h2 style={s.heading2}>Response Time</h2>
      <p style={s.paragraph}>
        We typically respond within 1&ndash;2 business days. For urgent matters, please
        indicate so in your subject line.
      </p>

      <h2 style={s.heading2}>Feature Requests</h2>
      <p style={s.paragraph}>
        We welcome suggestions for new features and improvements. Send your ideas to
        <a href="mailto:support@wbem.org" style={s.link}> support@wbem.org</a>.
      </p>

      <h2 style={s.heading2}>Privacy Concerns</h2>
      <p style={s.paragraph}>
        For privacy-related inquiries, please review our{" "}
        <a href="/privacy" style={s.link}>Privacy Policy</a> or email us directly.
      </p>
    </LegalLayout>
  );
}
