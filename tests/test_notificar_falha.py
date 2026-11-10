"""Alerta por e-mail: desligado sem variáveis, enviado na falha, sem rede nos testes."""

from typing import ClassVar

import pytest

from scripts import notificar_falha

AMBIENTE = {
    "ALERTA_SMTP_HOST": "smtp.exemplo.test",
    "ALERTA_SMTP_PORTA": "587",
    "ALERTA_SMTP_USUARIO": "usuario",
    "ALERTA_SMTP_SENHA": "segredo",
    "ALERTA_EMAIL_DE": "pipeline@exemplo.test",
    "ALERTA_EMAIL_PARA": "dono@exemplo.test",
}


class SmtpFalso:
    """Guarda o que o script faria com o servidor, sem abrir conexão."""

    instancias: ClassVar[list] = []

    def __init__(self, host, porta):
        self.host, self.porta = host, porta
        self.mensagens, self.login_feito, self.tls = [], None, False
        SmtpFalso.instancias.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *erro):
        return False

    def starttls(self, context=None):
        self.tls = True

    def login(self, usuario, senha):
        self.login_feito = (usuario, senha)

    def send_message(self, mensagem):
        self.mensagens.append(mensagem)


@pytest.fixture(autouse=True)
def smtp_falso(monkeypatch):
    SmtpFalso.instancias = []
    monkeypatch.setattr(notificar_falha.smtplib, "SMTP", SmtpFalso)


def test_sem_as_variaveis_o_alerta_fica_desligado(capsys):
    assert notificar_falha.notificar("o dbt build falhou", {}) is False

    assert "alerta por e-mail desligado" in capsys.readouterr().out
    assert SmtpFalso.instancias == []


def test_na_falha_envia_o_motivo_e_as_ultimas_linhas_do_log(tmp_path):
    log = tmp_path / "dbt.log"
    log.write_text("\n".join(f"linha {n}" for n in range(1, 31)), encoding="utf-8")

    assert notificar_falha.notificar("o dbt build falhou", AMBIENTE, log) is True

    servidor = SmtpFalso.instancias[0]
    mensagem = servidor.mensagens[0]
    assert (servidor.host, servidor.porta) == ("smtp.exemplo.test", 587)
    assert servidor.login_feito == ("usuario", "segredo")
    assert mensagem["Subject"] == "[collections-contact-risk] o dbt build falhou"
    assert mensagem["From"] == "pipeline@exemplo.test"
    assert mensagem["To"] == "dono@exemplo.test"
    corpo = mensagem.get_content()
    assert "o dbt build falhou" in corpo
    assert "linha 30" in corpo
    assert "linha 1\n" not in corpo


def test_sem_log_o_corpo_traz_so_o_motivo(tmp_path):
    assert notificar_falha.notificar("a ingestão falhou", AMBIENTE, tmp_path / "nao_existe.log")

    assert "a ingestão falhou" in SmtpFalso.instancias[0].mensagens[0].get_content()
