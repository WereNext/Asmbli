# AgentEngine Deployment Quick Reference

## 🚀 Deployment Decision Tree

```
Are you developing locally? 
├── YES → Claude Desktop Integration
└── NO → Are you working with a team?
    ├── YES → Docker Containers
    └── NO → Do you need enterprise scale?
        ├── YES → Kubernetes
        └── NO → Cloud Platforms (Railway/Render/Vercel)
```

## 📋 Deployment Options Comparison

| Deployment Type | Best For | Setup Time | Scaling | Cost | Production Ready |
|---|---|---|---|---|---|
| **Claude Desktop** | Local dev, Personal use | 5 minutes | Manual | Free | No |
| **Docker** | Team dev, Small production | 30 minutes | Manual/Compose | Low | Basic |
| **Kubernetes** | Enterprise, High scale | 2-4 hours | Auto | Medium | Yes |
| **Railway** | Quick production | 15 minutes | Auto | Pay-per-use | Yes |
| **Render** | Managed production | 20 minutes | Auto | Subscription | Yes |
| **Vercel** | Frontend/Edge | 10 minutes | Auto | Freemium | Yes |

## 🛠️ Quick Setup Commands

### Claude Desktop
```bash
# 1. Generate config via AgentEngine UI
# 2. Install MCP servers
npm install -g @figma/mcp-server @mcp/filesystem @mcp/git

# 3. Copy config to Claude Desktop folder
# Windows: %APPDATA%\Claude\claude_desktop_config.json
# macOS: ~/Library/Application Support/Claude/claude_desktop_config.json
# Linux: ~/.config/Claude/claude_desktop_config.json

# 4. Restart Claude Desktop
```

### Docker
```bash
# 1. Generate Docker files via AgentEngine UI
# 2. Build and run
docker build -t agentengine-app .
docker run -p 3000:3000 agentengine-app

# Or with compose
docker-compose up -d
```

### Kubernetes
```bash
# 1. Generate K8s manifests via AgentEngine UI
# 2. Build and push image
docker build -t your-registry/agentengine:latest .
docker push your-registry/agentengine:latest

# 3. Deploy
kubectl apply -f k8s/
kubectl get pods -l app=agentengine
```

### Railway
```bash
# 1. Install Railway CLI
npm install -g @railway/cli

# 2. Connect and deploy
railway login
railway link
railway deploy
```

### Render
```bash
# 1. Connect GitHub repo to Render
# 2. Set build/start commands:
#    Build: npm install && npm run build
#    Start: npm start
# 3. Configure environment variables
# 4. Deploy automatically on git push
```

### Vercel
```bash
# 1. Install Vercel CLI
npm install -g vercel

# 2. Deploy
vercel        # Preview deployment
vercel --prod # Production deployment
```

## 🔧 Essential MCP Servers

| MCP Server | Purpose | Install Command |
|---|---|---|
| **figma-mcp** | Design system integration | `npm install -g @figma/mcp-server` |
| **filesystem-mcp** | File operations | `npm install -g @mcp/filesystem` |
| **git-mcp** | Version control | `npm install -g @mcp/git` |
| **postgres-mcp** | Database access | `npm install -g @mcp/postgres` |
| **http-mcp** | API requests | `npm install -g @mcp/http` |
| **terminal-mcp** | Shell commands | `npm install -g @mcp/terminal` |

## 🔐 Security Checklist

### Development
- [ ] Use environment variables for secrets
- [ ] Enable local MCP server access controls
- [ ] Test with sample data only

### Staging/Production
- [ ] Implement HTTPS/TLS
- [ ] Use secret management (K8s secrets, cloud key vaults)
- [ ] Configure network policies
- [ ] Enable audit logging
- [ ] Set up monitoring and alerting
- [ ] Regular security updates

## 📊 Monitoring Essentials

### Health Checks
```javascript
// Add to your agent application
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});
```

### Key Metrics to Monitor
- **Response Time**: Agent query processing time
- **Error Rate**: Failed requests percentage
- **MCP Server Status**: Individual server health
- **Resource Usage**: CPU, memory, network
- **Agent Utilization**: Active vs idle agents

## 🚨 Troubleshooting

### Common Issues

**Claude Desktop Integration**
```bash
# Issue: MCP server not loading
# Check: Configuration syntax
cat ~/.config/Claude/claude_desktop_config.json | jq

# Issue: Permission denied
# Fix: Check file permissions and MCP server paths
```

**Docker Deployment**
```bash
# Issue: Container won't start
docker logs container-name

# Issue: Port conflicts
# Fix: Change port mapping
docker run -p 3001:3000 agentengine-app
```

**Kubernetes Issues**
```bash
# Issue: Pod crashes
kubectl describe pod pod-name
kubectl logs pod-name --previous

# Issue: Service not accessible
kubectl get endpoints service-name
```

## 💡 Best Practices

### Development Workflow
1. **Local First**: Always test with Claude Desktop integration
2. **Containerize Early**: Move to Docker for team collaboration
3. **Automate Testing**: Set up CI/CD pipelines
4. **Monitor from Day One**: Implement observability early

### Production Deployment
1. **Security First**: Never commit secrets to git
2. **Scale Gradually**: Start small, scale based on real usage
3. **Monitor Everything**: Logs, metrics, traces, business KPIs
4. **Plan for Failure**: Implement proper backup and recovery

### MCP Server Management
1. **Single Responsibility**: One server per integration type
2. **Version Control**: Tag and version your MCP servers
3. **Access Control**: Minimal permissions per server
4. **Health Checks**: Monitor each server independently

## 📚 Additional Resources

- **Full Deployment Guide**: `/docs/deployment-guide.md`
- **Podcast Script**: `/docs/deployment-podcast-script.md`
- **AgentEngine Documentation**: Generated via UI wizard
- **MCP Protocol Spec**: [Model Context Protocol Documentation]
- **Security Best Practices**: Enterprise security guidelines

## 🎯 Quick Decision Guide

**Choose Claude Desktop if:**
- You're developing locally
- You need rapid prototyping
- You're working solo
- Security is local-only

**Choose Docker if:**
- You're working with a team
- You need consistent environments
- You want simple production deployment
- You need moderate scaling

**Choose Kubernetes if:**
- You need enterprise scale
- You require high availability
- You have complex networking needs
- You need advanced monitoring

**Choose Cloud Platforms if:**
- You want managed infrastructure
- You need quick time-to-market
- You prefer pay-per-usage
- You want platform-specific optimizations

---

*This quick reference covers 80% of common deployment scenarios. For complex enterprise requirements, consult the full deployment guide and consider professional support.*