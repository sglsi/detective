#!/usr/bin/env python3
"""生成场景八背景（221B 起居室·黎明前抓捕现场）。

以场景五夜晚图作为图生图参考，保持房间布局、家具、镜头与写实摄影质感完全一致，
只把时间推进到黎明前，并加入"抓捕现场"痕迹（撞碎的窗玻璃、翻倒的椅子）。

用法：
    python3 tools/gen_scene8_bg.py
"""
import os
import sys

import requests
from coze_coding_dev_sdk.s3 import S3SyncStorage
from coze_coding_dev_sdk import ImageGenerationClient

REF = "godot_project/assets/backgrounds/scene5_parlor_night.jpg"
OUT_RAW = "/tmp/scene8_parlor_dawn_raw.png"
OUT_FINAL = "godot_project/assets/backgrounds/scene8_parlor_dawn.jpg"

PROMPT = (
    "同一间维多利亚伦敦贝克街221B起居室，保持参考图完全一致的镜头角度、房间布局与家具位置："
    "左侧燃着余烬的壁炉、左后方与右后方书架、右侧拱形窗、右侧前景带台灯的书桌、"
    "壁炉右侧的地毯与扶手椅、中下部大面积花纹地毯。画面写实摄影质感，材质细节丰富，光影真实。"
    "唯一变化是时间推进到黎明前的凌晨：窗外雨势转小，街面湿冷泛出灰蓝色微光，"
    "远处灯火稀疏，天际线刚泛起一线将亮未亮的青灰；壁炉只剩暗红余烬，室内主要由书桌台灯与煤气灯的"
    "暖黄光照明，整体比参考图更暗、对比更强、空气里有雨夜的湿冷感。"
    "刚刚发生过一场扭打：右侧拱形窗的木框玻璃被撞碎，窗框上残留几块尖锐的玻璃碴，"
    "碎片散落在右侧窗下与地毯边缘；一把椅子被撞翻斜倒在画面右侧地毯上；"
    "壁炉前的小桌上一只玻璃杯倾倒。画面中不要出现任何人物、人体、剪影或面孔，"
    "不要出现文字、字母、logo、水印或边框。"
)


def upload_ref() -> str:
    storage = S3SyncStorage(
        endpoint_url=os.getenv("COZE_BUCKET_ENDPOINT_URL"),
        access_key="",
        secret_key="",
        bucket_name=os.getenv("COZE_BUCKET_NAME"),
        region="cn-beijing",
    )
    with open(REF, "rb") as fh:
        content = fh.read()
    key = storage.upload_file(
        file_content=content,
        file_name="scene5_parlor_night_ref.jpg",
        content_type="image/jpeg",
    )
    url = storage.generate_presigned_url(key=key, expire_time=3600)
    print("[upload] key=%s" % key)
    print("[upload] url=%s" % url)
    return url


def main() -> int:
    if not os.path.exists(REF):
        print("缺少参考图: %s" % REF)
        return 1
    ref_url = upload_ref()
    client = ImageGenerationClient()
    resp = client.generate(
        prompt=PROMPT,
        image=ref_url,
        size="4096x2262",
        watermark=False,
    )
    if not resp.success:
        print("生成失败: %s" % resp.error_messages)
        return 1
    url = resp.image_urls[0]
    print("[generate] url=%s" % url)
    data = requests.get(url, timeout=120).content
    with open(OUT_RAW, "wb") as fh:
        fh.write(data)
    print("[generate] saved %s (%d bytes)" % (OUT_RAW, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
