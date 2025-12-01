'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Menu, X } from 'lucide-react'

interface NavigationProps {
  showBackButton?: boolean
  backHref?: string
  backLabel?: string
}

export function Navigation({ showBackButton = false, backHref = '/', backLabel = 'Home' }: NavigationProps) {
  const pathname = usePathname()
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  
  const isActive = (path: string) => pathname === path

  return (
    <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto px-4 py-4">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-4">
            {showBackButton && (
              <Link href={backHref} className="text-muted-foreground hover:text-foreground text-sm hidden md:block">
                ← {backLabel}
              </Link>
            )}
            <Link href="/" className="text-2xl font-bold italic font-display">
              Asmbli
            </Link>
          </div>
          
          {/* Desktop Navigation */}
          <nav className="hidden md:flex gap-6 items-center">
            <Link 
              href="/templates" 
              className={`hover:underline text-sm ${isActive('/templates') ? 'font-semibold text-foreground' : ''}`}
            >
              Templates
            </Link>
            <Link 
              href="/mcp-servers" 
              className={`hover:underline text-sm ${isActive('/mcp-servers') ? 'font-semibold text-foreground' : ''}`}
            >
              Library
            </Link>
            <Link 
              href="/dashboard" 
              className={`hover:underline text-sm ${isActive('/dashboard') ? 'font-semibold text-foreground' : ''}`}
            >
              Dashboard
            </Link>
            <Link
              href="/download"
              className={`hover:underline text-sm ${isActive('/download') ? 'font-semibold text-foreground' : ''}`}
            >
              Download
            </Link>
            <Link
              href="/contribute"
              className={`hover:underline text-sm ${isActive('/contribute') ? 'font-semibold text-foreground' : ''}`}
            >
              Beta Waitlist
            </Link>
            <Link href="/chat">
              <Button>View Demo</Button>
            </Link>
          </nav>

          {/* Mobile Menu Button */}
          <Button
            variant="ghost"
            size="sm"
            className="md:hidden"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>

        {/* Mobile Navigation */}
        {isMobileMenuOpen && (
          <nav className="md:hidden mt-4 pb-4 border-t pt-4">
            <div className="flex flex-col space-y-4">
              <Link 
                href="/templates" 
                className={`hover:text-primary transition-colors ${isActive('/templates') ? 'font-semibold text-foreground' : ''}`}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                Templates
              </Link>
              <Link 
                href="/mcp-servers" 
                className={`hover:text-primary transition-colors ${isActive('/mcp-servers') ? 'font-semibold text-foreground' : ''}`}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                Library
              </Link>
              <Link 
                href="/dashboard" 
                className={`hover:text-primary transition-colors ${isActive('/dashboard') ? 'font-semibold text-foreground' : ''}`}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                Dashboard
              </Link>
              <Link
                href="/download"
                className={`hover:text-primary transition-colors ${isActive('/download') ? 'font-semibold text-foreground' : ''}`}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                Download
              </Link>
              <Link
                href="/contribute"
                className={`hover:text-primary transition-colors ${isActive('/contribute') ? 'font-semibold text-foreground' : ''}`}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                Beta Waitlist
              </Link>
              <Link href="/chat" onClick={() => setIsMobileMenuOpen(false)}>
                <Button className="w-full">View Demo</Button>
              </Link>
            </div>
          </nav>
        )}
      </div>
    </header>
  )
}