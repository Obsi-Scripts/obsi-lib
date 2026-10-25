import { useEffect, useState } from "react";
import { EXIT_MS, useUi } from "../store";

const HOLD_MS = 260;

export function ProgressBar() {
	const progress = useUi((state) => state.progress);
	const clear = useUi((state) => state.clearProgress);
	const config = useUi((state) => state.config);
	const [now, setNow] = useState(() => performance.now());
	const [leaving, setLeaving] = useState(false);

	// Frame clock while running.
	useEffect(() => {
		if (!progress || progress.result) return;
		setLeaving(false);
		let frame = 0;
		const tick = () => {
			setNow(performance.now());
			frame = requestAnimationFrame(tick);
		};
		frame = requestAnimationFrame(tick);
		return () => cancelAnimationFrame(frame);
	}, [progress]);

	// Short hold on the final state, then fade out and clear.
	useEffect(() => {
		if (!progress?.result) return;
		const fade = window.setTimeout(() => setLeaving(true), HOLD_MS);
		const done = window.setTimeout(() => {
			setLeaving(false);
			clear();
		}, HOLD_MS + EXIT_MS);
		return () => {
			window.clearTimeout(fade);
			window.clearTimeout(done);
		};
	}, [progress?.result, clear]);

	if (!progress) return null;

	const elapsed = progress.result === "done" ? progress.duration : Math.min(progress.duration, now - progress.startedAt);
	const ratio = progress.duration > 0 ? elapsed / progress.duration : 1;
	const percent = Math.round(ratio * 100);
	const remaining = Math.max(0, (progress.duration - elapsed) / 1000);
	const cancelled = progress.result === "cancelled";
	const fill = cancelled ? "var(--color-ob-error)" : "var(--ob-accent)";

	return (
		<div
			className={`absolute left-1/2 w-[27rem] -translate-x-1/2 ${leaving ? "animate-ob-out" : "animate-ob-in-up"}`}
			style={{ bottom: `${config.progress.offset}vh` }}
		>
			<div className="rounded-[2px] border border-ob-line border-t-2 bg-ob-panel px-3.5 pt-2.5 pb-3" style={{ borderTopColor: fill }}>
				<div className="flex items-baseline gap-3">
					<span className="ob-label truncate text-ob-text">{progress.label}</span>
					<span className="ml-auto font-mono text-[0.8125rem] tabular-nums" style={{ color: fill }}>
						{String(percent).padStart(3, "0")}%
					</span>
				</div>

				{progress.description && <div className="mt-0.5 truncate text-[0.75rem] text-ob-muted">{progress.description}</div>}

				<div className="relative mt-2.5 h-[6px] border border-ob-line bg-ob-slot">
					<div className="absolute inset-y-0 left-0" style={{ width: `${ratio * 100}%`, background: fill }} />
					<div className="ob-ticks pointer-events-none absolute inset-0" />
				</div>

				<div className="mt-2 flex items-center">
					<span className="font-mono text-[0.75rem] text-ob-muted tabular-nums">{remaining.toFixed(1)}s</span>
					{progress.cancelable && !progress.result && (
						<span className="ml-auto flex items-center gap-1.5">
							<kbd className="min-w-[1.25rem] border border-ob-line bg-ob-slot px-1 text-center font-mono text-[0.6875rem] text-ob-text">
								{config.progress.cancelLabel}
							</kbd>
							<span className="ob-label text-ob-muted">{config.strings.cancel}</span>
						</span>
					)}
				</div>
			</div>
		</div>
	);
}
