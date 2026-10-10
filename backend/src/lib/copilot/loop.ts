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

const MAX_ROUNDS = 6;
// How much conversation the model sees, and how much we hand back to the client to store.
const MAX_MODEL_MESSAGES = 40;
const MAX_STORED_MESSAGES = 80;

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

/**
 * Keep the most recent messages, always starting at a user turn so we never
 * send a tool result whose originating tool call was cut off.
 */
function trimHistory(history: ChatMessage[], max: number): ChatMessage[] {
  if (history.length <= max) return history;
  let start = history.length - max;
  while (start < history.length && history[start].role !== 'user') start++;
  return start < history.length ? history.slice(start) : history.slice(-1);
}

/** Answer any tool calls in the last assistant message that have no result yet. */
function answerDanglingCalls(history: ChatMessage[], text: string) {
  const lastAssistantIdx = history.map((m) => m.role).lastIndexOf('assistant');
  const lastAssistant = history[lastAssistantIdx];
  if (!lastAssistant?.toolCalls?.length) return;
  const answered = new Set(
    history.slice(lastAssistantIdx + 1).filter((m) => m.role === 'tool').map((m) => m.callId)
  );
  for (const tc of lastAssistant.toolCalls) {
    if (!answered.has(tc.id)) {
      history.push({ role: 'tool', callId: tc.id, name: tc.name, text, failed: true });
    }
  }
}

/**
 * If the user typed a new message instead of answering an Approve/Decline card,
 * the earlier tool call never got a result, which providers reject. Fill those gaps.
 */
function repairHistory(messages: ChatMessage[]): ChatMessage[] {
  const out: ChatMessage[] = [];
  let open: { id: string; name: string }[] = [];
  const closeOpen = () => {
    for (const c of open) {
      out.push({
        role: 'tool',
        callId: c.id,
        name: c.name,
        text: 'Not executed: the user sent a new message instead of approving this action. Do not assume they declined it.',
        failed: true,
      });
    }
    open = [];
  };
  for (const m of messages) {
    if (!m || typeof m !== 'object') continue;
    if (m.role === 'tool') {
      open = open.filter((c) => c.id !== m.callId);
      out.push(m);
      continue;
    }
    closeOpen();
    out.push(m);
    if (m.role === 'assistant' && m.toolCalls?.length) {
      open = m.toolCalls.map((tc) => ({ id: tc.id, name: tc.name }));
    }
  }
  return out; // calls still open at the end are awaiting approval
}

