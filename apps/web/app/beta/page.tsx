'use client'

import Link from 'next/link'
import { useState } from 'react'
import { motion } from 'framer-motion'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Bot, Zap, Users, Shield, CheckCircle, Sparkles, Eye, Clock, GitBranch, MessageSquare } from 'lucide-react'
import { Navigation } from '@/components/Navigation'
import { Footer } from '@/components/Footer'

// Animation variants
const fadeInUp = {
  hidden: { opacity: 0, y: 40 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: "easeOut" as const } }
}

const fadeIn = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { duration: 0.6 } }
}

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1, delayChildren: 0.2 }
  }
}

const staggerItem = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.5 } }
}

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
      // Netlify Forms requires URL-encoded data
      const formBody = new URLSearchParams({
        'form-name': 'beta-waitlist',
        ...formData
      }).toString();

      const response = await fetch('/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formBody,
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

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }));
  };

  if (submitStatus === 'success') {
    return (
      <div className="text-center py-8">
        <CheckCircle className="h-16 w-16 text-green-500 mx-auto mb-4" />
        <h3 className="text-2xl font-semibold text-green-700 mb-2">You're on the list!</h3>
        <p className="text-muted-foreground max-w-md mx-auto">
          Thanks for joining the Asmbli beta waitlist. We'll notify you as soon as early access is available.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4" data-netlify="true" name="beta-waitlist">
      {/* Hidden field for Netlify Forms */}
      <input type="hidden" name="form-name" value="beta-waitlist" />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label htmlFor="firstName" className="block text-sm font-medium mb-1">First Name</label>
          <input
            type="text"
            id="firstName"
            name="firstName"
            placeholder="Your first name"
            value={formData.firstName}
            onChange={handleChange}
            className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent bg-white"
            required
          />
        </div>
        <div>
          <label htmlFor="lastName" className="block text-sm font-medium mb-1">Last Name</label>
          <input
            type="text"
            id="lastName"
            name="lastName"
            placeholder="Your last name"
            value={formData.lastName}
            onChange={handleChange}
            className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent bg-white"
            required
          />
        </div>
      </div>
      <div>
        <label htmlFor="email" className="block text-sm font-medium mb-1">Email Address</label>
        <input
          type="email"
          id="email"
          name="email"
          placeholder="you@company.com"
          value={formData.email}
          onChange={handleChange}
          className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent bg-white"
          required
        />
      </div>
      <div>
        <label htmlFor="useCase" className="block text-sm font-medium mb-1">What will you use Asmbli for? (Optional)</label>
        <textarea
          id="useCase"
          name="useCase"
          placeholder="Tell us about your use case - what kind of agents do you want to build?"
          value={formData.useCase}
          onChange={handleChange}
          rows={3}
          className="w-full px-4 py-3 border border-stone-300 rounded-lg focus:ring-2 focus:ring-warm-400 focus:border-transparent resize-none bg-white"
        />
      </div>
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-full bg-warm-500 hover:bg-warm-600 text-warm-50 py-3 text-lg disabled:opacity-50"
      >
        {isSubmitting ? 'Joining...' : 'Join the Beta Waitlist'}
      </Button>
      {submitStatus === 'error' && (
        <p className="text-red-600 text-center text-sm">
          Something went wrong. Please try again or email us directly at beta@asmbli.io
        </p>
      )}
    </form>
  );
}

// Hidden form for Netlify to detect at build time (required for JS-rendered forms)
function NetlifyFormDetection() {
  return (
    <form name="beta-waitlist" data-netlify="true" hidden>
      <input type="text" name="firstName" />
      <input type="text" name="lastName" />
      <input type="email" name="email" />
      <textarea name="useCase" />
    </form>
  );
}

