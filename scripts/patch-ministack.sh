#!/usr/bin/env bash
# Aplica o patch local no MiniStack: _parse_conditions com suporte aos shapes
# novos do provider aws v6 (PathPatternConfig/HostHeaderConfig/SourceIpConfig).
# Sem isso, regras de ALB criadas via Terraform ficam com Values: [].
#
# Idempotente. NÃO reinicia o ministack (restart apaga TODO o estado emulado) —
# se o patch for aplicado com o serviço rodando, reinicie quando for aceitável
# perder o estado e rode `make clean-state && make apply` depois.
set -euo pipefail

if ! command -v ministack >/dev/null; then
  echo "ERRO: ministack não encontrado no PATH" >&2
  exit 1
fi

PY=$(head -1 "$(command -v ministack)" | sed 's/^#!//; s/ .*//')
ALB=$("$PY" -c "import ministack.services.alb as m; print(m.__file__)")

if grep -q "_CONFIG_KEYS" "$ALB"; then
  echo "já patcheado: $ALB"
  exit 0
fi

"$PY" - "$ALB" <<'EOF'
import sys, re

path = sys.argv[1]
src = open(path).read()

patched = '''def _parse_conditions(params, prefix="Conditions"):
    conditions, i = [], 1
    _CONFIG_KEYS = {
        "path-pattern": "PathPatternConfig",
        "host-header": "HostHeaderConfig",
        "source-ip": "SourceIpConfig",
    }
    while True:
        field = _p(params, f"{prefix}.member.{i}.Field")
        if not field:
            break
        values, j = [], 1
        while True:
            v = _p(params, f"{prefix}.member.{i}.Values.member.{j}")
            if not v:
                break
            values.append(v)
            j += 1
        config_key = _CONFIG_KEYS.get(field)
        if not values and config_key:
            values, j = [], 1
            while True:
                v = _p(params, f"{prefix}.member.{i}.{config_key}.Values.member.{j}")
                if not v:
                    break
                values.append(v)
                j += 1
        conditions.append({"Field": field, "Values": values})
        i += 1
    return conditions
'''

# substitui o bloco inteiro da função (do def até o próximo def/EOF)
new = re.sub(
    r'def _parse_conditions\(params, prefix="Conditions"\):.*?(?=\ndef |\Z)',
    patched, src, count=1, flags=re.S,
)
if new == src:
    print("ERRO: função _parse_conditions não encontrada no formato esperado" , file=sys.stderr)
    sys.exit(1)
open(path, "w").write(new)
print(f"patcheado: {path}")
EOF

echo "ATENÇÃO: se o ministack está rodando, o patch só vale após restart"
echo "(restart apaga o estado emulado — depois: make clean-state && make apply)"
