import 'dotenv/config';
import { readFileSync, readdirSync } from 'fs';
import { resolve } from 'path';
import { Pool } from 'pg';

async function run() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const directory=resolve(process.cwd(),'migrations');
  try {
    await pool.query('CREATE TABLE IF NOT EXISTS schema_migrations(filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
    for(const filename of readdirSync(directory).filter(name=>name.endsWith('.sql')).sort()){
      const exists=await pool.query('SELECT 1 FROM schema_migrations WHERE filename=$1',[filename]); if(exists.rowCount)continue;
      const client=await pool.connect();
      try{await client.query('BEGIN');await client.query(readFileSync(resolve(directory,filename),'utf8'));await client.query('INSERT INTO schema_migrations(filename) VALUES($1)',[filename]);await client.query('COMMIT');console.log(`Applied ${filename}`);}catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}
    }
    console.log('Database migrations completed');
  }
  finally { await pool.end(); }
}
void run();
