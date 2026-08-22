import { Router } from "express";
import authRoutes from "../modules/auth/auth.routes";
import usersRoutes from "../modules/users/users.routes";
import conversationsRoutes from "../modules/conversations/conversations.routes";
import messagesRoutes from "../modules/conversations/messages.routes";
import preferencesRoutes from "../modules/preferences/preferences.routes";
import aiRoutes from "../modules/ai/ai.routes";

// All versioned API routes are mounted here and attached under
// env.API_PREFIX (/api/v1) in app.ts. /health is mounted separately,
// unversioned, since infra/uptime checks should never need to change
// their URL when the API version bumps.
const router = Router();

router.use("/auth", authRoutes);
router.use("/users", usersRoutes);
router.use("/conversations", conversationsRoutes);
router.use("/messages", messagesRoutes);
router.use("/preferences", preferencesRoutes);
router.use("/ai", aiRoutes);

export default router;
