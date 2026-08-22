import { z } from "zod";

export const aiChatSchema = z.object({
  prompt: z.string().trim().min(1, "prompt is required").max(8000),
  conversationId: z.string().uuid().optional(),
  provider: z.enum(["gemini", "huggingface"]).optional(),
});

export type AiChatInput = z.infer<typeof aiChatSchema>;
