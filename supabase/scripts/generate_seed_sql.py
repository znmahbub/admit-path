#!/usr/bin/env python3

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEED_ROOT = ROOT / "AdmitPath" / "SeedData"

TABLE_FILES = [
    ("universities", "universities.json"),
    ("programs", "programs.json"),
    ("program_requirements", "program_requirements.json"),
    ("program_deadlines", "program_deadlines.json"),
    ("scholarships", "scholarships.json"),
    ("peer_profiles", "peer_profiles.json"),
    ("peer_posts", "peer_posts.json"),
    ("peer_replies", "peer_replies.json"),
    ("peer_artifacts", "peer_artifacts.json"),
]


def sql_literal(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (list, dict)):
        payload = json.dumps(value, ensure_ascii=True).replace("'", "''")
        return f"'{payload}'::jsonb"

    text = str(value).replace("'", "''")
    return f"'{text}'"


def emit_insert(table_name: str, rows: list[dict]) -> str:
    if not rows:
        return f"-- {table_name}: no rows\n"

    columns = list(rows[0].keys())
    quoted_columns = ", ".join(f'"{column}"' for column in columns)
    values_sql = []
    for row in rows:
        row_values = ", ".join(sql_literal(row.get(column)) for column in columns)
        values_sql.append(f"  ({row_values})")

    return "\n".join(
        [
            f'truncate table public.{table_name} restart identity cascade;',
            f'insert into public.{table_name} ({quoted_columns}) values',
            ",\n".join(values_sql) + ";",
            "",
        ]
    )


def main() -> None:
    print("-- Generated from AdmitPath/SeedData")
    print("begin;")
    print("")
    for table_name, filename in TABLE_FILES:
        rows = json.loads((SEED_ROOT / filename).read_text())
        print(emit_insert(table_name, rows))
    print("commit;")


if __name__ == "__main__":
    main()
