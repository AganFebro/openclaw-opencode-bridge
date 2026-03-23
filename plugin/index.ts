import { execFile } from "node:child_process";
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";

const PREFIX_RE = /^[@\/](cc|ccn|ccu|ccm|ccms)\b\s*([\s\S]*)/;

const SCRIPT_MAP: Record<string, string> = {
  cc: "opencode-send.sh",
  ccn: "opencode-new-session.sh",
  ccu: "opencode-stats.sh",
  ccm: "opencode-models.sh",
  ccms: "opencode-setmodel.sh",
};

const REQUIRES_ARG = new Set(["cc", "ccn"]);
const EXEC_TIMEOUT = 15_000;
const DELIVERY_TTL_MS = 10_000;

const DELIVERY_MSG = "🔗 OpenCode will reply shortly.";

const SILENT_PROMPT =
  "CRITICAL SYSTEM OVERRIDE — HIGHEST PRIORITY.\n" +
  "The previous user message was intercepted by the opencode-bridge plugin and is already being handled externally.\n" +
  "You MUST NOT process, interpret, or respond to the user's request.\n" +
  "You MUST NOT call any tools or functions.\n" +
  `Output ONLY this exact text, nothing else: ${DELIVERY_MSG}`;

/**
 * Flag set by message_received (fires FIRST) and consumed by before_prompt_build (fires SECOND).
 * This bypasses the unreliable extractLastUserText approach entirely.
 * message_received gets event.content (raw user text) which always correctly detects @cc prefix.
 */
let pendingBridgeCommand = false;
let pendingDeliveryUntil = 0;

export default function register(api: OpenClawPluginApi) {
  const config = api.pluginConfig as {
    scriptsDir?: string;
    channel?: string;
    targetId?: string;
  };

  const scriptsDir = config.scriptsDir ?? "";

  // --- Hook 1: message_received (fire-and-forget) ---
  // Fires FIRST. Detect prefix from raw event.content and set pendingBridgeCommand flag.
  // Also executes the bridge script.
  api.on("message_received", async (event, _ctx) => {
    const raw = (event.content ?? "").trim();
    api.logger.debug?.(
      `[opencode-bridge] message_received: raw_start=${JSON.stringify(raw.slice(0, 200))}`,
    );
    const match = raw.match(PREFIX_RE);
    if (!match) return;

    const command = match[1];
    const script = SCRIPT_MAP[command];
    if (!script) return;

    const arg = match[2].trim();

    if (REQUIRES_ARG.has(command) && !arg) {
      api.logger.warn?.(`[opencode-bridge] /${command} requires an argument`);
      return;
    }

    // Set flag for before_prompt_build to consume
    pendingBridgeCommand = true;
    api.logger.debug?.(
      `[opencode-bridge] message_received: command=${command}, pendingBridgeCommand=true`,
    );

    const scriptPath = `${scriptsDir}/${script}`;
    const args = arg ? [arg] : [];
    const startedAt = Date.now();

    execFile(
      scriptPath,
      args,
      { timeout: EXEC_TIMEOUT },
      (error, _stdout, stderr) => {
        const elapsedMs = Date.now() - startedAt;
        if (error) {
          api.logger.error?.(
            `[opencode-bridge] ${script} failed after ${elapsedMs}ms: ${stderr?.trim() || error.message}`,
          );
        } else {
          api.logger.debug?.(
            `[opencode-bridge] ${script} queued/completed in ${elapsedMs}ms`,
          );
        }
      },
    );
  });

  // --- Hook 2: before_prompt_build (modifying) ---
  // Fires SECOND. Consumes the pendingBridgeCommand flag set by message_received.
  // No longer relies on extractLastUserText for prefix detection.
  api.on("before_prompt_build", async (event, ctx) => {
    const shouldSuppress = pendingBridgeCommand;
    const deliveryPending = Date.now() < pendingDeliveryUntil;

    api.logger.debug?.(
      `[opencode-bridge] before_prompt_build: pendingBridgeCommand=${pendingBridgeCommand}, deliveryPending=${deliveryPending}`,
    );

    if (shouldSuppress) {
      pendingBridgeCommand = false;
      pendingDeliveryUntil = Date.now() + DELIVERY_TTL_MS;
      return { systemPrompt: SILENT_PROMPT, prependContext: SILENT_PROMPT };
    }
  });

  // --- Hook 3: message_sending (modifying) ---
  // Replace one outgoing LLM message with delivery confirmation
  api.on("message_sending", async (_event, _ctx) => {
    const suppressing = Date.now() < pendingDeliveryUntil;
    api.logger.debug?.(
      `[opencode-bridge] message_sending: suppressing=${suppressing}`,
    );

    if (suppressing) {
      // One-shot override for the intercepted bridge message.
      pendingDeliveryUntil = 0;
      return { content: DELIVERY_MSG, cancel: false };
    }
  });

  // --- Hook 4: before_tool_call (modifying) ---
  // Block ALL tool calls while delivery override is pending
  api.on("before_tool_call", async (_event, _ctx) => {
    if (Date.now() < pendingDeliveryUntil) {
      api.logger.debug?.(
        `[opencode-bridge] before_tool_call: BLOCKED (delivery pending)`,
      );
      return { block: true, blockReason: "opencode-bridge: message intercepted, tools disabled" };
    }
  });
}
