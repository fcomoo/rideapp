import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'macuspana-premium-secret-2024';

const RegisterSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(6),
  role: z.enum(['client', 'driver']),
  phone: z.string().optional(),
});

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

export async function authRoutes(server: FastifyInstance) {
  // POST /api/auth/register
  server.post('/api/auth/register', async (request, reply) => {
    const parsed = RegisterSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos inválidos', details: parsed.error.issues });
    }
    const { name, email, password, role, phone } = parsed.data;
    try {
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing) {
        return reply.status(409).send({ error: 'El correo ya está registrado' });
      }
      const hashedPassword = await bcrypt.hash(password, 10);
      const user = await prisma.user.create({
        data: { name, email, password: hashedPassword, role, status: 'idle', phone },
      });
      const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
      return reply.status(201).send({
        token,
        user: { id: user.id, name: user.name, email: user.email, role: user.role, phone: user.phone },
      });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Error interno del servidor' });
    }
  });

  // POST /api/auth/login
  server.post('/api/auth/login', async (request, reply) => {
    const parsed = LoginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Datos inválidos' });
    }
    const { email, password } = parsed.data;
    try {
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) {
        return reply.status(401).send({ error: 'Credenciales inválidas' });
      }
      const validPassword = await bcrypt.compare(password, user.password);
      if (!validPassword) {
        return reply.status(401).send({ error: 'Credenciales inválidas' });
      }
      const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
      return reply.send({
        token,
        user: { id: user.id, name: user.name, email: user.email, role: user.role, phone: user.phone },
      });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Error interno del servidor' });
    }
  });

  // GET /api/auth/me
  server.get('/api/auth/me', async (request, reply) => {
    const authHeader = request.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Token requerido' });
    }
    const token = authHeader.split(' ')[1];
    try {
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
      const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
      if (!user) {
        return reply.status(404).send({ error: 'Usuario no encontrado' });
      }
      return reply.send({
        user: { id: user.id, name: user.name, email: user.email, role: user.role, phone: user.phone },
      });
    } catch (err) {
      return reply.status(401).send({ error: 'Token inválido o expirado' });
    }
  });
}
