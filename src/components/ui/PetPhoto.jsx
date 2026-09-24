import { useState } from "react";
import { SpeciesIcon } from "../icons/SpeciesIcon";

/**
 * Renders one photo when `src` is given and loads successfully, and the
 * hand-illustrated species icon otherwise — either because the species has
 * no reliable photo source (`src` is null/undefined) or the URL failed to
 * load at runtime. Never renders a broken-image glyph. Takes a bare `src`
 * rather than a pet object so it can render both a card thumbnail and each
 * image in a detail-page gallery, each with its own independent fallback.
 */
export function PetPhoto({ src, species, alt, className = "" }) {
  const [failed, setFailed] = useState(false);

  if (!src || failed) {
    return <SpeciesIcon species={species} className={className} />;
  }

  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
      className={`object-cover ${className}`}
    />
  );
}
