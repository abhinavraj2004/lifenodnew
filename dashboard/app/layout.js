import 'leaflet/dist/leaflet.css';

export const metadata = {
    title: 'Rescue Command Center',
    description: 'Real-time disaster response dashboard',
}

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <body>{children}</body>
        </html>
    )
}
