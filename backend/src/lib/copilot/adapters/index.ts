import { ChatRequest, ChatResponse, ProviderConfig } from '../types';
import { chatGemini } from './gemini';
import { chatOpenAI } from './openai';
import { chatAnthropic } from './anthropic';

export async function chat(config: ProviderConfig, request: ChatRequest): Promise<ChatResponse> {
  const provider = config.provider.toLowerCase();

  switch (provider) {
    case 'gemini':
      return await chatGemini(request, config.apiKey, config.model || 'gemini-2.5-flash');

    case 'openai':
      return await chatOpenAI(request, config.apiKey, config.model || 'gpt-4.1-mini');

    case 'groq':
      return await chatOpenAI(
        request,
        config.apiKey,
        config.model || 'llama-3.3-70b-versatile',
        'https://api.groq.com/openai/v1'
      );

    case 'deepseek':
      return await chatOpenAI(
        request,
        config.apiKey,
        config.model || 'deepseek-chat',
        'https://api.deepseek.com'
      );

    case 'anthropic':
      return await chatAnthropic(
        request,
        config.apiKey,
        config.model || 'claude-sonnet-5-5'
      );

    default:
      throw new Error(`Unsupported LLM provider: ${config.provider}`);
  }
}

export interface AvailableProviderInfo {
  id: string;
  name: string;
  dialect: 'gemini' | 'openai' | 'anthropic';
  defaultModel: string;
  models: string[];
}

export const AVAILABLE_PROVIDERS: AvailableProviderInfo[] = [
  {
    id: 'deepseek',
    name: 'DeepSeek',
    dialect: 'openai',
    defaultModel: 'deepseek-chat',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  },
  {
    id: 'gemini',
    name: 'Google Gemini',
    dialect: 'gemini',
    defaultModel: 'gemini-2.5-flash',
    models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.5-flash-lite'],
  },
  {
    id: 'openai',
    name: 'OpenAI',
    dialect: 'openai',
    defaultModel: 'gpt-4.1-mini',
    models: ['gpt-4.1-mini', 'gpt-4.1', 'gpt-4o-mini', 'gpt-4o', 'o4-mini'],
  },
  {
    id: 'groq',
    name: 'Groq (Fast Llama)',
    dialect: 'openai',
    defaultModel: 'llama-3.3-70b-versatile',
    models: ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'openai/gpt-oss-120b'],
  },
  {
    id: 'anthropic',
    name: 'Anthropic Claude',
    dialect: 'anthropic',
    defaultModel: 'claude-sonnet-5-5',
    models: ['claude-sonnet-5-5', 'claude-opus-5-5', 'claude-haiku-5-5', 'claude-sonnet-4-5'],
  },
];
