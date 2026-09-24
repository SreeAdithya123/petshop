import { Container } from "../layout/Container";

/**
 * Route-skeleton placeholder: just a heading naming the page. Working
 * content (forms, queries, dashboards) is built in the next pass, against
 * the real tables this schema already has.
 */
export function PagePlaceholder({ title }) {
  return (
    <Container className="py-16">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">{title}</h1>
    </Container>
  );
}
