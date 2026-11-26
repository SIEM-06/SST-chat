# NØLL CHAT

![HTML](https://img.shields.io/badge/HTML%2FCSS%2FJS-single%20file-E34F26?logo=html5&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Auth%20%7C%20Realtime%20%7C%20Storage-3ECF8E?logo=supabase&logoColor=white)
![WebRTC](https://img.shields.io/badge/WebRTC-voice%20rooms-333?logo=webrtc)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

A Discord-style real-time chat app with **text channels, voice rooms, reactions, file sharing, presence and an admin panel**. It is built as a single HTML file on top of **Supabase** (Auth, Postgres, Realtime and Storage) and **WebRTC**.

**🔗 Live demo:** https://sst-chat.vercel.app

---

## Features

**Messaging**
- Real-time text channels powered by Supabase `postgres_changes`
- Replies with quoted excerpts, plus editing and deleting your own messages
- Emoji reactions with live counters
- File and image attachments (Supabase Storage)
- Typing indicators sent over Realtime broadcast
- Paginated message history ("load older messages")

**Voice**
- Voice rooms using a **WebRTC peer-to-peer mesh**, with Supabase Realtime as the signalling channel
- "Speaking" indicator, mute and push-to-talk

**Presence & profiles**
- Online / away / do-not-disturb / invisible status using Realtime Presence
- Custom status, bio, avatar colour and accent colour
- Sound and desktop notifications

**Moderation**
- Role-based admin panel: create, rename and delete channels, promote users and ban or unban them
- Permissions are enforced **server-side with Row Level Security**, not just hidden in the UI (see [`supabase/schema.sql`](supabase/schema.sql))

## Architecture

```
                ┌──────────────── Supabase ────────────────┐
 Browser ──────▶│ Auth  │ Postgres + RLS │ Realtime │ Storage │
 (index.html)   └──────────────────────┬───────────────────┘
     ▲                                 │ broadcast: signalling
     │       WebRTC audio (P2P mesh)   ▼
     └──────────────────────────▶ other browsers
```

| Concern | Implementation |
|---|---|
| Auth | Supabase email + password |
| Data | `profiles`, `channels`, `messages`, `reactions` tables |
| Live updates | `postgres_changes` subscriptions per table |
| Typing / voice signalling | Realtime **broadcast** channels |
| Online users / voice participants | Realtime **presence** |
| Attachments | Public `attachments` storage bucket |
| Security | RLS policies plus a trigger that prevents users from changing their own role or ban status |

## Setup

1. Create a project on [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run [`supabase/schema.sql`](supabase/schema.sql). This creates the tables, RLS policies, realtime publication, storage bucket and a default `#genel` channel.
3. In `index.html`, set your project values:
   ```js
   const SUPABASE_URL = "https://YOUR-PROJECT.supabase.co";
   const SUPABASE_ANON_KEY = "sb_publishable_...";
   ```
   The publishable (anon) key is designed to be public. Your data is protected by the RLS policies.
4. Serve the folder (`npx serve .`) or deploy it as a static site on Vercel or Netlify.
5. Sign up, then make yourself an admin from the SQL Editor:
   ```sql
   update public.profiles set role = 'admin' where username = 'YOUR_USERNAME';
   ```

> Voice uses public STUN servers only. Users behind strict NATs may need a TURN server, which you can add to `ICE_SERVERS` in `index.html`.

## Tech stack

Vanilla JavaScript · HTML/CSS · Supabase (Auth, Postgres, Row Level Security, Realtime, Storage) · WebRTC · Vercel

---

## 🇹🇷 Türkçe özet

Discord tarzı, gerçek zamanlı bir sohbet uygulaması. Metin kanalları, **WebRTC sesli odalar**, emoji tepkileri, dosya paylaşımı, çevrimiçi durumu ve yönetim paneli içerir. Tek bir HTML dosyası olarak yazılmıştır ve arka planda Supabase'in Auth, Postgres, Realtime ve Storage servislerini kullanır. Yetkiler arayüzde gizlenmekle kalmaz, **sunucu tarafında RLS kurallarıyla** da korunur. Kurulum için `supabase/schema.sql` dosyasını Supabase SQL Editor'de çalıştırmak yeterlidir.

## License

[MIT](LICENSE) © 2026 Arda Furkan Deveci
