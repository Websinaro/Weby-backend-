import { Router } from "express";
import { validate } from "../../middleware/validate";
import { authenticate } from "../../middleware/auth";
import { authRateLimiter } from "../../middleware/rateLimiter";
import { googleAuthSchema, loginSchema, refreshSchema, registerSchema } from "./auth.schema";
import {
  googleHandler,
  loginHandler,
  logoutAllHandler,
  logoutHandler,
  meHandler,
  refreshHandler,
  registerHandler,
} from "./auth.controller";

const router = Router();

router.post("/register", authRateLimiter, validate({ body: registerSchema }), registerHandler);
router.post("/login", authRateLimiter, validate({ body: loginSchema }), loginHandler);
router.post("/google", authRateLimiter, validate({ body: googleAuthSchema }), googleHandler);
router.post("/refresh", authRateLimiter, validate({ body: refreshSchema }), refreshHandler);
router.post("/logout", validate({ body: refreshSchema }), logoutHandler);
router.post("/logout-all", authenticate, logoutAllHandler);
router.get("/me", authenticate, meHandler);

export default router;
