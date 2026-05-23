import { LegalLayout } from "./LegalLayout";
import { legalStyles as s } from "./legalStyles";

export default function Privacy() {
  return (
    <LegalLayout title="Privacy Policy" lastUpdated="May 22, 2026">
      <h2 style={s.heading2}>Introduction</h2>
      <p style={s.paragraph}>
        Sharer's Bible ("we," "our," or "us") is committed to protecting your privacy.
        This Privacy Policy explains how we collect, use, and safeguard your information
        when you use our website and related services (the "Services").
      </p>

      <h2 style={s.heading2}>Information We Collect</h2>
      <h3 style={s.heading3}>Information You Provide</h3>
      <ul style={s.list}>
        <li style={s.listItem}><strong>Contact information</strong> such as your name and email address when you contact us.</li>
        <li style={s.listItem}><strong>Feedback and communications</strong> you send to us.</li>
      </ul>
      <h3 style={s.heading3}>Information Collected Automatically</h3>
      <ul style={s.list}>
        <li style={s.listItem}><strong>Usage data</strong> including pages visited, features used, and interaction with the Services.</li>
        <li style={s.listItem}><strong>Device information</strong> such as browser type, operating system, and IP address.</li>
        <li style={s.listItem}><strong>Cookies and similar technologies</strong> to enhance your experience and analyze usage patterns.</li>
      </ul>

      <h2 style={s.heading2}>How We Use Your Information</h2>
      <ul style={s.list}>
        <li style={s.listItem}>To provide, maintain, and improve the Services.</li>
        <li style={s.listItem}>To respond to your comments, questions, and support requests.</li>
        <li style={s.listItem}>To monitor usage and troubleshoot technical issues.</li>
        <li style={s.listItem}>To comply with legal obligations.</li>
      </ul>

      <h2 style={s.heading2}>Data Sharing and Disclosure</h2>
      <p style={s.paragraph}>We do not sell your personal information. We may share data with:</p>
      <ul style={s.list}>
        <li style={s.listItem}><strong>Service providers</strong> who help us operate the Services (e.g., hosting, analytics).</li>
        <li style={s.listItem}><strong>Legal authorities</strong> when required by law or to protect our rights.</li>
      </ul>

      <h2 style={s.heading2}>Data Security</h2>
      <p style={s.paragraph}>
        We implement reasonable technical and organizational measures to protect your
        information. However, no method of transmission over the internet is 100% secure.
      </p>

      <h2 style={s.heading2}>Data Retention</h2>
      <p style={s.paragraph}>
        We retain your information only as long as necessary for the purposes described
        in this policy or as required by law.
      </p>

      <h2 style={s.heading2}>Your Rights</h2>
      <p style={s.paragraph}>Depending on your location, you may have rights including:</p>
      <ul style={s.list}>
        <li style={s.listItem}>Access to the personal data we hold about you.</li>
        <li style={s.listItem}>Correction of inaccurate or incomplete data.</li>
        <li style={s.listItem}>Deletion of your data ("right to be forgotten").</li>
        <li style={s.listItem}>Restriction or objection to processing.</li>
        <li style={s.listItem}>Data portability.</li>
      </ul>
      <p style={s.paragraph}>
        To exercise these rights, please <a href="/contact" style={s.link}>contact us</a>.
      </p>

      <h2 style={s.heading2}>Third-Party Services</h2>
      <p style={s.paragraph}>
        The Services may integrate with third-party platforms. These services have their
        own privacy policies, and we are not responsible for their practices.
      </p>

      <h2 style={s.heading2}>Children's Privacy</h2>
      <p style={s.paragraph}>
        The Services are not directed to children under 13. We do not knowingly
        collect personal information from children.
      </p>

      <h2 style={s.heading2}>Changes to This Policy</h2>
      <p style={s.paragraph}>
        We may update this Privacy Policy from time to time. Changes will be posted
        on this page with an updated "Last updated" date.
      </p>

      <h2 style={s.heading2}>Contact</h2>
      <p style={s.paragraph}>
        If you have questions about this Privacy Policy, please{" "}
        <a href="/contact" style={s.link}>contact us</a>.
      </p>
    </LegalLayout>
  );
}
