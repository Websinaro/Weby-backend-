import { prisma } from "../../database/prisma";
import { ApiError } from "../../utils/ApiError";

// Every function here takes userId as an explicit, required parameter
// sourced only from the verified access token (req.userId) - never from
// the request body/params - and every query is scoped `where: { userId }`
// (or via the conversation ownership check) so one user can never read
// or mutate another user's data.

export async function listConversations(userId: string, page: number, limit: number) {
  const [items, total] = await Promise.all([
    prisma.conversation.findMany({
      where: { userId },
      orderBy: { updatedAt: "desc" },
      skip: (page - 1) * limit,
      take: limit,
      select: { id: true, title: true, createdAt: true, updatedAt: true },
    }),
    prisma.conversation.count({ where: { userId } }),
  ]);

  return { items, page, limit, total, totalPages: Math.ceil(total / limit) };
}

export async function createConversation(userId: string, title?: string) {
  return prisma.conversation.create({
    data: { userId, title: title ?? "New conversation" },
  });
}

async function getOwnedConversation(userId: string, conversationId: string) {
  const conversation = await prisma.conversation.findUnique({ where: { id: conversationId } });
  if (!conversation || conversation.userId !== userId) {
    // Same error for "doesn't exist" and "exists but isn't yours" -
    // avoids leaking which conversation IDs are valid for other users.
    throw ApiError.notFound("Conversation not found", "CONVERSATION_NOT_FOUND");
  }
  return conversation;
}

export async function getConversation(userId: string, conversationId: string) {
  return getOwnedConversation(userId, conversationId);
}

export async function deleteConversation(userId: string, conversationId: string) {
  await getOwnedConversation(userId, conversationId);
  await prisma.conversation.delete({ where: { id: conversationId } });
}

export async function listMessages(
  userId: string,
  conversationId: string,
  page: number,
  limit: number
) {
  await getOwnedConversation(userId, conversationId);

  const [items, total] = await Promise.all([
    prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: "asc" },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.message.count({ where: { conversationId } }),
  ]);

  return { items, page, limit, total, totalPages: Math.ceil(total / limit) };
}

export async function addMessage(
  userId: string,
  conversationId: string,
  role: "user" | "assistant" | "system",
  content: string,
  provider?: string
) {
  await getOwnedConversation(userId, conversationId);

  const message = await prisma.message.create({
    data: { conversationId, role, content, provider },
  });

  await prisma.conversation.update({
    where: { id: conversationId },
    data: { updatedAt: new Date() },
  });

  return message;
}

export async function deleteMessage(userId: string, messageId: string) {
  const message = await prisma.message.findUnique({
    where: { id: messageId },
    include: { conversation: true },
  });

  if (!message || message.conversation.userId !== userId) {
    throw ApiError.notFound("Message not found", "MESSAGE_NOT_FOUND");
  }

  await prisma.message.delete({ where: { id: messageId } });
}
