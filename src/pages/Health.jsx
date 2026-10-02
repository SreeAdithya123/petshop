import { ArrowRight, Pill, Stethoscope, Warning } from "@phosphor-icons/react";
import { PharmacyChat } from "../components/health/PharmacyChat";
import { VetConsult } from "../components/health/VetConsult";
import { Container } from "../components/layout/Container";

const FEATURES = [
  {
    href: "#vet",
    icon: Stethoscope,
    title: "Vet teleconsultation",
    text: "Book a video consult with a licensed vet and join from home.",
    cta: "Book a consult",
  },
  {
    href: "#pharmacy",
    icon: Pill,
    title: "Pharmacy assistant",
    text: "Automated tips for everyday pet health worries, plus matching products from the store.",
    cta: "Ask the assistant",
  },
];

function FeatureCard({ feature }) {
  const Icon = feature.icon;
  return (
    <a
      href={feature.href}
      className="group flex items-start gap-4 rounded-xl border border-border bg-surface p-5 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
    >
      <span className="flex h-12 w-12 flex-none items-center justify-center rounded-xl bg-primary/10 text-primary">
        <Icon size={26} weight="duotone" aria-hidden="true" />
      </span>
      <span className="min-w-0">
        <span className="block font-display text-lg font-semibold text-ink">{feature.title}</span>
        <span className="mt-1 block text-sm text-ink-soft">{feature.text}</span>
        <span className="mt-2 inline-flex items-center gap-1 text-sm font-medium text-primary">
          {feature.cta}
          <ArrowRight size={14} className="transition-transform group-hover:translate-x-0.5" aria-hidden="true" />
        </span>
      </span>
    </a>
  );
}

function SectionHeading({ icon: Icon, id, title, description }) {
  return (
    <div className="flex items-start gap-3">
      <span className="flex h-10 w-10 flex-none items-center justify-center rounded-lg bg-primary text-white">
        <Icon size={22} aria-hidden="true" />
      </span>
      <div>
        <h2 id={id} className="font-display text-2xl font-bold text-ink">
          {title}
        </h2>
        <p className="mt-1 text-sm text-ink-soft">{description}</p>
      </div>
    </div>
  );
}

export function Health() {
  return (
    <Container className="py-10 lg:py-12">
      <div className="rounded-2xl bg-gradient-to-br from-primary/10 via-secondary/10 to-tertiary/10 p-6 md:p-8">
        <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Pet health</h1>
        <p className="mt-2 max-w-xl text-[15px] text-ink-soft">
          Talk to a vet from home, or get quick pointers on everyday concerns.
        </p>
        <div
          role="note"
          className="mt-5 flex items-start gap-3 rounded-xl border border-warning/40 bg-warning/10 p-4 text-sm text-ink"
        >
          <Warning size={20} weight="fill" className="mt-0.5 flex-none text-amber-700" aria-hidden="true" />
          <p>
            PETSTA Health gives general guidance and connects you to licensed vets. It does not replace a
            veterinarian — in an emergency go to your nearest vet clinic immediately.
          </p>
        </div>
      </div>

      <nav aria-label="Health tools" className="mt-6 grid gap-4 sm:grid-cols-2">
        {FEATURES.map((feature) => (
          <FeatureCard key={feature.href} feature={feature} />
        ))}
      </nav>

      <div className="mt-12 grid items-start gap-12 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
        <section id="vet" aria-labelledby="vet-heading" className="scroll-mt-24">
          <SectionHeading
            icon={Stethoscope}
            id="vet-heading"
            title="Vet teleconsultation"
            description="Book a slot with a vet and meet over video, phone or in person."
          />
          <div className="mt-5">
            <VetConsult />
          </div>
        </section>

        <section id="pharmacy" aria-labelledby="pharmacy-heading" className="scroll-mt-24 lg:sticky lg:top-24">
          <SectionHeading
            icon={Pill}
            id="pharmacy-heading"
            title="Pharmacy assistant"
            description="Describe what's wrong and get general care tips and related products."
          />
          <div className="mt-5">
            <PharmacyChat />
          </div>
        </section>
      </div>
    </Container>
  );
}
