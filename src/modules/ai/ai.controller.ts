import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { sendSuccess } from "../../utils/ApiResponse";
import { ApiError } from "../../utils/ApiError";
import * as service from "./ai.service";

export const chatHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  const { prompt, conversationId, provider } = req.body;
  const result = await service.chat(req.userId, prompt, conversationId, provider);
  sendSuccess(res, result);
});
