import { useEffect } from "react";
import { EXIT_MS, useUi } from "../store";
import type { TextPosition } from "../types";

const PLACE: Record<TextPosition, string> = {
	left: "left-0 top-1/2 -translate-y-1/2",
	right: "right-0 top-1/2 -translate-y-1/2",
	top: "top-6 left-1/2 -translate-x-1/2",
	bottom: "bottom-[6vh] left-1/2 -translate-x-1/2",
};

const EDGE: Record<TextPosition, string> = {
	left: "border-l-2 border-l-ob-accent",
	right: "border-r-2 border-r-ob-accent",
	top: "border-t-2 border-t-ob-accent",
	bottom: "border-t-2 border-t-ob-accent",
};

const ENTER: Record<TextPosition, string> = {
	left: "animate-ob-in-left",
	right: "animate-ob-in-right",
	top: "animate-ob-in-down",
	bottom: "animate-ob-in-up",
};

export function TextUI() {
	const text = useUi((state) => state.text);
	const clear = useUi((state) => state.clearText);
	const position = useUi((state) => state.config.textui.position);
	const press = useUi((state) => state.config.strings.press);

	useEffect(() => {
		if (!text?.leaving) return;
		const timer = window.setTimeout(clear, EXIT_MS);
		return () => window.clearTimeout(timer);
	}, [text?.leaving, clear]);

	if (!text) return null;
	const place = PLACE[position] ? position : "left";

	return (
		<div className={`absolute ${PLACE[place]}`}>
			<div
				className={`flex items-center gap-3 border border-ob-line bg-ob-panel px-3.5 py-2.5 ${EDGE[place]} ${
					text.leaving ? "animate-ob-out" : ENTER[place]
				}`}
			>
				{text.key && (
					<div className="flex flex-col items-center gap-0.5">
						<kbd className="flex h-8 min-w-8 items-center justify-center border border-ob-accent bg-ob-slot px-1.5 font-mono text-[0.875rem] font-bold text-ob-accent">
							{text.key}
						</kbd>
						<span className="text-[0.5625rem] tracking-[0.14em] text-ob-muted uppercase">{press}</span>
					</div>
				)}
				<div className="flex max-w-[18rem] flex-col">
					<span className="ob-label text-ob-text">{text.label}</span>
					{text.description && <span className="mt-0.5 text-[0.75rem] leading-snug text-ob-muted">{text.description}</span>}
				</div>
			</div>
		</div>
	);
}
