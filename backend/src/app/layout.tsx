import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Selisco Invoice Verification Portal',
  description: 'Cryptographic document verification for Selisco Invoices and Delivery Notes',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-slate-50 antialiased min-h-screen">
        {children}
      </body>
    </html>
  );
}
