import { db } from "../supabase";
import { scoreLead, temperatureFor, type ScoringSignals } from "./scoring";
import type { Conversation, Lead } from "../types";

/**
 * Rescores the lead and persists conversation state. Shared across every
 * provider implementation (Anthropic, Groq, ...) since it has nothing to do
 * with which LLM produced the reply.
 */
export async function finalizeTurn(params: {
  lead: Lead;
  conversation: Conversation;
  customerMessage: string;
  signals: ScoringSignals;
  repliesCount: number;
}): Promise<{ leadScore: number; temperature: string }> {
  const { lead, conversation, customerMessage, signals, repliesCount } = params;
  const supabase = db();

  const { count } = await supabase
    .from("villa_messages")
    .select("id", { count: "exact", head: true })
    .eq("conversation_id", conversation.id)
    .eq("role", "customer");

  signals.customerMessageCount = count ?? 1;
  signals.askedAboutBooking =
    signals.askedAboutBooking ||
    /\b(book|booking|payment|emi|token|advance|availab)/i.test(customerMessage);

  const leadScore = scoreLead(lead, signals);
  const temperature = temperatureFor(leadScore);

  await supabase
    .from("villa_leads")
    .update({
      lead_score: leadScore,
      lead_temperature: temperature,
      last_contact_at: new Date().toISOString(),
    })
    .eq("id", lead.id);

  await supabase
    .from("villa_conversations")
    .update({
      last_message_at: new Date().toISOString(),
      message_count: conversation.message_count + 1 + repliesCount,
    })
    .eq("id", conversation.id);

  return { leadScore, temperature };
}
