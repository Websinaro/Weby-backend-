import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { sendSuccess } from "../../utils/ApiResponse";
import { ApiError } from "../../utils/ApiError";
import * as service from "./users.service";

export const updateProfileHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  const user = await service.updateProfile(req.userId, req.body);
  sendSuccess(res, user);
});
