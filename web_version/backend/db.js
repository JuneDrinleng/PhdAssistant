// db.js — 精简后（仅连接 + 表级自动建表/迁移）
import { Pool } from "pg";
import dotenv from "dotenv";
dotenv.config();

const DATABASE_URL = process.env.DATABASE_URL;
const USE_SSL =
  String(process.env.PGSSL || "").toLowerCase() === "true"
    ? { rejectUnauthorized: false }
    : undefined;

export const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: USE_SSL,
});

/** 启动时初始化/迁移表结构（多用户隔离：每表都有 user_id 外键） */
export async function initSchema() {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // 1) 用户表（账号 + 密码哈希）
    await client.query(`
      CREATE TABLE IF NOT EXISTS app_user (
        id BIGSERIAL PRIMARY KEY,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    // 2) 单词表（每用户一套）
    await client.query(`
      CREATE TABLE IF NOT EXISTS words (
        id BIGSERIAL PRIMARY KEY,
        en TEXT NOT NULL,
        zh TEXT NOT NULL
      );
      ALTER TABLE words
        ADD COLUMN IF NOT EXISTS user_id BIGINT
          REFERENCES app_user(id) ON DELETE CASCADE;
      DO $$
      BEGIN
        -- 建"唯一约束"（而不是仅唯一索引），方便后端用 ON CONFLICT ON CONSTRAINT
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'uq_words_user_en'
        ) THEN
          ALTER TABLE words
            ADD CONSTRAINT uq_words_user_en UNIQUE (user_id, en);
        END IF;
      END $$;
    `);

    // 3) 电费（每用户一套）
    await client.query(`
      CREATE TABLE IF NOT EXISTS electricity_bill (
        id BIGSERIAL PRIMARY KEY,
        record_time TIMESTAMPTZ NOT NULL,
        fee_amount  NUMERIC(12,2) NOT NULL
      );
      ALTER TABLE electricity_bill
        ADD COLUMN IF NOT EXISTS user_id BIGINT
          REFERENCES app_user(id) ON DELETE CASCADE;
      CREATE INDEX IF NOT EXISTS idx_bill_user_time
        ON electricity_bill(user_id, record_time DESC);
    `);

    // 4) 专注会话（每用户一套）
    await client.query(`
      CREATE TABLE IF NOT EXISTS focus_session (
        id BIGSERIAL PRIMARY KEY,
        start_time TIMESTAMPTZ NOT NULL,
        end_time   TIMESTAMPTZ NOT NULL,
        task       TEXT NOT NULL
      );
      ALTER TABLE focus_session
        ADD COLUMN IF NOT EXISTS user_id BIGINT
          REFERENCES app_user(id) ON DELETE CASCADE;
      CREATE INDEX IF NOT EXISTS idx_focus_user_start
        ON focus_session(user_id, start_time DESC);
    `);

    await client.query("COMMIT");
    console.log("✅ schema ready (tables & constraints ensured)");
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("schema init error:", e);
    throw e;
  } finally {
    client.release();
  }
}
