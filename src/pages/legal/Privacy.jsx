import { LegalDocument } from "../../components/account/LegalDocument";
import { privacyPolicy } from "./legalText";

/** PETSTA's Privacy Policy (route /legal/privacy). The wording lives in legalText.js. */
export function Privacy() {
  return <LegalDocument doc={privacyPolicy} otherLabel="Read the Terms of Use" otherPath="/legal/terms" />;
}
