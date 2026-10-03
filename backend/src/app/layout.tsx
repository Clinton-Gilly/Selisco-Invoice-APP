import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: {
    default: 'Selisco | Cloud Operations Dashboard & Portal',
    template: '%s | Selisco',
  },
  description: 'Enterprise Invoice & Delivery Note Management, Cryptographic Verification, and Cloud API Services for Selisco.',
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
