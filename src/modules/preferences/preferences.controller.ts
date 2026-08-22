import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { sendSuccess } from "../../utils/ApiResponse";
import { ApiError } from "../../utils/ApiError";
import * as service from "./preferences.service";

export const getPreferencesHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  const prefs = await service.getPreferences(req.userId);
  sendSuccess(res, prefs);
});

export const updatePreferencesHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  const prefs = await service.updatePreferences(req.userId, req.body);
  sendSuccess(res, prefs);
});
