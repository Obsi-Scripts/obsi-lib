import { useEffect, useState } from "react";
import { emitNui } from "../nui";
import { useUi } from "../store";
import type { NotifyPosition, NotifyType, TextPosition } from "../types";

const SAMPLES: Record<NotifyType, { title: string; description: string; tag?: string }> = {
	success: { title: "Vehicle stored", description: "Your **Sultan RS** was parked in `Pillbox Garage`." },
	error: { title: "Not enough money", description: "You need **$2 500** in cash for this." },
	warning: { title: "Low fuel", description: "Fuel level is at `12%`, find a station.", tag: "Vehicle" },
	info: { title: "Shift started", description: "Report to the front desk.\nYour radio is set to channel `3`.", tag: "Police" },
};

const POSITIONS: NotifyPosition[] = ["top-right", "top-left", "top", "right", "left", "bottom-right", "bottom-left"];
const TEXT_POSITIONS: TextPosition[] = ["left", "right", "top", "bottom"];
const ACCENTS = ["#e5122e", "#5fb878", "#6ea8d8", "#d96bb0", "#e6e6e6"];

let mockTimer = 0;

/** Starts a mock progress bar and, like the Lua side, stops it once the duration has passed. */
function mockProgress(label: string, description: string, duration: number) {
	window.clearTimeout(mockTimer);
	emitNui("obsi-lib:progress", { op: "start", label, description, duration, cancelable: true });
	mockTimer = window.setTimeout(() => emitNui("obsi-lib:progress", { op: "stop", completed: true }), duration);
}

function Button({ label, onClick }: { label: string; onClick: () => void }) {
	return (
		<button
			type="button"
			onClick={onClick}
			className="border border-ob-line bg-ob-slot px-2 py-1 text-left font-mono text-[0.6875rem] text-ob-text transition-colors duration-150 hover:border-ob-accent"
		>
			{label}
		</button>
	);
}

/** Browser-only controls that fire the same messages the Lua side sends. */
export function DevPanel() {
	const config = useUi((state) => state.config);
	const [open, setOpen] = useState(true);

	useEffect(() => {
		const timers = [
			window.setTimeout(() => emitNui("obsi-lib:notify", { type: "success", ...SAMPLES.success, duration: 6000 }), 300),
			window.setTimeout(() => emitNui("obsi-lib:notify", { type: "info", ...SAMPLES.info, duration: 8000 }), 700),
			window.setTimeout(() => emitNui("obsi-lib:textui", { op: "show", key: "E", label: "Open stash", description: "Evidence locker #12" }), 500),
			window.setTimeout(() => mockProgress("Lockpicking", "Driver door", 6000), 900),
		];
		return () => timers.forEach((timer) => window.clearTimeout(timer));
	}, []);

	return (
		<div className="pointer-events-auto absolute top-4 left-4 w-[17rem] border border-ob-line border-t-2 border-t-ob-accent bg-ob-bg">
			<button type="button" onClick={() => setOpen(!open)} className="flex w-full items-center px-3 py-2">
				<span className="ob-label text-ob-text">obsi-lib dev</span>
				<span className="ml-auto font-mono text-[0.6875rem] text-ob-muted">{open ? "hide" : "show"}</span>
			</button>

			{open && (
				<div className="flex flex-col gap-3 px-3 pb-3">
					<section className="flex flex-col gap-1.5">
						<span className="ob-label text-ob-muted">Notify</span>
						<div className="grid grid-cols-2 gap-1">
							{(Object.keys(SAMPLES) as NotifyType[]).map((type) => (
								<Button key={type} label={type} onClick={() => emitNui("obsi-lib:notify", { type, ...SAMPLES[type] })} />
							))}
						</div>
						<select
							value={config.notify.position}
							onChange={(event) =>
								useUi.getState().setConfig({ notify: { ...config.notify, position: event.target.value as NotifyPosition } })
							}
							className="border border-ob-line bg-ob-slot px-2 py-1 font-mono text-[0.6875rem] text-ob-text"
						>
							{POSITIONS.map((position) => (
								<option key={position} value={position}>
									{position}
								</option>
							))}
						</select>
					</section>

					<section className="flex flex-col gap-1.5">
						<span className="ob-label text-ob-muted">Progress</span>
						<div className="grid grid-cols-2 gap-1">
							<Button
								label="start 5s"
								onClick={() => mockProgress("Repairing engine", "Hold still", 5000)}
							/>
							<Button
								label="cancel"
								onClick={() => {
									window.clearTimeout(mockTimer);
									emitNui("obsi-lib:progress", { op: "stop", completed: false });
								}}
							/>
						</div>
					</section>

					<section className="flex flex-col gap-1.5">
						<span className="ob-label text-ob-muted">Text UI</span>
						<div className="grid grid-cols-4 gap-1">
							{TEXT_POSITIONS.map((position) => (
								<Button
									key={position}
									label={position}
									onClick={() => {
										useUi.getState().setConfig({ textui: { position } });
										emitNui("obsi-lib:textui", { op: "show", key: "G", label: "Search", description: "Dumpster" });
									}}
								/>
							))}
						</div>
						<Button label="hide" onClick={() => emitNui("obsi-lib:textui", { op: "hide" })} />
					</section>

					<section className="flex flex-col gap-1.5">
						<span className="ob-label text-ob-muted">Accent</span>
						<div className="flex gap-1">
							{ACCENTS.map((accent) => (
								<button
									key={accent}
									type="button"
									aria-label={accent}
									onClick={() => emitNui("obsi-lib:config", { accent })}
									className={`h-5 w-5 border ${config.accent === accent ? "border-ob-text" : "border-ob-line"}`}
									style={{ background: accent }}
								/>
							))}
						</div>
					</section>
				</div>
			)}
		</div>
	);
}
