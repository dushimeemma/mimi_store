import 'dotenv/config';
import * as bcrypt from 'bcryptjs';
import { Pool } from 'pg';

async function run() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const email=process.env.BOOTSTRAP_ADMIN_EMAIL?.trim().toLowerCase(); const password=process.env.BOOTSTRAP_ADMIN_PASSWORD;
  if(!email||!password||password.startsWith('replace')) throw new Error('Set secure BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD values');
  const hash=await bcrypt.hash(password,12);
  try {
    await pool.query("INSERT INTO users(email,password_hash,full_name,role) VALUES($1,$2,'Mimi Store Owner','super_admin') ON CONFLICT ((lower(email))) DO NOTHING",[email,hash]);
    await pool.query("INSERT INTO categories(name,slug,sort_order) VALUES ('Dresses','dresses',1),('Sets','sets',2),('Shirts','shirts',3),('Skirts','skirts',4) ON CONFLICT(slug) DO NOTHING");
    const count=await pool.query('SELECT count(*)::int AS count FROM products');
    if(count.rows[0].count===0) await pool.query("INSERT INTO products(name,category,category_id,description,price_rwf,stock,badge,sku) SELECT v.name,v.category,c.id,v.description,v.price,v.stock,v.badge,v.sku FROM (VALUES ('Imena Draped Dress','Dresses','Elegant draped silhouette',68500,12,'New','MIM-DRE-001'),('Kigali Tailored Set','Sets','Modern tailored two-piece set',92000,7,'Bestseller','MIM-SET-001'),('Amahoro Linen Shirt','Shirts','Breathable everyday linen shirt',38500,18,null,'MIM-SHI-001'),('Mwezi Pleated Skirt','Skirts','Flowing pleated midi skirt',47000,9,null,'MIM-SKI-001')) AS v(name,category,description,price,stock,badge,sku) JOIN categories c ON c.name=v.category");
    console.log('Seed completed');
  } finally { await pool.end(); }
}
void run();
