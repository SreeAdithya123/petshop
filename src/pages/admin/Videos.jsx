import { useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient";
import { useAuthStore } from "../../store/authStore";
import { Container } from "../../components/layout/Container";
import { Button } from "../../components/ui/Button";
import { EmptyState } from "../../components/ui/EmptyState";

const initialForm = { title: "", video_url: "", thumbnail_url: "", category: "" };

function fieldClassName(hasError) {
  return `mt-1.5 w-full rounded-lg border bg-surface px-4 py-2.5 text-[15px] text-ink focus:outline-none ${
    hasError ? "border-error focus:border-error" : "border-border focus:border-primary"
  }`;
}

function validate(form) {
  const errors = {};
  if (!form.title.trim()) errors.title = "Enter a title.";
  if (!form.video_url.trim()) errors.video_url = "Enter a video URL.";
  return errors;
}

export function AdminVideos() {
  const session = useAuthStore((state) => state.session);
  const [videos, setVideos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(initialForm);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState(null);

  async function loadVideos() {
    setLoading(true);
    const { data } = await supabase
      .from("reference_videos")
      .select("*")
      .order("created_at", { ascending: false });
    setVideos(data ?? []);
    setLoading(false);
  }

  useEffect(() => {
    loadVideos();
  }, []);

  function updateField(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const validationErrors = validate(form);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    await supabase.from("reference_videos").insert({
      title: form.title.trim(),
      video_url: form.video_url.trim(),
      thumbnail_url: form.thumbnail_url.trim() || null,
      category: form.category.trim() || null,
      created_by: session.user.id,
    });
    setSubmitting(false);
    setForm(initialForm);
    setErrors({});
    setShowForm(false);
    await loadVideos();
  }

  async function handleDelete(video) {
    if (!window.confirm(`Delete "${video.title}"? This can't be undone.`)) return;
    setDeletingId(video.id);
    await supabase.from("reference_videos").delete().eq("id", video.id);
    await loadVideos();
    setDeletingId(null);
  }

  return (
    <Container className="py-12">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-bold text-ink">Reference videos</h1>
          <p className="mt-1 text-[15px] text-ink-soft">
            Manage the reference videos shown to shop owners and customers.
          </p>
        </div>
        <Button variant="accent" size="md" onClick={() => setShowForm((prev) => !prev)}>
          {showForm ? "Cancel" : "Add a video"}
        </Button>
      </div>

      {showForm && (
        <form
          onSubmit={handleSubmit}
          noValidate
          className="mt-8 flex flex-col gap-5 rounded-xl border border-border bg-surface p-6"
        >
          <div>
            <label htmlFor="title" className="block text-sm font-medium text-ink">
              Title
            </label>
            <input
              id="title"
              type="text"
              value={form.title}
              onChange={(event) => updateField("title", event.target.value)}
              aria-invalid={Boolean(errors.title)}
              className={fieldClassName(Boolean(errors.title))}
            />
            {errors.title && <p className="mt-1.5 text-sm text-error">{errors.title}</p>}
          </div>

          <div>
            <label htmlFor="video_url" className="block text-sm font-medium text-ink">
              Video URL
            </label>
            <input
              id="video_url"
              type="url"
              value={form.video_url}
              onChange={(event) => updateField("video_url", event.target.value)}
              aria-invalid={Boolean(errors.video_url)}
              className={fieldClassName(Boolean(errors.video_url))}
            />
            {errors.video_url && <p className="mt-1.5 text-sm text-error">{errors.video_url}</p>}
          </div>

          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <label htmlFor="thumbnail_url" className="block text-sm font-medium text-ink">
                Thumbnail URL <span className="text-ink-soft">(optional)</span>
              </label>
              <input
                id="thumbnail_url"
                type="url"
                value={form.thumbnail_url}
                onChange={(event) => updateField("thumbnail_url", event.target.value)}
                className={fieldClassName(false)}
              />
            </div>
            <div>
              <label htmlFor="category" className="block text-sm font-medium text-ink">
                Category <span className="text-ink-soft">(optional)</span>
              </label>
              <input
                id="category"
                type="text"
                value={form.category}
                onChange={(event) => updateField("category", event.target.value)}
                className={fieldClassName(false)}
              />
            </div>
          </div>

          <Button type="submit" variant="accent" size="md" disabled={submitting} className="self-start">
            {submitting ? "Saving…" : "Save video"}
          </Button>
        </form>
      )}

      {loading && <p className="mt-8 text-[15px] text-ink-soft">Loading videos…</p>}

      {!loading && videos.length === 0 && !showForm && (
        <div className="mt-8">
          <EmptyState title="No reference videos yet" description="Videos you add will show up here." />
        </div>
      )}

      {!loading && videos.length > 0 && (
        <ul className="mt-8 divide-y divide-border rounded-xl border border-border bg-surface">
          {videos.map((video) => (
            <li key={video.id} className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-4">
                {video.thumbnail_url && (
                  <img src={video.thumbnail_url} alt="" className="h-12 w-20 rounded object-cover" />
                )}
                <div>
                  <div className="font-display font-semibold text-ink">{video.title}</div>
                  <div className="mt-1 text-sm text-ink-soft">{video.category || "Uncategorized"}</div>
                </div>
              </div>
              <Button
                variant="outline"
                size="sm"
                className="text-error"
                disabled={deletingId === video.id}
                onClick={() => handleDelete(video)}
              >
                {deletingId === video.id ? "Deleting…" : "Delete"}
              </Button>
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}
