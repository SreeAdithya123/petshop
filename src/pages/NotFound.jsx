import { Container } from "../components/layout/Container";
import { Button } from "../components/ui/Button";
import { EmptyState } from "../components/ui/EmptyState";

export function NotFound() {
  return (
    <Container className="py-24">
      <EmptyState
        title="Page not found"
        description="That page doesn't exist, or it may have moved."
        action={<Button to="/">Back to home</Button>}
      />
    </Container>
  );
}
