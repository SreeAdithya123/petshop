import { Navigate, useLocation } from "react-router-dom";
import { roleHomePath, useAuthStore } from "../../store/authStore";

/**
 * Gates a route to specific roles. Not signed in -> /login (remembering
 * where they were headed). Signed in but wrong role -> their own
 * respective page, not a blank/forbidden screen.
 */
export function ProtectedRoute({ allowedRoles, children }) {
  const status = useAuthStore((state) => state.status);
  const profile = useAuthStore((state) => state.profile);
  const location = useLocation();

  if (status === "loading") return null;

  if (status === "signed-out" || !profile) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (!allowedRoles.includes(profile.role)) {
    return <Navigate to={roleHomePath(profile.role)} replace />;
  }

  return children;
}