function errorMessage(err: any): string {
  return err?.message || String(err);
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

  const bizRes = await query('SELECT name, currency FROM businesses WHERE id = $1', [businessId]);
  const businessName = bizRes.rows[0]?.name || 'Selisco Ltd';
  const currency = bizRes.rows[0]?.currency || 'KES';

  const toolCtx: ToolContext = { businessId, currency };

  const system = buildSystemPrompt({
    businessName,
    currency,
    screenContext,
    readOnly: providerConfig.readOnly,
  });

  const offeredTools: ToolDef[] = Object.values(TOOL_REGISTRY).filter(
    (t) => !(providerConfig.readOnly && t.writes)
  );

  const history: ChatMessage[] = trimHistory(repairHistory(params.messages || []), MAX_STORED_MESSAGES);

  const callModel = (toolChoice: 'auto' | 'none' = 'auto') =>
    chat(providerConfig, {
      system,
      messages: trimHistory(history, MAX_MODEL_MESSAGES),
      tools: offeredTools,
      toolChoice,
    });

  let actionExecuted: LoopResult['actionExecuted'];

  // ── Resume after the user approved a proposed action ───────────────────────
  if (approvedCall) {
    const tool = TOOL_REGISTRY[approvedCall.name];
    if (!tool || (providerConfig.readOnly && tool.writes)) {
      history.push({
        role: 'tool',
        callId: approvedCall.callId,
        name: approvedCall.name,
        text: `Error: action "${approvedCall.name}" is not available.`,
        failed: true,
      });
    } else {
      const description = tool.describe(approvedCall.parameters);
      try {
        const result = await tool.run(toolCtx, approvedCall.parameters);

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

        // The undo snapshot is for the audit log only; keep it out of the model's context.
        const { snapshot: _snapshot, ...modelResult } = result || {};
        history.push({
          role: 'tool',
          callId: approvedCall.callId,
          name: approvedCall.name,
          text: JSON.stringify(modelResult),
        });

        actionExecuted = { actionName: approvedCall.name, description, auditLogId, result: modelResult };
      } catch (execErr: any) {
        history.push({
          role: 'tool',
          callId: approvedCall.callId,
          name: approvedCall.name,
          text: `Action failed: ${errorMessage(execErr)}`,
          failed: true,
        });
      }
    }
    answerDanglingCalls(
      history,
      'Not executed: only one action is approved at a time. Propose it again if it is still needed.'
    );
  }

  // ── Resume after the user declined a proposed action ───────────────────────
  if (declinedCall) {
    history.push({
      role: 'tool',
      callId: declinedCall.callId,
      name: declinedCall.name,
      text: 'The user declined this action. It was NOT executed. Do not retry unless they ask again.',
      failed: true,
    });
    answerDanglingCalls(history, 'Not executed because the user declined the proposed action.');
  }

  // ── Agent loop ─────────────────────────────────────────────────────────────
  let latestText = '';
  let latestReasoning: string | undefined;

  for (let round = 1; round <= MAX_ROUNDS + 1; round++) {
    // On the extra final round, force a plain-text answer so the user always gets a reply.
    const isFinalRound = round > MAX_ROUNDS;
    const reply: ChatResponse = await callModel(isFinalRound ? 'none' : 'auto');

    const toolCalls = isFinalRound ? [] : reply.toolCalls || [];
    latestText = (reply.text || '').trim();
    latestReasoning = reply.reasoning;

    history.push({
      role: 'assistant',
      text: reply.text,
      toolCalls,
      raw: isFinalRound ? undefined : reply.raw,
      reasoning: reply.reasoning,
    });

    if (toolCalls.length === 0) break;

    let pendingAction: ProposedAction | undefined;

    for (const call of toolCalls) {
      if (pendingAction) break; // remaining calls are answered when the user responds

      const tool = TOOL_REGISTRY[call.name];
      if (!tool || (providerConfig.readOnly && tool.writes)) {
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: `Tool "${call.name}" is unknown or not permitted.`,
          failed: true,
        });
        continue;
      }

      const requiresConfirmation = tool.alwaysConfirm || (providerConfig.confirmWrites && tool.writes);

      if (requiresConfirmation) {
        pendingAction = {
          id: `prop_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          callId: call.id,
          name: call.name,
          description: tool.describe(call.arguments),
          parameters: call.arguments,
          alwaysConfirm: Boolean(tool.alwaysConfirm),
          table: tool.table,
        };
        continue;
      }

      try {
        const result = await tool.run(toolCtx, call.arguments);
        let auditLogId = '';
        if (tool.writes) {
          // Writes that skip confirmation are still audited so they can be undone.
          try {
            const auditRes = await query(
              `INSERT INTO copilot_audit_logs (
                business_id, action_name, description, parameters, result, target_entity, target_id
              ) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
              [
                businessId,
                call.name,
                tool.describe(call.arguments),
                JSON.stringify(call.arguments),
                JSON.stringify(result),
                result?.entity || tool.table || null,
                result?.id || null,
              ]
            );
            auditLogId = auditRes.rows[0]?.id;
          } catch (auditErr) {
            console.error('Failed to write copilot audit log:', auditErr);
          }
        }
        const { snapshot: _snapshot, ...modelResult } = result || {};
        if (tool.writes) {
          actionExecuted = {
            actionName: call.name,
            description: tool.describe(call.arguments),
            auditLogId,
            result: modelResult,
          };
        }
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: JSON.stringify(modelResult),
        });
      } catch (err: any) {
        history.push({
          role: 'tool',
          callId: call.id,
          name: call.name,
          text: `Error executing ${call.name}: ${errorMessage(err)}`,
          failed: true,
        });
      }
    }

    if (pendingAction) {
      return {
        text: latestText || `Please review this action: ${pendingAction.description}`,
        reasoning: latestReasoning,
        pendingAction,
        actionExecuted,
        messages: history,
      };
    }
  }

  return {
    text: latestText || "Sorry, I couldn't put together an answer for that. Could you rephrase or give a bit more detail?",
    reasoning: latestReasoning,
    actionExecuted,
    messages: history,
  };
}
