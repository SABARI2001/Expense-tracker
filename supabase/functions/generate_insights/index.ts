import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
    try {
        // Get authorization header
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: "Authorization required" }),
                { status: 401, headers: { "Content-Type": "application/json" } }
            );
        }

        // Initialize Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
        const supabase = createClient(supabaseUrl, supabaseKey, {
            global: {
                headers: { Authorization: authHeader },
            },
        });

        // Get authenticated user
        const { data: { user }, error: authError } = await supabase.auth.getUser();

        if (authError || !user) {
            return new Response(
                JSON.stringify({ error: "Invalid authentication" }),
                { status: 401, headers: { "Content-Type": "application/json" } }
            );
        }

        // Check user's subscription tier and role
        const { data: subscription } = await supabase
            .from('subscriptions')
            .select('tier')
            .eq('user_id', user.id)
            .maybeSingle();

        const { data: userRole } = await supabase
            .from('user_roles')
            .select('role')
            .eq('user_id', user.id)
            .single();

        const isPremium = subscription?.tier === 'premium';
        const isAdmin = userRole?.role === 'admin';

        // Enforce premium access (admins bypass)
        if (!isPremium && !isAdmin) {
            return new Response(
                JSON.stringify({
                    error: "Premium subscription required",
                    upgrade_required: true
                }),
                { status: 403, headers: { "Content-Type": "application/json" } }
            );
        }

        // Get request body
        const { expenses, timeframe } = await req.json();

        if (!expenses || !Array.isArray(expenses) || expenses.length === 0) {
            return new Response(
                JSON.stringify({ error: "No expenses provided" }),
                { status: 400, headers: { "Content-Type": "application/json" } }
            );
        }

        // Generate insights using OpenAI
        const openAiKey = Deno.env.get("OPENAI_API_KEY");

        if (!openAiKey) {
            // Fallback to basic insights if no API key
            const basicInsights = generateBasicInsights(expenses);
            return new Response(
                JSON.stringify({
                    insights: basicInsights,
                    method: "basic",
                    user_id: user.id
                }),
                { headers: { "Content-Type": "application/json" } }
            );
        }

        // Prepare expense summary for AI
        const expenseSummary = expenses.map(e => ({
            category: e.category,
            amount: e.amount,
            merchant: e.merchant,
            date: e.date
        }));

        const totalSpent = expenses.reduce((sum, e) => sum + (e.amount || 0), 0);
        const categoryBreakdown = expenses.reduce((acc, e) => {
            acc[e.category] = (acc[e.category] || 0) + e.amount;
            return acc;
        }, {} as Record<string, number>);

        // Call OpenAI for insights
        const aiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${openAiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                model: "gpt-3.5-turbo",
                messages: [
                    {
                        role: "system",
                        content: `You are a financial advisor analyzing spending patterns. Provide actionable insights, identify trends, and suggest improvements. Be concise and helpful.`
                    },
                    {
                        role: "user",
                        content: `Analyze these expenses:
Total Spent: ₹${totalSpent.toFixed(2)}
Timeframe: ${timeframe || 'Last 30 days'}
Category Breakdown: ${JSON.stringify(categoryBreakdown, null, 2)}
Number of Transactions: ${expenses.length}

Provide 3-5 key insights about spending patterns, potential savings, and recommendations.`
                    }
                ],
                temperature: 0.7,
                max_tokens: 500,
            }),
        });

        if (!aiResponse.ok) {
            throw new Error(`OpenAI API error: ${aiResponse.statusText}`);
        }

        const aiData = await aiResponse.json();
        const insights = aiData.choices[0]?.message?.content || "No insights generated";

        return new Response(
            JSON.stringify({
                insights,
                method: "ai",
                user_id: user.id,
                total_spent: totalSpent,
                transaction_count: expenses.length,
                category_breakdown: categoryBreakdown
            }),
            { headers: { "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Error in generate_insights:", error);
        return new Response(
            JSON.stringify({ error: "Internal server error", details: error.message }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});

// Fallback basic insights generator
function generateBasicInsights(expenses: any[]): string {
    const total = expenses.reduce((sum, e) => sum + (e.amount || 0), 0);
    const avgPerTransaction = total / expenses.length;

    const categoryTotals = expenses.reduce((acc, e) => {
        acc[e.category] = (acc[e.category] || 0) + e.amount;
        return acc;
    }, {} as Record<string, number>);

    const topCategory = Object.entries(categoryTotals)
        .sort(([, a], [, b]) => b - a)[0];

    return `Basic Spending Analysis:
• Total spent: ₹${total.toFixed(2)} across ${expenses.length} transactions
• Average per transaction: ₹${avgPerTransaction.toFixed(2)}
• Highest spending category: ${topCategory[0]} (₹${topCategory[1].toFixed(2)})
• Consider setting budgets for your top spending categories
• Track recurring expenses to identify potential savings`;
}
