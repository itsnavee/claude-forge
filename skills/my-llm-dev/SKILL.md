---
name: my-llm-dev
description: Use when building LLM-powered features — provides guided patterns for RAG, embeddings, prompt engineering, evaluation pipelines, and agent architectures. Also use for "build with LLM", "add AI feature", "RAG pipeline", or "prompt engineering".
argument-hint: "< rag | embeddings | prompts | eval | agents > [context]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(npx:*), Bash(python3:*), Bash(pip:*), Bash(node:*), Agent
---

# LLM Application Development

Structured guidance and implementation patterns for building LLM-powered features. Covers RAG, embeddings, prompt engineering, evaluation, and agent architectures.

## Quick Help

**What**: Patterns and implementation guidance for LLM-powered features — not general coding, specifically AI/ML integration.
**Usage**:
- `/my-llm-dev rag` — RAG implementation patterns (chunking, retrieval, reranking)
- `/my-llm-dev embeddings` — embedding strategies (model selection, indexing, similarity search)
- `/my-llm-dev prompts` — prompt engineering patterns (structured output, few-shot, chain-of-thought)
- `/my-llm-dev eval` — LLM evaluation frameworks (metrics, benchmarks, regression testing)
- `/my-llm-dev agents` — agent architecture patterns (tool use, planning, memory)
**Note**: Triggers automatically when code imports `anthropic`, `@anthropic-ai/sdk`, `langchain`, `llamaindex`, `openai`, or similar.

## Patterns

### RAG Implementation

When building retrieval-augmented generation:

**Chunking Strategy**
| Strategy | When to Use | Chunk Size |
|----------|------------|------------|
| Fixed-size with overlap | Simple docs, uniform structure | 512-1024 tokens, 20% overlap |
| Semantic (paragraph/section) | Structured docs with headings | Natural boundaries |
| Recursive (parent-child) | Long docs needing both detail and context | Parent: 2048, Child: 512 |
| Sentence-window | QA over precise facts | Single sentence + surrounding context |

**Retrieval Pipeline**
1. Query → embed with same model as documents
2. Vector similarity search (top-k, typically k=10-20)
3. Rerank with cross-encoder (cuts to top-3-5)
4. Inject into prompt as context
5. Generate with citation references

**What to watch for:**
- Embedding model must match at index and query time — different models = garbage results
- Chunk overlap prevents splitting key info across boundaries — but too much overlap wastes tokens
- Reranking is the highest-leverage improvement for retrieval quality — don't skip it
- Always include metadata (source, page, date) with chunks for citation

### Embedding Strategies

**Model Selection**
| Model | Dimensions | Speed | Quality | Cost |
|-------|-----------|-------|---------|------|
| text-embedding-3-small (OpenAI) | 1536 | Fast | Good | Low |
| text-embedding-3-large (OpenAI) | 3072 | Medium | Better | Medium |
| Voyage-3 | 1024 | Medium | Best for code | Medium |
| Local (e5-large, BGE) | 1024 | Varies | Good | Free |

**Indexing**
- HNSW for <1M vectors (good recall, fast, in-memory)
- IVF-PQ for >1M vectors (approximate, lower memory)
- pgvector for Postgres-native (simplest ops, good for <500k)
- Pinecone/Weaviate for managed (scales automatically)

**What to watch for:**
- Normalize embeddings before cosine similarity — some models don't normalize by default
- Batch embedding calls (not one-by-one) — 10x throughput improvement
- Store raw text alongside vectors — you'll need it for debugging retrieval quality

### Prompt Engineering Patterns

**Structured Output**
```
Use tool_use / function_calling for structured responses — not "respond in JSON".
Tool use is constrained by schema; free-form JSON instructions are unreliable.
```

**Few-Shot Selection**
- Dynamic few-shot: embed the input, retrieve the most similar examples from a pool
- Static few-shot: hand-pick 3-5 diverse examples covering edge cases
- Never use >10 examples — diminishing returns, wasted tokens

**Chain-of-Thought**
- Use `<thinking>` tags or system prompts to separate reasoning from output
- For Claude: extended thinking is built-in — use `thinking` parameter instead of manual CoT
- Verify reasoning matches conclusion — models can reason correctly then output wrong answers

**What to watch for:**
- Temperature 0 is not deterministic — it's "mostly deterministic." Use seeds if available.
- System prompts are more influential than user messages for behavioral instructions
- Long system prompts degrade instruction following — keep under 2000 tokens when possible

### LLM Evaluation

**Metrics**
| Metric | What It Measures | How to Compute |
|--------|-----------------|----------------|
| Factual accuracy | Are claims correct? | Human eval or LLM-as-judge against ground truth |
| Relevance | Does output address the query? | Semantic similarity to reference answer |
| Faithfulness | Is output grounded in provided context? | Check every claim traces to a source chunk |
| Toxicity/Safety | Harmful content? | Classifier (Perspective API, custom) |
| Latency | Time to first token, total time | Instrumentation |
| Cost | Tokens consumed per request | API usage tracking |

**Regression Testing**
- Maintain a golden dataset of (input, expected_output) pairs
- Run after every prompt change, model upgrade, or pipeline modification
- Flag regressions >5% on any metric
- Version control your prompts — they're code

**What to watch for:**
- LLM-as-judge has systematic biases (prefers verbose, prefers its own outputs) — calibrate with human agreement scores
- A/B testing in production is the only way to measure real-world quality — offline evals are necessary but not sufficient

### Agent Architectures

**Tool Use Pattern**
1. Define tools with precise descriptions and strict schemas
2. Let the model select tools based on the task
3. Execute tool calls and return results
4. Loop until the model signals completion

**Planning Patterns**
| Pattern | Description | When to Use |
|---------|------------|------------|
| ReAct | Reason → Act → Observe loop | Simple tool-use tasks |
| Plan-then-Execute | Full plan upfront, then execute | Multi-step tasks with known structure |
| Iterative Refinement | Draft → Critique → Revise | Creative/writing tasks |

**Memory Patterns**
- Conversation buffer: full history (simple, expensive at scale)
- Summary memory: periodically summarize and compress history
- Retrieval memory: embed messages, retrieve relevant ones per query
- Hybrid: recent messages in full + retrieval for older context

**What to watch for:**
- More tools = worse tool selection. Keep tool sets focused (<15 tools per agent).
- Tool descriptions are the most important part — not the schema. The model reads descriptions to decide when to use a tool.
- Agent loops need exit conditions — max iterations, timeout, and budget caps. Unbounded loops drain API credits.

## Steps

### 1. Identify the Pattern
From the user's argument or context, determine which pattern(s) apply.

### 2. Audit Existing Code
Read the relevant code to understand what's already implemented. Don't duplicate.

### 3. Recommend or Implement
- If the user is planning: provide the relevant pattern guidance with specific recommendations for their stack
- If the user is implementing: write code following the patterns above, adapted to their framework/language

### 4. Warn About Common Failures
For every recommendation, state the top failure mode and how to detect it.

## Gotchas

- RAG chunk size recommendations vary by model — what works for GPT-4 may be wrong for Claude
- Embedding models have different dimensionality — can't mix embeddings from different models in the same vector store

## Rules

- This skill is for LLM integration patterns — not general backend/frontend work
- Always recommend the simplest approach first (direct API call before framework, pgvector before Pinecone)
- State cost implications — embedding 1M docs is different from embedding 1K docs
- Never recommend a framework (LangChain, LlamaIndex) without stating what it adds over direct API calls
- If the task can be done with a single API call and no RAG/embedding/agent architecture, say so
