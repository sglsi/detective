#!/bin/bash

declare -A FILES=(
  ["watson_head.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_579ab660-d18c-40ad-8de7-962114bc972e.jpeg?sign=1816944704-b849c911b5-0-2160f769735b71d05297c2765f039022f6e49f62ed20244963aa44e4574e7826"
  ["watson_torso.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_2875f71c-ead3-4d17-94c6-fb2c8b8cc94e.jpeg?sign=1816944703-cf78c4fb15-0-96c86de106a364b0618dcee5a0b38b88b4d201e9f6d514a05569a54e34ec4f9d"
  ["watson_upperarm_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_92c79af8-82c7-4666-b0a7-5ecc719fea5a.jpeg?sign=1816944703-77c7b0f84c-0-dcc7d91fe09ca63e7691977c136b32d45deac048e254c6b8ba83640f2f476bb2"
  ["watson_upperarm_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_c7ec2c64-1a12-4ede-b795-720cb09dd8f8.jpeg?sign=1816944723-6a2adbd52a-0-d5dbcb44c3f5bc953ea09525eb51f0f562779de53dc3e2672c2c3cd70a03bdca"
  ["watson_forearm_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_fbe7e3f3-228f-432a-8112-9586dd1e2e3f.jpeg?sign=1816944723-53dabe4856-0-06841d5f07dddc6c8cf7015c947cfcdd2a3ede59ee36552f515bea7b642c51ef"
  ["watson_forearm_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_74ac22e7-6690-4c0c-a7d1-a9ceca8414c4.jpeg?sign=1816944724-e12012bb0f-0-4dc0ed565b7df987248d968d1c5e0071e725410e3c3bff45135fa3f7ba80ff52"
  ["watson_thigh_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_2d2c5958-5693-4a07-add4-805ac99b6ee6.jpeg?sign=1816944743-1d196fd72f-0-bec6d41c092edf27ab44dd140e64b5b43908faa17e4b7af555845bd1dfc8432c"
  ["watson_thigh_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_685c9a2b-1444-4998-8cc0-c0f87ccd1fd2.jpeg?sign=1816944742-1d25441a9c-0-12e001e53c34673ade28d139607f31948ded018f75fcb196ebb15a3d6c6968e6"
  ["watson_shin_L.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_e1fc040a-3b6e-4892-9e62-de577ddfaffe.jpeg?sign=1816944742-a21e8336bb-0-33ccc4bbb6190f97357212ed8fb9e9a0e502748abde0211657b940262f98338f"
  ["watson_shin_R.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_4d378673-3ed1-4f40-b956-7d5f90e76286.jpeg?sign=1816944764-4cfda4261a-0-6650c8de54580b207585002edfa4a149b97d49c83210ea13499d3108cfa78395"
  ["watson_hat.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_c192cc86-1901-415e-9923-b52bd5414322.jpeg?sign=1816944762-ade17659f6-0-c7e74c66663b1474e686a56eb46642c73108d7d779625380f1f4fd6a8ccff060"
)

echo "开始下载..."
for file in "${!FILES[@]}"; do
  echo "下载：$file"
  curl -L -o "$file" "${FILES[$file]}" 2>/dev/null
done

echo "下载完成！"
ls -lh *.jpg
