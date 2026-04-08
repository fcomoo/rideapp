import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { writeFile, mkdir } from 'fs/promises';
import { join } from 'path';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

export async function uploadRoutes(server: FastifyInstance) {
  // Registrar multipart para subida de archivos si no está registrado globalmente
  // wait server.register(import('@fastify/multipart')); // Esto se puede hacer en index.ts

  // POST /api/upload/avatar
  server.post('/api/upload/avatar', async (request, reply) => {
    try {
      const data = await request.file();
      if (!data) return reply.status(400).send({ error: 'No file provided' });

      const userId = (request.query as any).userId;
      if (!userId) return reply.status(400).send({ error: 'userId required' });

      const buffer = await data.toBuffer();
      const ext = data.filename.split('.').pop() || 'jpg';
      const filename = `${userId}-${randomUUID()}.${ext}`;
      
      const uploadDir = join(process.cwd(), 'uploads', 'avatars');
      await mkdir(uploadDir, { recursive: true });
      await writeFile(join(uploadDir, filename), buffer);

      const avatarUrl = `/uploads/avatars/${filename}`;
      
      await prisma.user.update({
        where: { id: userId },
        data: { avatarUrl } as any,
      });

      return reply.send({ avatarUrl });
    } catch (err: any) {
      console.error('[UPLOAD ERROR]:', err);
      return reply.status(500).send({ error: err.message });
    }
  });
}
