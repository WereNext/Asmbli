# 🚀 asmbli Deployment & Database Setup Guide

Your asmbli application is successfully deployed! Follow this guide to complete the database setup and data migration.

## 🌐 Deployment Status

✅ **Application Deployed**: https://asmbli.netlify.app  
✅ **Build Successful**: All components loaded correctly  
✅ **Database Integration**: Neon database code is ready  

## 🗄️ Database Setup (Required)

### Step 1: Enable Neon Integration in Netlify

1. **Go to Netlify Dashboard**
   - Visit: https://app.netlify.com/
   - Navigate to your `asmbli` site

2. **Enable Neon Integration**
   - Go to **Site settings** → **Integrations**
   - Find **Neon** in the available integrations
   - Click **Enable** and follow the setup process
   - This will automatically provision a PostgreSQL database and set `NETLIFY_DATABASE_URL`

3. **Verify Environment Variables**
   - Go to **Site settings** → **Environment variables**
   - Confirm `NETLIFY_DATABASE_URL` is present
   - It should look like: `postgresql://username:password@hostname:port/database`

### Step 2: Run Database Migrations

Once Neon is configured, you need to run the initial database schema:

#### Option A: Using Netlify Functions (Recommended)

1. **Deploy with Migrations**
   ```bash
   # The migrations will run automatically on next deployment
   git commit --allow-empty -m "Trigger migration deployment"
   git push origin main
   ```

2. **Or manually trigger via Function**
   - Visit: `https://asmbli.netlify.app/.netlify/functions/migrate`
   - This will run all pending migrations

#### Option B: Local Migration (If you have database access)

1. **Set Environment Variable Locally**
   ```bash
   # Get the database URL from Netlify dashboard
   export NETLIFY_DATABASE_URL="your_database_url_here"
   ```

2. **Run Migrations**
   ```bash
   npm run migrate
   ```

3. **Check Migration Status**
   ```bash
   npm run migrate:status
   ```

### Step 3: Verify Database Setup

1. **Open the Application**
   - Visit: https://asmbli.netlify.app
   - The app should load without database errors

2. **Check Browser Console**
   - Open DevTools (F12)
   - Look for any database connection errors
   - Should see successful database operations

## 📋 Data Migration (If you have existing data)

If you were using asmbli before and have data in localStorage, follow these steps:

### Automatic Migration Process

1. **Visit the Application**
   - Go to: https://asmbli.netlify.app
   - If you have existing localStorage data, a migration modal should appear

2. **Follow Migration Wizard**
   - **Step 1**: Review data summary (templates, configs, preferences)
   - **Step 2**: Create backup (recommended)
   - **Step 3**: Download backup file for safety
   - **Step 4**: Run migration to cloud database
   - **Step 5**: Verify migration success

### Manual Migration (If needed)

If the automatic migration doesn't work:

1. **Export Your Data**
   ```javascript
   // Open browser console on the old site
   const backup = {
     templates: JSON.parse(localStorage.getItem('agentengine_templates') || '[]'),
     preferences: JSON.parse(localStorage.getItem('agentengine_user_preferences') || '{}'),
     configs: JSON.parse(localStorage.getItem('agentengine_user_configs') || '{}')
   };
   console.log(JSON.stringify(backup, null, 2));
   // Copy the output
   ```

2. **Import to New System**
   - Use the import functionality in the new application
   - Or contact support with your backup data

## 🔧 Configuration Options

### Environment Variables

You can configure these in Netlify → Site settings → Environment variables:

```bash
# Database (automatically set by Neon integration)
NETLIFY_DATABASE_URL=postgresql://...

# Optional: Application settings
NODE_ENV=production
DEBUG=false

# Optional: Feature flags
ENABLE_ANALYTICS=true
ENABLE_PUBLIC_TEMPLATES=true
```

### Database Configuration

The database automatically includes:
- **User management** (accounts, roles, preferences)
- **Agent configurations** (your wizard data and settings)
- **Template system** (public and private templates)
- **Analytics tracking** (usage statistics)
- **Key-value storage** (backward compatibility)

## 🧪 Testing Database Integration

### 1. Basic Functionality Test

Visit the app and try:
- ✅ Create a new agent configuration
- ✅ Save it as a template
- ✅ Load saved configurations
- ✅ Access public templates

### 2. Data Persistence Test

1. Create some test data
2. Close and reopen browser
3. Verify data is still there (stored in database, not localStorage)

### 3. Migration Test

1. If you have old localStorage data
2. Follow the migration wizard
3. Verify all data transferred correctly

## 🚨 Troubleshooting

### Database Connection Issues

**Problem**: "Database connection failed" errors
**Solutions**:
1. Verify Neon integration is enabled in Netlify
2. Check environment variables are set
3. Redeploy the application
4. Check Netlify function logs

### Migration Issues

**Problem**: Migration modal doesn't appear
**Solutions**:
1. Open browser DevTools
2. Check localStorage for existing data:
   ```javascript
   Object.keys(localStorage).filter(key => key.includes('agentengine'))
   ```
3. Manually trigger migration if needed

**Problem**: Migration fails partway
**Solutions**:
1. Check browser console for specific errors
2. Ensure you have internet connection
3. Try migration again (it's safe to retry)
4. Use backup file if needed

### Performance Issues

**Problem**: App feels slow after database integration
**Solutions**:
1. Check network connection
2. Database queries are optimized, but network latency affects speed
3. Consider using cached data where appropriate

## 📞 Support

### Getting Help

1. **Check Browser Console**
   - Open DevTools (F12) → Console
   - Look for error messages
   - Take screenshots of any errors

2. **Check Database Status**
   ```javascript
   // In browser console
   console.log('Environment:', process.env.NODE_ENV);
   // Check if database operations work
   ```

3. **Gather Information**
   - Browser and version
   - Any error messages
   - Steps to reproduce issues
   - Whether you were migrating data

### Database Schema

Your database includes these main tables:

```sql
-- Users and authentication
users (id, email, name, role, created_at, updated_at)

-- Agent configurations from the wizard
agent_configs (id, user_id, config, created_at, updated_at)

-- Shared and private templates
templates (id, name, description, config, is_public, created_by, created_at)

-- Usage analytics
user_actions (id, user_id, action, metadata, created_at)

-- Key-value storage for flexibility
kv_store (key, value, created_at, updated_at)
```

## 🎉 You're All Set!

Once you complete these steps:

✅ **Database**: PostgreSQL via Neon, automatically managed  
✅ **Migrations**: Schema created and ready  
✅ **Data**: Migrated from localStorage (if applicable)  
✅ **Application**: Fully functional with cloud storage  

**🌟 Key Benefits Now Active:**
- 💾 **Persistent Storage**: Data saved in cloud database
- 🔄 **Cross-Device Sync**: Access your configurations anywhere
- 🚀 **Better Performance**: Optimized data loading
- 📈 **Analytics**: Usage tracking and insights
- 🤝 **Template Sharing**: Public template marketplace
- 🔒 **Data Security**: Professional-grade database hosting

**🔗 Quick Links:**
- 🌐 **Application**: https://asmbli.netlify.app
- 📊 **Netlify Dashboard**: https://app.netlify.com/
- 📖 **Database Documentation**: [DATABASE.md](./DATABASE.md)
- 🛠️ **Migration Scripts**: `npm run migrate`

---

**🎯 Ready to build amazing AI agents with asmbli!**