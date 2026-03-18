# Skill: Generate Code from Prompt

## Description
Generates code in any programming language based on a free-form prompt provided by the user. This skill follows a structured process to understand requirements, generate high-quality code, and deliver it ready to use.

## Arguments
- `$ARGUMENTS`: The user's prompt describing what code they need (including language, functionality, and any constraints).

## Steps

### 1. Parse the User's Prompt
- Read the user's prompt carefully: `$ARGUMENTS`
- Identify the following from the prompt:
  - **Programming language** (e.g., Python, TypeScript, Java, Go, Rust, C#, etc.)
  - **Purpose/functionality** (what the code should do)
  - **Constraints** (performance, libraries, style, framework, etc.)
  - **Output format** (single file, module, class, function, CLI tool, API, etc.)
- If any critical detail is missing (especially the language), ask the user for clarification before proceeding.

### 2. Plan the Code Structure
- Define the file(s) to be created and their names using language-appropriate conventions.
- Outline the main components:
  - Imports / dependencies
  - Data structures / types / interfaces
  - Core logic (functions, classes, modules)
  - Entry point (if applicable: `main`, CLI args, server start, etc.)
- If the code requires external dependencies, list them and note installation commands (e.g., `pip install`, `npm install`, `cargo add`).

### 3. Generate the Code
- Write the code following these principles:
  - **Idiomatic**: Follow the conventions and best practices of the target language.
  - **Well-structured**: Clean separation of concerns, meaningful names.
  - **Typed**: Use type annotations/hints where the language supports them.
  - **Documented**: Add docstrings/comments for public functions and complex logic.
  - **Error handling**: Include appropriate error handling for the language.
  - **Ready to run**: The code must be immediately executable (all imports, no placeholders).
- Save the generated files to the user's working directory or repository.

### 4. Add Setup Instructions
- Create or update a `README.md` (if generating a standalone project) with:
  - Description of what the code does
  - Prerequisites (language version, runtime, etc.)
  - Installation steps for dependencies
  - How to run the code
  - Example usage / expected output
- If the code is a single file or snippet, include setup instructions as comments at the top of the file instead.

### 5. Validate the Code
- Run a syntax check or linter appropriate for the language:
  - Python: `python -m py_compile <file>` or `ruff check`
  - TypeScript/JavaScript: `npx tsc --noEmit` or `npx eslint`
  - Go: `go vet`
  - Rust: `cargo check`
  - Java: `javac`
  - Other: use the language's standard validation tool
- If there are errors, fix them and re-validate.
- If the code includes tests, run them.

### 6. Deliver to the User
- Present the generated code to the user.
- Summarize what was generated:
  - Files created
  - Language and key libraries used
  - How to run it
  - Any assumptions made
- Ask the user if they want any modifications or improvements.
