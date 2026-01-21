'use client';

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { CheckCircle, Download, Lock, Shield, Sparkles, Monitor, Palette, Cpu, AlertTriangle } from 'lucide-react';

const PREVIEW_PASSWORD = 'asmbli2025'; // Simple client-side check for MVP

interface DownloadInfo {
  platform: string;
  version: string;
  size: string;
  filename: string;
  downloadUrl: string;
  features: string[];
}

const mvpDownloads: DownloadInfo[] = [
  {
    platform: 'Windows',
    version: 'MVP Preview',
    size: '~13MB',
    filename: 'Asmbli-MVP-Preview-Windows.zip',
    downloadUrl: '/downloads/windows/mvp-preview/Asmbli-MVP-Preview-Windows.zip',
    features: [
      'Streamlined chat interface',
      'OpenAI, Anthropic & Ollama support',
      'Web search integration',
      '6 beautiful color themes',
      'Local-first - your data stays private',
      'Customizable system prompts',
    ],
  },
  {
    platform: 'macOS',
    version: 'MVP Preview',
    size: '~20MB',
    filename: 'Asmbli-MVP-Preview-macOS.zip',
    downloadUrl: '/downloads/macos/mvp-preview/Asmbli-MVP-Preview-macOS.zip',
    features: [
      'Streamlined chat interface',
      'OpenAI, Anthropic & Ollama support',
      'Web search integration',
      '6 beautiful color themes',
      'Local-first - your data stays private',
      'Customizable system prompts',
    ],
  },
];

const highlights = [
  {
    icon: Monitor,
    title: 'Clean Interface',
    description: 'Focused chat experience with slide-out settings panel',
  },
  {
    icon: Cpu,
    title: 'Multiple AI Providers',
    description: 'OpenAI, Anthropic Claude, and local Ollama models',
  },
  {
    icon: Palette,
    title: 'Beautiful Themes',
    description: '6 color schemes with light/dark mode support',
  },
  {
    icon: Sparkles,
    title: 'Smart Features',
    description: 'Web search, temperature control, custom prompts',
  },
];

