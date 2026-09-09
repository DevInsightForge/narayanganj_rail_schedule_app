# Supabase Free Tier Setup & Operational Guide
**Narayanganj Commuter: Zero-Backend Transit Delay Engine**

---

## 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and log in.
2. Click **New Project**.
3. Choose a project name (e.g., `narayanganj-rail-api`).
4. Set a secure database password.
5. **Region:** Select **Singapore (`ap-southeast-1`)** or **Mumbai (`ap-south-1`)** for minimal latency from Bangladesh (~40–60ms).
6. Pricing Tier: **Free ($0/month)**.
7. Click **Create new project**.

---

## 2. Apply Database Schema & Anti-Spam Migration
1. In your Supabase Project Dashboard, click on **SQL Editor** in the left navigation sidebar.
2. Click **New query**.
3. Open [`supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql) in this repository, copy its entire contents, and paste it into the query editor.
4. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`).
5. Verify that the output shows `Success. No rows returned`.

This creates:
- `session_snapshots` table (read-only for anon).
- `report_ledger` table (partitioned by date, sealed RLS).
- `device_rate_limits` table (lockless cooldown tracker).
- `maintain_report_partitions()` cron task scheduled for 03:00 UTC daily.
- `submit_arrival_report()` atomic `SECURITY DEFINER` stored procedure.
- `get_active_board_overlay()` single-roundtrip read RPC function.

---

## 3. Retrieve API Credentials & Configure Environment
1. In the Supabase Dashboard, go to **Project Settings** (gear icon) $\to$ **API**.
2. Find:
   - **Project URL**: e.g., `https://abcdefghijklm.supabase.co`
   - **Project API Keys** $\to$ `anon` / `public`: e.g., `eyJhbGciOi...`
3. In your local Flutter workspace, create or update `.env`:
   ```env
   COMMUNITY_API_ENABLED=true
   COMMUNITY_API_BASE_URL=https://abcdefghijklm.supabase.co
   COMMUNITY_API_KEY=eyJhbGciOi...
   ```
4. For CI/CD (GitHub Actions), add repository secrets:
   - `COMMUNITY_API_BASE_URL`
   - `COMMUNITY_API_KEY`

---

## 4. Free External Keep-Alive Heartbeat (Preventing 7-Day Inactivity Pause)
Supabase pauses free tier databases if no queries occur for 7 consecutive days. Because GitHub Actions automatically disables scheduled workflows after 60 days of repository inactivity, use a free external uptime service.

### Recommended: [Cron-job.org](https://cron-job.org) or [UptimeRobot](https://uptimerobot.com)
1. Register for a free account on [cron-job.org](https://cron-job.org).
2. Create a new cron job:
   - **Title**: `Narayanganj Rail Supabase Heartbeat`
   - **URL**: `https://your-project-id.supabase.co/rest/v1/session_snapshots?limit=1`
   - **Schedule**: Every 6 hours (e.g. `0 */6 * * *`)
   - **Request Method**: `GET`
   - **Headers**:
     - `apikey`: `<your-supabase-anon-key>`
     - `Authorization`: `Bearer <your-supabase-anon-key>`
3. Save the job.
4. This ensures a 0.5ms query executes 4 times a day, keeping the database permanently active without paying for Pro.
