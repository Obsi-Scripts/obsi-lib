export type NotifyType = "success" | "error" | "warning" | "info";

export type NotifyPosition =
	| "top-right"
	| "top-left"
	| "top"
	| "right"
	| "left"
	| "bottom-right"
	| "bottom-left";

export type TextPosition = "left" | "right" | "top" | "bottom";

export interface NotifyPayload {
	title?: string;
	description?: string;
	type?: NotifyType;
	duration?: number;
	tag?: string;
	position?: NotifyPosition;
}

export interface Toast {
	id: number;
	title?: string;
	description?: string;
	type: NotifyType;
	duration: number;
	tag?: string;
	position: NotifyPosition;
	count: number;
	/** Changes whenever the timer restarts (duplicate merged). */
	stamp: number;
	leaving: boolean;
}

export interface ProgressPayload {
	op: "start" | "stop";
	label?: string;
	description?: string;
	duration?: number;
	cancelable?: boolean;
	completed?: boolean;
}

export interface ProgressState {
	label: string;
	description?: string;
	duration: number;
	cancelable: boolean;
	startedAt: number;
	/** Set once the bar stops: 'done' or 'cancelled'. */
	result?: "done" | "cancelled";
}

export interface TextPayload {
	op: "show" | "hide";
	key?: string;
	label?: string;
	description?: string;
}

export interface TextState {
	key?: string;
	label: string;
	description?: string;
	leaving: boolean;
}

export interface SoundPayload {
	op: "play" | "stop" | "volume" | "stopAll";
	id?: string;
	file?: string;
	volume?: number;
	loop?: boolean;
}

export interface UiConfig {
	accent: string;
	notify: { position: NotifyPosition; max: number; duration: number };
	progress: { offset: number; cancelLabel: string };
	textui: { position: TextPosition };
	strings: { cancel: string; press: string; notice: string };
}
