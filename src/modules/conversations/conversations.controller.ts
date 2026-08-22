import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { sendSuccess } from "../../utils/ApiResponse";
import { ApiError } from "../../utils/ApiError";
import * as service from "./conversations.service";

function requireUserId(req: Request): string {
  if (!req.userId) throw ApiError.unauthorized();
  return req.userId;
}

export const listConversationsHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  const { page, limit } = req.query as unknown as { page: number; limit: number };
  const result = await service.listConversations(userId, page, limit);
  sendSuccess(res, result);
});

export const createConversationHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  const conversation = await service.createConversation(userId, req.body.title);
  sendSuccess(res, conversation, 201);
});

export const getConversationHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  const conversation = await service.getConversation(userId, req.params.id);
  sendSuccess(res, conversation);
});

export const deleteConversationHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  await service.deleteConversation(userId, req.params.id);
  sendSuccess(res, { deleted: true });
});

export const listMessagesHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  const { page, limit } = req.query as unknown as { page: number; limit: number };
  const result = await service.listMessages(userId, req.params.id, page, limit);
  sendSuccess(res, result);
});

export const createMessageHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  const { role, content, provider } = req.body;
  const message = await service.addMessage(userId, req.params.id, role, content, provider);
  sendSuccess(res, message, 201);
});

export const deleteMessageHandler = asyncHandler(async (req: Request, res: Response) => {
  const userId = requireUserId(req);
  await service.deleteMessage(userId, req.params.id);
  sendSuccess(res, { deleted: true });
});
