# Rescue Command Center

This is a Next.js dashboard for visualizing Rescue Mesh signals in real-time.

## Features
- **Real-time Map**: Visualizes SOS signals using `react-leaflet`.
- **Live Sync**: Connects to Supabase for real-time data updates.
- **API Endpoint**: Provides `/api/sync` for the mobile app to upload mesh data.

## Setup Instructions

### 1. Supabase Setup
1. Create a project at [supabase.com](https://supabase.com).
2. Go to the **SQL Editor** and run this script to create the table:
   ```sql
   create table messages (
     id text primary key,
     payload text,
     lat float8,
     lng float8,
     timestamp int8,
     priority int,
     created_at timestamptz default now(),
     status text default 'synced'
   );
   ```

### 2. Environment Variables
Create a `.env.local` file in this directory (`dashboard/.env.local`):

```bash
NEXT_PUBLIC_SUPABASE_URL=your_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

### 3. Run the Dashboard
```bash
# Install dependencies
npm install

# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the Control Center.

### 4. Connect Mobile App
In the Flutter app (Gateway Node), ensure the `cloudEndpoint` points to your computer's IP:
- Example: `http://192.168.1.5:3000/api/sync`
- *(Note: `localhost` won't work from an Android Emulator/Phone, use your local network IP)*
