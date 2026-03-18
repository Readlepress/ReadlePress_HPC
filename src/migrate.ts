import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';

const adminPool = new Pool({
  connectionString: process.env.DATABASE_ADMIN_URL || 'postgresql://readlepress_admin:dev_password_only@localhost:5432/readlepress',
});

async function runMigrations() {
  const client = await adminPool.connect();
  const migrationsDir = path.join(__dirname, '..', 'db', 'migrations');
  const repeatableDir = path.join(__dirname, '..', 'db', 'repeatable');

  try {
    // Ensure schema_migrations table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        description TEXT,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    // Run versioned migrations in order
    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    for (const file of migrationFiles) {
      const version = file.split('__')[0];

      const applied = await client.query(
        'SELECT 1 FROM schema_migrations WHERE version = $1',
        [version]
      );

      if (applied.rows.length > 0) {
        console.log(`  ✓ ${file} (already applied)`);
        continue;
      }

      console.log(`  → Applying ${file}...`);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
      await client.query(sql);
      console.log(`  ✓ ${file} applied`);
    }

    // Run repeatable migrations
    console.log('\nRunning repeatable migrations...');
    if (fs.existsSync(repeatableDir)) {
      const repeatableFiles = fs.readdirSync(repeatableDir)
        .filter(f => f.endsWith('.sql'))
        .sort();

      for (const file of repeatableFiles) {
        console.log(`  → Running ${file}...`);
        const sql = fs.readFileSync(path.join(repeatableDir, file), 'utf-8');
        await client.query(sql);
        console.log(`  ✓ ${file} complete`);
      }
    }

    console.log('\nAll migrations complete.');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await adminPool.end();
  }
}

runMigrations();
