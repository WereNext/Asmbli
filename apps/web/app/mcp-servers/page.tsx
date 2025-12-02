'use client'

import Link from 'next/link'
import { useState, useMemo } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { ArrowLeft, Server, Database, Search, Brain, Calendar, Terminal, Clock, Link as LinkIcon, HardDrive, Bot, Shield, Mail, Zap, Users, X, FileText, Monitor } from 'lucide-react'
import { 
  SiGithub, 
  SiFigma, 
  SiPostgresql,
  SiGit,
  SiBrave,
  SiSlack,
  SiNotion,
  SiLinear,
  SiDiscord,
  SiOpenai,
  SiAnthropic,
  SiZapier,
  SiGmail
} from 'react-icons/si'
import { Navigation } from '@/components/Navigation'
import { Footer } from '@/components/Footer'

// Static data from your extensions library - MCP servers and key integrations
const mcpServers = [
  // Core MCP Servers
  {
    id: 'filesystem-mcp',
    name: 'Filesystem MCP Server',
    category: 'Development & Code',
    provider: 'MCP Core',
    description: 'Access and manage local files and directories through Model Context Protocol',
    features: ['Read and write local files', 'Directory traversal and listing', 'File search and pattern matching', 'File metadata access', 'Permission management', 'Batch operations', 'File watching and monitoring', 'Safe sandbox operations'],
    complexity: 'low',
    authMethod: 'none',
    pricing: 'free',
    icon: 'HardDrive'
  },
  {
    id: 'git-mcp',
    name: 'Git MCP Server',
    category: 'Development & Code',
    provider: 'MCP Core',
    description: 'Git repository operations and version control through Model Context Protocol (Early Development)',
    features: ['Repository cloning and initialization', 'Branch management and switching', 'Commit history and diff analysis', 'File staging and committing', 'Remote repository operations', 'Merge conflict resolution', 'Tag and release management', 'Submodule support'],
    complexity: 'medium',
    authMethod: 'none',
    pricing: 'free',
    icon: 'Git'
  },
  {
    id: 'postgres-mcp',
    name: 'PostgreSQL MCP Server',
    category: 'Analytics & Data',
    provider: 'MCP Core',
    description: 'PostgreSQL database operations and queries through Model Context Protocol (Official + Community versions available)',
    features: ['SQL query execution (read-only in official version)', 'Database schema introspection', 'Table and view operations', 'Connection to PostgreSQL databases', 'Enhanced features in community versions', 'Performance analysis (community versions)', 'Read/write access (community versions)', 'Multiple database connections'],
    complexity: 'high',
    authMethod: 'database-credentials',
    pricing: 'free',
    icon: 'PostgreSQL'
  },
  {
    id: 'memory-mcp',
    name: 'Memory MCP Server',
    category: 'AI & Machine Learning',
    provider: 'MCP Core',
    description: 'Persistent memory and knowledge base management for AI agents',
    features: ['Persistent knowledge storage', 'Semantic search and retrieval', 'Context-aware memory management', 'Entity relationship tracking', 'Memory consolidation', 'Fact verification and updates', 'Memory expiration policies', 'Cross-session continuity'],
    complexity: 'medium',
    authMethod: 'none',
    pricing: 'free',
    icon: 'Brain'
  },
  {
    id: 'search-mcp',
    name: 'Search MCP Server',
    category: 'Browser & Web Tools',
    provider: 'MCP Core',
    description: 'Web search and information retrieval through Model Context Protocol',
    features: ['Web search with multiple engines', 'Real-time information retrieval', 'Search result ranking and filtering', 'Domain-specific searches', 'Image and video search', 'News and recent content', 'Safe search filtering', 'Multi-language support'],
    complexity: 'low',
    authMethod: 'api-key',
    pricing: 'freemium',
    icon: 'Search'
  },
  {
    id: 'terminal-mcp',
    name: 'Terminal MCP Server',
    category: 'Development & Code',
    provider: 'MCP Core',
    description: 'Execute shell commands and terminal operations through Model Context Protocol',
    features: ['Shell command execution', 'Environment variable management', 'Process monitoring and control', 'File system operations', 'Package manager integration', 'Build tool automation', 'System information queries', 'Security sandboxing'],
    complexity: 'high',
    authMethod: 'none',
    pricing: 'free',
    icon: 'Terminal'
  },
  {
    id: 'http-mcp',
    name: 'HTTP MCP Server',
    category: 'Development & Code',
    provider: 'MCP Core',
    description: 'HTTP client for API requests and web service integration',
    features: ['HTTP GET, POST, PUT, DELETE requests', 'Request header and body customization', 'Authentication handling', 'Response parsing and formatting', 'Error handling and retries', 'Rate limiting and throttling', 'SSL/TLS certificate validation', 'Proxy and middleware support'],
    complexity: 'medium',
    authMethod: 'api-key',
    pricing: 'free',
    icon: 'LinkIcon'
  },
  {
    id: 'calendar-mcp',
    name: 'Calendar MCP Server',
    category: 'Automation & Productivity',
    provider: 'MCP Core',
    description: 'Calendar and scheduling operations through Model Context Protocol',
    features: ['Event creation and management', 'Calendar synchronization', 'Meeting scheduling', 'Availability checking', 'Reminder and notification setup', 'Recurring event handling', 'Multi-calendar support', 'Time zone management'],
    complexity: 'medium',
    authMethod: 'oauth',
    pricing: 'free',
    icon: 'Calendar'
  },
  {
    id: 'sequential-thinking-mcp',
    name: 'Sequential Thinking MCP Server',
    category: 'AI & Machine Learning',
    provider: 'MCP Core',
    description: 'Dynamic problem-solving through thought sequences and structured reasoning for AI agents',
    features: ['Sequential thought generation', 'Problem decomposition', 'Multi-step reasoning chains', 'Dynamic thinking sequences', 'Reasoning pattern recognition', 'Logical flow management', 'Thought process tracking', 'Cognitive workflow optimization'],
    complexity: 'medium',
    authMethod: 'none',
    pricing: 'free',
    icon: 'Brain'
  },
  {
    id: 'time-mcp',
    name: 'Time MCP Server',
    category: 'Automation & Productivity',
    provider: 'MCP Core',
    description: 'Time and timezone conversion capabilities with scheduling and temporal operations',
    features: ['Timezone conversion and management', 'Time format standardization', 'Schedule calculation', 'Date arithmetic operations', 'World clock functionality', 'Time-based calculations', 'Calendar integration support', 'Temporal query processing'],
    complexity: 'low',
    authMethod: 'none',
    pricing: 'free',
    icon: 'Clock'
  },
  // Key Integrations
  {
    id: 'figma-mcp',
    name: 'Figma MCP Server',
    category: 'Design & Prototyping',
    provider: 'Figma',
    description: 'Connect to Figma files, components, and design systems through Model Context Protocol with current platform features',
    features: ['Access Figma files and projects', 'Read and modify design components', 'Extract design tokens and styles', 'Manage design system libraries', 'Code Connect integration', 'Library Analytics API access', 'Dev Mode component inspection', 'Collaborate on design reviews', 'Export assets and specifications'],
    complexity: 'medium',
    authMethod: 'oauth',
    pricing: 'freemium',
    icon: 'Figma'
  },
  {
    id: 'vscode',
    name: 'VSCode MCP Server',
    category: 'Development & Code',
    provider: 'Microsoft',
    description: 'VSCode integration for code editing, extension management, and workspace control through Model Context Protocol',
    features: ['Open and edit files in VSCode', 'Extension management and recommendations', 'Workspace and project navigation', 'Code formatting and linting', 'Integrated terminal access', 'Debug configuration', 'Snippet management', 'Settings synchronization', 'Multi-cursor editing commands'],
    complexity: 'medium',
    authMethod: 'none',
    pricing: 'free',
    icon: 'VSCode'
  },
  {
    id: 'github',
    name: 'GitHub MCP Server',
    category: 'Development & Code',
    provider: 'GitHub',
    description: 'GitHub integration for repository management, pull requests, and collaborative development through Model Context Protocol',
    features: ['Repository and file access', 'Pull request management', 'Issue tracking and creation', 'Code review and comments', 'Branch and commit operations', 'GitHub Actions integration', 'Design system repository management', 'Component library maintenance', 'Webhook and event handling'],
    complexity: 'medium',
    authMethod: 'oauth',
    pricing: 'freemium',
    icon: 'Github'
  },
  {
    id: 'slack',
    name: 'Slack Integration',
    category: 'Communication & Collaboration',
    provider: 'Slack',
    description: 'Integrate with Slack for team communication, notifications, and design collaboration workflows via API or MCP',
    features: ['Channel and DM messaging', 'File and image sharing', 'Design review notifications', 'Automated status updates', 'Team collaboration workflows', 'Integration with design tools', 'Feedback collection and routing', 'Design system announcements', 'MCP server protocol support'],
    complexity: 'medium',
    authMethod: 'oauth',
    pricing: 'freemium',
    icon: 'Slack'
  },
  {
    id: 'openai-api',
    name: 'OpenAI GPT Models',
    category: 'AI & Machine Learning',
    provider: 'OpenAI',
    description: 'Access OpenAI GPT models for design content generation, code assistance, and creative ideation',
    features: ['Text generation and editing', 'Code generation and review', 'Design content creation', 'Component documentation', 'Design system guidelines', 'Accessibility recommendations', 'UX copy and microcopy', 'Design critique and feedback'],
    complexity: 'low',
    authMethod: 'api-key',
    pricing: 'paid',
    icon: 'OpenAI'
  },
  {
    id: 'anthropic-api',
    name: 'Anthropic Claude',
    category: 'AI & Machine Learning',
    provider: 'Anthropic',
    description: 'Integrate Claude for safe AI assistance in design workflows, documentation, and analysis',
    features: ['Safe and helpful AI responses', 'Long-context understanding', 'Design analysis and critique', 'Accessibility auditing', 'Design system consistency checks', 'Code review and suggestions', 'Documentation improvement', 'Design process optimization'],
    complexity: 'low',
    authMethod: 'api-key',
    pricing: 'paid',
    icon: 'Anthropic'
  },
  {
    id: 'zapier-webhooks',
    name: 'Zapier Automation',
    category: 'Automation & Productivity',
    provider: 'Zapier',
    description: 'Connect to 5000+ apps through Zapier workflows and automation triggers',
    features: ['Multi-app workflow automation', 'Trigger-based task execution', 'Data transformation and routing', 'Conditional logic and filters', 'Scheduled and real-time automation', 'Error handling and retries', 'Webhook and API integrations', 'Custom app connections'],
    complexity: 'medium',
    authMethod: 'api-key',
    pricing: 'freemium',
    icon: 'Zap'
  },
  {
    id: 'gmail-api',
    name: 'Gmail Integration',
    category: 'Email & Communication',
    provider: 'Google Gmail',
    description: 'Full Gmail API access for email automation, management, and communication workflows',
    features: ['Email sending and receiving', 'Advanced search and filtering', 'Label and folder management', 'Attachment processing', 'Draft management', 'Signature and template support', 'Bulk email operations', 'Threading and conversation tracking'],
    complexity: 'medium',
    authMethod: 'oauth',
    pricing: 'free',
    icon: 'Mail'
  },
  {
    id: 'discord-bot',
    name: 'Discord Bot Integration',
    category: 'Email & Communication',
    provider: 'Discord',
    description: 'Discord bot capabilities for community management, notifications, and automated interactions',
    features: ['Server and channel management', 'Message sending and monitoring', 'Slash command creation', 'Voice channel integration', 'Role and permission management', 'Embed and rich message support', 'Webhook integrations', 'Community moderation tools'],
    complexity: 'medium',
    authMethod: 'bot-token',
    pricing: 'free',
    icon: 'Users'
  }
]

