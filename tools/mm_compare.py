#!/usr/bin/env python3
"""双图对比：判断两张背景是否为同一间房/同一视觉体系。

用法：
    python3 tools/mm_compare.py A.jpg B.jpg --question "..."
"""
import argparse
import base64
import mimetypes

from coze_coding_dev_sdk.llm import LLMClient
from langchain_core.messages import HumanMessage

DEFAULT_MODEL = "qwen-3-5-plus-260215"


def _data_uri(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("--question", required=True)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    args = ap.parse_args()

    content = [{"type": "text", "text": args.question}]
    for path in args.images:
        content.append({"type": "image_url", "image_url": {"url": _data_uri(path)}})

    client = LLMClient()
    msg = HumanMessage(content=content)
    resp = client.invoke(model=args.model, messages=[msg])
    print(getattr(resp, "content", str(resp)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
