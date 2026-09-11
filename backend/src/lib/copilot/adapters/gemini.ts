import { ChatMessage, ChatRequest, ChatResponse, ToolCall, ToolDef } from '../types';

export async function chatGemini(
  request: ChatRequest,
  apiKey: string,
  modelName: string = 'gemini-2.5-flash'
): Promise<ChatResponse> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    modelName
  )}:generateContent?key=${apiKey}`;

  // Format system instruction
  const systemInstruction = request.system
    ? { parts: [{ text: request.system }] }
    : undefined;

  // Convert ChatMessages to Gemini contents format
  const rawContents: any[] = [];

  for (const msg of request.messages) {
    if (msg.role === 'user') {
      rawContents.push({
        role: 'user',
        parts: [{ text: msg.text || '' }],
      });
    } else if (msg.role === 'assistant') {
      if (msg.raw && Array.isArray(msg.raw.parts)) {
        // Replay exact provider parts
        rawContents.push({
          role: 'model',
          parts: msg.raw.parts,
        });
      } else {
        const parts: any[] = [];
        if (msg.text) {
          parts.push({ text: msg.text });
        }
        if (msg.toolCalls && msg.toolCalls.length > 0) {
          for (const tc of msg.toolCalls) {
            parts.push({
              functionCall: {
                name: tc.name,
                args: tc.arguments,
              },
            });
          }
        }
        if (parts.length > 0) {
          rawContents.push({ role: 'model', parts });
        }
      }
    } else if (msg.role === 'tool') {
      let parsedResult: any = msg.text;
      try {
        parsedResult = msg.text ? JSON.parse(msg.text) : {};
      } catch (_) {}

      rawContents.push({
        role: 'function',
        parts: [
          {
            functionResponse: {
              name: msg.name || 'tool',
              response: {
                result: parsedResult,
                failed: msg.failed || false,
              },
            },
          },
        ],
      });
    }
  }

  // Merge adjacent contents with same role to ensure alternation
  const contents: any[] = [];
  for (const c of rawContents) {
    if (contents.length > 0 && contents[contents.length - 1].role === c.role) {
      contents[contents.length - 1].parts.push(...c.parts);
    } else {
      contents.push({ role: c.role, parts: [...c.parts] });
    }
  }

  // Format tools for Gemini (both functionDeclarations and function_declarations for compatibility)
  let tools: any[] | undefined;
  if (request.tools && request.tools.length > 0) {
    const declarations = request.tools.map((t: ToolDef) => ({
      name: t.name,
      description: t.description,
      parameters: t.parameters,
    }));
    tools = [
      {
        functionDeclarations: declarations,
      },
    ];
  }

  const payload: any = {
    contents,
    system_instruction: systemInstruction,
  };

  if (tools) {
    payload.tools = tools;
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    let parsedErr = errText;
    try {
      const json = JSON.parse(errText);
      parsedErr = json.error?.message || errText;
    } catch (_) {}
    throw new Error(`Gemini API error (${res.status}): ${parsedErr}`);
  }

  const data = await res.json();
  const candidate = data.candidates?.[0];
  const parts = candidate?.content?.parts || [];

  let text = '';
  let reasoning = '';
  const toolCalls: ToolCall[] = [];

  for (const part of parts) {
    if (part.text) {
      text += part.text;
    }
    if (part.thought) {
      reasoning += part.thought;
    }
    if (part.functionCall) {
      toolCalls.push({
        id: `call_${Math.random().toString(36).substring(2, 9)}`,
        name: part.functionCall.name,
        arguments: part.functionCall.args || {},
      });
    }
  }

  return {
    text,
    reasoning: reasoning || undefined,
    toolCalls,
    raw: candidate?.content,
    stopReason: candidate?.finishReason,
    usage: {
      promptTokens: data.usageMetadata?.promptTokenCount,
      completionTokens: data.usageMetadata?.candidatesTokenCount,
      totalTokens: data.usageMetadata?.totalTokenCount,
    },
  };
}
