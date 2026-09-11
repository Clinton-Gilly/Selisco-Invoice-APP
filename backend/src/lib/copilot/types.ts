export type Role = 'user' | 'assistant' | 'tool' | 'system';

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, any>;
}

export interface ChatMessage {
  role: Role;
  text?: string;
  toolCalls?: ToolCall[];
  raw?: any; // provider's own content blocks for exact replay
  callId?: string; // for role: 'tool'
  name?: string; // tool name
  failed?: boolean;
  reasoning?: string;
}

export interface JSONSchema {
  type: string;
  properties?: Record<string, any>;
  required?: string[];
  description?: string;
}

export interface ToolContext {
  businessId: string;
  currency: string;
}

export interface ToolDef {
  name: string;
  description: string;
  parameters: JSONSchema;
  writes: boolean;
  minRole?: string;
  table?: string;
  alwaysConfirm?: boolean;
  describe: (args: any) => string;
  run: (ctx: ToolContext, args: any) => Promise<any>;
}

export type SupportedProvider = 'gemini' | 'openai' | 'anthropic' | 'groq' | 'deepseek';

export interface ProviderConfig {
  provider: SupportedProvider;
  model: string;
  apiKey: string;
  baseUrl?: string;
  readOnly?: boolean;
  confirmWrites?: boolean;
}

export interface ScreenContext {
  route: string;
  screenName: string;
  activeTab?: string;
  visibleCount?: number;
  activeRecord?: Record<string, any>;
  formData?: Record<string, any>;
  customNote?: string;
}

export interface ChatRequest {
  system?: string;
  messages: ChatMessage[];
  tools?: ToolDef[];
  temperature?: number;
}

export interface ChatResponse {
  text: string;
  reasoning?: string;
  toolCalls: ToolCall[];
  raw?: any;
  stopReason?: string;
  usage?: {
    promptTokens?: number;
    completionTokens?: number;
    totalTokens?: number;
  };
}

export interface ProposedAction {
  id: string;
  callId: string;
  name: string;
  description: string; // Plain-language sentence from describe()
  parameters: Record<string, any>;
  alwaysConfirm: boolean;
  table?: string;
}
