import { ChatMessage, ChatRequest, ChatResponse, ToolCall, ToolDef } from '../types';

export async function chatOpenAI(
  request: ChatRequest,
  apiKey: string,
  modelName: string = 'gpt-4o-mini',
  customBaseUrl?: string
): Promise<ChatResponse> {
  const baseUrl = (customBaseUrl || 'https://api.openai.com/v1').replace(/\/+$/, '');
  const url = `${baseUrl}/chat/completions`;

  const messages: any[] = [];

  if (request.system) {
    messages.push({
      role: 'system',
      content: request.system,
    });
  }

  for (const msg of request.messages) {
    if (msg.role === 'user') {
      messages.push({
        role: 'user',
        content: msg.text || '',
      });
    } else if (msg.role === 'assistant') {
      if (msg.raw) {
        messages.push(msg.raw);
      } else {
        const item: any = {
          role: 'assistant',
          content: msg.text || null,
        };
        if (msg.toolCalls && msg.toolCalls.length > 0) {
          item.tool_calls = msg.toolCalls.map((tc) => ({
            id: tc.id,
            type: 'function',
            function: {
              name: tc.name,
              arguments: JSON.stringify(tc.arguments),
            },
          }));
        }
        messages.push(item);
      }
    } else if (msg.role === 'tool') {
      messages.push({
        role: 'tool',
        tool_call_id: msg.callId || 'call_default',
        content: msg.text || '',
      });
    }
  }

  let tools: any[] | undefined;
  if (request.tools && request.tools.length > 0) {
    tools = request.tools.map((t: ToolDef) => ({
      type: 'function',
      function: {
        name: t.name,
        description: t.description,
        parameters: t.parameters,
      },
    }));
  }

  const payload: any = {
    model: modelName,
    messages,
  };

  if (tools) {
    payload.tools = tools;
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    let parsedErr = errText;
    try {
      const json = JSON.parse(errText);
      parsedErr = json.error?.message || errText;
    } catch (_) {}
    throw new Error(`OpenAI-dialect API error (${res.status}): ${parsedErr}`);
  }

  const data = await res.json();
  const choice = data.choices?.[0];
  const message = choice?.message;

  const toolCalls: ToolCall[] = [];
  if (message?.tool_calls) {
    for (const tc of message.tool_calls) {
      let args: Record<string, any> = {};
      try {
        args = typeof tc.function?.arguments === 'string' ? JSON.parse(tc.function.arguments) : tc.function?.arguments || {};
      } catch (e) {
        console.warn('Failed to parse tool call arguments:', tc.function?.arguments);
      }
      toolCalls.push({
        id: tc.id,
        name: tc.function?.name,
        arguments: args,
      });
    }
  }

  return {
    text: message?.content || '',
    reasoning: message?.reasoning_content || undefined,
    toolCalls,
    raw: message,
    stopReason: choice?.finish_reason,
    usage: {
      promptTokens: data.usage?.prompt_tokens,
      completionTokens: data.usage?.completion_tokens,
      totalTokens: data.usage?.total_tokens,
    },
  };
}
