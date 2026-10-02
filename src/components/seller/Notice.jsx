const TONES = {
  info: "border-primary/20 bg-primary/5 text-ink",
  success: "border-trust/30 bg-trust/10 text-ink",
  warning: "border-warning/40 bg-warning/10 text-ink",
  error: "border-error/30 bg-error/5 text-error",
};

export function Notice({ tone = "info", title, children, className = "" }) {
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={`rounded-xl border px-4 py-3 text-sm ${TONES[tone]} ${className}`}
    >
      {title && <p className="font-medium">{title}</p>}
      {children && <div className={title ? "mt-0.5" : ""}>{children}</div>}
    </div>
  );
}
