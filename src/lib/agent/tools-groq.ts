import { TOOLS } from "./tools";

export interface GroqTool {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

interface SchemaProperty {
  type?: string;
  enum?: unknown[];
  [key: string]: unknown;
}

interface JsonSchemaObject {
  type?: string;
  properties?: Record<string, SchemaProperty>;
  required?: string[];
  [key: string]: unknown;
}

/**
 * Groq's models commonly emit an explicit `null` for an optional field it has
 * no value for, rather than omitting the key. Groq's server validates tool
 * arguments against the schema before the call reaches us, and both a bare
 * `type: "string"` AND an `enum` list reject `null` on their own even when
 * the field isn't required — each needs `null` added separately. Anthropic
 * never hit this because it omits unfilled optional fields instead.
 */
function allowNullOnOptionalFields(schema: JsonSchemaObject): JsonSchemaObject {
  if (schema.type !== "object" || !schema.properties) return schema;

  const required = new Set(schema.required ?? []);
  const properties: Record<string, SchemaProperty> = {};

  for (const [key, prop] of Object.entries(schema.properties)) {
    if (required.has(key)) {
      properties[key] = prop;
      continue;
    }

    const patched: SchemaProperty = { ...prop };
    if (typeof patched.type === "string") {
      patched.type = [patched.type, "null"] as unknown as string;
    }
    if (Array.isArray(patched.enum) && !patched.enum.includes(null)) {
      patched.enum = [...patched.enum, null];
    }
    properties[key] = patched;
  }

  return { ...schema, properties };
}

/**
 * Groq's chat completions API is OpenAI-compatible — same function-calling
 * shape, different field names than Anthropic's tool format. TOOLS in
 * ./tools.ts stays the single source of truth; this just reshapes it.
 */
export const GROQ_TOOLS: GroqTool[] = TOOLS.map((t) => ({
  type: "function",
  function: {
    name: t.name,
    description: t.description ?? "",
    parameters: allowNullOnOptionalFields(
      t.input_schema as unknown as JsonSchemaObject,
    ) as unknown as Record<string, unknown>,
  },
}));
