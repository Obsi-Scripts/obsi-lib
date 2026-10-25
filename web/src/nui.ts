import { useEffect, useRef } from "react";

/** True in a normal browser (dev mode), false inside the FiveM NUI frame. */
export const isBrowser = (): boolean => !("invokeNative" in window);

interface NuiMessage<T> {
	action: string;
	data: T;
}

/** Subscribes to SendNUIMessage({ action, data }) for one action. */
export function useNuiAction<T>(action: string, handler: (data: T) => void): void {
	const saved = useRef(handler);

	useEffect(() => {
		saved.current = handler;
	}, [handler]);

	useEffect(() => {
		const listener = (event: MessageEvent<NuiMessage<T>>) => {
			if (event.data && event.data.action === action) saved.current(event.data.data);
		};
		window.addEventListener("message", listener);
		return () => window.removeEventListener("message", listener);
	}, [action]);
}

declare global {
	interface Window {
		GetParentResourceName?: () => string;
	}
}

/** POSTs to a RegisterNUICallback handler. Resolves to null in the browser. */
export async function postNui<T = unknown>(name: string, body?: unknown): Promise<T | null> {
	if (isBrowser()) return null;
	const resource = window.GetParentResourceName ? window.GetParentResourceName() : "obsi-lib";
	try {
		const response = await fetch(`https://${resource}/${name}`, {
			method: "POST",
			headers: { "Content-Type": "application/json; charset=UTF-8" },
			body: JSON.stringify(body ?? {}),
		});
		return (await response.json()) as T;
	} catch {
		return null;
	}
}

/** Emulates a Lua SendNUIMessage (used by the browser dev panel and mocks). */
export function emitNui<T>(action: string, data: T): void {
	window.dispatchEvent(new MessageEvent("message", { data: { action, data } }));
}
