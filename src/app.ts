import express, { Express } from "express";
import helmet from "helmet";
import cors from "cors";
import compression from "compression";
import { randomUUID } from "crypto";
import pinoHttp from "pino-http";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { globalRateLimiter } from "./middleware/rateLimiter";
import { errorHandler } from "./middleware/errorHandler";
import { notFoundHandler } from "./middleware/notFound";
import apiRoutes from "./routes";
import healthRoutes from "./modules/health/health.routes";

export function createApp(): Express {
  const app = express();

  // Trust proxy: needed for correct req.ip behind Render/Railway/any
  // reverse proxy or load balancer, which matters for rate limiting.
  app.set("trust proxy", 1);

  app.use(
    helmet({
      contentSecurityPolicy: env.NODE_ENV === "production" ? undefined : false,
    })
  );

  const allowedOrigins = env.CORS_ORIGIN.split(",").map((o) => o.trim());
  app.use(
    cors({
      origin: (origin, callback) => {
        // Allow no-origin requests (mobile apps, curl, server-to-server).
        if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
        callback(new Error("Not allowed by CORS"));
      },
      credentials: true,
    })
  );

  app.use(compression());
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true, limit: "1mb" }));

  // Attach a request ID to every request for correlating logs.
  app.use((req, _res, next) => {
    req.requestId = (req.headers["x-request-id"] as string) || randomUUID();
    next();
  });

  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req as any).requestId,
      customLogLevel: (_req, res, err) => {
        if (err || res.statusCode >= 500) return "error";
        if (res.statusCode >= 400) return "warn";
        return "info";
      },
      // Never log headers/body by default - only method/url/status/duration.
      serializers: {
        req: (req) => ({ method: req.method, url: req.url }),
        res: (res) => ({ statusCode: res.statusCode }),
      },
    })
  );

  app.use(globalRateLimiter);

  app.use("/health", healthRoutes);
  app.use(env.API_PREFIX, apiRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
