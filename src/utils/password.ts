import argon2 from "argon2";

// Argon2id is the OWASP-recommended variant: resistant to both GPU
// cracking and side-channel attacks. Parameters below follow current
// OWASP baseline guidance and can be tuned for your hardware.
const HASH_OPTIONS: argon2.Options = {
  type: argon2.argon2id,
  memoryCost: 19456, // ~19 MB
  timeCost: 2,
  parallelism: 1,
};

export async function hashPassword(plain: string): Promise<string> {
  return argon2.hash(plain, HASH_OPTIONS);
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plain);
  } catch {
    // Malformed hash or verification failure - treat as invalid credentials,
    // never throw this upward as it could leak information via stack traces.
    return false;
  }
}
