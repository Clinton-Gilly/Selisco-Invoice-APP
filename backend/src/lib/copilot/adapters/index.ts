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
      return await chatOpenAI(request, config.apiKey, config.model || 'gpt-4o-mini');

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
        config.model || 'claude-3-7-sonnet-latest'
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
    models: [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ],
  },
  {
    id: 'openai',
    name: 'OpenAI',
    dialect: 'openai',
    defaultModel: 'gpt-4o-mini',
    models: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'gpt-4.1-mini', 'o3-mini', 'o1'],
  },
  {
    id: 'groq',
    name: 'Groq (Fast Llama & DeepSeek)',
    dialect: 'openai',
    defaultModel: 'llama-3.3-70b-versatile',
    models: [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'deepseek-r1-distill-llama-70b',
      'mixtral-8x7b-32768',
    ],
  },
  {
    id: 'anthropic',
    name: 'Anthropic Claude',
    dialect: 'anthropic',
    defaultModel: 'claude-3-7-sonnet-latest',
    models: [
      'claude-3-7-sonnet-latest',
      'claude-3-5-sonnet-latest',
      'claude-3-5-haiku-latest',
      'claude-3-opus-latest',
    ],
  },
];
