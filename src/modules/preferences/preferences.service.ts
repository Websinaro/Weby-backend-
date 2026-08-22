import { prisma } from "../../database/prisma";
import { UpdatePreferencesInput } from "./preferences.schema";

// These are the CLOUD-synchronized preferences only. Device-only data
// (installed apps, contacts, relationship mappings) intentionally has
// no backend model at all - it never leaves the device, per spec.
export async function getPreferences(userId: string) {
  const existing = await prisma.preference.findUnique({ where: { userId } });
  if (existing) return existing;
  return prisma.preference.create({ data: { userId } });
}

export async function updatePreferences(userId: string, input: UpdatePreferencesInput) {
  await getPreferences(userId); // ensures a row exists
  return prisma.preference.update({ where: { userId }, data: input });
}
