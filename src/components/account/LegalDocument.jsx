import { ArrowLeft } from "@phosphor-icons/react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { LEGAL_EFFECTIVE_DATE, LEGAL_REVIEW_NOTE } from "../../pages/legal/legalText";
import { Container } from "../layout/Container";

const backClassName = "inline-flex items-center gap-1.5 text-sm text-ink-soft hover:text-ink";

/**
 * Reader for one legal document from legalText.js: title, effective date,
 * the sections, the "to be reviewed by counsel" note, and links to the other
 * document and to Support.
 */
export function LegalDocument({ doc, otherLabel, otherPath }) {
  const navigate = useNavigate();
  const location = useLocation();
  // "default" means the page was opened directly (for example in a new tab
  // from the sign-up form), so there is no previous page to return to.
  const canGoBack = location.key !== "default";

  return (
    <Container className="py-10 lg:py-12">
      <article className="mx-auto max-w-2xl">
        {canGoBack ? (
          <button type="button" onClick={() => navigate(-1)} className={backClassName}>
            <ArrowLeft size={16} aria-hidden="true" />
            Back
          </button>
        ) : (
          <Link to="/" className={backClassName}>
            <ArrowLeft size={16} aria-hidden="true" />
            Back to PETSTA
          </Link>
        )}

        <h1 className="mt-6 font-display text-3xl font-bold text-ink md:text-4xl">{doc.title}</h1>
        <p className="mt-1.5 text-sm text-ink-soft">Effective {LEGAL_EFFECTIVE_DATE}</p>
        <p className="mt-5 text-base leading-relaxed text-ink">{doc.intro}</p>

        {doc.sections.map((section) => (
          <section key={section.heading} className="mt-8">
            <h2 className="font-display text-xl font-semibold text-ink">{section.heading}</h2>
            {section.paragraphs?.map((paragraph) => (
              <p key={paragraph} className="mt-3 text-[15px] leading-relaxed text-ink">
                {paragraph}
              </p>
            ))}
            {section.bullets && (
              <ul className="mt-3 list-disc space-y-2.5 pl-5 text-[15px] leading-relaxed text-ink marker:text-ink-soft">
                {section.bullets.map((bullet) => (
                  <li key={bullet}>{bullet}</li>
                ))}
              </ul>
            )}
          </section>
        ))}

        <p className="mt-10 rounded-xl border border-primary/20 bg-primary/5 px-4 py-3 text-sm text-ink-soft">
          {LEGAL_REVIEW_NOTE}
        </p>

        <div className="mt-5 flex flex-wrap gap-x-6 gap-y-2 text-sm">
          <Link to={otherPath} className="font-medium text-primary hover:underline">
            {otherLabel}
          </Link>
          <Link to="/support" className="font-medium text-primary hover:underline">
            Contact support
          </Link>
        </div>
      </article>
    </Container>
  );
}
