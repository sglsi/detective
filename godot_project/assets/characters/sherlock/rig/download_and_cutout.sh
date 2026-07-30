#!/bin/bash

# 下载并抠图脚本
declare -A FILES=(
  ["sherlock_master.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_57222ab5-6278-4c69-9c67-7a7554a648fe.jpeg?sign=1816917022-8691be3cee-0-2c45176fa5483b2b94dcdf59416f3abf501f200b03edac7676ced5060a176e4a"
  ["sherlock_hat_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_8b542cc3-8752-4e84-b2d4-28298b0857ea.jpeg?sign=1816917022-759f202ead-0-5963a42369383697bf0969079870d19012f685893785a5dd88c494f8c9ed0af4"
  ["sherlock_head_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_bbf94948-fd2d-4848-af34-21f02dc32f17.jpeg?sign=1816917021-1ee8ea8ba3-0-b975dbdd08377daeabeef41bc64963a3eabb3eb09f6bc72e0c71b3a42a8c4e74"
  ["sherlock_torso_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_29b50a8b-902f-4e65-9a53-612ce28bee27.jpeg?sign=1816917045-21eb491b5d-0-1cd5cdabf080e8486931622c4eb864d749dea30ce239efc917bbb2f590b821ee"
  ["sherlock_upperarm_L_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_065be235-6e39-40dd-97be-4ac97e84e651.jpeg?sign=1816917046-4e0ce38210-0-7e6cc243b087fe61299843e60cd555a4406b6293753e3a2467da14bd443def24"
  ["sherlock_upperarm_R_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_582abaa8-9721-4ff1-b312-4941b3de8ea4.jpeg?sign=1816917045-218d9ee4ca-0-ffe4d14843e5ad06a87bca6af8f0ecc711a37d816ce61623b52f698829d014a6"
  ["sherlock_forearm_L_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_3cc2d7ef-65ff-446c-b380-eda94bf132fb.jpeg?sign=1816917068-fef0bb9b8c-0-100c74070129f7870176e581dcb354b651f26da50a77261b3ff837c5c44ef732"
  ["sherlock_forearm_R_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_8d38e118-cb95-42f9-957e-72f324d2c410.jpeg?sign=1816917072-94be38406b-0-21bbb97149bcd40be57cdbad255df7bfea8d6ab190967cbf93ceb81b7c7c4722"
  ["sherlock_thigh_L_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_583e94a2-685e-4da7-954c-21c4c57fb848.jpeg?sign=1816917069-fbe42ef259-0-864066b25817adc4427b5b2ed54de1ef5086d2878c13b331e28fcb598c7b85e6"
  ["sherlock_thigh_R_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_a823f7b4-f1b1-449c-8e88-e50741a870ec.jpeg?sign=1816917095-ca6e0dda30-0-cbe7f95146f01d00b3566d21fe112e74be6f041e66f75a958eaa2ca4d89decd7"
  ["sherlock_shin_L_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_81160bf8-cbcd-4673-a211-e6e85a27507f.jpeg?sign=1816917094-53f6c9e7c0-0-69236189d399227adca60aabb2f44b10c0234e75d0165de5f3fc099d1edbe500"
  ["sherlock_shin_R_greenscreen.jpg"]="https://coze-coding-project.tos.coze.site/coze_storage_7664902873347784744/image/generate_image_f3f116f1-c728-4d23-826c-d7fe46db103a.jpeg?sign=1816917095-a640e13c9b-0-b1d9df76b01ad048c1fe2cd2fdde6ebeb07018c2a55f41d7bda5376bb0f12e0f"
)

echo "开始下载..."
for file in "${!FILES[@]}"; do
  echo "下载：$file"
  curl -L -o "$file" "${FILES[$file]}" 2>/dev/null
done

echo "下载完成！"
ls -lh *.jpg
