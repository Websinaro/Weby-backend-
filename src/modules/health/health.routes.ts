import { Router } from "express";
import { prisma } from "../../database/prisma";
import { sendSuccess } from "../../utils/ApiResponse";
import { asyncHandler } from "../../utils/asyncHandler";

const router = Router();

// Liveness: process is up. Does not leak internal details.
router.get("/", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

// Readiness: process is up AND its dependencies (database) are reachable.
router.get("/ready", asyncHandler(async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    sendSuccess(res, { status: "ok", database: "connected" });
  } catch {
    res.status(503).json({ success: false, error: { code: "DB_UNAVAILABLE", message: "Database unreachable" } });
  }
}));

export default router;
