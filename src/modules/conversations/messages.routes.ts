import { Router } from "express";
import { authenticate } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { messageIdParamSchema } from "./conversations.schema";
import { deleteMessageHandler } from "./conversations.controller";

// Standalone /api/v1/messages/:id route, per spec section 12
// (DELETE /api/messages/:id lives outside the /conversations/:id nesting).
const router = Router();

router.use(authenticate);
router.delete("/:id", validate({ params: messageIdParamSchema }), deleteMessageHandler);

export default router;
