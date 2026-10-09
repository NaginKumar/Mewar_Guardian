import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const body = await request.json();
    const { category, location, description, prompt, mode, history } = body;

    const apiKey = process.env.GROQ_API_KEY;
    // Conversational Chatbot Mode using Groq `openai/gpt-oss-120b`
    if (mode === 'chat') {
      const formattedHistory = Array.isArray(history)
        ? history.map((m) => ({
            role: m.sender === 'user' ? 'user' : 'assistant',
            content: m.text
          }))
        : [];

      const systemMessage = {
        role: 'system',
        content: `You are Rakshak AI, a helpful, protective, intelligent, and friendly Campus Safety & General AI Assistant.
- Answer ANY question the user asks naturally in Hinglish, Hindi, or English.
- Give detailed, conversational, distinct, and accurate answers to every message. Never give canned or repeated identical responses.
- If the user talks about safety, night time travel, or emergency help, give actionable safety advice.`
      };

      const messagesPayload = [
        systemMessage,
        ...formattedHistory,
        { role: 'user', content: prompt || 'Hello' }
      ];

      if (apiKey) {
        try {
          const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${apiKey}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              model: 'openai/gpt-oss-120b',
              messages: messagesPayload,
              max_tokens: 500,
              temperature: 0.7
            })
          });

          const data = await groqRes.json();
          if (data.choices?.[0]?.message?.content) {
            return NextResponse.json({ response: data.choices[0].message.content });
          }
        } catch (err) {
          console.error('Groq API Chat Error:', err);
        }
      }

      // Dynamic Conversational Fallback
      return NextResponse.json({
        response: `Namaste! Aapne pucha: "${prompt}". Main Rakshak AI aapki campus safety aur queries me puri madad kar sakta hoon. Aap kya jaan na chahte hain?`
      });
    }

    // Emergency incident classification mode
    const systemPrompt = `You are Rakshak AI's Emergency Classifier. Evaluate this campus emergency report:
Category: ${category}
Location: ${location}
Description: ${description || 'Emergency SOS triggered'}

Respond strictly with a JSON object in this format:
{
  "severity": "CRITICAL" | "HIGH" | "MEDIUM" | "LOW",
  "threat_score": number between 10 and 100,
  "summary": "1 sentence executive summary of the threat",
  "student_advice": ["Immediate step 1", "Immediate step 2", "Immediate step 3"],
  "security_action": "Recommended deployment protocol for QRT team"
}`;

    if (apiKey) {
      try {
        const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            model: 'openai/gpt-oss-120b',
            messages: [{ role: 'system', content: systemPrompt }],
            response_format: { type: 'json_object' },
            temperature: 0.2
          })
        });

        const data = await groqRes.json();
        const content = data.choices?.[0]?.message?.content;
        if (content) {
          const parsed = JSON.parse(content);
          return NextResponse.json({ success: true, groq: true, data: parsed });
        }
      } catch (err) {
        console.error('Groq Emergency Classifier API Error:', err);
      }
    }

    // Fallback Emergency Classification
    const isCritical = /assault|stalk|weapon|attack|bleeding|fire|choke|harass/i.test(`${category} ${description}`);
    const isHigh = /theft|chase|injury|unconscious|fight/i.test(`${category} ${description}`);

    const fallbackData = {
      severity: isCritical ? 'CRITICAL' : isHigh ? 'HIGH' : 'MEDIUM',
      threat_score: isCritical ? 92 : isHigh ? 75 : 55,
      summary: `High priority ${category} detected at ${location}. Quick Response Team notified instantly.`,
      student_advice: [
        'Move towards nearest open building or security kiosk.',
        'Stay on line or keep phone visible for live responder beacon.',
        'Share your real-time tracking link with trusted contacts.'
      ],
      security_action: `Deploy nearest QRT Patrol unit to ${location} with siren on.`
    };

    return NextResponse.json({ success: true, groq: false, data: fallbackData });

  } catch (error) {
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
