import { Router } from "express";
import { authenticate } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import {
  conversationIdParamSchema,
  createConversationSchema,
  createMessageSchema,
  listConversationsQuerySchema,
  listMessagesQuerySchema,
} from "./conversations.schema";
import {
  createConversationHandler,
  createMessageHandler,
  deleteConversationHandler,
  getConversationHandler,
  listConversationsHandler,
  listMessagesHandler,
} from "./conversations.controller";

const router = Router();

router.use(authenticate);

router.get("/", validate({ query: listConversationsQuerySchema }), listConversationsHandler);
router.post("/", validate({ body: createConversationSchema }), createConversationHandler);
router.get("/:id", validate({ params: conversationIdParamSchema }), getConversationHandler);
router.delete("/:id", validate({ params: conversationIdParamSchema }), deleteConversationHandler);

router.get(
  "/:id/messages",
  validate({ params: conversationIdParamSchema, query: listMessagesQuerySchema }),
  listMessagesHandler
);
router.post(
  "/:id/messages",
  validate({ params: conversationIdParamSchema, body: createMessageSchema }),
  createMessageHandler
);

export default router;
