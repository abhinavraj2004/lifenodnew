"use client";

import dynamic from 'next/dynamic';
import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabaseClient';

// Dynamic import for the Map component to avoid SSR issues
const RescueMap = dynamic(() => import('../components/RescueMap'), {
    ssr: false,
    loading: () => <div className="loading-map">Sort of Loading Map...</div>
});

// Priority colors (kept for sidebar)
const priorityColors = {
    1: '#e63946', // Critical - Red
    2: '#f4a261', // Warning - Orange
    3: '#ffd166', // Info - Yellow
};

export default function Home() {
    const [messages, setMessages] = useState([]);
    const [sidebarOpen, setSidebarOpen] = useState(false);
    const [selectedSignal, setSelectedSignal] = useState(null);

    // Hazard Alert State
    const [showHazardModal, setShowHazardModal] = useState(false);
    const [hazardForm, setHazardForm] = useState({
        location: 'Idukki Dam',
        description: 'Water level at 2401 ft',
        level: 'CRITICAL' // CRITICAL, HIGH, MEDIUM, LOW
    });

    const handleBroadcastAlert = async () => {
        try {
            const response = await fetch('/api/hazards', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(hazardForm)
            });
            if (response.ok) {
                alert('Hazard Alert Broadcasted Successfully!');
                setShowHazardModal(false);
            } else {
                alert('Failed to broadcast alert.');
            }
        } catch (e) {
            console.error(e);
            alert('Error connecting to server.');
        }
    };



    useEffect(() => {
        const fetchMessages = async () => {
            console.log('Dashboard: Fetching messages...');
            console.log('Dashboard: Supabase URL:', process.env.NEXT_PUBLIC_SUPABASE_URL ? 'Defined' : 'Missing');

            const { data, error } = await supabase
                .from('messages')
                .select('*')
                .order('timestamp', { ascending: false });

            if (data) {
                console.log(`Dashboard: Loaded ${data.length} messages`);
                setMessages(data);
            }
            if (error) {
                console.error('Dashboard: Error loading messages (RAW):', error);
                console.error('Dashboard: Error loading messages (JSON):', JSON.stringify(error, null, 2));
                alert(`Error loading data: ${error.message || JSON.stringify(error)}`);
            }
        };

        fetchMessages();

        // Realtime Subscription
        const channel = supabase
            .channel('messages_channel')
            .on(
                'postgres_changes',
                { event: '*', schema: 'public', table: 'messages' },
                (payload) => {
                    console.log('Realtime update:', payload);
                    fetchMessages(); // Refresh list on any change
                }
            )
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, []);

    const criticalCount = messages.filter(m => m.priority === 1).length;
    const mediumCount = messages.filter(m => m.priority === 2).length;
    const totalCount = messages.length;

    const handleSignalClick = (msg) => {
        setSelectedSignal(msg.id);
        // In full version, we can pass a "flyTo" prop to RescueMap
    };

    return (
        <div className="app-container">
            {/* Hazard Modal */}
            {showHazardModal && (
                <div className="modal-overlay">
                    <div className="modal-content">
                        <h2>⚠️ Broadcast Hazard Alert</h2>
                        <div className="form-group">
                            <label>Location / Source</label>
                            <input
                                type="text"
                                value={hazardForm.location}
                                onChange={e => setHazardForm({ ...hazardForm, location: e.target.value })}
                            />
                        </div>
                        <div className="form-group">
                            <label>Description / Level</label>
                            <input
                                type="text"
                                value={hazardForm.description}
                                onChange={e => setHazardForm({ ...hazardForm, description: e.target.value })}
                            />
                        </div>
                        <div className="form-group">
                            <label>Risk Level</label>
                            <select
                                value={hazardForm.level}
                                onChange={e => setHazardForm({ ...hazardForm, level: e.target.value })}
                            >
                                <option value="CRITICAL">CRITICAL</option>
                                <option value="HIGH">HIGH</option>
                                <option value="MEDIUM">MEDIUM</option>
                                <option value="LOW">LOW</option>
                            </select>
                        </div>
                        <div className="modal-actions">
                            <button className="btn-cancel" onClick={() => setShowHazardModal(false)}>Cancel</button>
                            <button className="btn-danger" onClick={handleBroadcastAlert}>BROADCAST ALERT</button>
                        </div>
                    </div>
                </div>
            )}

            {/* Mobile Toggle */}
            <button
                className="mobile-toggle"
                onClick={() => setSidebarOpen(!sidebarOpen)}
                aria-label="Toggle sidebar"
            >
                {sidebarOpen ? '✕' : '☰'}
            </button>

            {/* Sidebar Overlay (Mobile) */}
            <div
                className={`sidebar-overlay ${sidebarOpen ? 'open' : ''}`}
                onClick={() => setSidebarOpen(false)}
            />

            {/* Sidebar */}
            <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
                <div className="sidebar-header">
                    <h1 className="sidebar-title">RESCUE MESH</h1>
                    <span className="sidebar-subtitle">Command Center</span>
                </div>

                {/* Broadcast Button */}
                <div style={{ padding: '0 20px 20px 20px' }}>
                    <button
                        className="btn-broadcast"
                        onClick={() => setShowHazardModal(true)}
                    >
                        ⚠️ BROADCAST ALERT
                    </button>
                </div>

                {/* Stats Grid */}
                <div className="stats-grid">
                    <div className="stat-card">
                        <div className="stat-icon critical">🚨</div>
                        <div className="stat-content">
                            <div className="stat-label">Critical Signals</div>
                            <div className="stat-value critical">{criticalCount}</div>
                        </div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-icon warning">⚠️</div>
                        <div className="stat-content">
                            <div className="stat-label">Medium Priority</div>
                            <div className="stat-value warning">{mediumCount}</div>
                        </div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-icon info">📡</div>
                        <div className="stat-content">
                            <div className="stat-label">Total Signals</div>
                            <div className="stat-value info">{totalCount}</div>
                        </div>
                    </div>
                </div>

                {/* Signal List */}
                <h3 style={{
                    fontSize: '12px',
                    color: 'rgba(255,255,255,0.5)',
                    textTransform: 'uppercase',
                    letterSpacing: '1px',
                    marginTop: '10px'
                }}>
                    Live Signals
                </h3>
                <div className="signal-list">
                    {messages.map((msg) => (
                        <div
                            key={msg.id}
                            className="signal-item"
                            onClick={() => handleSignalClick(msg)}
                            style={selectedSignal === msg.id ? {
                                borderColor: priorityColors[msg.priority],
                                background: 'rgba(255,255,255,0.08)'
                            } : {}}
                        >
                            <div className={`signal-priority p${msg.priority}`} />
                            <div className="signal-content">
                                <div className="signal-text">{msg.payload}</div>
                                <div className="signal-meta">
                                    <div className="signal-meta">
                                        {msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString() : 'Unknown'} • {msg.lat.toFixed(4)}, {msg.lng.toFixed(4)}
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            </aside>

            {/* Map */}
            <main className="map-container">
                <RescueMap messages={messages} />

                {/* Status Bar */}
                <div className="status-bar">
                    <div className="status-indicator" />
                    <span className="status-text">Mesh Network Active</span>
                    <span className="status-text" style={{ opacity: 0.5 }}>•</span>
                    <span className="status-text">{totalCount} signals tracked</span>
                </div>
            </main>
        </div>
    );
}
