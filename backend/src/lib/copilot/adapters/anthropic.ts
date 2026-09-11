import { ChatMessage, ChatRequest, ChatResponse, ToolCall, ToolDef } from '../types';

export async function chatAnthropic(
  request: ChatRequest,
  apiKey: string,
  modelName: string = 'claude-3-7-sonnet-latest'
): Promise<ChatResponse> {
  const url = 'https://api.anthropic.com/v1/messages';

  const rawMessages: any[] = [];

  for (const msg of request.messages) {
    if (msg.role === 'user') {
      rawMessages.push({
        role: 'user',
        content: [{ type: 'text', text: msg.text || '' }],
      });
    } else if (msg.role === 'assistant') {
      if (msg.raw && Array.isArray(msg.raw)) {
        // Exact replay of raw content blocks
        rawMessages.push({
          role: 'assistant',
          content: msg.raw,
        });
      } else {
        const blocks: any[] = [];
        if (msg.text) {
          blocks.push({ type: 'text', text: msg.text });
        }
        if (msg.toolCalls && msg.toolCalls.length > 0) {
          for (const tc of msg.toolCalls) {
            blocks.push({
              type: 'tool_use',
              id: tc.id,
              name: tc.name,
              input: tc.arguments,
            });
          }
        }
        rawMessages.push({ role: 'assistant', content: blocks });
      }
    } else if (msg.role === 'tool') {
      rawMessages.push({
        role: 'user',
        content: [
          {
            type: 'tool_result',
            tool_use_id: msg.callId,
            content: msg.text || '',
            is_error: msg.failed || false,
          },
        ],
      });
    }
  }

  // Merge adjacent messages with same role (e.g. multiple tool results or user turns)
  const messages: any[] = [];
  for (const m of rawMessages) {
    if (messages.length > 0 && messages[messages.length - 1].role === m.role) {
      const prevContent = Array.isArray(messages[messages.length - 1].content)
        ? messages[messages.length - 1].content
        : [{ type: 'text', text: messages[messages.length - 1].content || '' }];
      const currContent = Array.isArray(m.content) ? m.content : [{ type: 'text', text: m.content || '' }];
      messages[messages.length - 1].content = [...prevContent, ...currContent];
    } else {
      messages.push({ ...m, content: Array.isArray(m.content) ? [...m.content] : m.content });
    }
  }

  let tools: any[] | undefined;
  if (request.tools && request.tools.length > 0) {
    tools = request.tools.map((t: ToolDef) => ({
      name: t.name,
      description: t.description,
      input_schema: t.parameters,
    }));
  }

  const payload: any = {
    model: modelName,
    max_tokens: 4096,
    messages,
  };

  if (request.system) {
    payload.system = request.system;
  }

  if (tools) {
    payload.tools = tools;
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
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
    throw new Error(`Anthropic API error (${res.status}): ${parsedErr}`);
  }

  const data = await res.json();
  const contentBlocks = data.content || [];

  let text = '';
  let reasoning = '';
  const toolCalls: ToolCall[] = [];

  for (const block of contentBlocks) {
    if (block.type === 'text') {
      text += block.text;
    } else if (block.type === 'thinking') {
      reasoning += block.thinking;
    } else if (block.type === 'tool_use') {
      toolCalls.push({
        id: block.id,
        name: block.name,
        arguments: block.input || {},
      });
    }
  }

  return {
    text,
    reasoning: reasoning || undefined,
    toolCalls,
    raw: contentBlocks, // store raw content blocks for exact replay
    stopReason: data.stop_reason,
    usage: {
      promptTokens: data.usage?.input_tokens,
      completionTokens: data.usage?.output_tokens,
      totalTokens: (data.usage?.input_tokens || 0) + (data.usage?.output_tokens || 0),
    },
  };
}
