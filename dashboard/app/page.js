"use client";

import dynamic from 'next/dynamic';
import React, { useEffect, useState } from 'react';

// Dynamic import for Leaflet to avoid SSR issues
const MapContainer = dynamic(() => import('react-leaflet').then(mod => mod.MapContainer), { ssr: false });
const TileLayer = dynamic(() => import('react-leaflet').then(mod => mod.TileLayer), { ssr: false });
const Marker = dynamic(() => import('react-leaflet').then(mod => mod.Marker), { ssr: false });
const Popup = dynamic(() => import('react-leaflet').then(mod => mod.Popup), { ssr: false });

export default function Home() {
    const [messages, setMessages] = useState([]);

    useEffect(() => {
        // Mock fetching data from Supabase
        const mockData = [
            { id: '1', lat: 9.9312, lng: 76.2673, priority: 1, payload: 'MEDICAL: Leg injury' },
            { id: '2', lat: 9.9350, lng: 76.2700, priority: 2, payload: 'FOOD: Need water' },
            { id: '3', lat: 9.9400, lng: 76.2600, priority: 1, payload: 'SOS: Trapped on roof' },
        ];
        setMessages(mockData);

        // In real app: supabase.from('messages').select('*')...
    }, []);

    return (
        <main style={{ height: '100vh', width: '100%' }}>
            <div style={{ position: 'absolute', zIndex: 1000, top: 20, left: 20, background: 'white', padding: 20, borderRadius: 8 }}>
                <h1>Rescue Command Center</h1>
                <p>Live Signals: {messages.length}</p>
            </div>

            <MapContainer center={[9.9312, 76.2673]} zoom={13} style={{ height: '100%', width: '100%' }}>
                <TileLayer
                    attribution='&copy; OpenStreetMap contributors'
                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />
                {messages.map((msg) => (
                    <Marker key={msg.id} position={[msg.lat, msg.lng]}>
                        <Popup>
                            <strong>Priority: {msg.priority}</strong><br />
                            {msg.payload}
                        </Popup>
                    </Marker>
                ))}
            </MapContainer>
        </main>
    );
}
