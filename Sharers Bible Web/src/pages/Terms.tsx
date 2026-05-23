import { LegalLayout } from "./LegalLayout";
import { legalStyles as s } from "./legalStyles";

export default function Terms() {
  return (
    <LegalLayout title="Terms &amp; Conditions" lastUpdated="May 22, 2026">
      <h2 style={s.heading2}>Acceptance of Terms</h2>
      <p style={s.paragraph}>
        By accessing or using Sharer's Bible (the "Services"), you agree to be bound
        by these Terms &amp; Conditions. If you do not agree, do not use the Services.
      </p>

      <h2 style={s.heading2}>Description of Services</h2>
      <p style={s.paragraph}>
        Sharer's Bible provides tools to browse, select, and share Bible verses.
        The Services are provided for personal, non-commercial, and ministerial use.
      </p>

      <h2 style={s.heading2}>User Responsibilities</h2>
      <ul style={s.list}>
        <li style={s.listItem}>You must be at least 13 years old to use the Services.</li>
        <li style={s.listItem}>You agree not to misuse the Services or interfere with their operation.</li>
        <li style={s.listItem}>You agree not to use the Services for any unlawful purpose.</li>
        <li style={s.listItem}>You are responsible for maintaining the confidentiality of any account credentials.</li>
      </ul>

      <h2 style={s.heading2}>Bible Content and Copyright</h2>
      <p style={s.paragraph}>
        Bible verses displayed through the Services are sourced from publicly available
        translations. Each translation may have its own licensing terms:
      </p>
      <ul style={s.list}>
        <li style={s.listItem}>Some translations are in the public domain.</li>
        <li style={s.listItem}>Others are used under license from their respective copyright holders.</li>
        <li style={s.listItem}>Attribution for each translation is displayed within the app where applicable.</li>
      </ul>
      <p style={s.paragraph}>
        Users are responsible for ensuring their use of Bible verse content complies with
        the license terms of each translation.
      </p>

      <h2 style={s.heading2}>Intellectual Property</h2>
      <p style={s.paragraph}>
        The software, design, and user interface of the Services are owned by Sharer's Bible
        and are protected by copyright and other intellectual property laws. Bible verse
        content remains the property of its respective copyright holders.
      </p>

      <h2 style={s.heading2}>Disclaimer of Warranties</h2>
      <p style={s.paragraph}>
        THE SERVICES ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY
        KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
      </p>

      <h2 style={s.heading2}>Limitation of Liability</h2>
      <p style={s.paragraph}>
        IN NO EVENT SHALL SHARER'S BIBLE BE LIABLE FOR ANY INDIRECT, INCIDENTAL,
        SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO YOUR
        USE OF THE SERVICES.
      </p>

      <h2 style={s.heading2}>Changes to Terms</h2>
      <p style={s.paragraph}>
        We reserve the right to modify these terms at any time. Continued use of the
        Services after changes constitutes acceptance of the new terms.
      </p>

      <h2 style={s.heading2}>Governing Law</h2>
      <p style={s.paragraph}>
        These terms shall be governed by and construed in accordance with the laws of
        the State of Texas, without regard to its conflict of law provisions.
      </p>

      <h2 style={s.heading2}>Contact</h2>
      <p style={s.paragraph}>
        For questions about these terms, please <a href="/contact" style={s.link}>contact us</a>.
      </p>
    </LegalLayout>
  );
}
