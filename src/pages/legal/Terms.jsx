import { LegalDocument } from "../../components/account/LegalDocument";
import { terms } from "./legalText";

/** PETSTA's Terms of Use (route /legal/terms). The wording lives in legalText.js. */
export function Terms() {
  return <LegalDocument doc={terms} otherLabel="Read the Privacy Policy" otherPath="/legal/privacy" />;
}
