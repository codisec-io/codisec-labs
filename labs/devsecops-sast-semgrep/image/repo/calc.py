"""
Calculadora simples de expressões — contém uso perigoso de eval()
intencional pro lab.
"""


def calcular(expressao):
    # VULNERÁVEL: eval() executa QUALQUER código Python contido na
    # string, não só aritmética. Se "expressao" vier (mesmo que
    # indiretamente) de input do usuário, é execução de código arbitrário.
    resultado = eval(expressao)
    return resultado
