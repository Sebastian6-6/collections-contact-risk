"""Mede a régua de risco nos cortes de validação: o instrumento do loop de refinamento (4.7b).

Uso, a partir da raiz do repositório, com o banco já construído pela pipeline:
    python scripts/medir_regua.py

Para cada corte (2026-09-15 e 2026-09-22), compila `analyses/regua_metricas.sql` com a `var`
`data_corte_validacao`, executa o SQL no DuckDB do projeto (só leitura) e imprime:
  - a acurácia balanceada, a média entre a fração dos desfechos de risco (terceiro, opt_out e
    falecido) cujo par ficou em `atencao` ou `bloqueado` e a fração dos `contato_confirmado` cujo
    par ficou `liberado`;
  - a fração de `terceiro` pegos e a de `contato_confirmado` liberados, com as quantidades.
Sai com código 1 se o dbt falhar ao compilar.
"""

import json
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from ingestion.main import caminho_do_banco  # noqa: E402

CORTES = ("2026-09-15", "2026-09-22")
ANALISE = "regua_metricas"
PROJETO_DBT = "collections_contact_risk"
COMANDO_DBT = "from dbt.cli.main import cli; cli()"

Metricas = dict[str, object]


def compilar_metricas(raiz: Path, data_corte: str) -> str:
    """Compila a análise das métricas para o corte e devolve o SQL, sem rodar nada no banco.

    O dbt roda em outro processo: no mesmo, a conexão dele ao DuckDB ficaria aberta e impediria a
    leitura em modo só de leitura logo depois.
    """
    processo = subprocess.run(
        [
            sys.executable, "-c", COMANDO_DBT,
            "--quiet", "compile",
            "--select", ANALISE,
            "--project-dir", str(raiz),
            "--profiles-dir", str(raiz),
            "--vars", json.dumps({"data_corte_validacao": data_corte}),
        ],
        capture_output=True, text=True, encoding="utf-8", check=False,
    )
    if processo.returncode != 0:
        saida = processo.stdout[-800:]
        raise RuntimeError(f"o dbt não compilou {ANALISE} para o corte {data_corte}: {saida}")
    compilado = raiz / "target" / "compiled" / PROJETO_DBT / "analyses" / f"{ANALISE}.sql"
    return compilado.read_text(encoding="utf-8")


def executar_metricas(banco: Path, sql: str) -> Metricas:
    """Roda o SQL compilado em conexão só de leitura e devolve a linha única como dicionário."""
    conexao = duckdb.connect(str(banco), read_only=True)
    try:
        cursor = conexao.execute(sql)
        colunas = [coluna[0] for coluna in cursor.description]
        return dict(zip(colunas, cursor.fetchone(), strict=True))
    finally:
        conexao.close()


def formatar_fracao(parte: int, total: int, fracao: float | None) -> str:
    """Escreve `parte de total (xx,xx%)` com vírgula decimal; sem total, diz que não há base."""
    if fracao is None:
        return f"{parte} de {total} (sem base)"
    return f"{parte} de {total} ({fracao * 100:.2f}%)".replace(".", ",")


def formatar_metricas(metricas: Metricas) -> str:
    """Monta o bloco de texto de um corte."""
    acuracia = metricas["acuracia_balanceada"]
    acuracia_texto = "sem base" if acuracia is None else f"{acuracia:.4f}".replace(".", ",")
    return "\n".join(
        [
            f"Corte {metricas['dt_corte']}",
            f"  acurácia balanceada: {acuracia_texto}",
            "  terceiros pegos: " + formatar_fracao(
                metricas["qt_terceiro_pego"], metricas["qt_terceiro"],
                metricas["fracao_terceiro_pego"]),
            "  confirmados liberados: " + formatar_fracao(
                metricas["qt_confirmado_liberado"], metricas["qt_confirmado"],
                metricas["fracao_confirmado_liberado"]),
            "  riscos pegos (terceiro, opt_out, falecido): " + formatar_fracao(
                metricas["qt_risco_pego"], metricas["qt_risco"], metricas["fracao_risco_pego"]),
        ]
    )


def main(
    raiz: Path = RAIZ,
    compilar: Callable[[Path, str], str] = compilar_metricas,
    executar: Callable[[Path, str], Metricas] = executar_metricas,
) -> int:
    """Imprime as métricas de cada corte e devolve 0, ou 1 se a compilação falhar."""
    banco = caminho_do_banco(raiz)
    for data_corte in CORTES:
        try:
            sql = compilar(raiz, data_corte)
        except RuntimeError as erro:
            print(f"[ERRO] {erro}")
            return 1
        print(formatar_metricas(executar(banco, sql)))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