const getServerIcon = (iconName: string) => {
  switch (iconName) {
    case 'HardDrive': return FileText
    case 'Git': return SiGit as any
    case 'PostgreSQL': return SiPostgresql as any
    case 'Database': return Database
    case 'Brain': return Brain
    case 'Search': return Search
    case 'Terminal': return Terminal
    case 'LinkIcon': return LinkIcon
    case 'Calendar': return Calendar
    case 'Clock': return Clock
    case 'Figma': return SiFigma as any
    case 'Github': return SiGithub as any
    case 'VSCode': return Monitor
    case 'Slack': return SiSlack as any
    case 'OpenAI': return SiOpenai as any
    case 'Anthropic': return Bot
    case 'Bot': return Bot
    case 'Zap': return SiZapier as any
    case 'Mail': return SiGmail as any
    case 'Users': return Users
    default: return Server
  }
}

const getCategoryColor = (category: string) => {
  switch (category) {
    case 'Development & Code': return 'bg-blue-100 text-blue-800'
    case 'Analytics & Data': return 'bg-purple-100 text-purple-800'
    case 'AI & Machine Learning': return 'bg-green-100 text-green-800'
    case 'Browser & Web Tools': return 'bg-orange-100 text-orange-800'
    case 'Design & Prototyping': return 'bg-pink-100 text-pink-800'
    case 'Automation & Productivity': return 'bg-yellow-100 text-yellow-800'
    case 'Communication & Collaboration': return 'bg-cyan-100 text-cyan-800'
    case 'Email & Communication': return 'bg-indigo-100 text-indigo-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

const getComplexityColor = (complexity: string) => {
  switch (complexity) {
    case 'low': return 'bg-green-100 text-green-800'
    case 'medium': return 'bg-yellow-100 text-yellow-800'
    case 'high': return 'bg-red-100 text-red-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

const getPricingColor = (pricing: string) => {
  switch (pricing) {
    case 'free': return 'bg-green-100 text-green-800'
    case 'freemium': return 'bg-blue-100 text-blue-800'
    case 'paid': return 'bg-orange-100 text-orange-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

export default function MCPServersPage() {
  const [selectedCategories, setSelectedCategories] = useState<string[]>([])
  const [selectedComplexity, setSelectedComplexity] = useState<string[]>([])
  const [selectedPricing, setSelectedPricing] = useState<string[]>([])

  // Get unique values for filters
  const categories = [...new Set(mcpServers.map(server => server.category))]
  const complexities = [...new Set(mcpServers.map(server => server.complexity))]
  const pricingOptions = [...new Set(mcpServers.map(server => server.pricing))]

  // Filter servers based on selected filters
  const filteredServers = useMemo(() => {
    return mcpServers.filter(server => {
      const matchesCategory = selectedCategories.length === 0 || selectedCategories.includes(server.category)
      const matchesComplexity = selectedComplexity.length === 0 || selectedComplexity.includes(server.complexity)
      const matchesPricing = selectedPricing.length === 0 || selectedPricing.includes(server.pricing)
      
      return matchesCategory && matchesComplexity && matchesPricing
    })
  }, [selectedCategories, selectedComplexity, selectedPricing])

  const toggleFilter = (type: 'category' | 'complexity' | 'pricing', value: string) => {
    switch (type) {
      case 'category':
        setSelectedCategories(prev => 
          prev.includes(value) ? prev.filter(c => c !== value) : [...prev, value]
        )
        break
      case 'complexity':
        setSelectedComplexity(prev => 
          prev.includes(value) ? prev.filter(c => c !== value) : [...prev, value]
        )
        break
      case 'pricing':
        setSelectedPricing(prev => 
          prev.includes(value) ? prev.filter(p => p !== value) : [...prev, value]
        )
        break
    }
  }

  const clearAllFilters = () => {
    setSelectedCategories([])
    setSelectedComplexity([])
    setSelectedPricing([])
  }

  const hasActiveFilters = selectedCategories.length > 0 || selectedComplexity.length > 0 || selectedPricing.length > 0

  return (
    <div className="flex flex-col min-h-screen">
      {/* Navigation */}
      <Navigation />

      {/* Header Section */}
      <section className="py-12 px-4 bg-muted/50">
        <div className="container mx-auto max-w-4xl">
          <Link href="/" className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-6">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Home
          </Link>
          
          <div className="text-center">
            <div className="flex justify-center mb-4">
              <Server className="h-16 w-16 text-primary" />
            </div>
            <h1 className="text-4xl font-bold mb-4">
              Library
            </h1>
            <p className="text-xl text-muted-foreground mb-8 max-w-3xl mx-auto">
              Model Context Protocol (MCP) servers provide standardized ways for AI agents to interact with 
              external tools, services, and data sources. Each server implements specific capabilities that 
              extend your agent's functionality.
            </p>
            <div className="flex gap-4 justify-center text-sm text-muted-foreground">
              <span className="flex items-center gap-2">
                <Badge variant="outline" className="bg-green-100 text-green-800">MCP Core</Badge>
                {mcpServers.filter(s => s.provider === 'MCP Core').length} Official Servers
              </span>
              <span className="flex items-center gap-2">
                <Badge variant="outline" className="bg-blue-100 text-blue-800">Integrations</Badge>
                {mcpServers.filter(s => s.provider !== 'MCP Core').length} Platform Integrations
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* What is MCP Section */}
      <section className="py-12 px-4">
        <div className="container mx-auto max-w-4xl">
          <Card>
            <CardHeader>
              <CardTitle className="text-2xl">What are MCP Servers?</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-muted-foreground">
                MCP (Model Context Protocol) servers are specialized programs that provide AI agents with access to 
                external resources and capabilities. They act as bridges between your AI agent and various tools, 
                databases, APIs, and services.
              </p>
              <div className="grid md:grid-cols-2 gap-6 mt-6">
                <div>
                  <h3 className="font-semibold mb-2">🔌 Standardized Integration</h3>
                  <p className="text-sm text-muted-foreground">
                    All MCP servers follow the same protocol, making it easy to add new capabilities to your agents.
                  </p>
                </div>
                <div>
                  <h3 className="font-semibold mb-2">🛡️ Secure by Design</h3>
                  <p className="text-sm text-muted-foreground">
                    Built-in security controls and sandboxing protect your system while enabling powerful functionality.
                  </p>
                </div>
                <div>
                  <h3 className="font-semibold mb-2">⚡ Instant Deployment</h3>
                  <p className="text-sm text-muted-foreground">
                    Most servers can be installed and configured in minutes using package managers like uvx.
                  </p>
                </div>
                <div>
                  <h3 className="font-semibold mb-2">🔄 Real-time Communication</h3>
                  <p className="text-sm text-muted-foreground">
                    Bi-directional communication allows agents to dynamically query and interact with external systems.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Filter Chips Section */}
      <section className="py-8 px-4 border-b bg-background">
        <div className="container mx-auto">
          <div className="flex flex-wrap items-center gap-4 mb-6">
            <h3 className="text-lg font-semibold">Filter by:</h3>
            
            {/* Category Filters */}
            <div className="flex flex-wrap gap-2">
              <span className="text-sm font-medium text-muted-foreground">Category:</span>
              {categories.map(category => (
                <Badge
                  key={category}
                  variant={selectedCategories.includes(category) ? "default" : "outline"}
                  className={`cursor-pointer transition-colors ${
                    selectedCategories.includes(category) 
                      ? getCategoryColor(category).replace('bg-', 'bg-').replace('text-', 'text-') 
                      : 'hover:bg-muted'
                  }`}
                  onClick={() => toggleFilter('category', category)}
                >
                  {category}
                  {selectedCategories.includes(category) && (
                    <X className="ml-1 h-3 w-3" />
                  )}
                </Badge>
              ))}
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-4 mb-6">
            {/* Complexity Filters */}
            <div className="flex flex-wrap gap-2">
              <span className="text-sm font-medium text-muted-foreground">Complexity:</span>
              {complexities.map(complexity => (
                <Badge
                  key={complexity}
                  variant={selectedComplexity.includes(complexity) ? "default" : "outline"}
                  className={`cursor-pointer transition-colors ${
                    selectedComplexity.includes(complexity) 
                      ? getComplexityColor(complexity) 
                      : 'hover:bg-muted'
                  }`}
                  onClick={() => toggleFilter('complexity', complexity)}
                >
                  {complexity}
                  {selectedComplexity.includes(complexity) && (
                    <X className="ml-1 h-3 w-3" />
                  )}
                </Badge>
              ))}
            </div>

            {/* Pricing Filters */}
            <div className="flex flex-wrap gap-2">
              <span className="text-sm font-medium text-muted-foreground">Pricing:</span>
              {pricingOptions.map(pricing => (
                <Badge
                  key={pricing}
                  variant={selectedPricing.includes(pricing) ? "default" : "outline"}
                  className={`cursor-pointer transition-colors ${
                    selectedPricing.includes(pricing) 
                      ? getPricingColor(pricing) 
                      : 'hover:bg-muted'
                  }`}
                  onClick={() => toggleFilter('pricing', pricing)}
                >
                  {pricing}
                  {selectedPricing.includes(pricing) && (
                    <X className="ml-1 h-3 w-3" />
                  )}
                </Badge>
              ))}
            </div>

            {/* Clear Filters Button */}
            {hasActiveFilters && (
              <Button
                variant="ghost"
                size="sm"
                onClick={clearAllFilters}
                className="ml-auto"
              >
                <X className="mr-1 h-4 w-4" />
                Clear All
              </Button>
            )}
          </div>

          <div className="text-sm text-muted-foreground">
            Showing {filteredServers.length} of {mcpServers.length} servers and integrations
          </div>
        </div>
      </section>

      {/* Servers Grid */}
      <section className="py-12 px-4">
        <div className="container mx-auto">
          <h2 className="text-3xl font-bold text-center mb-12">
            Available MCP Servers & Integrations
          </h2>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredServers.map((server) => {
              const IconComponent = getServerIcon(server.icon)
              return (
                <Card key={server.id} className="hover:shadow-lg transition-shadow">
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        <IconComponent className="h-8 w-8 text-primary" />
                        <div>
                          <CardTitle className="text-lg">{server.name}</CardTitle>
                          <div className="flex gap-2 mt-1">
                            <Badge variant="secondary" className={getCategoryColor(server.category)}>
                              {server.category}
                            </Badge>
                            <Badge variant="outline" className={getComplexityColor(server.complexity)}>
                              {server.complexity}
                            </Badge>
                          </div>
                        </div>
                      </div>
                      <Badge variant="outline" className={getPricingColor(server.pricing)}>
                        {server.pricing}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <CardDescription className="mb-4">
                      {server.description}
                    </CardDescription>
                    
                    <div className="space-y-3">
                      <div>
                        <h4 className="font-medium text-sm mb-2">Key Features:</h4>
                        <div className="flex flex-wrap gap-1">
                          {server.features.slice(0, 3).map((feature) => (
                            <Badge key={feature} variant="outline" className="text-xs">
                              {feature}
                            </Badge>
                          ))}
                          {server.features.length > 3 && (
                            <Badge variant="outline" className="text-xs">
                              +{server.features.length - 3} more
                            </Badge>
                          )}
                        </div>
                      </div>

                      <div className="flex justify-between items-center">
                        <div>
                          <h4 className="font-medium text-sm mb-1">Provider:</h4>
                          <p className="text-xs text-muted-foreground">{server.provider}</p>
                        </div>
                        <div>
                          <h4 className="font-medium text-sm mb-1">Auth:</h4>
                          <p className="text-xs text-muted-foreground">{server.authMethod.replace('-', ' ')}</p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-12 px-4 bg-muted/50">
        <div className="container mx-auto max-w-2xl text-center">
          <h2 className="text-3xl font-bold mb-6">
            Ready to Build with MCP?
          </h2>
          <p className="text-lg text-muted-foreground mb-8">
            Join the beta to get access to 50+ MCP server integrations and start building
            AI agents that connect to real tools.
          </p>
          <div className="flex gap-4 justify-center">
            <Link href="/beta">
              <Button size="lg" className="bg-warm-500 hover:bg-warm-600 text-warm-50">
                Join the Beta Waitlist
              </Button>
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <Footer />
    </div>
  )
}