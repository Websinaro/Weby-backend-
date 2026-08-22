import { prisma } from "../../database/prisma";
import { ApiError } from "../../utils/ApiError";
import { ProviderUnavailableError } from "./providers/AIProvider";
import { aiRouter } from "./ai.router";
import { getPreferences } from "../preferences/preferences.service";

const HISTORY_MESSAGE_LIMIT = 20;

// Handles a single "Weby, explain quantum computing" style AI request:
// resolves the user's preferred provider, optionally loads recent
// conversation context, calls the router, and persists both the user
// message and the assistant reply if a conversationId was supplied.
export async function chat(userId: string, prompt: string, conversationId?: string, providerOverride?: string) {
  const prefs = await getPreferences(userId);
  const providerPreference = providerOverride ?? prefs.aiProvider;

  let history: { role: "user" | "assistant" | "system"; content: string }[] = [];

  if (conversationId) {
    const conversation = await prisma.conversation.findUnique({ where: { id: conversationId } });
    if (!conversation || conversation.userId !== userId) {
      throw ApiError.notFound("Conversation not found", "CONVERSATION_NOT_FOUND");
    }

    const recent = await prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: "desc" },
      take: HISTORY_MESSAGE_LIMIT,
    });
    history = recent.reverse().map((m) => ({ role: m.role, content: m.content }));

    await prisma.message.create({ data: { conversationId, role: "user", content: prompt } });
  }

  let result;
  try {
    result = await aiRouter.generate(prompt, providerPreference, {
      model: prefs.aiModel ?? undefined,
      history,
    });
  } catch (err) {
    if (err instanceof ProviderUnavailableError) {
      throw ApiError.badRequest(
        "The AI assistant is temporarily unavailable. Please try again shortly.",
        "AI_PROVIDER_UNAVAILABLE"
      );
    }
    throw err;
  }

  if (conversationId) {
    await prisma.message.create({
      data: {
        conversationId,
        role: "assistant",
        content: result.text,
        provider: result.provider,
      },
    });
    await prisma.conversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
    });
  }

  return result;
}
