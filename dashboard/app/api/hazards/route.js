import { supabase } from '../../../lib/supabaseClient'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'; // Ensure no caching

export async function GET() {
    console.log('API: GET /api/hazards detected');
    try {
        // Get the latest hazard alert
        console.log('API: Querying Supabase...');
        const { data, error } = await supabase
            .from('hazards')
            .select('*')
            .order('updated_at', { ascending: false })
            .limit(1)

        if (error) {
            console.error('API: Supabase Error:', error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        console.log('API: Data retrieved:', data);

        if (!data || data.length === 0) {
            // Return default/empty if no hazards
            return NextResponse.json({
                dam: "None",
                level: "N/A",
                risk: "LOW",
                updated: "Never"
            })
        }

        return NextResponse.json(data[0])

    } catch (e) {
        console.error('API: Critical Error:', e)
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
    }
}

export async function POST(request) {
    console.log('API: POST /api/hazards detected');
    try {
        const body = await request.json()
        // Body expected: { type, level, description, location }
        console.log('API: Body:', body);

        const { data, error } = await supabase
            .from('hazards')
            .insert([body])
            .select()

        if (error) {
            console.error('Supabase Error:', error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        return NextResponse.json({ message: 'Hazard broadcasted', data })

    } catch (e) {
        console.error('Hazard API Error:', e)
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
    }
}
