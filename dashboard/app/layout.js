import 'leaflet/dist/leaflet.css';
import './globals.css';
import { Inter } from 'next/font/google'

export const metadata = {
    title: 'Rescue Mesh - Command Center',
    description: 'Real-time disaster response dashboard with mesh network visualization',
}

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <head>
                <link rel="preconnect" href="https://fonts.googleapis.com" />
                <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&display=swap" rel="stylesheet" />
            </head>
            <body>{children}</body>
        </html>
    )
}
