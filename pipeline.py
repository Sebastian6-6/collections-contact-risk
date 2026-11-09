"""Roda a pipeline do zero: apaga o banco, grava a bronze com a ingestão e executa o dbt build.

Uso, a partir da raiz do repositório:
    python pipeline.py

O banco DuckDB é recriado a cada execução e a ingestão lê todos os arquivos de novo, então
duas execuções a partir do mesmo estado inicial dão o mesmo resultado.
"""

import sys
from collections.abc import Callable
from pathlib import Path

from dbt.cli.main import dbtRunner

from ingestion import ErroDeIngestao
from ingestion.main import CONFIGURACAO_PADRAO, RAIZ_PADRAO, caminho_do_banco, carregar_entidades
from ingestion.main import executar as executar_ingestao

SUFIXOS_DO_BANCO = ("", ".wal")


def apagar_banco(raiz: Path) -> None:
    """Remove o banco e o seu arquivo de log de escrita, se existirem."""
    banco = caminho_do_banco(raiz)
    for sufixo in SUFIXOS_DO_BANCO:
        banco.with_name(banco.name + sufixo).unlink(missing_ok=True)
    print(f"[OK] banco recriado do zero: {banco.relative_to(raiz).as_posix()}")


def executar_dbt(raiz: Path) -> bool:
    """Roda `dbt build` no projeto da raiz e diz se passou."""
    resultado = dbtRunner().invoke(
        ["build", "--project-dir", str(raiz), "--profiles-dir", str(raiz)]
    )
    return resultado.success


def main(
    raiz: Path = RAIZ_PADRAO,
    configuracao: Path = CONFIGURACAO_PADRAO,
    rodar_dbt: Callable[[Path], bool] = executar_dbt,
) -> int:
    """Apaga o banco, grava a bronze e roda o dbt; devolve 0 só se tudo passou."""
    apagar_banco(raiz)
    try:
        entidades = carregar_entidades(configuracao)
    except ErroDeIngestao as erro:
        print(f"[ERRO] {erro}")
        return 1
    if executar_ingestao(entidades, raiz, caminho_do_banco(raiz)) != 0:
        print("[ERRO] a ingestão falhou; o dbt não foi executado")
        return 1
    if not rodar_dbt(raiz):
        print("[ERRO] o dbt build falhou")
        return 1
    print("[OK] pipeline concluída")
    return 0


if __name__ == "__main__":
    sys.exit(main())
