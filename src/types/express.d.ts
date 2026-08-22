// Augments Express's Request type with the authenticated user id,
// populated by the `authenticate` middleware after verifying the JWT.
export {};

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      requestId?: string;
    }
  }
}
