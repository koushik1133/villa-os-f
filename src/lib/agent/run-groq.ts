import Groq from "groq-sdk";
import { env } from "../env";
import { db } from "../supabase";
import { SYSTEM_PROMPT, buildLeadContext } from "./prompt";
import { GROQ_TOOLS } from "./tools-groq";
import { executeTool, type ToolContext } from "./execute";
import type { ScoringSignals } from "./scoring";
import { finalizeTurn } from "./finalize";
import type { RunAgentParams, RunResult } from "./types";
import type { AgentReply, Message } from "../types";

type ChatMessage = Groq.Chat.Completions.ChatCompletionMessageParam;

let groqClient: Groq | null = null;
function client(): Groq {
  if (!groqClient) groqClient = new Groq({ apiKey: env.groqApiKey });
  return groqClient;
}

/** Ceiling on tool round-trips per customer message. */
const MAX_TURNS = 8;

/** How much history to replay. Older context lives in the lead profile. */
const HISTORY_LIMIT = 40;

/** Groq replies are short WhatsApp messages — no need for a large ceiling. */
const MAX_TOKENS = 2048;

/**
 * Runs one customer message through the agent using Groq's free tier.
 *
 * Test-only path — see run.ts for the Anthropic implementation this mirrors.
 * Groq's chat completions API is OpenAI-compatible: no prompt-cache
 * breakpoints, no adaptive thinking/effort, and tool calls arrive as
 * `tool_calls` on the assistant message rather than content blocks. The
 * knowledge base and system prompt are folded into one system message per
 * request instead of being split for caching.
 */
export async function runAgentGroq(params: RunAgentParams): Promise<RunResult> {
  const { lead, conversation, customerMessage, deliver } = params;
  const supabase = db();

  const signals: ScoringSignals = {};
  const ctx: ToolContext = { lead, conversationId: conversation.id, deliver, signals };

  const history = await buildHistory(conversation.id);

  // Free-tier Groq has an 8K-token-per-minute cap on this model — the full
  // knowledge base text alone can burn most of that. Anthropic gets it
  // inlined and cached; Groq relies entirely on the search_knowledge_base
  // tool call instead, which the system prompt already instructs it to use
  // before answering anything factual.
  const messages: ChatMessage[] = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history,
    {
      role: "user",
      content: `${buildLeadContext({ lead, nowIso: new Date().toISOString() })}\n\n${customerMessage}`,
    },
  ];

  const replies: AgentReply[] = [];
  const toolsUsed: string[] = [];
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

  for (let turn = 0; turn < MAX_TURNS; turn++) {
    const response = await client().chat.completions.create({
      model: env.groqModel,
      max_tokens: MAX_TOKENS,
      messages,
      tools: GROQ_TOOLS,
      tool_choice: "auto",
    });

    const message = response.choices[0]?.message;
    if (!message) break;

    usage.input += response.usage?.prompt_tokens ?? 0;
    usage.output += response.usage?.completion_tokens ?? 0;

    // Reconstruct rather than push the response object directly — the
    // response type carries fields the request param type doesn't accept.
    messages.push({
      role: "assistant",
      content: message.content,
      tool_calls: message.tool_calls,
    } as ChatMessage);

    if (message.content && message.content.trim()) {
      const text = message.content.trim();
      replies.push({ text });
      await deliver({ text });
      await supabase.from("villa_messages").insert({
        conversation_id: conversation.id,
        lead_id: lead.id,
        role: "agent",
        body: text,
      });
    }

    const toolCalls = message.tool_calls ?? [];
    if (toolCalls.length === 0) break;

    for (const call of toolCalls) {
      if (call.type !== "function") continue;
      toolsUsed.push(call.function.name);

      let input: Record<string, unknown> = {};
      try {
        input = JSON.parse(call.function.arguments || "{}");
      } catch {
        // Malformed tool arguments — fall through with an empty object so
        // the handler reports a clean error instead of throwing here.
      }

      const output = await executeTool(ctx, call.function.name, input);
      messages.push({
        role: "tool",
        tool_call_id: call.id,
        content: JSON.stringify(output),
      });
    }

    if (lead.opted_out) break;
  }

  const { leadScore, temperature } = await finalizeTurn({
    lead,
    conversation,
    customerMessage,
    signals,
    repliesCount: replies.length,
  });

  return { replies, leadScore, temperature, toolsUsed, usage };
}

/** Same replay logic as the Anthropic path — see run.ts for the rationale. */
async function buildHistory(conversationId: string): Promise<ChatMessage[]> {
  const { data } = await db()
    .from("villa_messages")
    .select("*")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true })
    .limit(HISTORY_LIMIT);

  const rows = (data ?? []) as Message[];
  const out: ChatMessage[] = [];

  for (const m of rows) {
    const text = m.body?.trim() || (m.media_url ? `[sent ${m.media_kind ?? "file"}]` : "");
    if (!text) continue;

    const role: "user" | "assistant" = m.role === "customer" ? "user" : "assistant";

    const last = out[out.length - 1];
    if (last && last.role === role && typeof last.content === "string") {
      last.content = `${last.content}\n${text}`;
    } else {
      out.push({ role, content: text });
    }
  }

  while (out.length && out[0].role === "assistant") out.shift();

  return out;
}
