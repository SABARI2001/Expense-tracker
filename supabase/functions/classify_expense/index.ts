import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
    try {
        const { description, merchant } = await req.json();

        if (!description && !merchant) {
            return new Response(
                JSON.stringify({ error: "Description or merchant required" }),
                { status: 400, headers: { "Content-Type": "application/json" } }
            );
        }

        // Combine description and merchant for better classification
        const fullText = `${merchant || ''} ${description || ''}`.trim();

        // Try AI classification first
        let category = "Uncategorized";
        let confidence = 0.0;
        let method = "rule-based";

        try {
            const openAiKey = Deno.env.get("OPENAI_API_KEY");

            if (openAiKey) {
                // Call OpenAI for classification
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
                                content: `You are an expense categorization assistant. Categorize expenses into one of these categories:
- Food & Dining
- Groceries
- Transportation
- Shopping
- Entertainment
- Healthcare
- Utilities
- Education
- Travel
- Insurance
- Investment
- Rent
- Personal Care
- Uncategorized

Respond with ONLY the category name and a confidence score (0.0-1.0) in JSON format: {"category": "...", "confidence": 0.95}`
                            },
                            {
                                role: "user",
                                content: `Categorize this expense: "${fullText}"`
                            }
                        ],
                        temperature: 0.3,
                        max_tokens: 50,
                    }),
                });

                if (aiResponse.ok) {
                    const aiData = await aiResponse.json();
                    const content = aiData.choices[0]?.message?.content;

                    if (content) {
                        try {
                            const parsed = JSON.parse(content);
                            category = parsed.category || category;
                            confidence = parsed.confidence || 0.85;
                            method = "ai";
                        } catch (e) {
                            console.error("Failed to parse AI response:", e);
                        }
                    }
                }
            }
        } catch (aiError) {
            console.error("AI classification failed, using fallback:", aiError);
        }

        // Fallback to rule-based if AI didn't work
        if (method === "rule-based") {
            const result = ruleBasedCategorize(fullText);
            category = result.category;
            confidence = result.confidence;
        }

        return new Response(
            JSON.stringify({
                category,
                confidence,
                method,
                original_text: fullText
            }),
            { headers: { "Content-Type": "application/json" } }
        );
    } catch (error) {
        console.error("Error in classify_expense:", error);
        return new Response(
            JSON.stringify({ error: "Internal server error", category: "Uncategorized", confidence: 0.0 }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});

// Rule-based categorization fallback
function ruleBasedCategorize(text: string): { category: string; confidence: number } {
    const lowerText = text.toLowerCase();

    const categories = {
        "Food & Dining": ["restaurant", "cafe", "coffee", "starbucks", "mcdonald", "kfc", "domino", "pizza", "burger", "food", "zomato", "swiggy", "ubereats", "dining"],
        "Groceries": ["grocery", "supermarket", "walmart", "bigbasket", "grofers", "blinkit", "dunzo", "dmart", "reliance", "more"],
        "Transportation": ["uber", "lyft", "ola", "rapido", "taxi", "cab", "metro", "bus", "train", "fuel", "petrol", "diesel", "parking", "toll"],
        "Shopping": ["amazon", "flipkart", "myntra", "ajio", "shopping", "mall", "store", "retail", "clothing", "fashion", "electronics"],
        "Entertainment": ["netflix", "prime", "hotstar", "spotify", "youtube", "movie", "cinema", "pvr", "inox", "game", "gaming"],
        "Healthcare": ["hospital", "clinic", "doctor", "medical", "pharmacy", "medicine", "health", "apollo", "fortis"],
        "Utilities": ["electricity", "water", "gas", "internet", "broadband", "wifi", "mobile", "phone", "recharge", "bill", "airtel", "jio"],
        "Education": ["school", "college", "university", "course", "tuition", "education", "book", "udemy", "coursera"],
        "Travel": ["flight", "hotel", "airbnb", "booking", "makemytrip", "goibibo", "travel", "vacation", "airline"],
        "Insurance": ["insurance", "premium", "policy", "lic"],
        "Investment": ["mutual fund", "sip", "stock", "share", "investment", "zerodha", "groww", "upstox"],
        "Rent": ["rent", "lease", "housing", "apartment", "flat", "maintenance"],
        "Personal Care": ["salon", "spa", "gym", "fitness", "yoga", "beauty", "cosmetic", "haircut"],
    };

    for (const [category, keywords] of Object.entries(categories)) {
        for (const keyword of keywords) {
            if (lowerText.includes(keyword)) {
                return { category, confidence: 0.85 };
            }
        }
    }

    return { category: "Uncategorized", confidence: 0.5 };
}
