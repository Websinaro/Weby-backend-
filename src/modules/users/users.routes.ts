import { Router } from "express";
import { authenticate } from "../../middleware/auth";
import { validate } from "../../middleware/validate";
import { updateProfileSchema } from "./users.schema";
import { updateProfileHandler } from "./users.controller";

const router = Router();
router.use(authenticate);

router.patch("/me", validate({ body: updateProfileSchema }), updateProfileHandler);

export default router;
