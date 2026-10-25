import { Fragment, type ReactNode } from "react";

/**
 * Safe inline formatting for server provided text (never rendered as HTML):
 *   **bold**   `mono`   line breaks with \n
 */
export function RichText({ text }: { text: string }) {
	const lines = text.split("\n");
	return (
		<>
			{lines.map((line, lineIndex) => (
				<Fragment key={lineIndex}>
					{lineIndex > 0 && <br />}
					{renderLine(line)}
				</Fragment>
			))}
		</>
	);
}

function renderLine(line: string): ReactNode[] {
	const parts: ReactNode[] = [];
	const pattern = /(\*\*[^*]+\*\*|`[^`]+`)/g;
	let last = 0;
	let match: RegExpExecArray | null = pattern.exec(line);
	while (match) {
		if (match.index > last) parts.push(line.slice(last, match.index));
		const token = match[0];
		if (token.startsWith("**")) {
			parts.push(
				<strong key={match.index} className="font-semibold text-ob-text">
					{token.slice(2, -2)}
				</strong>,
			);
		} else {
			parts.push(
				<span key={match.index} className="font-mono text-ob-text">
					{token.slice(1, -1)}
				</span>,
			);
		}
		last = match.index + token.length;
		match = pattern.exec(line);
	}
	if (last < line.length) parts.push(line.slice(last));
	return parts;
}
