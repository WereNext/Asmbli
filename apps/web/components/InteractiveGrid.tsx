'use client'

import { useEffect, useRef, useState } from 'react'

interface GridPoint {
  x: number
  y: number
  originalX: number
  originalY: number
  vx: number
  vy: number
}

export function InteractiveGrid() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const pointsRef = useRef<GridPoint[]>([])
  const mouseRef = useRef({ x: -1000, y: -1000 })
  const animationRef = useRef<number>()
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 })

  useEffect(() => {
    const updateDimensions = () => {
      setDimensions({
        width: window.innerWidth,
        height: window.innerHeight
      })
    }

    updateDimensions()
    window.addEventListener('resize', updateDimensions)
    return () => window.removeEventListener('resize', updateDimensions)
  }, [])

  useEffect(() => {
    if (!dimensions.width || !dimensions.height) return

    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    // Grid configuration
    const gridSpacing = 50
    const cols = Math.ceil(dimensions.width / gridSpacing) + 1
    const rows = Math.ceil(dimensions.height / gridSpacing) + 1

    // Initialize grid points
    pointsRef.current = []
    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        pointsRef.current.push({
          x: i * gridSpacing,
          y: j * gridSpacing,
          originalX: i * gridSpacing,
          originalY: j * gridSpacing,
          vx: 0,
          vy: 0
        })
      }
    }

    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX, y: e.clientY }
    }

    const handleMouseLeave = () => {
      mouseRef.current = { x: -1000, y: -1000 }
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseleave', handleMouseLeave)

    const animate = () => {
      ctx.clearRect(0, 0, dimensions.width, dimensions.height)

      const mouse = mouseRef.current
      const influenceRadius = 150
      const maxDisplacement = 20
      const returnSpeed = 0.08
      const friction = 0.85

      // Update points
      pointsRef.current.forEach(point => {
        const dx = mouse.x - point.originalX
        const dy = mouse.y - point.originalY
        const distance = Math.sqrt(dx * dx + dy * dy)

        if (distance < influenceRadius) {
          const force = (1 - distance / influenceRadius) * maxDisplacement
          const angle = Math.atan2(dy, dx)

          // Push away from mouse
          point.vx -= Math.cos(angle) * force * 0.1
          point.vy -= Math.sin(angle) * force * 0.1
        }

        // Apply velocity
        point.x += point.vx
        point.y += point.vy

        // Apply friction
        point.vx *= friction
        point.vy *= friction

        // Spring back to original position
        point.vx += (point.originalX - point.x) * returnSpeed
        point.vy += (point.originalY - point.y) * returnSpeed
      })

      // Draw grid lines
      ctx.strokeStyle = 'rgba(200, 180, 160, 0.08)'
      ctx.lineWidth = 1

      // Horizontal lines
      for (let j = 0; j < rows; j++) {
        ctx.beginPath()
        for (let i = 0; i < cols; i++) {
          const point = pointsRef.current[i * rows + j]
          if (point) {
            if (i === 0) {
              ctx.moveTo(point.x, point.y)
            } else {
              ctx.lineTo(point.x, point.y)
            }
          }
        }
        ctx.stroke()
      }

      // Vertical lines
      for (let i = 0; i < cols; i++) {
        ctx.beginPath()
        for (let j = 0; j < rows; j++) {
          const point = pointsRef.current[i * rows + j]
          if (point) {
            if (j === 0) {
              ctx.moveTo(point.x, point.y)
            } else {
              ctx.lineTo(point.x, point.y)
            }
          }
        }
        ctx.stroke()
      }

      // Draw intersection dots that glow near mouse
      pointsRef.current.forEach(point => {
        const dx = mouse.x - point.x
        const dy = mouse.y - point.y
        const distance = Math.sqrt(dx * dx + dy * dy)

        if (distance < influenceRadius * 1.5) {
          const intensity = 1 - distance / (influenceRadius * 1.5)
          const radius = 1.5 + intensity * 2
          const alpha = 0.1 + intensity * 0.4

          ctx.beginPath()
          ctx.arc(point.x, point.y, radius, 0, Math.PI * 2)
          ctx.fillStyle = `rgba(200, 140, 100, ${alpha})`
          ctx.fill()
        }
      })

      animationRef.current = requestAnimationFrame(animate)
    }

    animate()

    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseleave', handleMouseLeave)
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
    }
  }, [dimensions])

  return (
    <canvas
      ref={canvasRef}
      width={dimensions.width}
      height={dimensions.height}
      className="fixed inset-0 pointer-events-none z-0"
      style={{ opacity: 0.7 }}
    />
  )
}
