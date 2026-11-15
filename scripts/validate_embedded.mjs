import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
const root=process.cwd();
const db=new PGlite();
await db.exec(fs.readFileSync(root+'/sql/01_schema.sql','utf8'));
console.log('Schema created');
const load=fs.readFileSync(root+'/sql/02_load_data.sql','utf8');
await db.exec("BEGIN; SET search_path TO olx; SET TIME ZONE 'Asia/Kolkata';");
for (const line of load.split('\n').filter(x=>x.startsWith('\\copy '))){
 const m=line.match(/^\\copy (.+) FROM '([^']+)' WITH (.+)$/);
 await db.query(`COPY ${m[1]} FROM '/dev/blob' WITH ${m[3]}`,[],{blob:new Blob([fs.readFileSync(root+'/'+m[2])])});
 console.log('Loaded '+m[2]);
}
await db.exec('COMMIT; ANALYZE;');
const results=await db.exec(fs.readFileSync(root+'/sql/03_validate_data.sql','utf8'));
fs.writeFileSync(root+'/docs/cp1_validation.json',JSON.stringify({engine:'PGlite (embedded PostgreSQL; not native psql)',version:(await db.query('select version()')).rows[0],results:results.map(x=>x.rows)},null,2)+'\n');
console.log(JSON.stringify(results.map(x=>x.rows).filter(x=>x.length&& !x[0].indexname),null,2));
// Plan every read without executing expensive baseline work; execute writes in a rollback.
const workload=fs.readFileSync(root+'/queries/workload_30.sql','utf8');
const blocks=workload.split(/^-- @/m).slice(1);const smoke=[];
for(const b of blocks){const id=b.slice(0,3);if(!/^[RW]\d\d$/.test(id))continue;const sql=b.slice(3).trim();
 if(id.startsWith('R')){await db.exec('EXPLAIN '+sql);smoke.push(id+': planned');}
 else{await db.exec('BEGIN;');await db.exec(sql);await db.exec('ROLLBACK;');smoke.push(id+': executed and rolled back');}
}
fs.writeFileSync(root+'/docs/cp1_workload_check.txt',smoke.join('\n')+'\n');console.log(smoke.join('\n'));
await db.close();
