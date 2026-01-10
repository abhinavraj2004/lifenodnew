'use client';

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Priority colors
const priorityColors = {
    1: '#e63946', // Critical - Red
    2: '#f4a261', // Warning - Orange
    3: '#ffd166', // Info - Yellow
};

const priorityLabels = {
    1: 'CRITICAL',
    2: 'MEDIUM',
    3: 'LOW',
};

// Icon creation helper
const createIcon = (priority) => {
    const color = priorityColors[priority] || '#00b4d8';
    return L.divIcon({
        className: 'custom-div-icon',
        html: `
            <div style="
                width: 24px;
                height: 24px;
                background: ${color};
                border-radius: 50%;
                border: 3px solid white;
                box-shadow: 0 0 15px ${color}, 0 4px 8px rgba(0,0,0,0.3);
            "></div>
            <div style="
                width: 40px;
                height: 40px;
                background: ${color};
                opacity: 0.3;
                border-radius: 50%;
                position: absolute;
                top: -8px; 
                left: -8px;
                animation: pulse 2s infinite;
            "></div>
        `,
        iconSize: [24, 24],
        iconAnchor: [12, 12],
        popupAnchor: [0, -12],
    });
};

export default function RescueMap({ messages }) {
    return (
        <MapContainer
            key="rescue-map-container"
            center={[9.9312, 76.2673]}
            zoom={13}
            style={{ height: '100%', width: '100%' }}
            zoomControl={false}
        >
            <TileLayer
                attribution='&copy; <a href="https://carto.com/">CARTO</a>'
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
            />
            {messages.map((msg) => (
                <Marker
                    key={msg.id}
                    position={[msg.lat, msg.lng]}
                    icon={createIcon(msg.priority)}
                >
                    <Popup>
                        <div className={`popup-priority p${msg.priority}`}>
                            {priorityLabels[msg.priority]}
                        </div>
                        <div className="popup-message">{msg.payload}</div>
                        <div className="popup-coords">
                            📍 {msg.lat.toFixed(6)}, {msg.lng.toFixed(6)}
                        </div>
                    </Popup>
                </Marker>
            ))}
        </MapContainer>
    );
}