export default function BetaWaitlistPage() {
  return (
    <div className="flex flex-col min-h-screen">
      {/* Hidden form for Netlify detection at build time */}
      <NetlifyFormDetection />

      {/* Navigation */}
      <Navigation />

      {/* Hero Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-gradient-to-br from-warm-50/20 to-background overflow-hidden">
        <div className="container mx-auto max-w-4xl text-center">
          <motion.div
            className="inline-flex items-center gap-2 bg-warm-100 text-warm-700 px-4 py-2 rounded-full text-sm font-medium mb-6"
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <Sparkles className="h-4 w-4" />
            Early Access Coming Soon
          </motion.div>
          <motion.h1
            className="text-3xl sm:text-4xl lg:text-5xl font-bold italic mb-4 sm:mb-6 font-display leading-tight"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
          >
            Join the Asmbli Beta
          </motion.h1>
          <motion.p
            className="text-lg sm:text-xl text-muted-foreground mb-6 sm:mb-8 max-w-3xl mx-auto px-4"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
          >
            Be among the first to experience the future of AI agent templates.
            Get early access to build, customize, and control AI agents with full transparency.
          </motion.p>
        </div>
      </section>

      {/* Signup Form Section */}
      <section className="py-12 sm:py-16 px-4">
        <div className="container mx-auto max-w-xl">
          <motion.div
            initial={{ opacity: 0, y: 40, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ duration: 0.6, delay: 0.3 }}
          >
            <Card className="border-2 border-warm-200 shadow-xl">
              <CardHeader className="text-center pb-2">
                <CardTitle className="text-2xl">Request Early Access</CardTitle>
                <CardDescription className="text-base">
                  Join the waitlist and we'll notify you when beta access is available
                </CardDescription>
              </CardHeader>
              <CardContent className="pt-6">
                <BetaSignupForm />
              </CardContent>
            </Card>
          </motion.div>
        </div>
      </section>

      {/* What You'll Get Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto">
          <motion.div
            className="text-center mb-8 sm:mb-12"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            variants={fadeInUp}
          >
            <h2 className="text-2xl sm:text-3xl font-bold mb-4 font-display">
              What Beta Members Get
            </h2>
            <p className="text-base sm:text-lg text-muted-foreground max-w-2xl mx-auto px-4">
              Early access comes with exclusive benefits
            </p>
          </motion.div>

          <motion.div
            className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 max-w-6xl mx-auto"
            variants={staggerContainer}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-50px" }}
          >
            <motion.div variants={staggerItem}>
              <Card className="text-center border-2 hover:border-warm-300 transition-colors h-full">
                <CardHeader className="pb-6 pt-8">
                  <div className="w-12 h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <Clock className="h-6 w-6 text-warm-600" />
                  </div>
                  <CardTitle className="text-lg">Early Access</CardTitle>
                  <CardDescription>
                    Be first to use new features before they're publicly available
                  </CardDescription>
                </CardHeader>
              </Card>
            </motion.div>

            <motion.div variants={staggerItem}>
              <Card className="text-center border-2 hover:border-warm-300 transition-colors h-full">
                <CardHeader className="pb-6 pt-8">
                  <div className="w-12 h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <Users className="h-6 w-6 text-warm-600" />
                  </div>
                  <CardTitle className="text-lg">Direct Feedback</CardTitle>
                  <CardDescription>
                    Shape the product roadmap with direct access to our team
                  </CardDescription>
                </CardHeader>
              </Card>
            </motion.div>

            <motion.div variants={staggerItem}>
              <Card className="text-center border-2 hover:border-warm-300 transition-colors h-full">
                <CardHeader className="pb-6 pt-8">
                  <div className="w-12 h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <Eye className="h-6 w-6 text-warm-600" />
                  </div>
                  <CardTitle className="text-lg">Glass Box Access</CardTitle>
                  <CardDescription>
                    Full visibility into agent reasoning and decision-making
                  </CardDescription>
                </CardHeader>
              </Card>
            </motion.div>

            <motion.div variants={staggerItem}>
              <Card className="text-center border-2 hover:border-warm-300 transition-colors h-full">
                <CardHeader className="pb-6 pt-8">
                  <div className="w-12 h-12 bg-warm-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <Shield className="h-6 w-6 text-warm-600" />
                  </div>
                  <CardTitle className="text-lg">Privacy First</CardTitle>
                  <CardDescription>
                    Your data stays on your device - we never see or store it
                  </CardDescription>
                </CardHeader>
              </Card>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* What's Coming Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4">
        <div className="container mx-auto max-w-4xl">
          <div className="text-center mb-8 sm:mb-12">
            <h2 className="text-2xl sm:text-3xl font-bold mb-4 font-display">
              What We're Building
            </h2>
            <p className="text-base sm:text-lg text-muted-foreground px-4">
              A glimpse at what's coming in the Asmbli beta
            </p>
          </div>

          {/* Visual Reasoning Flow - Featured */}
          <Card className="border-2 border-warm-300 mb-8">
            <CardHeader>
              <div className="flex items-center gap-3 mb-2">
                <div className="w-12 h-12 bg-warm-200 rounded-lg flex items-center justify-center">
                  <GitBranch className="h-6 w-6 text-warm-700" />
                </div>
                <div>
                  <CardTitle className="text-xl">Visual Reasoning Flow</CardTitle>
                  <CardDescription>Build your agent's logic visually</CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground mb-6">
                Design how your agent thinks with our visual canvas. Drag, drop, and connect
                reasoning blocks to create sophisticated decision-making workflows - no code required.
              </p>

              <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Simple Reasoning</h4>
                  <p className="text-xs text-muted-foreground">
                    Goal → Context → Reasoning flow for quick decisions and basic analysis
                  </p>
                </div>
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Decision Gateway</h4>
                  <p className="text-xs text-muted-foreground">
                    Multi-path branching with conditional logic for complex decisions
                  </p>
                </div>
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Research & Analysis</h4>
                  <p className="text-xs text-muted-foreground">
                    Deep research with iterative analysis, validation, and synthesis
                  </p>
                </div>
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Problem Solving</h4>
                  <p className="text-xs text-muted-foreground">
                    Systematic breakdown and solution generation for technical issues
                  </p>
                </div>
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Conversation Design</h4>
                  <p className="text-xs text-muted-foreground">
                    Interactive dialogue flows with context awareness and memory
                  </p>
                </div>
                <div className="p-4 bg-warm-50 rounded-lg border border-warm-200">
                  <h4 className="font-semibold text-sm mb-2">Chain of Thought</h4>
                  <p className="text-xs text-muted-foreground">
                    Step-by-step reasoning with visible thought process (CoT, ToT, ReAct)
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="grid md:grid-cols-3 gap-8">
            <Card className="border-2">
              <CardHeader>
                <div className="flex items-center gap-3 mb-2">
                  <div className="w-10 h-10 bg-warm-100 rounded-lg flex items-center justify-center">
                    <Bot className="h-5 w-5 text-warm-600" />
                  </div>
                  <CardTitle>Agent Building Platform</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Create specialized AI agents with custom personalities, tools, and reasoning patterns.
                  Connect MCP servers and deploy agents that actually get work done.
                </p>
              </CardContent>
            </Card>

            <Card className="border-2">
              <CardHeader>
                <div className="flex items-center gap-3 mb-2">
                  <div className="w-10 h-10 bg-warm-100 rounded-lg flex items-center justify-center">
                    <MessageSquare className="h-5 w-5 text-warm-600" />
                  </div>
                  <CardTitle>Custom AI Chat Interface</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  A beautiful chat experience for any AI provider - Claude, OpenAI, Gemini, or local models.
                  Bring your own keys and own your conversations.
                </p>
              </CardContent>
            </Card>

            <Card className="border-2">
              <CardHeader>
                <div className="flex items-center gap-3 mb-2">
                  <div className="w-10 h-10 bg-warm-100 rounded-lg flex items-center justify-center">
                    <Eye className="h-5 w-5 text-warm-600" />
                  </div>
                  <CardTitle>Live Task Control</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Human verification at every step. Watch agents work, approve critical actions,
                  and intervene when needed. You stay in control.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-warm-50/10">
        <div className="container mx-auto max-w-3xl">
          <div className="text-center mb-8 sm:mb-12">
            <h2 className="text-2xl sm:text-3xl font-bold mb-4 font-display">
              Frequently Asked Questions
            </h2>
          </div>

          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">When will beta access be available?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  We're rolling out beta access in waves starting soon. Join the waitlist to secure your spot -
                  earlier signups get priority access.
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Is Asmbli free during beta?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Beta members get free access to all features during the beta period.
                  Help us shape the future of AI agents with your feedback.
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg">What do I need to use Asmbli?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Asmbli runs on Windows, macOS, and Linux. You'll need your own API keys for
                  AI providers (Claude, OpenAI, etc.) or you can use local models via Ollama for
                  complete privacy.
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Is my data private?</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-muted-foreground">
                  Absolutely. Asmbli is local-first - your conversations, agent configurations,
                  and workflows stay on your device. We never see or store your data.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-12 sm:py-16 lg:py-20 px-4 bg-gradient-to-br from-warm-100/30 to-warm-50/30">
        <div className="container mx-auto max-w-2xl text-center">
          <h2 className="text-2xl sm:text-3xl font-bold mb-4 sm:mb-6 font-display">
            Ready to Own Your AI Experience?
          </h2>
          <p className="text-base sm:text-lg text-muted-foreground mb-6 sm:mb-8 px-4">
            Join thousands of developers and teams waiting to build the next generation of AI agents.
          </p>

          <Link href="#" onClick={(e) => { e.preventDefault(); window.scrollTo({ top: 0, behavior: 'smooth' }); }}>
            <Button size="lg" className="bg-warm-500 hover:bg-warm-600 text-warm-50">
              Join the Beta Waitlist
            </Button>
          </Link>

          <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row gap-3 sm:gap-6 justify-center items-center text-xs sm:text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>No credit card required</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>Early access priority</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-green-500" />
              <span>100% local-first privacy</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <Footer />
    </div>
  )
}
