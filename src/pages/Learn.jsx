import { useEffect, useState } from "react";
import { Container } from "../components/layout/Container";
import { EmptyState } from "../components/ui/EmptyState";
import { supabase } from "../lib/supabaseClient";

export function Learn() {
  const [videos, setVideos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    async function loadVideos() {
      setLoading(true);
      const { data, error } = await supabase.from("reference_videos").select("*");
      if (cancelled) return;
      if (error) setError(error.message);
      else setVideos(data ?? []);
      setLoading(false);
    }
    loadVideos();
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <Container className="py-16">
        <p className="text-ink-soft">Loading…</p>
      </Container>
    );
  }

  return (
    <Container className="py-10 lg:py-12">
      <h1 className="font-display text-3xl font-bold text-ink md:text-4xl">Learn</h1>
      <p className="mt-2 text-[15px] text-ink-soft">Videos on pet care, from our shops and our team.</p>

      {error && <p className="mt-6 text-sm text-error">{error}</p>}

      {videos.length > 0 ? (
        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {videos.map((video) => (
            <a
              key={video.id}
              href={video.video_url}
              target="_blank"
              rel="noreferrer"
              className="block rounded-xl border border-border bg-surface p-4 transition-[box-shadow,transform] duration-200 hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]"
            >
              {video.thumbnail_url ? (
                <img
                  src={video.thumbnail_url}
                  alt={video.title}
                  className="h-40 w-full rounded-lg object-cover"
                />
              ) : (
                <div className="h-40 w-full rounded-lg bg-primary/5" />
              )}
              <h3 className="mt-3 text-[15px] font-medium text-ink">{video.title}</h3>
              {video.category && <p className="mt-1 text-sm capitalize text-ink-soft">{video.category}</p>}
            </a>
          ))}
        </div>
      ) : (
        <EmptyState title="No videos yet" description="Check back soon for pet care tips." />
      )}
    </Container>
  );
}
