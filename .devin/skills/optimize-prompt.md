# Skill: Optimize Prompt

## Description
Receives a base prompt from the user and optimizes it following prompt engineering best practices. Produces a refined, well-structured prompt that maximizes clarity, specificity, and effectiveness for use with LLMs.

## Arguments
- `$ARGUMENTS`: The user's base prompt that needs to be optimized.

## Steps

### 1. Receive and Analyze the Base Prompt
- Read the user's base prompt carefully: `$ARGUMENTS`
- Identify the following characteristics:
  - **Intent**: What is the user trying to achieve with this prompt?
  - **Target audience/model**: Is this prompt for a chatbot, code generator, writing assistant, agent, etc.?
  - **Weaknesses**: What issues does the current prompt have? Look for:
    - Vagueness or ambiguity
    - Missing context or constraints
    - Lack of structure
    - No output format specification
    - Missing role/persona definition
    - No examples (few-shot)
    - No success criteria
    - Overly long or unfocused instructions
- Summarize the analysis to the user before proceeding.

### 2. Apply Prompt Engineering Best Practices
Optimize the prompt by applying the following techniques as appropriate:

#### 2.1 — Role & Persona Definition
- Add a clear system role or persona at the beginning (e.g., "You are an expert backend engineer specializing in...").
- Define the tone, expertise level, and behavior expected.

#### 2.2 — Task Clarity & Specificity
- Rewrite vague instructions into specific, actionable directives.
- Break complex tasks into numbered steps or sub-tasks.
- Use imperative verbs (e.g., "Analyze", "Generate", "List", "Compare").

#### 2.3 — Context & Constraints
- Add relevant context the model needs to perform well.
- Define explicit constraints:
  - Length limits (e.g., "in 3 paragraphs", "max 500 words")
  - Format requirements (e.g., JSON, markdown, bullet points)
  - Language or technical restrictions
  - What to include AND what to avoid

#### 2.4 — Output Format Specification
- Define the exact expected output structure.
- Use delimiters or templates when useful (e.g., ```json, XML tags, markdown headers).
- Specify if the output should be a list, table, code block, narrative, etc.

#### 2.5 — Few-Shot Examples (if applicable)
- Add 1-3 input/output examples that demonstrate the desired behavior.
- Use clear delimiters to separate examples (e.g., `### Example 1`).
- Ensure examples cover typical and edge cases.

#### 2.6 — Chain of Thought / Reasoning
- If the task requires analysis or decision-making, add instructions like:
  - "Think step by step before giving your final answer."
  - "First analyze the problem, then propose a solution."
  - "Explain your reasoning before concluding."

#### 2.7 — Guardrails & Edge Cases
- Add instructions for handling ambiguous or unexpected inputs.
- Define fallback behavior (e.g., "If the input is unclear, ask for clarification instead of guessing.").
- Include negative instructions where needed (e.g., "Do NOT include personal opinions.").

#### 2.8 — Structure & Readability
- Organize the prompt with clear sections using markdown headers or numbered lists.
- Place the most important instructions first.
- Use delimiters to separate the system instructions from user input placeholders (e.g., `---`, XML tags, triple backticks).
- Keep the prompt concise — remove redundancy without losing clarity.

### 3. Generate the Optimized Prompt
- Write the final optimized prompt incorporating all applicable techniques from Step 2.
- Format it cleanly using markdown.
- Include placeholders for dynamic user input where appropriate (e.g., `{{user_input}}`, `{{topic}}`, `{{language}}`).

### 4. Provide a Before/After Comparison
- Present the original prompt and the optimized prompt side by side.
- Use this format:

```
### Original Prompt
<the user's original prompt>

### Optimized Prompt
<the new optimized prompt>
```

### 5. Explain the Changes
- List each optimization applied and why, for example:
  - "Added a role definition to set the model's expertise context."
  - "Added output format specification to ensure structured responses."
  - "Included a few-shot example to demonstrate expected behavior."
  - "Added chain-of-thought instruction to improve reasoning quality."
- This helps the user learn prompt engineering principles.

### 6. Offer Variations (Optional)
- If relevant, offer 2-3 alternative versions of the optimized prompt:
  - **Concise version**: Shorter, for quick interactions.
  - **Detailed version**: More thorough, with examples and guardrails.
  - **System prompt version**: Formatted specifically as a system prompt for API use.
- Ask the user which version they prefer or if they want further adjustments.

### 7. Deliver and Iterate
- Present the final optimized prompt to the user.
- Ask if they want to:
  - Adjust the tone or style
  - Add or remove examples
  - Change the output format
  - Adapt it for a specific model or platform (OpenAI, Anthropic, local models, etc.)
- Iterate until the user is satisfied with the result.
