import { Request, Response } from "express";
import { sendError } from "../utils/ApiResponse";

export function notFoundHandler(req: Request, res: Response) {
  sendError(res, 404, "ROUTE_NOT_FOUND", `No route for ${req.method} ${req.originalUrl}`);
}
