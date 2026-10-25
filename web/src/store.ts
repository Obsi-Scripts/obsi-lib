import { create } from "zustand";
import type {
	NotifyPayload,
	NotifyType,
	ProgressPayload,
	ProgressState,
	TextPayload,
	TextState,
	Toast,
	UiConfig,
} from "./types";

const TYPES: NotifyType[] = ["success", "error", "warning", "info"];

export const DEFAULT_CONFIG: UiConfig = {
	accent: "#e5122e",
	notify: { position: "top-right", max: 5, duration: 5000 },
	progress: { offset: 14, cancelLabel: "X" },
	textui: { position: "left" },
	strings: { cancel: "Cancel", press: "Press", notice: "Notice" },
};

export const EXIT_MS = 140;

interface UiStore {
	config: UiConfig;
	setConfig: (config: Partial<UiConfig>) => void;

	toasts: Toast[];
	notify: (payload: NotifyPayload) => void;
	dismiss: (id: number) => void;
	remove: (id: number) => void;

	progress: ProgressState | null;
	progressEvent: (payload: ProgressPayload) => void;
	clearProgress: () => void;

	text: TextState | null;
	textEvent: (payload: TextPayload) => void;
	clearText: () => void;
}

let nextToast = 1;

export const useUi = create<UiStore>((set, get) => ({
	config: DEFAULT_CONFIG,
	setConfig: (config) =>
		set((state) => ({
			config: {
				...state.config,
				...config,
				notify: { ...state.config.notify, ...config.notify },
				progress: { ...state.config.progress, ...config.progress },
				textui: { ...state.config.textui, ...config.textui },
				strings: { ...state.config.strings, ...config.strings },
			},
		})),

	toasts: [],
	notify: (payload) => {
		const { config, toasts } = get();
		const type: NotifyType = TYPES.includes(payload.type as NotifyType) ? (payload.type as NotifyType) : "info";
		const duration = Math.max(1000, Number(payload.duration) || config.notify.duration);

		// Same message still on screen: bump its counter and restart the timer.
		const twin = toasts.find(
			(toast) =>
				!toast.leaving &&
				toast.type === type &&
				toast.title === payload.title &&
				toast.description === payload.description,
		);
		if (twin) {
			set({
				toasts: toasts.map((toast) =>
					toast.id === twin.id ? { ...toast, count: toast.count + 1, stamp: Date.now(), duration } : toast,
				),
			});
			return;
		}

		const toast: Toast = {
			id: nextToast++,
			title: payload.title,
			description: payload.description,
			type,
			duration,
			tag: payload.tag,
			position: payload.position ?? config.notify.position,
			count: 1,
			stamp: Date.now(),
			leaving: false,
		};

		const visible = toasts.filter((entry) => !entry.leaving);
		const overflow = visible.length + 1 - Math.max(1, config.notify.max);
		const retire = new Set(visible.slice(0, Math.max(0, overflow)).map((entry) => entry.id));
		set({
			toasts: [...toasts.map((entry) => (retire.has(entry.id) ? { ...entry, leaving: true } : entry)), toast],
		});
	},
	dismiss: (id) =>
		set((state) => ({ toasts: state.toasts.map((toast) => (toast.id === id ? { ...toast, leaving: true } : toast)) })),
	remove: (id) => set((state) => ({ toasts: state.toasts.filter((toast) => toast.id !== id) })),

	progress: null,
	progressEvent: (payload) => {
		if (payload.op === "start") {
			set({
				progress: {
					label: payload.label ?? "",
					description: payload.description,
					duration: Math.max(100, Number(payload.duration) || 5000),
					cancelable: payload.cancelable === true,
					startedAt: performance.now(),
				},
			});
			return;
		}
		const current = get().progress;
		if (!current || current.result) return;
		set({ progress: { ...current, result: payload.completed ? "done" : "cancelled" } });
	},
	clearProgress: () => set({ progress: null }),

	text: null,
	textEvent: (payload) => {
		if (payload.op === "show") {
			set({
				text: {
					key: payload.key,
					label: payload.label ?? "",
					description: payload.description,
					leaving: false,
				},
			});
			return;
		}
		const current = get().text;
		if (current) set({ text: { ...current, leaving: true } });
	},
	clearText: () => set({ text: null }),
}));
