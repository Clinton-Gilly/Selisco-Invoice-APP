export type InvoiceStatus = 'DRAFT' | 'ISSUED' | 'PAID' | 'OVERDUE' | 'CANCELLED';
export type DeliveryStatus = 'PENDING' | 'IN_TRANSIT' | 'DELIVERED' | 'REJECTED';

export interface Business {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  currency: string;
  address?: string | null;
  logo_url?: string | null;
  created_at: string;
  updated_at: string;
}

export interface InvoiceItem {
  id?: string;
  invoice_id?: string;
  product_name: string;
  description?: string | null;
  quantity: number;
  unit_price: number;
  total_price: number;
  created_at?: string;
}

export interface Invoice {
  id: string;
  business_id: string;
  invoice_number: string;
  customer_name: string;
  customer_phone?: string | null;
  customer_email?: string | null;
  status: InvoiceStatus;
  subtotal: number;
  tax: number;
  total_amount: number;
  verification_token: string;
  issued_date: string;
  due_date: string;
  notes?: string | null;
  created_at: string;
  updated_at: string;
  items?: InvoiceItem[];
  business?: Business;
  delivery_notes?: DeliveryNote[];
}

export interface DeliveryNoteItem {
  id?: string;
  delivery_note_id?: string;
  invoice_item_id?: string;
  product_name: string;
  ordered_quantity: number;
  delivered_quantity: number;
  created_at?: string;
}

export interface DeliveryNote {
  id: string;
  invoice_id: string;
  business_id: string;
  note_number: string;
  status: DeliveryStatus;
  recipient_name?: string | null;
  recipient_signature_url?: string | null;
  notes?: string | null;
  dispatched_at?: string | null;
  delivered_at?: string | null;
  created_at: string;
  updated_at: string;
  items?: DeliveryNoteItem[];
  invoice?: Invoice;
}

export interface AnalyticsSummary {
  total_revenue: number;
  pending_amount: number;
  total_invoices: number;
  paid_invoices: number;
  pending_invoices: number;
  total_deliveries: number;
  delivered_count: number;
  delivery_success_rate: number;
  monthly_trends: {
    month: string;
    revenue: number;
    count: number;
  }[];
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}
