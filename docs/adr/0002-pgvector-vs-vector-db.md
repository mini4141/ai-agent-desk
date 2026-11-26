# ADR 0002: pgvector inside PostgreSQL instead of a dedicated vector database

**Status:** accepted · **Date:** 2026-11-26

## Context
Each company brings its own knowledge; retrieval must never cross tenants. Options: pgvector in the primary PostgreSQL (RDS), or a separate
vector service (OpenSearch/Pinecone/Qdrant).

## Decision
`knowledge_chunks.embedding vector(1024)` (Titan Text Embeddings v2 dimensions) with an HNSW cosine index, queried through the `neighbor` gem.
The tenant filter is `acts_as_tenant`'s default scope, so every query is `WHERE company_id = ? ORDER BY embedding <=> ? LIMIT k`.

## Why
- **Transactional with the rest of the data:** a source, its chunks and its status change in one transaction; deleting a company deletes its vectors (`dependent:`/FK).
- **Tenant filtering is plain SQL.** With pgvector 0.8 `hnsw.iterative_scan = relaxed_order` keeps scanning until the filter yields k rows, which fixes the classic "filtered ANN returns too few rows" problem.
- **One less thing to run** in a two-AZ ECS setup; RDS already has backups, monitoring and IAM.
- **Measured** (`docs/db-performance.md`): for a 20k-chunk tenant the HNSW plan takes ~4 ms vs ~103 ms for btree + exact sort; for a ~345-chunk tenant the planner correctly prefers the tenant btree.

## Consequences / when to revisit
Tens of millions of vectors, or very high write rates during re-embedding, would justify a dedicated engine. The retrieval boundary is one class (`Retriever`), so the swap is local.
