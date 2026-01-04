import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ExpenseData {
    amount: number
    merchant: string
    raw_message?: string
}

interface CategorizationResult {
    category: string
    confidence: number
    merchant: string
    explanation: string
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { expense }: { expense: ExpenseData } = await req.json()

        // Get OpenAI API key from environment
        const openaiKey = Deno.env.get('OPENAI_API_KEY')
        if (!openaiKey) {
            throw new Error('OpenAI API key not configured')
        }

        // Check merchant rules first
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const authHeader = req.headers.get('Authorization')!
        const token = authHeader.replace('Bearer ', '')
        const { data: { user } } = await supabaseClient.auth.getUser(token)

        if (!user) {
            throw new Error('Unauthorized')
        }

        // Check for existing merchant rules
        const { data: rules } = await supabaseClient
            .from('merchant_rules')
            .select('*')
            .eq('user_id', user.id)
            .ilike('merchant_pattern', `%${expense.merchant}%`)
            .order('confidence', { ascending: false })
            .limit(1)

        if (rules && rules.length > 0) {
            const rule = rules[0]

            // Update rule usage
            await supabaseClient
                .from('merchant_rules')
                .update({ times_used: rule.times_used + 1 })
                .eq('id', rule.id)

            return new Response(
                JSON.stringify({
                    category: rule.category,
                    confidence: rule.confidence,
                    merchant: expense.merchant,
                    explanation: `Learned from previous categorization (used ${rule.times_used + 1} times)`,
                } as CategorizationResult),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Call OpenAI for categorization
        const prompt = `Categorize this expense transaction for an Indian user:
Merchant: ${expense.merchant}
Amount: ₹${expense.amount}
${expense.raw_message ? `SMS: ${expense.raw_message}` : ''}

Return ONLY a JSON object with:
{
  "category": "one of: Food & Dining, Transportation, Shopping, Entertainment, Bills & Utilities, Healthcare, Education, Travel, Groceries, Other",
  "confidence": 0.0-1.0,
  "merchant": "normalized merchant name",
  "explanation": "brief reason for categorization"
}

Consider Indian context: UPI payments, common Indian merchants, local services.`

        const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${openaiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: 'gpt-3.5-turbo',
                messages: [
                    { role: 'system', content: 'You are a financial categorization assistant for Indian users. Always respond with valid JSON only.' },
                    { role: 'user', content: prompt }
                ],
                temperature: 0.3,
                max_tokens: 200,
            }),
        })

        if (!openaiResponse.ok) {
            throw new Error(`OpenAI API error: ${openaiResponse.statusText}`)
        }

        const aiResult = await openaiResponse.json()
        const content = aiResult.choices[0].message.content
        const result: CategorizationResult = JSON.parse(content)

        // If confidence is high, save as a rule
        if (result.confidence >= 0.8) {
            await supabaseClient.from('merchant_rules').insert({
                user_id: user.id,
                merchant_pattern: expense.merchant,
                category: result.category,
                confidence: result.confidence,
                times_used: 1,
            })
        }

        // If confidence is low, queue notification for user confirmation
        if (result.confidence < 0.7) {
            await supabaseClient.from('notification_queue').insert({
                user_id: user.id,
                type: 'categorization_needed',
                title: 'Confirm Expense Category',
                body: `Please confirm category for ${expense.merchant}`,
                data: {
                    expense,
                    suggested_category: result.category,
                    confidence: result.confidence,
                },
            })
        }

        return new Response(
            JSON.stringify(result),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
