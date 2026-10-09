import './globals.css';

export const metadata = {
  title: 'Rakshak AI | Campus Emergency & Security Dispatch System',
  description: 'AI-powered campus emergency reporting, instant SOS notification to security, real-time responder location tracking, and accurate arrival time estimation.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="bg-[#070a12] text-slate-100 antialiased min-h-screen">
        {children}
      </body>
    </html>
  );
}
