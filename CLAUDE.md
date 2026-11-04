# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Saxy is an XML 1.0 SAX parser and encoder in Elixir (Hex package `saxy`). No runtime deps. Supports Elixir 1.12+ / OTP 24+ (see CI matrix in `.github/workflows/test.yml`), so avoid newer-only APIs.

## Commands

- `mix deps.get` — install deps
- `mix test` — run all tests
- `mix test test/saxy/parser/element_test.exs:LINE` — run a single test
- `mix format` — format (line length 130; `defhalt`, `emit_event` are paren-less locals)
- `mix docs` — build ExDoc (dev only)
- Benchmarks live in `bench/` (separate mix project): `cd bench && mix run bench.binary.exs`

## Architecture

Public API is in `lib/saxy.ex` (`parse_string/4`, `parse_stream/4`, `encode!/2`, `encode_to_iodata/2`). Other modules: `Saxy.Partial` (manual chunked parsing), `Saxy.SimpleForm` (DOM-like tuples), `Saxy.XML`/`Saxy.Builder` (encoder DSL/protocol), `Saxy.Handler` (behaviour users implement).

### Parser (the non-obvious part)

`lib/saxy/parser/builder.ex` (~1400 lines) is a macro that generates the whole parser. `Saxy.Parser.Binary` and `Saxy.Parser.Stream` (`lib/saxy/parser.ex`) both `use Saxy.Parser.Builder` with `streaming?: false|true`, so one source yields two modules.

- Parser functions are binary-pattern-matching state functions with signature `(buffer, more?, original, pos, state)`. `original` and `pos` are used for error reporting and zero-copy slicing.
- `lookahead/2` (`parser/lookahead.ex`) is a macro that, in streaming mode, adds clauses for incomplete tokens (`edge_ngrams`, partial UTF-8 via `BufferingHelper.utf8_binaries/0`).
- When a token may be split across chunks and `more?` is true, the code calls `halt!(fun(token, ...))` (`buffering_helper.ex`). That returns `{:halted, continuation_fun, state}`; the continuation prepends the leftover token to the next chunk and re-enters the same function.
- Events go through `Saxy.Emitter` (`emit_event` macro). Handler return values `:ok | :stop | :halt` map to continue / finish early / suspend (halt enables `Saxy.Partial`).
- Errors: `Saxy.Parser.Utils.parse_error/4` builds `Saxy.ParseError`.

When changing parsing logic, change the builder once, and cover both binary and streaming paths. Streaming bugs usually come from tokens split across chunk boundaries (see recent "UTF-8 chars split across chunks" fix).

### Performance rules

Design goal is speed, so keep the binary-matching optimizations intact (see the Forza posts "How I sped up my XML parser by 15 times" and "Binary parsing optimizations in Elixir"):

- Keep the match context alive: pass the buffer forward to the next function, never return `rest` from a helper.
- Hand a parser function only a buffer matched by its caller, never a binary built or written out (`<<>>`, `token <> chunk`). One such call makes the function check for a match context on every call, so a loop pays for it on every byte. That is why halt continuations match the joined buffer before calling.
- One function per grammar rule. Don't write a shared dispatcher clause-matching on a token type, since the compiler doesn't reorder binary clauses.
- Every clause starts with a `<<...>>` pattern as its first argument. Keep argument order consistent across related functions.
- Prefer `::bits` over `::bytes` (avoids a divisible-by-8 check).
- Slice names and text with `binary_part(original, pos, len)` by tracking `pos`/`len`, rather than building binaries. Use iodata where building is unavoidable (e.g. character references), not repeated `<>`.
- Return parse errors immediately, no throw/catch.
- Put hot clauses first. Inline the hottest ones.
- After parser edits, check `ERL_COMPILER_OPTIONS=bin_opt_info mix compile --force` for new warnings, and compare `bench/` results before and after.

### Tests

- `test/support/parsing_case.ex` provides a case template that runs parsing tests against both binary and stream (chunked) parsers.
- `test/support/fixture/*.xml` are XML fixtures; `test/support/test_handlers.ex` has shared handlers.
- `stream_data` is used for property tests.

## Releasing

Version lives in `mix.exs` (`@version`); update `CHANGELOG.md` too. Commits are titled like `Release vX.Y.Z`.
