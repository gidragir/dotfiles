export interface TemplateParams {
  query?: string;
}

export const runtime = {
  handler: async function ({ query }: TemplateParams): Promise<string> {
    try {
      if (!query) {
        return "No query provided to template skill.";
      }
      return `Template skill executed successfully with query: ${query}`;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error in template skill: ${message}`;
    }
  },
};
