#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/scripts/secret-scan.sh"\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit && echo "pre-commit secret scan installed"
