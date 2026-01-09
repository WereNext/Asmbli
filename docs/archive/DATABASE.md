# Database Integration Guide - asmbli

This guide covers the Neon database integration for the asmbli application.

## Overview

asmbli now uses **Netlify Neon** as its primary database solution. Neon is a serverless PostgreSQL database that integrates seamlessly with Netlify deployments.

## Quick Start

### 1. Environment Setup

The database connection is automatically configured when deploying to Netlify with Neon integration enabled. The `NETLIFY_DATABASE_URL` environment variable is automatically provided.

For local development, you can set up a local environment variable:

```bash
cp .env.example .env.local
# Edit .env.local with your database URL
```

### 2. Run Migrations

Before using the database, run the initial schema migration:

```bash
npm run migrate
```

Check migration status:

```bash
npm run migrate:status
```

### 3. Test Connection

Test your database connection:

```bash
npx tsx lib/test-db.ts
```

## Database Schema

### Tables

1. **users** - User accounts and profiles
2. **agent_configs** - User-created agent configurations  
3. **templates** - Shared agent templates
4. **user_actions** - Analytics and usage tracking
5. **kv_store** - Key-value storage (backward compatibility)

### Schema Details

```sql
-- Users table
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('beginner', 'power_user', 'enterprise')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Agent configurations table
CREATE TABLE agent_configs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  config JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- More tables defined in lib/migrations/001_initial_schema.sql
```

## Usage Examples

### Using the Database Class

```typescript
import { Database } from './lib/database';

// Create a user
const user = await Database.createUser(
  'user@example.com', 
  'John Doe', 
  'power_user'
);

// Save an agent configuration
const config = await Database.saveAgentConfig(user.id, {
  agentName: 'My Assistant',
  extensions: [...],
  // ... other config
});

// Get user's configurations
const configs = await Database.getAgentConfigs(user.id);
```

### Using React Hooks

```typescript
import { useUser, useAgentConfigs, useTemplates } from './hooks/useDatabase';

function MyComponent({ userId }) {
  const { user, loading, error } = useUser(userId);
  const { configs, saveConfig } = useAgentConfigs(userId);
  const { templates } = useTemplates(userId);

  // Component logic...
}
```

### Template Storage (Database-backed)

```typescript
import { TemplateStorageDB } from './utils/templateStorageDB';

// Save a template
const template = await TemplateStorageDB.saveTemplate(
  wizardData,
  {
    name: 'My Template',
    description: 'A custom agent template',
    category: 'development',
    tags: ['coding', 'assistant']
  },
  userId,
  true // isPublic
);

// Get all templates for user
const templates = await TemplateStorageDB.getTemplates('power_user', userId);
```

## Migration Management

### Creating Migrations

```bash
npm run migrate:create add_new_feature
```

This creates a new migration file in `lib/migrations/` with timestamp prefix.

### Migration Files

Migration files are SQL scripts in `lib/migrations/`:
- `001_initial_schema.sql` - Initial database schema
- `YYYYMMDDHHMMSS_migration_name.sql` - Additional migrations

### Running Migrations

```bash
# Run all pending migrations
npm run migrate

# Check status
npm run migrate:status
```

## Key Features

### 1. User Management
- User registration and authentication
- Role-based access control
- User profile management

### 2. Agent Configuration Storage
- Save/load agent configurations
- Version tracking
- User-specific configurations

### 3. Template System
- Public and private templates
- Template sharing
- Usage analytics

### 4. Analytics & Tracking
- User action logging
- Usage statistics
- Performance metrics

### 5. Key-Value Storage
- Backward compatibility with existing localStorage
- Flexible data storage
- Prefix-based queries

## API Reference

### Database Class Methods

#### User Management
```typescript
Database.createUser(email: string, name: string, role: UserRole)
Database.getUserById(userId: string)
Database.getUserByEmail(email: string)
Database.updateUser(userId: string, updates: Partial<User>)
```

#### Agent Configurations
```typescript
Database.saveAgentConfig(userId: string, config: any)
Database.getAgentConfigs(userId: string)
Database.updateAgentConfig(configId: string, config: any)
Database.deleteAgentConfig(configId: string)
```

#### Templates
```typescript
Database.saveTemplate(name: string, description: string, config: any, isPublic?: boolean, createdBy?: string)
Database.getPublicTemplates()
Database.getUserTemplates(userId: string)
Database.getTemplateById(templateId: string)
```

#### Analytics
```typescript
Database.logUserAction(userId: string, action: string, metadata?: any)
Database.getUserActionStats(userId: string, days?: number)
```

#### Key-Value Store
```typescript
Database.set(key: string, value: any)
Database.get(key: string)
Database.delete(key: string)
Database.getByPrefix(prefix: string)
```

## Error Handling

The database layer includes comprehensive error handling:

```typescript
try {
  const user = await Database.createUser(email, name, role);
} catch (error) {
  console.error('Failed to create user:', error);
  // Handle error appropriately
}
```

React hooks automatically handle loading states and errors:

```typescript
const { data, loading, error } = useUser(userId);

if (loading) return <Loading />;
if (error) return <Error message={error} />;
```

## Performance Considerations

1. **Connection Pooling**: Neon automatically handles connection pooling
2. **Indexing**: Key indexes are created for frequently queried columns
3. **JSONB**: Configuration data is stored as JSONB for efficient queries
4. **Caching**: Consider implementing application-level caching for frequently accessed data

## Security

1. **Prepared Statements**: All queries use parameterized statements
2. **Input Validation**: Validate data before database operations
3. **Access Control**: Implement proper user authorization
4. **Environment Variables**: Database credentials are managed by Netlify

## Deployment

### Netlify Deployment

1. Enable Neon integration in Netlify dashboard
2. Deploy application - database URL is automatically configured
3. Run migrations on first deployment

### Environment Variables

- `NETLIFY_DATABASE_URL` - Automatically provided by Netlify
- `NODE_ENV` - Application environment
- `DEBUG` - Enable debug logging (optional)

## Troubleshooting

### Common Issues

1. **Connection Errors**
   - Verify NETLIFY_DATABASE_URL is set
   - Check database accessibility
   - Review Netlify deployment logs

2. **Migration Failures**
   - Check SQL syntax in migration files
   - Verify database permissions
   - Review migration logs

3. **Performance Issues**
   - Check query performance with EXPLAIN
   - Consider adding indexes
   - Review connection usage

### Debugging

Enable debug logging:
```bash
DEBUG=true npm run dev
```

Check database connection:
```bash
npx tsx lib/test-db.ts
```

## Migration from localStorage

The new database system is designed to be backward compatible. Existing localStorage data can be migrated:

1. Export data from localStorage
2. Import using database methods
3. Update application code to use database hooks

Example migration script:
```typescript
// Migrate templates from localStorage to database
const localTemplates = JSON.parse(localStorage.getItem('agentengine_templates') || '[]');
for (const template of localTemplates) {
  await TemplateStorageDB.importTemplate(JSON.stringify(template), userId);
}
```

## Support

For database-related issues:
1. Check this documentation
2. Review migration logs
3. Test database connectivity
4. Check Netlify deployment logs
5. Contact support with specific error messages