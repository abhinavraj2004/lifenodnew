import { createClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic';

export async function POST(request) {
    console.log('API: POST /api/sync detected');
    try {
        const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
        const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
        const supabase = createClient(supabaseUrl, supabaseKey)

        const messages = await request.json()

        if (!Array.isArray(messages)) {
            return NextResponse.json(
                { error: 'Invalid body, expected array of messages' },
                { status: 400 }
            )
        }

        if (messages.length === 0) {
            return NextResponse.json({ message: 'No messages to sync' })
        }

        // Map fields if necessary, but assuming app sends matching JSON keys
        const { data, error } = await supabase
            .from('messages')
            .upsert(messages, { onConflict: 'id' })

        if (error) {
            console.error('Supabase Error:', error)
            return NextResponse.json({ error: error.message }, { status: 500 })
        }

        return NextResponse.json({
            message: 'Sync successful',
            count: messages.length
        })

    } catch (e) {
        console.error('Sync API Error:', e)
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
    }
}
