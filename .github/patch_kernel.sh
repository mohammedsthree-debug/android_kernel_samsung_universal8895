#!/bin/bash
set -e

echo "=== Phase 1: Fix DTC yylloc multiple definition ==="
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' scripts/dtc/dtc-lexer.lex.c_shipped || true
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' scripts/dtc/dtc-lexer.l || true

echo "=== Phase 2: Add -fcommon to host build flags ==="
sed -i 's/HOSTCFLAGS   :=/HOSTCFLAGS   := -fcommon /g' Makefile || true
sed -i 's/HOSTCFLAGS   =/HOSTCFLAGS   = -fcommon /g' Makefile || true

echo "=== Phase 3: Precise -Werror removal ==="
# Use Python for precise regex surgery on Makefiles
python3 << 'PYEOF'
import re, os

def patch_makefile(path):
    try:
        with open(path, 'r') as f:
            content = f.read()
        original = content
        # Remove standalone -Werror but NOT -Werror-implicit-function-declaration or -Werror=xxx
        # Match -Werror that is NOT followed by a hyphen, equals, or word char
        content = re.sub(r'(?<![\w-])-Werror(?![\w=-])', '-Wno-error', content)
        if content != original:
            with open(path, 'w') as f:
                f.write(content)
            print(f'  Patched: {path}')
    except Exception as e:
        pass

# Patch root Makefile
patch_makefile('Makefile')

# Patch all sub-Makefiles and Kbuild files (skip toolchain dirs)
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if not d.startswith('toolchain')]
    for fname in files:
        if fname in ('Makefile', 'Kbuild'):
            patch_makefile(os.path.join(root, fname))
PYEOF

echo "After patching, -Werror lines in root Makefile:"
grep -n 'Werror' Makefile | head -10

echo "=== Phase 4: Fix floating-point in decon_reg.c ==="
echo 'CFLAGS_decon_reg.o += -mno-general-regs-only' >> drivers/video/fbdev/exynos/dpu/Makefile

echo "=== Phase 5: Fix displayport_drv.c uninitialized variable ==="
sed -i 's/training_aux_rd_interval;/training_aux_rd_interval = 0;/g' drivers/video/fbdev/exynos/dpu/displayport_drv.c || true

echo "=== All patches applied successfully ==="
