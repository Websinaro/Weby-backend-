import { prisma } from "../../database/prisma";
import { ApiError } from "../../utils/ApiError";

export async function updateProfile(userId: string, data: { name?: string; avatarUrl?: string }) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw ApiError.notFound("User not found");

  return prisma.user.update({
    where: { id: userId },
    data,
    select: {
      id: true,
      email: true,
      name: true,
      avatarUrl: true,
      authProvider: true,
      emailVerified: true,
    },
  });
}
