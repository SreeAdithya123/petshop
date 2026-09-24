import { Link } from "react-router-dom";

const base =
  "inline-flex items-center justify-center gap-2 rounded-lg font-medium transition-colors duration-150 active:scale-[0.98] disabled:opacity-50 disabled:pointer-events-none whitespace-nowrap";

const variants = {
  accent: "bg-accent text-white hover:opacity-90",
  primary: "bg-primary text-white hover:opacity-90",
  outline: "border border-border text-ink hover:bg-primary/5",
  ghost: "text-primary hover:bg-primary/5",
};

const sizes = {
  sm: "px-4 py-2 text-sm",
  md: "px-5 py-2.5 text-[15px]",
  lg: "px-6 py-3.5 text-base",
};

export function Button({ variant = "primary", size = "md", to, className = "", children, ...props }) {
  const Component = to ? Link : "button";
  return (
    <Component
      to={to}
      className={`${base} ${sizes[size]} ${variants[variant]} ${className}`}
      {...props}
    >
      {children}
    </Component>
  );
}
