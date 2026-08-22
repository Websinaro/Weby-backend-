import { Router } from "express";
import { authenticate } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { updatePreferencesSchema } from "./preferences.schema";
import { getPreferencesHandler, updatePreferencesHandler } from "./preferences.controller";

const router = Router();
router.use(authenticate);

router.get("/", getPreferencesHandler);
router.patch("/", validate({ body: updatePreferencesSchema }), updatePreferencesHandler);

export default router;
