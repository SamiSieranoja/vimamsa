#!/usr/bin/env bash
# Run ONLY the uinput E2E tests in the ub_blank VM, semi-interactively.
#
# These tests type real key events through a virtual keyboard (uinput), which
# land in whatever window currently has focus. Wayland won't let a window that
# was launched non-interactively (via guestcontrol) steal focus, so this needs
# exactly ONE bit of interaction: when prompted, click the vimamsa window on the
# VM's desktop once. Every test in the run then finds it already focused.
#
# The heavy lifting (sync, provision, uinput/Wayland setup) is shared with
# run_tests_vm.sh; this wrapper just restricts the run to the E2E file and turns
# on the interactive focus wait.
#
# Usage:
#   VM_PASS='<guest password>' ./run_e2e_vm.sh
#   VM_PASS='<guest password>' ./run_e2e_vm.sh e2e_cmdline   # explicit filter
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export VMA_E2E_INTERACTIVE=1

echo ">> E2E VM run: the vimamsa window will open on the VM desktop."
echo ">> When you see the '[E2E] Click the vimamsa window…' prompt, click that"
echo ">> window once to focus it; the tests then type into it via uinput."

# Default to the cmdline E2E file; forward any explicit filter args instead.
exec "$HERE/run_tests_vm.sh" "${@:-e2e_cmdline}"