export default function PreviewDownloadPage() {
  const [password, setPassword] = useState('');
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handlePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    // Simple client-side validation for MVP
    setTimeout(() => {
      if (password === PREVIEW_PASSWORD) {
        setIsAuthenticated(true);
        setError('');
      } else {
        setError('Invalid password. Please check your invite email.');
      }
      setIsLoading(false);
    }, 500);
  };

  const handleDownload = (download: DownloadInfo) => {
    // Track download
    if (typeof window !== 'undefined' && (window as any).gtag) {
      (window as any).gtag('event', 'download', {
        event_category: 'preview',
        event_label: `mvp-${download.platform.toLowerCase()}`,
        value: 1,
      });
    }

    // Trigger download
    const link = document.createElement('a');
    link.href = download.downloadUrl;
    link.download = download.filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Password gate
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-neutral-900 via-neutral-800 to-neutral-900 flex items-center justify-center p-4">
        <Card className="w-full max-w-md bg-neutral-800/50 border-neutral-700">
          <CardHeader className="text-center">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-teal-500 to-cyan-500 flex items-center justify-center mx-auto mb-4">
              <Lock className="w-8 h-8 text-white" />
            </div>
            <CardTitle className="text-2xl text-white">Preview Access</CardTitle>
            <CardDescription className="text-neutral-400">
              Enter your preview password to download
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handlePasswordSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="password" className="text-neutral-300">
                  Password
                </Label>
                <Input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter preview password"
                  className="bg-neutral-900 border-neutral-600 text-white placeholder:text-neutral-500"
                  autoFocus
                />
              </div>
              {error && (
                <p className="text-sm text-red-400 bg-red-900/20 px-3 py-2 rounded-md">
                  {error}
                </p>
              )}
              <Button
                type="submit"
                disabled={isLoading || !password}
                className="w-full bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 text-white"
              >
                {isLoading ? 'Verifying...' : 'Access Preview'}
              </Button>
            </form>
            <p className="text-xs text-neutral-500 text-center mt-4">
              Don't have a password?{' '}
              <a href="/beta" className="text-teal-400 hover:underline">
                Join the beta waitlist
              </a>
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Download page (after authentication)
  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-900 via-neutral-800 to-neutral-900">
      <div className="container mx-auto px-4 py-16">
        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-teal-500/10 rounded-full mb-6">
            <Sparkles className="w-4 h-4 text-teal-400" />
            <span className="text-sm text-teal-400 font-medium">MVP Preview</span>
          </div>
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
            Asmbli MVP Preview
          </h1>
          <p className="text-xl text-neutral-400 max-w-2xl mx-auto">
            Thank you for being an early tester! Download the latest MVP build
            and help shape the future of Asmbli.
          </p>
        </div>

        {/* Download Cards */}
        <div className="grid md:grid-cols-2 gap-6 max-w-4xl mx-auto mb-12">
          {mvpDownloads.map((download) => (
            <Card key={download.platform} className="bg-neutral-800/50 border-neutral-700">
              <CardHeader>
                <CardTitle className="flex items-center gap-4 text-white">
                  <div className={`w-14 h-14 rounded-xl flex items-center justify-center ${
                    download.platform === 'Windows'
                      ? 'bg-gradient-to-br from-blue-500 to-indigo-600'
                      : 'bg-gradient-to-br from-neutral-600 to-neutral-700'
                  }`}>
                    <span className="text-white font-bold text-lg">
                      {download.platform === 'Windows' ? 'WIN' : 'MAC'}
                    </span>
                  </div>
                  <div>
                    <div className="text-xl">{download.platform}</div>
                    <CardDescription className="text-neutral-400">
                      {download.version} • {download.size} • ZIP Archive
                    </CardDescription>
                  </div>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Features list */}
                <div>
                  <h4 className="font-semibold text-sm text-neutral-300 mb-3">
                    What's Included:
                  </h4>
                  <ul className="space-y-1">
                    {download.features.slice(0, 4).map((feature, index) => (
                      <li
                        key={index}
                        className="flex items-center gap-2 text-sm text-neutral-400"
                      >
                        <CheckCircle className="w-4 h-4 text-teal-500 flex-shrink-0" />
                        {feature}
                      </li>
                    ))}
                  </ul>
                </div>

                {/* Download button */}
                <Button
                  onClick={() => handleDownload(download)}
                  size="lg"
                  className="w-full bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 text-white"
                >
                  <Download className="w-5 h-5 mr-2" />
                  Download for {download.platform}
                </Button>

                {/* Requirements */}
                <div className="text-xs text-neutral-500">
                  <p>
                    <strong>Requirements:</strong>{' '}
                    {download.platform === 'Windows'
                      ? 'Windows 10/11 64-bit'
                      : 'macOS 10.15+ (Intel or Apple Silicon)'}
                  </p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Feature highlights */}
        <div className="max-w-4xl mx-auto mb-12">
          <h2 className="text-2xl font-bold text-white text-center mb-8">
            What's New in This Build
          </h2>
          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            {highlights.map((highlight, index) => (
              <div
                key={index}
                className="text-center p-6 rounded-xl bg-neutral-800/30 border border-neutral-700/50"
              >
                <div className="w-12 h-12 rounded-lg bg-neutral-700/50 flex items-center justify-center mx-auto mb-4">
                  <highlight.icon className="w-6 h-6 text-teal-400" />
                </div>
                <h3 className="font-semibold text-white mb-2">{highlight.title}</h3>
                <p className="text-sm text-neutral-400">{highlight.description}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Installation Instructions */}
        <div className="max-w-4xl mx-auto mb-12">
          <Card className="bg-amber-900/20 border-amber-700/50 mb-6">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-amber-400">
                <AlertTriangle className="w-5 h-5" />
                Important: Security Bypass Required
              </CardTitle>
              <CardDescription className="text-amber-200/70">
                Since this is a preview build, it's not code-signed. You'll need to bypass security warnings to run it.
              </CardDescription>
            </CardHeader>
          </Card>

          <div className="grid md:grid-cols-2 gap-6">
            {/* macOS Instructions */}
            <Card className="bg-neutral-800/50 border-neutral-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-neutral-600 flex items-center justify-center text-sm font-bold">
                    MAC
                  </span>
                  macOS Installation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">1</span>
                    <p className="text-sm text-neutral-300">Extract the ZIP file to your Applications folder</p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">2</span>
                    <p className="text-sm text-neutral-300">Double-click the app — macOS will block it initially</p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">3</span>
                    <p className="text-sm text-neutral-300">Open <strong>System Settings → Privacy & Security</strong></p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">4</span>
                    <p className="text-sm text-neutral-300">Scroll down and click <strong>"Open Anyway"</strong> next to the Asmbli message</p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">5</span>
                    <p className="text-sm text-neutral-300">Click <strong>"Open"</strong> in the confirmation dialog</p>
                  </div>
                </div>
                <div className="bg-neutral-900/50 rounded-lg p-3 mt-4">
                  <p className="text-xs text-neutral-400">
                    <strong>Tip:</strong> You only need to do this once. After allowing the app, it will open normally.
                  </p>
                </div>
              </CardContent>
            </Card>

            {/* Windows Instructions */}
            <Card className="bg-neutral-800/50 border-neutral-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center gap-2">
                  <span className="w-8 h-8 rounded-lg bg-blue-600 flex items-center justify-center text-sm font-bold">
                    WIN
                  </span>
                  Windows Installation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-3">
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">1</span>
                    <p className="text-sm text-neutral-300">Extract the ZIP file to any folder</p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">2</span>
                    <p className="text-sm text-neutral-300">Double-click <strong>asmbli.exe</strong> to run</p>
                  </div>
                  <div className="flex gap-3">
                    <span className="w-6 h-6 rounded-full bg-teal-500 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">3</span>
                    <p className="text-sm text-neutral-300">If SmartScreen appears, click <strong>"More info"</strong> then <strong>"Run anyway"</strong></p>
                  </div>
                </div>
                <div className="bg-neutral-900/50 rounded-lg p-3 mt-4">
                  <p className="text-xs text-neutral-400">
                    <strong>Note:</strong> Windows Defender may scan the file on first run. This is normal for unsigned applications.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Quick Start */}
        <Card className="max-w-3xl mx-auto bg-neutral-800/50 border-neutral-700 mb-12">
          <CardHeader>
            <CardTitle className="text-white">After Installation</CardTitle>
            <CardDescription className="text-neutral-400">
              Get up and running in 2 easy steps
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid md:grid-cols-2 gap-6">
              <div className="text-center">
                <div className="w-10 h-10 rounded-full bg-teal-500 text-white flex items-center justify-center mx-auto mb-3 font-bold">
                  1
                </div>
                <h4 className="font-semibold text-white mb-2">Add API Key</h4>
                <p className="text-sm text-neutral-400">
                  Enter your OpenAI, Anthropic, or use local Ollama
                </p>
              </div>
              <div className="text-center">
                <div className="w-10 h-10 rounded-full bg-teal-500 text-white flex items-center justify-center mx-auto mb-3 font-bold">
                  2
                </div>
                <h4 className="font-semibold text-white mb-2">Start Chatting</h4>
                <p className="text-sm text-neutral-400">
                  Customize your agent and begin conversations
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Feedback CTA */}
        <div className="text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-neutral-800 rounded-full mb-4">
            <Shield className="w-4 h-4 text-green-400" />
            <span className="text-sm text-green-400 font-medium">
              Preview Build • Not for Production Use
            </span>
          </div>
          <p className="text-neutral-400 mb-4">
            Found a bug or have feedback? We'd love to hear from you!
          </p>
          <a
            href="https://github.com/WereNext/Asmbli/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="text-teal-400 hover:underline"
          >
            Report issues on GitHub →
          </a>
        </div>
      </div>
    </div>
  );
}
