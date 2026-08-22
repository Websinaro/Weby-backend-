import { z } from "zod";

export const updatePreferencesSchema = z.object({
  assistantName: z.string().trim().min(1).max(50).optional(),
  wakeWord: z.string().trim().min(2).max(30).optional(),
  language: z.string().trim().min(2).max(10).optional(),
  voice: z.string().trim().min(1).max(50).optional(),
  voiceVerificationEnabled: z.boolean().optional(),
  theme: z.enum(["light", "dark", "system"]).optional(),
  aiProvider: z.enum(["gemini", "huggingface"]).optional(),
  aiModel: z.string().trim().max(100).nullable().optional(),
});

export type UpdatePreferencesInput = z.infer<typeof updatePreferencesSchema>;
