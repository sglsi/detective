#!/bin/bash

declare -A FILES=(
  ["watson_head.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_88a21b01-ad6e-46ec-984e-3b8dfc5de577.jpeg?sign=1817044963-5426d76f82-0-1cac8682948866de4315a55d8fd0ce9fc418bfc07b8b47677e1978df4a60c365"
  ["watson_torso.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_f7d446eb-0be1-4cd8-bf5e-619fb6a53a33.jpeg?sign=1817044962-beef98f933-0-2f960e603fbfb1c955f0e1694ee486a39a84555612f5a201b70bcdbc1a06d1f7"
  ["watson_upperarm_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_def72f13-12ea-4469-a1db-704730f5d77d.jpeg?sign=1817044962-fec2fe413b-0-3da3cd0356e16a9bee6c4ef296143e700f7b76e05662f7287e178139d093e751"
  ["watson_upperarm_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_10ffb7aa-7848-409c-bb4e-33969166cb73.jpeg?sign=1817044984-491ed6036e-0-3602737667123eb5eba7baa2a0c9fe852987f2706aaedc73fcbf3163f6bbbd38"
  ["watson_forearm_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_1a8996f1-0ba0-4fb6-80c0-1a50870b33b3.jpeg?sign=1817044986-99e0f087b5-0-c1e3cf126a2aeaaaa1db9d100fbb8ed620066eeacf528a8f4ce9c2ca163b197f"
  ["watson_forearm_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_4938b747-7fa4-4551-9bef-eee920c37281.jpeg?sign=1817044985-78eaad3cc7-0-df414d02b488119a599b755836e1c56f6d06617f06ed2bfd31bf2f649db15b62"
  ["watson_thigh_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_ec1e5b8d-83a5-4970-8a02-a892dd73ea40.jpeg?sign=1817045016-5fb4855aec-0-d6365202b1ccdcde620f12bb265dba0c8aedb577c3a16d6321ba94eb224a4e7f"
  ["watson_thigh_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_a0fd4cf8-eefc-4329-ad8f-c9a6c1dd0764.jpeg?sign=1817045013-6622984d77-0-88c4e3d986d78e22c1fb975fa34cdc4f6f605d1a7ab02e104e1ae1f727d8864c"
  ["watson_shin_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_425fa1b5-007e-4f8a-882d-4f8d9c2d42c6.jpeg?sign=1817045015-59e9c1be78-0-4c34827ce95baee9d50382bb33335cf0534b4ef0dca095d83bd50624f2f053e4"
  ["watson_shin_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_059e683b-2960-4f9d-8335-1c167970338b.jpeg?sign=1817045038-e61fda73df-0-7398beb511039e58d7255c84982e37c182e0975f0782a96c2d9db61ef28de3e0"
  ["watson_hat.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_e4b75fe3-a67e-4c11-bb32-a97f19b4f60d.jpeg?sign=1817045036-d982fc7629-0-357ac393aa92d3089dfbca2781288768458ddd8d6870a769f0eb5a492383c441"
)

echo "开始下载..."
for file in "${!FILES[@]}"; do
  echo "下载：$file"
  curl -L -o "$file" "${FILES[$file]}" 2>/dev/null
done

echo "下载完成！"
ls -lh *.jpg
