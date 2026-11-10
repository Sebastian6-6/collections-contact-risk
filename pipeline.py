"""Roda a pipeline do zero: apaga o banco, grava a bronze com a ingestão e executa o dbt build.

Uso, a partir da raiz do repositório:
    python pipeline.py [--avisar-warn]

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
from scripts.notificar_falha import notificar as notificar_por_email

SUFIXOS_DO_BANCO = ("", ".wal")


def apagar_banco(raiz: Path) -> None:
    """Remove o banco e o seu arquivo de log de escrita, se existirem."""
    banco = caminho_do_banco(raiz)
    for sufixo in SUFIXOS_DO_BANCO:
        banco.with_name(banco.name + sufixo).unlink(missing_ok=True)
    print(f"[OK] banco recriado do zero: {banco.relative_to(raiz).as_posix()}")


def executar_dbt(raiz: Path) -> int | None:
    """Roda `dbt build` no projeto da raiz; devolve `None` se falhou, senão a contagem de WARN."""
    resultado = dbtRunner().invoke(
        ["build", "--project-dir", str(raiz), "--profiles-dir", str(raiz)]
    )
    if not resultado.success:
        return None
    return sum(1 for item in resultado.result.results if item.status == "warn")


def main(
    raiz: Path = RAIZ_PADRAO,
    configuracao: Path = CONFIGURACAO_PADRAO,
    rodar_dbt: Callable[[Path], int | None] = executar_dbt,
    avisar_warn: bool = False,
    notificar: Callable[[str], object] = notificar_por_email,
) -> int:
    """Apaga o banco, grava a bronze e roda o dbt; devolve 0 só se tudo passou.

    A falha da ingestão ou do dbt dispara o alerta por e-mail; com `avisar_warn`, também o
    WARN. O código de saída não depende do alerta.
    """
    apagar_banco(raiz)
    try:
        entidades = carregar_entidades(configuracao)
    except ErroDeIngestao as erro:
        print(f"[ERRO] {erro}")
        notificar("a ingestão falhou")
        return 1
    if executar_ingestao(entidades, raiz, caminho_do_banco(raiz)) != 0:
        print("[ERRO] a ingestão falhou; o dbt não foi executado")
        notificar("a ingestão falhou")
        return 1
    avisos = rodar_dbt(raiz)
    if avisos is None:
        print("[ERRO] o dbt build falhou")
        notificar("o dbt build falhou")
        return 1
    if avisos and avisar_warn:
        notificar(f"o dbt build terminou com {avisos} testes em WARN")
    print("[OK] pipeline concluída")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(avisar_warn="--avisar-warn" in sys.argv[1:]))
