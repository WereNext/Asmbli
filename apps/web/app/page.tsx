'use client'

import Link from 'next/link'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { ArrowRight, Bot, Code, Zap, Users, Server, FileText, Key, Target, Shield, CheckCircle, Database, Search, Monitor, ExternalLink, Lock } from 'lucide-react'
import { 
  SiGithub, 
  SiFigma, 
  SiPostgresql,
  SiGit,
  SiBrave,
  SiMongodb,
  SiSlack,
  SiNotion,
  SiLinear,
  SiDiscord,
  SiAirtable,
  SiGooglesheets
} from 'react-icons/si'
import { Navigation } from '@/components/Navigation'
import { Footer } from '@/components/Footer'

function BetaSignupForm() {
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    useCase: ''
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'success' | 'error'>('idle');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setSubmitStatus('idle');

    try {
      const response = await fetch('/.netlify/functions/beta-signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData),
      });

      if (response.ok) {
        setSubmitStatus('success');
        setFormData({ firstName: '', lastName: '', email: '', useCase: '' });
      } else {
        throw new Error('Submission failed');
      }
    } catch (error) {
      setSubmitStatus('error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
  };

  if (submitStatus === 'success') {
    return (
      <div className="text-center py-8">
        <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-green-700 mb-2">Thank you for signing up!</h3>
        <p className="text-muted-foreground">
          We've received your beta access request. You'll hear from us soon!
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <input
            type="text"
            name="firstName"
            placeholder="First Name"
            value={formData.firstName}
            onChange={handleChange}
            className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent"
            required
          />
        </div>
        <div>
          <input
            type="text"
            name="lastName"
            placeholder="Last Name"
            value={formData.lastName}
            onChange={handleChange}
            className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent"
            required
          />
        </div>
      </div>
      <div>
        <input
          type="email"
          name="email"
          placeholder="Email Address"
          value={formData.email}
          onChange={handleChange}
          className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent"
          required
        />
      </div>
      <div>
        <textarea
          name="useCase"
          placeholder="What would you like to use AI agents for? (Optional)"
          value={formData.useCase}
          onChange={handleChange}
          rows={3}
          className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent resize-none"
        />
      </div>
      <Button 
        type="submit" 
        disabled={isSubmitting}
        className="w-full bg-warm-500 hover:bg-warm-600 text-warm-50 py-3 text-lg disabled:opacity-50"
      >
        {isSubmitting ? 'Submitting...' : 'Request Beta Access'}
      </Button>
      {submitStatus === 'error' && (
        <p className="text-red-600 text-center text-sm">
          Something went wrong. Please try again or email us directly.
        </p>
      )}
    </form>
  );
}

export default function HomePage() {
  return (
    <div className="flex flex-col min-h-screen">
      {/* Navigation */}
      <Navigation />

      {/* Hero Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-gradient-to-br from-warm-50/20 to-background">
        <div className="container mx-auto max-w-4xl text-center">
          {/* Hero Screenshot First */}
          <div className="mb-8 sm:mb-12">
            <div className="max-w-5xl mx-auto px-2 sm:px-4">
              <div className="rounded-lg sm:rounded-xl border bg-card p-1 sm:p-2 md:p-3 shadow-xl hover:shadow-2xl sm:shadow-2xl sm:hover:shadow-3xl transition-shadow duration-300">
                <video
                  autoPlay
                  loop
                  muted
                  playsInline
                  className="w-full h-auto rounded-md sm:rounded-lg hover:scale-[1.02] transition-transform duration-300 object-contain max-h-[300px] sm:max-h-[400px] md:max-h-[500px] lg:max-h-[600px] xl:max-h-[700px]"
                  aria-label="Asmbli - AI Agent Orchestration Platform"
                >
                  <source src="/hero-demo-new.mp4" type="video/mp4" />
                  <img
                    src="/hero-app-screenshot.png"
                    alt="Asmbli - AI Agent Orchestration Platform"
                    className="w-full h-auto rounded-md sm:rounded-lg"
                  />
                </video>
              </div>
            </div>
          </div>

          {/* Hero Text */}
          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold italic mb-4 sm:mb-6 font-display leading-tight">
            Own Your AI Experiences
          </h1>
          <p className="text-lg sm:text-xl text-muted-foreground mb-6 sm:mb-8 max-w-3xl mx-auto px-4">
            The desktop platform that puts AI agent power in everyone's hands. See exactly what your agents are doing,
            chain them together, and keep full control. No black boxes. No vendor lock-in.
          </p>

          {/* Key Capabilities */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 mb-8 sm:mb-12 max-w-4xl mx-auto px-4">
            <div className="text-center p-4 sm:p-0">
              <div className="w-10 h-10 sm:w-12 sm:h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-2 sm:mb-3">
                <Users className="h-5 w-5 sm:h-6 sm:w-6 text-warm-600" />
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">Agent Orchestration</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Chain multiple specialized agents together. Research, analyze, create, and review in coordinated workflows.
              </p>
            </div>
            <div className="text-center p-4 sm:p-0">
              <div className="w-10 h-10 sm:w-12 sm:h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-2 sm:mb-3">
                <Server className="h-5 w-5 sm:h-6 sm:w-6 text-warm-600" />
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">MCP Tool Integration</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Connect agents to GitHub, databases, file systems, Slack, and 50+ tools via Model Context Protocol.
              </p>
            </div>
            <div className="text-center p-4 sm:p-0 sm:col-span-2 lg:col-span-1">
              <div className="w-10 h-10 sm:w-12 sm:h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-2 sm:mb-3">
                <Target className="h-5 w-5 sm:h-6 sm:w-6 text-warm-600" />
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">Live Task Control</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Watch agents work in real-time. Pause, modify, or redirect tasks mid-execution with full transparency.
              </p>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center px-4">
            <Link href="https://github.com/WereNext/Asmbli" target="_blank" rel="noopener noreferrer">
              <Button size="lg" className="w-full sm:w-auto bg-warm-500 hover:bg-warm-600 text-warm-50">
                Get Started Free
              </Button>
            </Link>
            <Link href="/contribute">
              <Button size="lg" variant="outline" className="w-full sm:w-auto">
                Join Beta Waitlist
              </Button>
            </Link>
          </div>

          {/* Status Bar */}
          <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-6 text-xs sm:text-sm text-muted-foreground px-4">
            <span className="flex items-center gap-2">
              <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>
              <span className="whitespace-nowrap">Full Transparency</span>
            </span>
            <span className="flex items-center gap-2">
              <span className="w-2 h-2 bg-warm-400 rounded-full"></span>
              <span className="whitespace-nowrap">DSPy Powered</span>
            </span>
            <span className="flex items-center gap-1">
              <Shield className="w-3 h-3" />
              <span className="whitespace-nowrap">Your Data, Your Control</span>
            </span>
          </div>
        </div>
      </section>

      {/* Why Asmbli Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto">
          <div className="text-center mb-8 sm:mb-12">
            <h2 className="text-2xl sm:text-3xl font-bold mb-4 font-display">
              Why Asmbli?
            </h2>
            <p className="text-base sm:text-lg text-muted-foreground max-w-2xl mx-auto px-4">
              AI agents shouldn't be mysterious. See every decision, understand every action, maintain full control.
            </p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 max-w-6xl mx-auto">
            <Card className="text-center border-2 hover:border-warm-300 transition-colors">
              <CardHeader className="pb-8 pt-8">
                <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
                  <Search className="h-6 w-6 text-green-600" />
                </div>
                <CardTitle className="text-lg">Glass Box AI</CardTitle>
                <CardDescription>
                  Watch agents think in real-time. Every reasoning step, every tool call, every decision - fully visible and explainable.
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="text-center border-2 hover:border-warm-300 transition-colors">
              <CardHeader className="pb-8 pt-8">
                <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
                  <Users className="h-6 w-6 text-blue-600" />
                </div>
                <CardTitle className="text-lg">Chain of Agents</CardTitle>
                <CardDescription>
                  Orchestrate multi-agent workflows. Research agents hand off to analysts, who hand off to writers. Visible collaboration.
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="text-center border-2 hover:border-warm-300 transition-colors">
              <CardHeader className="pb-8 pt-8">
                <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-3">
                  <Server className="h-6 w-6 text-purple-600" />
                </div>
                <CardTitle className="text-lg">50+ Tool Integrations</CardTitle>
                <CardDescription>
                  MCP servers connect agents to GitHub, PostgreSQL, Slack, file systems, and more. Real capabilities, real results.
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="text-center border-2 hover:border-warm-300 transition-colors">
              <CardHeader className="pb-8 pt-8">
                <div className="w-12 h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3">
                  <Shield className="h-6 w-6 text-warm-600" />
                </div>
                <CardTitle className="text-lg">You Own Everything</CardTitle>
                <CardDescription>
                  Your data stays on your machine. Your agents, your workflows, your way. No subscription required to use what you build.
                </CardDescription>
              </CardHeader>
            </Card>
          </div>
        </div>
      </section>

      {/* Get Started Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4">
        <div className="container mx-auto max-w-4xl text-center">
          <h2 className="text-2xl sm:text-3xl font-bold mb-4 sm:mb-6 font-display">
            From Zero to Agents in Minutes
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
            <div className="text-center p-4 sm:p-0">
              <div className="w-12 h-12 sm:w-16 sm:h-16 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <span className="text-xl sm:text-2xl font-bold text-warm-700">1</span>
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">Clone & Run</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Download from GitHub. Start the DSPy backend and Flutter app. Works on Windows, macOS, and Linux.
              </p>
            </div>
            <div className="text-center p-4 sm:p-0">
              <div className="w-12 h-12 sm:w-16 sm:h-16 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <span className="text-xl sm:text-2xl font-bold text-warm-700">2</span>
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">Connect Your AI</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Add your Claude, OpenAI, or Gemini key - or run fully local with Ollama. Your keys never leave your device.
              </p>
            </div>
            <div className="text-center p-4 sm:p-0 sm:col-span-2 lg:col-span-1">
              <div className="w-12 h-12 sm:w-16 sm:h-16 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <span className="text-xl sm:text-2xl font-bold text-warm-700">3</span>
              </div>
              <h3 className="font-semibold mb-2 text-sm sm:text-base">Build Agent Workflows</h3>
              <p className="text-xs sm:text-sm text-muted-foreground">
                Create specialized agents, chain them together, connect MCP tools, and watch them collaborate on real tasks.
              </p>
            </div>
          </div>

          <div className="mt-8 sm:mt-12 px-4">
            <Link href="https://github.com/WereNext/Asmbli" target="_blank" rel="noopener noreferrer">
              <Button size="lg" className="w-full sm:w-auto bg-warm-500 hover:bg-warm-600 text-warm-50">
                Get Started on GitHub
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* What's an API Key Section */}
      <section className="py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto max-w-5xl">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4 font-display">
              Choose Your AI: Cloud APIs or Local Models
            </h2>
            <p className="text-lg text-muted-foreground max-w-3xl mx-auto">
              Connect to cloud AI services with your own API key, or run completely local models for maximum privacy and security
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 mb-12">
            {/* What is an API Key */}
            <Card className="border-2 border-warm-300/20 bg-warm-50/10">
              <CardHeader>
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-warm-200/50 rounded-lg flex items-center justify-center">
                    <Key className="h-5 w-5 text-warm-600" />
                  </div>
                  <CardTitle>Cloud AI with Your API Key</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="text-muted-foreground">
                  Use your own API key to connect to Claude, GPT-4, or Gemini. Direct connection to providers with enterprise-grade security:
                </p>
                <ul className="space-y-2">
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm">Authenticates your requests to the AI provider</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm">Tracks your usage for billing purposes</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm">Ensures your conversations remain private to your account</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm">Allows you to set usage limits and control costs</span>
                  </li>
                </ul>
              </CardContent>
            </Card>

            {/* Local Models */}
            <Card className="border-2 border-green-300/20 bg-green-50/10">
              <CardHeader>
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-green-500/10 rounded-lg flex items-center justify-center">
                    <Lock className="h-5 w-5 text-green-600" />
                  </div>
                  <CardTitle>Local Models (Maximum Security)</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="text-muted-foreground">
                  Run AI models completely offline on your own hardware for ultimate privacy and control:
                </p>
                <ul className="space-y-2">
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm"><strong>Zero network calls</strong> - everything runs locally</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm"><strong>No data ever leaves</strong> your machine</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm"><strong>No usage costs</strong> after initial setup</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                    <span className="text-sm"><strong>Perfect for sensitive</strong> or classified work</span>
                  </li>
                </ul>
              </CardContent>
            </Card>
          </div>

          {/* Provider Data Safety Policies */}
          <Card className="border-2 border-warm-300/30 bg-warm-50/20">
            <CardHeader>
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-warm-300/50 rounded-lg flex items-center justify-center">
                  <Lock className="h-5 w-5 text-warm-700" />
                </div>
                <CardTitle>Provider Data Safety Policies</CardTitle>
              </div>
              <CardDescription className="text-base">
                Major AI providers have strong data protection commitments when you use their API keys
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {/* Anthropic */}
                <div className="space-y-2">
                  <h4 className="font-semibold flex items-center gap-2">
                    <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                    Anthropic (Claude)
                  </h4>
                  <ul className="space-y-1 text-sm text-muted-foreground ml-4">
                    <li>• API inputs/outputs are <strong>NOT used</strong> for training models</li>
                    <li>• Data is <strong>automatically deleted</strong> within 30 days unless legally required</li>
                    <li>• <strong>Zero data retention</strong> option available for enterprise customers</li>
                    <li>• SOC 2 Type II certified with strict security controls</li>
                  </ul>
                </div>

                {/* OpenAI */}
                <div className="space-y-2">
                  <h4 className="font-semibold flex items-center gap-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    OpenAI (GPT)
                  </h4>
                  <ul className="space-y-1 text-sm text-muted-foreground ml-4">
                    <li>• API data is <strong>NOT used</strong> for training by default</li>
                    <li>• 30-day data retention for abuse monitoring (can opt-out)</li>
                    <li>• Enterprise agreements available with custom retention</li>
                    <li>• SOC 2 compliant with regular security audits</li>
                  </ul>
                </div>

                {/* Google */}
                <div className="space-y-2">
                  <h4 className="font-semibold flex items-center gap-2">
                    <div className="w-2 h-2 bg-warm-400 rounded-full"></div>
                    Google (Gemini)
                  </h4>
                  <ul className="space-y-1 text-sm text-muted-foreground ml-4">
                    <li>• API data <strong>NOT used</strong> for model improvement</li>
                    <li>• Customizable data retention policies</li>
                    <li>• Cloud-level encryption and security standards</li>
                    <li>• ISO 27001, SOC 1/2/3 certified infrastructure</li>
                  </ul>
                </div>

                <div className="mt-6 p-4 bg-warm-100/50 rounded-lg border border-warm-300/20">
                  <p className="text-sm flex items-start gap-2">
                    <Shield className="h-4 w-4 text-warm-700 mt-0.5 flex-shrink-0" />
                    <span>
                      <strong>Key Point:</strong> When you use your own API key with Asmbli, your data goes directly to your chosen provider. 
                      We never see, store, or process your conversations - ensuring maximum privacy and compliance with your provider's security policies.
                    </span>
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="text-center mt-8">
            <p className="text-muted-foreground mb-6">
              Choose your AI approach: cloud convenience or local privacy
            </p>
            <div className="grid sm:grid-cols-2 gap-4 max-w-4xl mx-auto">
              <div>
                <h4 className="font-semibold mb-3 text-sm">Cloud AI Providers</h4>
                <div className="flex flex-col gap-2">
                  <Link href="https://console.anthropic.com/api" target="_blank" rel="noopener noreferrer">
                    <Button variant="outline" size="sm" className="w-full">
                      Get Anthropic API Key
                      <ExternalLink className="ml-2 h-3 w-3" />
                    </Button>
                  </Link>
                  <Link href="https://platform.openai.com/api-keys" target="_blank" rel="noopener noreferrer">
                    <Button variant="outline" size="sm" className="w-full">
                      Get OpenAI API Key
                      <ExternalLink className="ml-2 h-3 w-3" />
                    </Button>
                  </Link>
                  <Link href="https://makersuite.google.com/app/apikey" target="_blank" rel="noopener noreferrer">
                    <Button variant="outline" size="sm" className="w-full">
                      Get Google API Key
                      <ExternalLink className="ml-2 h-3 w-3" />
                    </Button>
                  </Link>
                </div>
              </div>
              <div>
                <h4 className="font-semibold mb-3 text-sm">Local Models via Ollama</h4>
                <div className="flex flex-col gap-2">
                  <Button variant="outline" size="sm" className="w-full">
                    Built-in Ollama Support
                    <Lock className="ml-2 h-3 w-3" />
                  </Button>
                  <Button variant="outline" size="sm" className="w-full" disabled>
                    Auto Model Discovery
                    <Lock className="ml-2 h-3 w-3" />
                  </Button>
                  <Button variant="outline" size="sm" className="w-full" disabled>
                    Custom Endpoints
                    <Lock className="ml-2 h-3 w-3" />
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* MCP Servers Library Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto">
          <div className="text-center mb-8 sm:mb-12">
            <h2 className="text-2xl sm:text-3xl font-bold mb-4">
              Connect Agents to Real Tools
            </h2>
            <p className="text-base sm:text-lg text-muted-foreground max-w-2xl mx-auto px-4">
              MCP (Model Context Protocol) servers give your agents access to real capabilities - file systems, databases, APIs, and more.
            </p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-4">
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <FileText className="h-5 w-5 text-blue-500" />
                  <CardTitle className="text-sm">Filesystem</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  File operations, directory traversal, search & monitoring
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiGit className="h-5 w-5 text-orange-500" />
                  <CardTitle className="text-sm">Git</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Repository cloning, branch management, commit operations
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiGithub className="h-5 w-5 text-gray-800" />
                  <CardTitle className="text-sm">GitHub</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Issues, pull requests, code review, actions integration
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiPostgresql className="h-5 w-5 text-blue-600" />
                  <CardTitle className="text-sm">PostgreSQL</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  SQL execution, schema introspection, performance analysis
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <Database className="h-5 w-5 text-purple-500" />
                  <CardTitle className="text-sm">Memory</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Knowledge storage, semantic search, context management
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiBrave className="h-5 w-5 text-orange-600" />
                  <CardTitle className="text-sm">Brave Search</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Real-time web search, ranking, domain-specific queries
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <Server className="h-5 w-5 text-green-500" />
                  <CardTitle className="text-sm">HTTP/Fetch</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  API requests, authentication, response parsing
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiFigma className="h-5 w-5 text-purple-600" />
                  <CardTitle className="text-sm">Figma</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Design files, components, design systems integration
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <Monitor className="h-5 w-5 text-blue-700" />
                  <CardTitle className="text-sm">VSCode</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Code editing, extensions, workspace control
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiSlack className="h-5 w-5 text-purple-700" />
                  <CardTitle className="text-sm">Slack</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Team communication, channels, message automation
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiNotion className="h-5 w-5 text-black" />
                  <CardTitle className="text-sm">Notion</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Knowledge bases, documents, database operations
                </CardDescription>
              </CardHeader>
            </Card>
            <Card className="hover:shadow-lg transition-shadow bg-warm-50/10 border-warm-200/20">
              <CardHeader className="pb-3">
                <div className="flex items-center gap-2">
                  <SiLinear className="h-5 w-5 text-blue-800" />
                  <CardTitle className="text-sm">Linear</CardTitle>
                </div>
                <CardDescription className="text-xs">
                  Issue tracking, project management, team workflows
                </CardDescription>
              </CardHeader>
            </Card>
          </div>
          <div className="text-center mt-8">
            <Link href="/mcp-servers">
              <Button variant="outline">
                View All MCP Servers
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Democratizing AI Section */}
      <section id="democratizing-ai" className="py-12 sm:py-16 lg:py-20 px-4 bg-gradient-to-br from-warm-100/30 to-warm-50/30">
        <div className="container mx-auto max-w-2xl text-center">
          <h2 className="text-2xl sm:text-3xl font-bold mb-4 sm:mb-6 font-display">
            AI Agents for Everyone
          </h2>
          <p className="text-base sm:text-lg text-muted-foreground mb-6 sm:mb-8 px-4">
            Powerful AI shouldn't be locked behind enterprise contracts. Asmbli puts professional-grade
            agent orchestration in the hands of individuals, startups, and teams of any size.
          </p>

          <div className="bg-white rounded-lg sm:rounded-xl shadow-lg p-4 sm:p-6 lg:p-8 border mx-4 sm:mx-0">
            <div className="text-center py-8">
              <div className="w-16 h-16 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <Users className="h-8 w-8 text-warm-600" />
              </div>
              <h3 className="text-xl font-semibold mb-4">No Gatekeepers</h3>
              <p className="text-muted-foreground mb-6">
                Bring your own API keys. Run locally or in the cloud. Inspect every line of code.
                The full platform is yours - no artificial limitations, no premium tiers for core features.
              </p>
              <div className="flex flex-col sm:flex-row gap-3 justify-center">
                <Link href="https://github.com/WereNext/Asmbli" target="_blank" rel="noopener noreferrer">
                  <Button className="w-full sm:w-auto bg-warm-500 hover:bg-warm-600 text-warm-50">
                    Get the Platform
                  </Button>
                </Link>
                <Link href="https://github.com/WereNext/Asmbli#-quick-start" target="_blank" rel="noopener noreferrer">
                  <Button variant="outline" className="w-full sm:w-auto">
                    Quick Start Guide
                  </Button>
                </Link>
              </div>
            </div>
          </div>

          <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center items-center text-xs sm:text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>See all agent reasoning</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>Inspect every decision</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>Modify anything</span>
            </div>
          </div>
        </div>
      </section>

      {/* How We Build Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-blue-50/10">
        <div className="container mx-auto max-w-4xl text-center">
          <h2 className="text-2xl sm:text-3xl font-bold mb-4 sm:mb-6 font-display">
            Built in the Open, With AI
          </h2>
          <div className="bg-white rounded-lg shadow-lg p-6 sm:p-8 border">
            <div className="flex items-start space-x-4 mb-6">
              <Bot className="w-8 h-8 text-blue-600 flex-shrink-0 mt-1" />
              <div className="text-left">
                <p className="text-lg text-muted-foreground leading-relaxed mb-4">
                  Asmbli is developed using Claude Code - proving that AI-assisted development can create
                  real, production-quality tools. Every feature, every component, built through transparent human-AI collaboration.
                </p>
                <p className="text-xl font-semibold text-blue-600 font-display">
                  The process is as visible as the product.
                </p>
              </div>
            </div>
            <div className="bg-purple-50 border border-purple-200 rounded-lg p-6">
              <p className="text-muted-foreground leading-relaxed mb-4">
                We believe the best way to build trust in AI is to show exactly how it works. That's why Asmbli's
                development is fully transparent - you can see every conversation, every decision, every iteration.
              </p>
              <p className="text-sm text-muted-foreground">
                Built with Claude Code, GitHub Copilot, and Kiro - demonstrating that AI collaboration
                is ready for serious software development.
              </p>
              <div className="mt-4 bg-warm-100 border border-warm-200 rounded-lg p-4">
                <p className="text-warm-700 text-sm font-medium">
                  Dogfooding the future: using AI agents to build tools for AI agents.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Privacy Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto max-w-3xl text-center">
          <div className="flex items-center justify-center gap-2 mb-4">
            <Shield className="h-5 w-5 sm:h-6 sm:w-6 text-warm-600" />
            <h2 className="text-xl sm:text-2xl font-bold font-display">
              Your Data Stays Yours
            </h2>
          </div>
          <p className="text-base sm:text-lg text-muted-foreground mb-6 px-4">
            Everything runs locally on your machine. Your conversations, your agent configurations, your workflows -
            they never leave your device unless you explicitly choose to share them.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center items-center text-xs sm:text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-warm-600" />
              <span className="whitespace-nowrap">Local-first architecture</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-warm-600" />
              <span className="whitespace-nowrap">Your API keys, secured locally</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-warm-600" />
              <span className="whitespace-nowrap">No telemetry, no tracking</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <Footer />
    </div>
  )
}