import request from "supertest";
import { createApp } from "../src/app";
import { prisma } from "../src/database/prisma";

// Requires a live Postgres test database - see auth.test.ts header comment.
const app = createApp();

const userA = {
  name: "Owner",
  email: `weby-conv-a-${Date.now()}@example.com`,
  password: "correct-horse-battery-staple",
};
const userB = {
  name: "Intruder",
  email: `weby-conv-b-${Date.now()}@example.com`,
  password: "correct-horse-battery-staple",
};

let tokenA: string;
let tokenB: string;
let conversationId: string;

beforeAll(async () => {
  const a = await request(app).post("/api/v1/auth/register").send(userA);
  tokenA = a.body.data.accessToken;
  const b = await request(app).post("/api/v1/auth/register").send(userB);
  tokenB = b.body.data.accessToken;
});

afterAll(async () => {
  await prisma.user.deleteMany({ where: { email: { in: [userA.email, userB.email] } } });
  await prisma.$disconnect();
});

describe("Conversation ownership", () => {
  it("creates a conversation for the authenticated user", async () => {
    const res = await request(app)
      .post("/api/v1/conversations")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ title: "Test conversation" });
    expect(res.status).toBe(201);
    conversationId = res.body.data.id;
  });

  it("lets the owner read their conversation", async () => {
    const res = await request(app)
      .get(`/api/v1/conversations/${conversationId}`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(res.status).toBe(200);
  });

  it("blocks a different user from reading it (404, not 403, to avoid leaking existence)", async () => {
    const res = await request(app)
      .get(`/api/v1/conversations/${conversationId}`)
      .set("Authorization", `Bearer ${tokenB}`);
    expect(res.status).toBe(404);
  });

  it("blocks a different user from posting messages into it", async () => {
    const res = await request(app)
      .post(`/api/v1/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${tokenB}`)
      .send({ role: "user", content: "hi" });
    expect(res.status).toBe(404);
  });

  it("allows the owner to add and list messages", async () => {
    const create = await request(app)
      .post(`/api/v1/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ role: "user", content: "Hello Weby" });
    expect(create.status).toBe(201);

    const list = await request(app)
      .get(`/api/v1/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${tokenA}`);
    expect(list.status).toBe(200);
    expect(list.body.data.items.length).toBe(1);
  });

  it("paginates the conversation list", async () => {
    const res = await request(app)
      .get("/api/v1/conversations?page=1&limit=1")
      .set("Authorization", `Bearer ${tokenA}`);
    expect(res.status).toBe(200);
    expect(res.body.data.items.length).toBeLessThanOrEqual(1);
    expect(res.body.data.limit).toBe(1);
  });

  it("validates message role input", async () => {
    const res = await request(app)
      .post(`/api/v1/conversations/${conversationId}/messages`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ role: "not-a-role", content: "x" });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe("VALIDATION_ERROR");
  });
});
