#!/usr/bin/env python3
"""多模态图片描述工具：用平台 LLM 视觉模型描述/审查素材图。

用法：
    python3 tools/mm_describe.py <图片路径> [更多图片...] [--question "要问的问题"]

示例：
    python3 tools/mm_describe.py assets/backgrounds/x.jpg --question "画面里有没有水印？"

模型名带日期后缀（可用列表见 llm skill），默认 qwen-3-5-plus-260215。
"""
import argparse
import base64
import mimetypes
import os
import sys

from coze_coding_dev_sdk.llm import LLMClient
from langchain_core.messages import HumanMessage

DEFAULT_QUESTION = (
    "请详细描述这张图：场景类型、时间、光源、主要家具与构图、整体色调。"
    "如果画面里出现 AI 生成水印、logo 或文字，请明确指出它的位置。"
)
DEFAULT_MODEL = "qwen-3-5-plus-260215"


def _data_uri(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("--question", default=DEFAULT_QUESTION)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    args = ap.parse_args()

    client = LLMClient()
    for path in args.images:
        if not os.path.exists(path):
            print("SKIP (missing): %s" % path)
            continue
        print("=" * 20, path, "=" * 20)
        msg = HumanMessage(content=[
            {"type": "text", "text": args.question},
            {"type": "image_url", "image_url": {"url": _data_uri(path)}},
        ])
        resp = client.invoke(model=args.model, messages=[msg])
        print(getattr(resp, "content", str(resp)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
