import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  console.log('Enabling PostGIS...');
  await prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS postgis;');
  console.log('PostGIS enabled successfully!');
}
main().catch(e => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
