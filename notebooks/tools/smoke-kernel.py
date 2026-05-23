"""Smoke test: start the .NET PowerShell kernel headlessly and run one trivial
cell to prove the kernel + jupyter_client toolchain works on this box.

This is NOT a full nbconvert --execute pass against the real notebooks — those
contain `vagrant`, `kubeadm`, and `ssh` calls that require live infrastructure.
This smoke just proves the kernel can boot and respond.

Usage:
    uv run python tools/smoke-kernel.py
"""
from __future__ import annotations

import sys
from jupyter_client.manager import KernelManager

KERNEL_NAME = ".net-powershell"
# Use Write-Host so output flows through stdout regardless of how the kernel
# packages PowerShell pipeline objects. Avoids ambiguity around result vs.
# display_data vs. stream messages.
TEST_CODE = 'Write-Host "PSVersion=$($PSVersionTable.PSVersion.Major)"'


def main() -> int:
    km = KernelManager(kernel_name=KERNEL_NAME)
    print(f"Starting kernel '{KERNEL_NAME}'...")
    km.start_kernel()
    try:
        kc = km.client()
        kc.start_channels()
        kc.wait_for_ready(timeout=60)
        print("Kernel ready. Executing test cell...")
        msg_id = kc.execute(TEST_CODE)
        # Drain iopub for output. We accept stream / execute_result / display_data
        # since different kernels package output differently.
        output_text: list[str] = []
        seen_msgs: list[str] = []
        while True:
            try:
                msg = kc.get_iopub_msg(timeout=30)
            except Exception:
                break
            ct = msg["header"]["msg_type"]
            seen_msgs.append(ct)
            if ct == "stream":
                output_text.append(msg["content"]["text"])
            elif ct in ("execute_result", "display_data"):
                output_text.append(str(msg["content"]["data"].get("text/plain", "")))
            elif ct == "error":
                print("KERNEL ERROR:", msg["content"]["evalue"])
                return 2
            elif ct == "status" and msg["content"]["execution_state"] == "idle":
                if msg["parent_header"].get("msg_id") == msg_id:
                    break
        print(f"  iopub messages seen: {seen_msgs}")
        result = "".join(output_text).strip()
        print(f"Cell output: {result!r}")
        if not result:
            print("FAIL: kernel produced no output.")
            return 3
        print("PASS: kernel responsive.")
        return 0
    finally:
        kc.stop_channels()
        km.shutdown_kernel(now=True)


if __name__ == "__main__":
    raise SystemExit(main())
