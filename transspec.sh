#!/bin/bash

# baidu_translate函数，它接受要翻译的文本并返回翻译结果
baidu_translate() {
        APPID="$appid"
        SECRET_KEY="$key"
        QUERY="$1"
        TARGET="zh"
        SALT=$(date +%N | md5sum | head -c 10)
        SIGN=$(echo -n "$APPID$QUERY$SALT$SECRET_KEY" | md5sum | awk '{print $1}')

        RESPONSE=$(curl -sG "http://api.fanyi.baidu.com/api/trans/vip/translate" --data-urlencode "q=$QUERY" -d "appid=$APPID" -d "salt=$SALT" -d "from=auto" -d "to=$TARGET" -d "sign=$SIGN")
        TRANSLATED_TEXT=$(echo $RESPONSE | jq -r '.trans_result[0].dst')
        echo "$TRANSLATED_TEXT"
}

# 处理 spec 文件
spec_file=$1
output_file="translated.spec"

translate_description=0
description_buffer=""
description_subtitle=""

if `grep -q "Summary (zh_CN.UTF-8): null" $1`;then
	echo "文件翻译出错，需重新编译"
	exit 1
fi

if `grep -q "Summary (zh_CN.UTF-8):" $1`;then 
	echo "文件已经翻译过了"
	exit 0
fi

while IFS= read -r line
do
  if [[ $line =~ ^Summary: ]]; then
    # 提取 Summary 文本
    summary_text="$(echo $line |sed -e 's/Summary://g'|sed 's/^ *//;s/ *$//')"
    # 翻译 Summary 文本
    translated_summary=$(baidu_translate "$summary_text")
    echo "$line" >> "$output_file"
    echo "Summary (zh_CN.UTF-8): $translated_summary" >> "$output_file"
  elif [[ $line =~ ^%description ]]; then
    # 处理上一个 %description 段落缓冲区中的翻译
    if [[ $translate_description -eq 1 && -n "$description_buffer" ]]; then
      translated_description=$(baidu_translate "$description_buffer")
      echo "%description -l zh_CN.UTF-8${description_subtitle}" >> "$output_file"
      echo "$translated_description" >> "$output_file"
    fi
    # 输出 %description 标记并准备新一轮翻译
    translate_description=1
    description_buffer=""
    description_subtitle="${line#%description}"
    echo "$line" >> "$output_file"
  elif [[ $line =~ ^% ]]; then
    # 遇到下一个 % 标记，处理当前 %description 的翻译
    if [[ $translate_description -eq 1 && -n "$description_buffer" ]]; then
      translated_description=$(baidu_translate "$description_buffer")
      echo "%description -l zh_CN.UTF-8${description_subtitle}" >> "$output_file"
      echo "$translated_description"$'\n' >> "$output_file"
    fi
    translate_description=0
    echo "$line" >> "$output_file"
  elif [[ $translate_description -eq 1 ]]; then
    # 累积描述内容到缓冲区，但不立即翻译
    description_buffer+="$line"$''
    echo "$line" >> "$output_file"
  else
    # 将其他非 %description %开头的部分直接输出
    echo "$line" >> "$output_file"
  fi
done < "$spec_file"

# 最后处理可能还有未翻译的内容
if [[ $translate_description -eq 1 && -n "$description_buffer" ]]; then
  translated_description=$(baidu_translate "$description_buffer")
  echo "%description -l zh_CN.UTF-8${description_subtitle}" >> "$output_file"
  echo "$translated_description"$'\n' >> "$output_file"
fi

mv $output_file $1

sed -i 's/｛/{/g' $1
sed -i 's/｝/}/g' $1

# 提示用户
echo "翻译完成，结果保存在 $1 中。"
