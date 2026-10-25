import { useEffect } from "react";
import { DevPanel } from "./components/DevPanel";
import { Notifications } from "./components/Notifications";
import { ProgressBar } from "./components/ProgressBar";
import { SoundEngine } from "./components/SoundEngine";
import { TextUI } from "./components/TextUI";
import { isBrowser, postNui, useNuiAction } from "./nui";
import { useUi } from "./store";
import type { NotifyPayload, ProgressPayload, TextPayload, UiConfig } from "./types";

export function App() {
	const accent = useUi((state) => state.config.accent);

	useNuiAction<Partial<UiConfig>>("obsi-lib:config", (config) => useUi.getState().setConfig(config));
	useNuiAction<NotifyPayload>("obsi-lib:notify", (payload) => useUi.getState().notify(payload));
	useNuiAction<ProgressPayload>("obsi-lib:progress", (payload) => useUi.getState().progressEvent(payload));
	useNuiAction<TextPayload>("obsi-lib:textui", (payload) => useUi.getState().textEvent(payload));

	useEffect(() => {
		if (/^#[0-9a-f]{6}$/i.test(accent)) document.documentElement.style.setProperty("--ob-accent", accent);
	}, [accent]);

	useEffect(() => {
		void postNui("ready");
	}, []);

	const browser = isBrowser();

	return (
		<div className="pointer-events-none relative h-full w-full overflow-hidden">
			{browser && <DevBackdrop />}
			<Notifications />
			<TextUI />
			<ProgressBar />
			<SoundEngine />
			{browser && <DevPanel />}
		</div>
	);
}

/** Stand-in for the game world in browser dev mode. */
function DevBackdrop() {
	return (
		<div
			className="absolute inset-0"
			style={{
				background:
					"linear-gradient(180deg, #3d4a57 0%, #5b6a74 38%, #6f6a5f 52%, #2c2f31 53%, #1f2224 100%)",
			}}
		/>
	);
}
