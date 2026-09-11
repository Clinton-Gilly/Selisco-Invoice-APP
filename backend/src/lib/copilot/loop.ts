import { query } from '@/lib/db';
import { chat } from './adapters';
import { TOOL_REGISTRY } from './registry';
import { buildSystemPrompt } from './voice';
import {
  ChatMessage,
  ChatResponse,
  ProposedAction,
  ProviderConfig,
  ScreenContext,
  ToolContext,
  ToolDef,
} from './types';

const MAX_ROUNDS = 5;

export interface LoopResult {
  text: string;
  reasoning?: string;
  pendingAction?: ProposedAction;
  actionExecuted?: {
    actionName: string;
    description: string;
    auditLogId: string;
    result: any;
  };
  messages: ChatMessage[];
}

export async function runCopilotLoop(params: {
  businessId: string;
  messages: ChatMessage[];
  screenContext?: ScreenContext;
  providerConfig: ProviderConfig;
  approvedCall?: {
    callId: string;
    name: string;
    parameters: Record<string, any>;
  };
  declinedCall?: {
    callId: string;
    name: string;
  };
}): Promise<LoopResult> {
  const { businessId, screenContext, providerConfig, approvedCall, declinedCall } = params;

  // Retrieve business details for currency & name
  const bizRes = await query('SELECT name, currency FROM businesses WHERE id = $1', [businessId]);
  const businessName = bizRes.rows[0]?.name || 'Selisco Ltd';
  const currency = bizRes.rows[0]?.currency || 'KES';

  const toolCtx: ToolContext = {
    businessId,
    currency,
  };

  // Build system prompt
  const system = buildSystemPrompt({
    businessName,
    currency,
    screenContext,
    readOnly: providerConfig.readOnly,
  });

  // Filter offered tools based on readOnly
  const offeredTools: ToolDef[] = Object.values(TOOL_REGISTRY).filter((t) => {
    if (providerConfig.readOnly && t.writes) return false;
    return true;
  });

  const history: ChatMessage[] = [...params.messages];

  // If handling an approved call from the client
  if (approvedCall) {
    const tool = TOOL_REGISTRY[approvedCall.name];
    if (!tool) {
      history.push({
        role: 'tool',
        callId: approvedCall.callId,
        name: approvedCall.name,
        text: `Error: Tool ${approvedCall.name} not found in registry.`,
        failed: true,
      });
    } else {
      try {
        const result = await tool.run(toolCtx, approvedCall.parameters);
        const description = tool.describe(approvedCall.parameters);

        // Record in audit log
        let auditLogId = '';
        try {
          const auditRes = await query(
            `INSERT INTO copilot_audit_logs (
              business_id, action_name, description, parameters, result, target_entity, target_id
            ) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
            [
              businessId,
              approvedCall.name,
              description,
              JSON.stringify(approvedCall.parameters),
              JSON.stringify(result),
              result?.entity || tool.table || null,
              result?.id || null,
            ]
          );
          auditLogId = auditRes.rows[0]?.id;
        } catch (auditErr) {
          console.error('Failed to write copilot audit log:', auditErr);
        }

        history.push({
          role: 'tool',
          callId: approvedCall.callId,
          name: approvedCall.name,
          text: JSON.stringify(result),
        });

        // Find the last assistant message and satisfy any OTHER unanswered tool_calls
        // (The AI may have proposed multiple tool_calls; user approved one; the rest
        //  need placeholder responses or the API returns 400.)
        const lastAssistant = [...history].reverse().find((m) => m.role === 'assistant');
        if (lastAssistant?.toolCalls && lastAssistant.toolCalls.length > 0) {
          const answeredCallIds = new Set(
            history.filter((m) => m.role === 'tool').map((m) => m.callId)
          );
          for (const tc of lastAssistant.toolCalls) {
            if (!answeredCallIds.has(tc.id)) {
              history.push({
                role: 'tool',
                callId: tc.id,
                name: tc.name,
                text: 'Action was skipped (only one action approved at a time).',
                failed: false,
              });
            }
          }
        }

        // Let model provide natural language summary of execution
        const followup = await chat(providerConfig, {
          system,
          messages: history,
          tools: offeredTools,
        });

        history.push({
          role: 'assistant',
          text: followup.text,
          raw: followup.raw,
        });

        return {
          text: followup.text,
          reasoning: followup.reasoning,
          actionExecuted: {
            actionName: approvedCall.name,
            description,
            auditLogId,
            result,
          },
          messages: history,
        };
      } catch (execErr: any) {
        history.push({
          role: 'tool',
          callId: approvedCall.callId,
          name: approvedCall.name,
          text: `Action failed: ${execErr.message}`,
          failed: true,
        });
      }
    }
  }

  // If handling a declined call from the client
  if (declinedCall) {
    history.push({
      role: 'tool',
      callId: declinedCall.callId,
      name: declinedCall.name,
      text: 'User declined this action. Do not retry it unless explicitly requested.',
      failed: true,
    });

    // Satisfy any other unanswered tool_calls from the last assistant message
    const lastAssistant = [...history].reverse().find((m) => m.role === 'assistant');
    if (lastAssistant?.toolCalls && lastAssistant.toolCalls.length > 0) {
      const answeredCallIds = new Set(
        history.filter((m) => m.role === 'tool').map((m) => m.callId)
      );
      for (const tc of lastAssistant.toolCalls) {
        if (!answeredCallIds.has(tc.id)) {
          history.push({
            role: 'tool',
            callId: tc.id,
            name: tc.name,
            text: 'Action skipped because user declined the batch.',
            failed: true,
          });
        }
      }
    }

    const followup = await chat(providerConfig, {
      system,
      messages: history,
      tools: offeredTools,
    });

    history.push({
      role: 'assistant',
      text: followup.text,
      raw: followup.raw,
    });

    return {
      text: followup.text,
      reasoning: followup.reasoning,
      messages: history,
    };
  }

  // Multi-turn agent loop
  let latestText = '';
  let latestReasoning: string | undefined;

  for (let round = 1; round <= MAX_ROUNDS; round++) {
    const reply: ChatResponse = await chat(providerConfig, {
      system,
      messages: history,
      tools: offeredTools,
    });

    latestText = reply.text;
    latestReasoning = reply.reasoning;

    // Append model reply to history
    history.push({
      role: 'assistant',
      text: reply.text,
      toolCalls: reply.toolCalls,
      raw: reply.raw,
      reasoning: reply.reasoning,
    });

    // If no tool calls, conversation turn is complete
    if (!reply.toolCalls || reply.toolCalls.length === 0) {
      break;
    }

    // Process tool calls
    let pausedForHuman = false;
    let pendingAction: ProposedAction | undefined;

    for (const call of reply.toolCalls) {
      const tool = TOOL_REGISTRY[call.name];

      if (!tool) {
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: `Tool "${call.name}" is unknown or not permitted.`,
          failed: true,
        });
        continue;
      }

      // Check safety gate
      const requiresConfirmation =
        tool.alwaysConfirm || (providerConfig.confirmWrites && tool.writes);

      if (requiresConfirmation) {
        // Stop the loop and propose to human user
        const description = tool.describe(call.arguments);
        pendingAction = {
          id: `prop_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          callId: call.id,
          name: call.name,
          description,
          parameters: call.arguments,
          alwaysConfirm: Boolean(tool.alwaysConfirm),
          table: tool.table,
        };
        pausedForHuman = true;
        break; // Pause loop
      }

      // Safe to execute immediately
      try {
        const result = await tool.run(toolCtx, call.arguments);
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: JSON.stringify(result),
        });
      } catch (err: any) {
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: `Error executing ${call.name}: ${err.message}`,
          failed: true,
        });
      }
    }

    if (pausedForHuman && pendingAction) {
      return {
        text: latestText || `I have prepared the following action for your review:`,
        reasoning: latestReasoning,
        pendingAction,
        messages: history,
      };
    }
  }

  return {
    text: latestText,
    reasoning: latestReasoning,
    messages: history,
  };
}
