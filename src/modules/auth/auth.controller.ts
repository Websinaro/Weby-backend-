import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { sendSuccess } from "../../utils/ApiResponse";
import { ApiError } from "../../utils/ApiError";
import * as authService from "./auth.service";

export const registerHandler = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.register(req.body, req);
  sendSuccess(res, result, 201);
});

export const loginHandler = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.login(req.body, req);
  sendSuccess(res, result);
});

export const googleHandler = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.loginWithGoogle(req.body.idToken, req);
  sendSuccess(res, result);
});

export const refreshHandler = asyncHandler(async (req: Request, res: Response) => {
  const result = await authService.refresh(req.body.refreshToken, req);
  sendSuccess(res, result);
});

export const logoutHandler = asyncHandler(async (req: Request, res: Response) => {
  await authService.logout(req.body.refreshToken);
  sendSuccess(res, { loggedOut: true });
});

export const logoutAllHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  await authService.logoutAll(req.userId);
  sendSuccess(res, { loggedOut: true });
});

export const meHandler = asyncHandler(async (req: Request, res: Response) => {
  if (!req.userId) throw ApiError.unauthorized();
  const user = await authService.getMe(req.userId);
  sendSuccess(res, user);
});
