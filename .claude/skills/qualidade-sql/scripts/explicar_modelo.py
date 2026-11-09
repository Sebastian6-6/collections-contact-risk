#!/usr/bin/env python3
"""Mostra o plano real (EXPLAIN ANALYZE) de um modelo dbt já compilado no DuckDB.

Otimizar sem medir é chute. Este script pega o SQL que o dbt compilou em
target/compiled/, executa EXPLAIN ANALYZE no banco do projeto (só leitura) e,
além do plano completo, destaca operadores que costumam indicar problema:
produto cartesiano e joins por laço aninhado.

Uso, a partir da raiz do projeto:
    dbt compile --select <modelo>
    python .claude/skills/qualidade-sql/scripts/explicar_modelo.py <modelo> [--banco caminho]

Sem --banco, o caminho vem do primeiro `path:` do profiles.yml da raiz.
"""

import argparse
import re
import sys
from pathlib import Path

import duckdb

PASTA_COMPILADOS = Path("target") / "compiled"
OPERADORES_SUSPEITOS = {
    "CROSS_PRODUCT": "produto cartesiano: falta condição de join?",
    "NESTED_LOOP_JOIN": "join por laço aninhado: condição sem igualdade?",
    "BLOCKWISE_NL_JOIN": "join por blocos sem igualdade: confira a condição",
    "PIECEWISE_MERGE_JOIN": "join por desigualdade: confira se é intencional",
}


def achar_sql_compilado(modelo: str) -> Path:
    """Localiza target/compiled/**/<modelo>.sql; falha com instrução clara se não existir."""
    encontrados = sorted(PASTA_COMPILADOS.rglob(f"{modelo}.sql"))
    if not encontrados:
        sys.exit(
            f"SQL compilado de '{modelo}' não encontrado em {PASTA_COMPILADOS}/.\n"
            f"Rode antes: dbt compile --select {modelo}"
        )
    if len(encontrados) > 1:
        sys.exit(f"Mais de um compilado para '{modelo}': {[str(p) for p in encontrados]}")
    return encontrados[0]


def caminho_do_banco_no_profiles(profiles: Path = Path("profiles.yml")) -> Path:
    """Lê o primeiro `path:` do profiles.yml sem depender de biblioteca YAML."""
    if not profiles.exists():
        sys.exit("profiles.yml não encontrado na pasta atual; informe --banco")
    achado = re.search(
        r"^\s*path:\s*['\"]?([^'\"\n#]+)", profiles.read_text(encoding="utf-8"), re.M
    )
    if not achado:
        sys.exit("Nenhum `path:` no profiles.yml; informe --banco")
    return Path(achado.group(1).strip())


def montar_plano(banco: Path, sql: str) -> str:
    with duckdb.connect(str(banco), read_only=True) as conexao:
        linhas = conexao.execute(f"EXPLAIN ANALYZE {sql}").fetchall()
    return "\n".join(str(linha[-1]) for linha in linhas)


def alertas_do_plano(plano: str) -> list[str]:
    """Procura operadores suspeitos no texto do plano, ignorando espaços e caixa."""
    normalizado = re.sub(r"[\s_]+", "_", plano.upper())
    return [
        f"{operador}: {explicacao}"
        for operador, explicacao in OPERADORES_SUSPEITOS.items()
        if operador in normalizado
    ]


def main(argumentos: list[str] | None = None) -> int:
    # Consoles do Windows usam cp1252 por padrão e quebrariam os acentos e as bordas do plano.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    leitor = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    leitor.add_argument("modelo", help="nome do modelo dbt (nome do arquivo, sem .sql)")
    leitor.add_argument("--banco", type=Path, help="arquivo .duckdb; padrão: path do profiles.yml")
    opcoes = leitor.parse_args(argumentos)

    banco = opcoes.banco or caminho_do_banco_no_profiles()
    if not banco.exists():
        sys.exit(f"Banco {banco} não existe; rode a pipeline antes")
    compilado = achar_sql_compilado(opcoes.modelo)
    sql = compilado.read_text(encoding="utf-8").strip().rstrip(";")

    plano = montar_plano(banco, sql)
    print(f"Modelo: {opcoes.modelo}  ({compilado})")
    print(plano)
    alertas = alertas_do_plano(plano)
    print("\nAlertas:" if alertas else "\nNenhum operador suspeito no plano.")
    for alerta in alertas:
        print(f"  - {alerta}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
