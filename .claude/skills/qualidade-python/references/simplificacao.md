# Simplification pass

Read the diff, not the whole file, and ask each question. Change the code only
when the answer is clearly "yes, this is simpler", and keep the tests green.

## Structure
- [ ] **Can a nested block become a guard clause?** Return or raise early so the
      main path is not indented three levels deep.
- [ ] **Does each function do one thing its name says?** If the docstring needs
      "and", it is probably two functions.
- [ ] **Is transformation separated from I/O?** Pure functions (data in, data out)
      are easy to test and deterministic; keep reading and writing at the edges.
- [ ] **Is there an abstraction with a single user?** Inline it. Extract only when
      the same logic appears a third time.
- [ ] **Is behaviour that varies by source written as code?** Move it to
      configuration (column aliases, file patterns, formats).

## Expressions
- [ ] A loop that only builds a list or dict reads better as a comprehension — but
      a comprehension with two conditions and a nested loop does not.
- [ ] Flags passed around as `True/False` arguments often hide two functions.
- [ ] Magic values (`11`, `"55"`, `"S/N"`) get a named constant that says why.
- [ ] `dataclass(frozen=True)` for records instead of loose dicts or tuples.

## Standard library first
- [ ] `pathlib` instead of `os.path`; `csv` and `json` before pandas for reading.
- [ ] Before adding a dependency, check the treatment-stage library rule in the
      skill (offline, deterministic when pinned, changes a business decision).

## Errors
- [ ] No bare `except:` and no `except Exception: pass`. Catch the specific error,
      and either record it (ingestion) or re-raise with context.
- [ ] Error messages say what to do next ("run `dbt compile --select x` first").

## Cleanup
- [ ] Dead code, commented-out code, unused imports and parameters are gone.
- [ ] Comments explain decisions, not lines. No summary comment at the end of a file.
