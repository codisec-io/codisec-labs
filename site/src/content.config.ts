import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    excerpt: z.string(),
    author: z.string(),
    ogImage: z.string().optional(),
  }),
});

// labs/ vive na raiz do repositório (fora de site/), não em src/content/,
// porque é a fonte de verdade compartilhada com scripts/build_catalog.py
// e com a CLI — não duplicar os lab.yaml para dentro do site.
const labTask = z.object({
  id: z.string(),
  title: z.string(),
  theory: z.string(),
  steps: z.array(z.string()),
  break_again_command: z.string().optional(),
  validation: z.object({
    command: z.string(),
    expected_exit_code: z.number().optional(),
    expected_output_contains: z.string().optional(),
    success_message: z.string(),
    error_message: z.string(),
  }),
});

const labs = defineCollection({
  loader: glob({ pattern: '*/lab.yaml', base: '../labs' }),
  schema: z.object({
    id: z.string(),
    title: z.string(),
    category: z.enum(['appsec', 'devsecops', 'devops']),
    difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
    duration: z.string(),
    description: z.string(),
    image: z.string(),
    tags: z.array(z.string()).default([]),
    maintainers: z.array(z.string()).default([]),
    exposed_ports: z.array(z.number()).default([]),
    tasks: z.array(labTask).min(1),
    recovery: z.object({
      reset_command: z.string(),
    }),
  }),
});

export const collections = { blog, labs };
