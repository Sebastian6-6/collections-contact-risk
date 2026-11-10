"""Manda um e-mail curto quando a pipeline falha ou termina com testes em WARN.

A configuração vem só de variáveis de ambiente, nunca de arquivo:
    ALERTA_SMTP_HOST, ALERTA_SMTP_PORTA, ALERTA_SMTP_USUARIO, ALERTA_SMTP_SENHA,
    ALERTA_EMAIL_DE, ALERTA_EMAIL_PARA
Sem elas o alerta fica desligado: o script imprime uma linha e não faz nada, então um clone limpo
e o CI se comportam como antes.
"""

import os
import smtplib
import ssl
from collections.abc import Mapping
from email.message import EmailMessage
from pathlib import Path

VARIAVEIS = (
    "ALERTA_SMTP_HOST",
    "ALERTA_SMTP_PORTA",
    "ALERTA_SMTP_USUARIO",
    "ALERTA_SMTP_SENHA",
    "ALERTA_EMAIL_DE",
    "ALERTA_EMAIL_PARA",
)
LOG_PADRAO = Path("logs") / "dbt.log"
LINHAS_DO_LOG = 20


def ultimas_linhas(caminho: Path, quantidade: int = LINHAS_DO_LOG) -> str:
    """Devolve o fim do log do dbt, ou texto vazio se ele não existir."""
    if not caminho.exists():
        return ""
    linhas = caminho.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(linhas[-quantidade:])


def notificar(
    motivo: str,
    ambiente: Mapping[str, str] = os.environ,
    caminho_log: Path = LOG_PADRAO,
) -> bool:
    """Envia o e-mail de alerta com o motivo e o fim do log; devolve se enviou.

    Existe para a pipeline avisar o responsável sem depender de ninguém olhar o terminal.
    """
    if not all(ambiente.get(nome) for nome in VARIAVEIS):
        print("[OK] alerta por e-mail desligado: variáveis ALERTA_* ausentes")
        return False

    mensagem = EmailMessage()
    mensagem["Subject"] = f"[collections-contact-risk] {motivo}"
    mensagem["From"] = ambiente["ALERTA_EMAIL_DE"]
    mensagem["To"] = ambiente["ALERTA_EMAIL_PARA"]
    log = ultimas_linhas(caminho_log)
    mensagem.set_content(f"{motivo}\n\nÚltimas linhas do log:\n{log}" if log else motivo)

    host, porta = ambiente["ALERTA_SMTP_HOST"], int(ambiente["ALERTA_SMTP_PORTA"])
    with smtplib.SMTP(host, porta) as servidor:
        # O contexto padrão confere o certificado do servidor antes de enviar a senha.
        servidor.starttls(context=ssl.create_default_context())
        servidor.login(ambiente["ALERTA_SMTP_USUARIO"], ambiente["ALERTA_SMTP_SENHA"])
        servidor.send_message(mensagem)
    print("[OK] alerta enviado por e-mail")
    return True
