# Selisco Cloud Hosting & Deployment Guide

This guide walks you through hosting the **Selisco Cloud Dashboard & API Portal** on cloud providers (such as Vercel, Render, Railway, or Docker) and connecting the mobile client.

---

## 1. Hosting on Vercel (Recommended)

The dashboard and backend services are built with **Next.js 14**, making Vercel the fastest, serverless zero-maintenance hosting solution.

### Step 1: Connect GitHub Repository
1. Log in to [Vercel](https://vercel.com).
2. Click **"Add New..."** → **"Project"**.
3. Import your GitHub repository: `Clinton-Gilly/Selisco-Invoice-APP`.

### Step 2: Configure Project Name & Root Directory
- **Project Name:** Set to `selisco-dashboard` or `selisco-portal` (instead of generic `backend`).
- **Framework Preset:** Next.js
- **Root Directory:** Click "Edit" and set to **`backend`**. *(Crucial step because the Next.js project is in the `backend/` directory)*.

### Step 3: Configure Environment Variables
In the Vercel project settings under **Environment Variables**, add:
- `DATABASE_URL`: Your Neon PostgreSQL connection string:
  ```env
  postgresql://<user>:<password>@<neon-host>/neondb?sslmode=require
  ```
- `NEXT_PUBLIC_APP_URL`: Your live domain (e.g., `https://selisco-dashboard.vercel.app` or custom domain).

### Step 4: Deploy
Click **Deploy**. Vercel will build and serve:
- **Cloud Dashboard:** `https://your-domain.vercel.app/`
- **Mobile APK Download:** `https://your-domain.vercel.app/download`
- **Document Verification:** `https://your-domain.vercel.app/verify/{invoice_id}`
- **REST APIs & AI Copilot:** `https://your-domain.vercel.app/api/*`

---

## 2. Docker & Container Hosting (Render, Railway, Fly.io, VPS)

A production-ready multi-stage `Dockerfile` is provided in `backend/Dockerfile`, along with `docker-compose.yml` in the root.

### Running with Docker Compose:
```bash
# 1. Ensure your DATABASE_URL is set in backend/.env.local or environment
docker compose up -d --build
```
Your dashboard will be available at `http://localhost:3000`.

### Deploying to Render / Railway:
1. Create a new Web Service and link your GitHub repository.
2. Set Root Directory to `backend` (or use Dockerfile build).
3. Set environment variable `DATABASE_URL`.
4. Deploy!

---

## 3. Mobile App Client Configuration

The Flutter mobile application connects to the cloud dashboard and API automatically.

### Overriding the Base URL at Build Time:
When building the mobile app for a custom production domain, you can pass `--dart-define`:
```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.vercel.app
```
By default, if no build flag is passed, it uses the production cloud host configured in `mobile/lib/core/constants/api_constants.dart`.

---

## 4. Key Endpoints Summary

| Endpoint | Purpose |
| :--- | :--- |
| `/` | Selisco Cloud Dashboard & Live Operations Hub |
| `/download` | Mobile APK Download Portal (v1.1.0) |
| `/verify/:id?token=...` | Cryptographic QR Invoice & Delivery Note Verification |
| `/api/invoices` | Invoices CRUD, PDF & WhatsApp Data |
| `/api/delivery-notes` | Delivery Notes & Dispatches |
| `/api/analytics` | Executive Metrics & Cash Flow KPIs |
| `/api/copilot/chat` | AI Copilot Chat Engine & Function Calling |
| `/api/version` | Automated OTA Mobile Update Checker & Download Metadata |
