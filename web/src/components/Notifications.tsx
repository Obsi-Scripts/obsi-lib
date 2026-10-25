import { useEffect } from "react";
import { EXIT_MS, useUi } from "../store";
import type { NotifyPosition, NotifyType, Toast } from "../types";
import { RichText } from "./RichText";

const TYPE_COLOR: Record<NotifyType, string> = {
	success: "var(--color-ob-success)",
	error: "var(--color-ob-error)",
	warning: "var(--color-ob-warning)",
	info: "var(--color-ob-info)",
};

const TYPE_LABEL: Record<NotifyType, string> = {
	success: "OK",
	error: "ERR",
	warning: "WARN",
	info: "INFO",
};

const STACK: Record<NotifyPosition, string> = {
	"top-right": "top-6 right-6 items-end",
	"top-left": "top-6 left-6 items-start",
	top: "top-6 left-1/2 -translate-x-1/2 items-center",
	right: "top-1/2 right-6 -translate-y-1/2 items-end",
	left: "top-1/2 left-6 -translate-y-1/2 items-start",
	"bottom-right": "bottom-6 right-6 items-end flex-col-reverse",
	"bottom-left": "bottom-6 left-6 items-start flex-col-reverse",
};

function enterAnimation(position: NotifyPosition): string {
	if (position.endsWith("right")) return "animate-ob-in-right";
	if (position.endsWith("left")) return "animate-ob-in-left";
	return "animate-ob-in-down";
}

function ToastCard({ toast }: { toast: Toast }) {
	const dismiss = useUi((state) => state.dismiss);
	const remove = useUi((state) => state.remove);
	const notice = useUi((state) => state.config.strings.notice);
	const color = TYPE_COLOR[toast.type];

	// Timer restarts whenever a duplicate merged into this toast (stamp changes).
	useEffect(() => {
		if (toast.leaving) return;
		const timer = window.setTimeout(() => dismiss(toast.id), toast.duration);
		return () => window.clearTimeout(timer);
	}, [toast.id, toast.duration, toast.stamp, toast.leaving, dismiss]);

	useEffect(() => {
		if (!toast.leaving) return;
		const timer = window.setTimeout(() => remove(toast.id), EXIT_MS);
		return () => window.clearTimeout(timer);
	}, [toast.leaving, toast.id, remove]);

	return (
		<div
			className={`relative w-[21rem] overflow-hidden rounded-[2px] border border-ob-line bg-ob-panel ${
				toast.leaving ? "animate-ob-out" : enterAnimation(toast.position)
			}`}
		>
			<div className="absolute inset-y-0 left-0 w-[3px]" style={{ background: color }} />

			<div className="flex flex-col gap-1 py-2.5 pr-3 pl-4">
				<div className="flex items-center gap-2">
					<span className="ob-label font-mono" style={{ color }}>
						{TYPE_LABEL[toast.type]}
					</span>
					<span className="h-3 w-px bg-ob-line" />
					<span className="ob-label truncate text-ob-muted">{toast.tag ?? notice}</span>
					{toast.count > 1 && (
						<span className="ml-auto border border-ob-line bg-ob-slot px-1.5 font-mono text-[0.6875rem] text-ob-text">
							x{toast.count}
						</span>
					)}
				</div>

				{toast.title && <div className="text-[0.875rem] leading-tight font-medium text-ob-text">{toast.title}</div>}
				{toast.description && (
					<div className="text-[0.8125rem] leading-snug text-ob-muted">
						<RichText text={toast.description} />
					</div>
				)}
			</div>

			<div className="h-[2px] w-full bg-ob-slot">
				<div
					key={toast.stamp}
					className="ob-timer h-full"
					style={{ background: color, animationDuration: `${toast.duration}ms`, animationPlayState: toast.leaving ? "paused" : "running" }}
				/>
			</div>
		</div>
	);
}

export function Notifications() {
	const toasts = useUi((state) => state.toasts);
	if (toasts.length === 0) return null;

	const groups = new Map<NotifyPosition, Toast[]>();
	for (const toast of toasts) {
		const list = groups.get(toast.position) ?? [];
		list.push(toast);
		groups.set(toast.position, list);
	}

	return (
		<>
			{[...groups.entries()].map(([position, list]) => (
				<div key={position} className={`pointer-events-none absolute flex flex-col gap-2 ${STACK[position] ?? STACK["top-right"]}`}>
					{list.map((toast) => (
						<ToastCard key={toast.id} toast={toast} />
					))}
				</div>
			))}
		</>
	);
}
