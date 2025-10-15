// service.js — 多用户账号登录 + JWT 鉴权 + 按 user_id 隔离
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { pool, initSchema } from "./db.js";
import { format } from "fast-csv";
import archiver from "archiver";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "change-me";

// 若部署在反向代理后，可按需开启
if (String(process.env.TRUST_PROXY || "").toLowerCase() === "true") {
  app.set("trust proxy", true);
}

app.use(cors());
app.use(express.json());

/* =================== Auth 工具函数 =================== */
function signToken(user) {
  // payload 里放最小必要信息
  return jwt.sign({ sub: user.id, username: user.username }, JWT_SECRET, {
    expiresIn: "7d",
  });
}

function requireAuth(req, res, next) {
  const raw = req.headers.authorization || "";
  const token = raw.replace(/^Bearer\s+/i, "");
  if (!token) return res.status(401).json({ error: "Unauthorized" });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = { id: payload.sub, username: payload.username };
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
}
// 放在路由最上面任意位置
app.get("/health", (_req, res) => res.status(200).send("ok"));
/* =================== Auth 路由 =================== */
// 注册
app.post("/auth/register", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: "missing username or password" });
  }
  try {
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      `INSERT INTO app_user (username, password_hash)
       VALUES ($1,$2)
       ON CONFLICT (username) DO NOTHING
       RETURNING id, username`,
      [username, hash]
    );
    if (!rows.length) return res.status(409).json({ error: "username exists" });
    const token = signToken(rows[0]);
    res.status(201).json({ token, user: rows[0] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 登录
app.post("/auth/login", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: "missing username or password" });
  }
  try {
    const { rows } = await pool.query(
      "SELECT id, username, password_hash FROM app_user WHERE username=$1",
      [username]
    );
    if (!rows.length) return res.status(401).json({ error: "invalid creds" });
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: "invalid creds" });
    const token = signToken(rows[0]);
    res.json({ token, user: { id: rows[0].id, username: rows[0].username } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 当前用户
app.get("/auth/me", requireAuth, (req, res) => res.json({ user: req.user }));

/* =================== 数据导出（按用户） =================== */
app.get("/db/export", requireAuth, async (req, res) => {
  const ts = new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
  res.setHeader("Content-Disposition", `attachment; filename=db-${ts}.zip`);
  res.setHeader("Content-Type", "application/zip");

  const zip = archiver("zip", { zlib: { level: 9 } });
  zip.on("error", (err) => res.destroy(err));
  zip.pipe(res);

  try {
    const tables = [
      {
        name: "words",
        sql: "SELECT * FROM words WHERE user_id=$1 ORDER BY en",
      },
      {
        name: "electricity_bill",
        sql: "SELECT * FROM electricity_bill WHERE user_id=$1 ORDER BY record_time DESC",
      },
      {
        name: "focus_session",
        sql: "SELECT * FROM focus_session WHERE user_id=$1 ORDER BY start_time DESC",
      },
    ];
    for (const t of tables) {
      const { rows } = await pool.query(t.sql, [req.user.id]);
      const csvStream = format({ headers: true });
      zip.append(csvStream, { name: `${t.name}.csv` });
      rows.forEach((r) => csvStream.write(r));
      csvStream.end();
    }
    await zip.finalize();
  } catch (e) {
    if (!res.headersSent) res.status(500).json({ error: e.message });
  }
});

/* =================== 单词本（按用户隔离） =================== */
// 查询
app.get("/words", requireAuth, async (req, res) => {
  const kw = req.query.q;
  const sql = kw
    ? "SELECT * FROM words WHERE user_id=$1 AND (en ILIKE $2 OR zh ILIKE $2) ORDER BY en"
    : "SELECT * FROM words WHERE user_id=$1 ORDER BY en";
  const args = kw ? [req.user.id, `%${kw}%`] : [req.user.id];
  try {
    const { rows } = await pool.query(sql, args);
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 新增（同一用户下 en 唯一；重复返回 409）
app.post("/words", requireAuth, async (req, res) => {
  const { en, zh } = req.body || {};
  if (!en || !zh) return res.status(400).json({ error: "missing en or zh" });
  try {
    const { rowCount } = await pool.query(
      `INSERT INTO words (en, zh, user_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, en) DO NOTHING
       RETURNING id`,
      [en, zh, req.user.id]
    );
    if (rowCount === 0) return res.sendStatus(409); // 重复
    res.sendStatus(201);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 更新（唯一冲突 409）
app.put("/words/:id", requireAuth, async (req, res) => {
  const { en, zh } = req.body || {};
  if (!en || !zh) return res.status(400).json({ error: "missing en or zh" });
  try {
    await pool.query(
      "UPDATE words SET en=$1, zh=$2 WHERE id=$3 AND user_id=$4",
      [en, zh, req.params.id, req.user.id]
    );
    res.sendStatus(204);
  } catch (e) {
    if (e.code === "23505") return res.sendStatus(409); // 唯一性冲突
    res.status(500).json({ error: e.message });
  }
});

// 删除单条
app.delete("/words/:id", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM words WHERE id=$1 AND user_id=$2", [
      req.params.id,
      req.user.id,
    ]);
    res.sendStatus(204);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 清空当前用户词条
app.delete("/words", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM words WHERE user_id=$1", [req.user.id]);
    res.sendStatus(204);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/* =================== 电费（按用户隔离） =================== */
app.get("/bills", requireAuth, async (req, res) => {
  const limit = parseInt(req.query.limit, 10) || 100;
  const since = req.query.since || "1970-01-01 00:00:00";
  try {
    const { rows } = await pool.query(
      `SELECT record_time, fee_amount
         FROM electricity_bill
        WHERE user_id=$1 AND record_time >= $2
        ORDER BY record_time DESC
        LIMIT $3`,
      [req.user.id, since, limit]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/bills", requireAuth, async (req, res) => {
  const { record_time, fee_amount } = req.body || {};
  if (!record_time || fee_amount === undefined) {
    return res.status(400).json({ error: "missing record_time or fee_amount" });
  }
  try {
    await pool.query(
      `INSERT INTO electricity_bill (record_time, fee_amount, user_id)
       VALUES ($1, $2, $3)`,
      [record_time, fee_amount, req.user.id]
    );
    res.sendStatus(201);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/* =================== 专注会话（按用户隔离） =================== */
app.get("/focus", requireAuth, async (req, res) => {
  const limit = parseInt(req.query.limit, 10) || 100;
  const since = req.query.since || "1970-01-01 00:00:00";
  try {
    const { rows } = await pool.query(
      `SELECT id, start_time, end_time, task
         FROM focus_session
        WHERE user_id=$1 AND start_time >= $2
        ORDER BY start_time DESC
        LIMIT $3`,
      [req.user.id, since, limit]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post("/focus", requireAuth, async (req, res) => {
  const { start_time, end_time, task } = req.body || {};
  if (!start_time || !end_time || !task) {
    return res
      .status(400)
      .json({ error: "missing start_time, end_time or task" });
  }
  try {
    await pool.query(
      `INSERT INTO focus_session (start_time, end_time, task, user_id)
       VALUES ($1,$2,$3,$4)`,
      [start_time, end_time, task, req.user.id]
    );
    res.sendStatus(201);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.put("/focus/:id", requireAuth, async (req, res) => {
  const { start_time, end_time, task } = req.body || {};
  if (!start_time || !end_time || !task) {
    return res
      .status(400)
      .json({ error: "missing start_time, end_time or task" });
  }
  try {
    await pool.query(
      `UPDATE focus_session
          SET start_time=$1, end_time=$2, task=$3
        WHERE id=$4 AND user_id=$5`,
      [start_time, end_time, task, req.params.id, req.user.id]
    );
    res.sendStatus(204);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete("/focus/:id", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM focus_session WHERE id=$1 AND user_id=$2", [
      req.params.id,
      req.user.id,
    ]);
    res.sendStatus(204);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete("/focus", requireAuth, async (req, res) => {
  try {
    await pool.query("DELETE FROM focus_session WHERE user_id=$1", [
      req.user.id,
    ]);
    res.sendStatus(204);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/* =================== 启动：先初始化表结构，再监听端口 =================== */
(async () => {
  await initSchema(); // 表级自动建表/迁移（按 user_id）
  app.listen(port, () => console.log(`👍 API running on :${port}`));
})();
