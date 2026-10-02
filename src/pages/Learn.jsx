import { useEffect, useState } from "react";
import { AccountPageHeader, ErrorNote, LoadingNote } from "../components/account/AccountPage";
import { safeExternalUrl } from "../components/account/accountHelpers";
import { EmptyState } from "../components/ui/EmptyState";
import { supabase } from "../lib/supabaseClient";

const cardClassName =
  "block rounded-xl border border-border bg-surface p-4 transition-[box-shadow,transform] duration-200";

function VideoCard({ video }) {
  const href = safeExternalUrl(video.video_url);
  const content = (
    <>
      {video.thumbnail_url ? (
        <img src={video.thumbnail_url} alt="" loading="lazy" className="h-40 w-full rounded-lg object-cover" />
      ) : (
        <div className="h-40 w-full rounded-lg bg-primary/5" />
      )}
      <h3 className="mt-3 text-[15px] font-medium text-ink">{video.title}</h3>
      {video.category && <p className="mt-1 text-sm capitalize text-ink-soft">{video.category}</p>}
    </>
  );

  if (!href) return <div className={cardClassName}>{content}</div>;

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`${cardClassName} hover:-translate-y-1 hover:shadow-[0_16px_32px_-16px_rgba(20,24,31,0.25)]`}
    >
      {content}
    </a>
  );
}

export function Learn() {
  const [videos, setVideos] = useState(null);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function loadVideos() {
      const { data, error: loadError } = await supabase
        .from("reference_videos")
        .select("id, title, video_url, thumbnail_url, category")
        .order("created_at", { ascending: false });
      if (cancelled) return;
      if (loadError) setError(loadError.message);
      else setVideos(data ?? []);
    }
    loadVideos();
    return () => {
      cancelled = true;
    };
  }, [reloadKey]);

  function retry() {
    setError("");
    setVideos(null);
    setReloadKey((key) => key + 1);
  }

  return (
    <div>
      <AccountPageHeader title="Learn" description="Videos on pet care, from our shops and our team." />

      {error ? (
        <ErrorNote message={error} onRetry={retry} />
      ) : !videos ? (
        <LoadingNote />
      ) : videos.length > 0 ? (
        <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {videos.map((video) => (
            <VideoCard key={video.id} video={video} />
          ))}
        </div>
      ) : (
        <EmptyState title="No videos yet" description="Check back soon for pet care tips." />
      )}
    </div>
  );
}
