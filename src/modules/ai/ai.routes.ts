import { Router } from "express";
import { authenticate } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { aiChatSchema } from "./ai.schema";
import { chatHandler } from "./ai.controller";

const router = Router();

router.use(authenticate);
router.post("/chat", validate({ body: aiChatSchema }), chatHandler);

export default router;
