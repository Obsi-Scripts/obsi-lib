import { useCallback, useEffect, useRef } from "react";
import { postNui, useNuiAction } from "../nui";
import type { SoundPayload } from "../types";

/** Short names live in build/sounds/<name>.mp3; urls (http, https, nui) are used as they are. */
function resolveSource(file: string): string {
	if (/^(https?|nui):\/\//i.test(file)) return file;
	return `./sounds/${file}.mp3`;
}

function clampVolume(value: unknown): number {
	const volume = Number(value);
	if (Number.isNaN(volume)) return 0.5;
	return Math.min(1, Math.max(0, volume));
}

/** Audio player for ObsiLib.sound. Renders nothing; reports finished sounds back to Lua. */
export function SoundEngine() {
	const sounds = useRef(new Map<string, HTMLAudioElement>());
	const anonymous = useRef(0);

	const release = useCallback((id: string, notify: boolean) => {
		const audio = sounds.current.get(id);
		if (!audio) return;
		audio.pause();
		audio.src = "";
		sounds.current.delete(id);
		if (notify) void postNui("sound:ended", { id });
	}, []);

	const play = useCallback(
		(payload: SoundPayload) => {
			if (!payload.file) return;
			const id = payload.id ?? `anon:${++anonymous.current}`;
			release(id, false);

			const audio = new Audio(resolveSource(payload.file));
			audio.volume = clampVolume(payload.volume);
			audio.loop = payload.loop === true;
			sounds.current.set(id, audio);

			audio.addEventListener("ended", () => release(id, true));
			audio.addEventListener("error", () => release(id, true));
			audio.play().catch(() => release(id, true));
		},
		[release],
	);

	useNuiAction<SoundPayload>("obsi-lib:sound", (payload) => {
		switch (payload.op) {
			case "play":
				play(payload);
				break;
			case "stop":
				if (payload.id) release(payload.id, false);
				break;
			case "volume": {
				const audio = payload.id ? sounds.current.get(payload.id) : undefined;
				if (audio) audio.volume = clampVolume(payload.volume);
				break;
			}
			case "stopAll":
				for (const id of [...sounds.current.keys()]) release(id, false);
				break;
		}
	});

	useEffect(() => {
		const map = sounds.current;
		return () => {
			for (const audio of map.values()) audio.pause();
			map.clear();
		};
	}, []);

	return null;
}
