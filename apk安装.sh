#!/bin/bash
# 脚本开始，使用bash解释器执行

# 检测系统是否为Ubuntu
system_check() {
    # 检查是否存在系统信息文件
    if [ -f /etc/os-release ]; then
        # 提取系统名称
        os_name=$(grep -i "NAME" /etc/os-release | awk -F '"' '{print $2}')
        # 检查是否包含"Ubuntu"关键字
        if [[ "$os_name" != *"Ubuntu"* ]]; then
            echo "哎呀，这不是 Ubuntu 系统，小爪子抓不住啦~ 退出啦~ (๑・_・๑)"
            exit 1  # 退出脚本
        fi
    else
        # 如果找不到系统信息文件，提示并退出
        echo "找不到系统信息，可能不是 Ubuntu 系统，小爪子抓不住啦~ 退出啦~ (๑・_・๑)"
        exit 1
    fi
    # 系统检测成功，输出提示信息
    echo "检测到这是 Ubuntu 系统，可以继续啦~ 喵呜~ (๑・̀ㅂ・́)و✧"
}

# 检查必要工具是否安装
tool_check() {
    # 检查aapt工具是否存在
    if ! command -v aapt &> /dev/null; then
        echo "aapt 工具不存在，正在安装中... (๑・.・๑)"
        sudo apt-get install -y aapt  # 安装aapt
        if [ $? -ne 0 ]; then  # 检查安装是否成功
            echo "aapt 工具安装失败，请检查网络连接或权限~ (๑・_・๑)"
            exit 1
        fi
    else
        echo "哇哦，你已经安装好了 aapt 工具，真是个小天才~ (๑・̀ㅂ・́)و✧"
    fi

    # 检查adb工具是否存在
    if ! command -v adb &> /dev/null; then
        echo "adb 工具不存在，正在安装中... (๑・.・๑)"
        sudo apt-get install -y adb  # 安装adb
        if [ $? -ne 0 ]; then
            echo "adb 工具安装失败，请检查网络连接或权限~ (๑・_・๑)"
            exit 1
        fi
    else
        echo "哇哦，你已经安装好了 adb 工具，真是个小天才~ (๑・̀ㅂ・́)و✧"
    fi

    # 检查wget工具是否存在
    if ! command -v wget &> /dev/null; then
        echo "wget 工具不存在，正在安装中... (๑・.・๑)"
        sudo apt-get install -y wget  # 安装wget
        if [ $? -ne 0 ]; then
            echo "wget 工具安装失败，请检查网络连接或权限~ (๑・_・๑)"
            exit 1
        fi
    fi
}

# 初始化必要的文件和目录
file_init() {
    adb_file="$HOME/.adb.txt"  # 定义adb历史记录文件路径
    https_file="$HOME/.https.txt"  # 定义下载链接历史记录文件路径
    apk_folder="$HOME/.apk123"  # 定义APK存储目录

    # 检查并创建.adb.txt文件
    if [ ! -f "$adb_file" ]; then
        touch "$adb_file"  # 创建文件
        sudo chattr +i "$adb_file"  # 设置文件为不可变属性
        echo ".adb 文件已创建并设置为不可变属性，以后就不用检查工具啦~ (๑・̀ㅂ・́)و✧"
    else
        echo "检测到 .adb 文件，工具检查已跳过喵~ (๑・.・๑)"
    fi

    # 检查并创建.https.txt文件
    if [ ! -f "$https_file" ]; then
        touch "$https_file"  # 创建文件
        sudo chattr +i "$https_file"  # 设置文件为不可变属性
        echo ".https 文件已创建并设置为不可变属性，下载链接将保存在这里哦~ (๑・̀ㅂ・́)و✧"
    fi

    # 检查并创建APK存储目录
    if [ ! -d "$apk_folder" ]; then
        mkdir "$apk_folder"  # 创建目录
    fi
}

# 生成随机编号（用于文件命名）
get_random_id() {
    # 使用时间戳和SHA256生成随机字符串，截取前6位
    echo $(date +%s%N | sha256sum | head -c 6)
}

# 显示历史路径列表
show_history() {
    echo "历史路径列表：(๑・.・๑)"
    # 遍历历史路径数组并显示
    for i in "${!history_paths[@]}"; do
        echo "$i: ${history_paths[$i]}"
    done
}

# 删除历史路径
delete_history() {
    show_history  # 显示历史路径
    read -p "请输入要删除的路径编号（或输入 'q' 退出）: " choice  # 提示用户输入

    if [[ "$choice" == "q" ]]; then
        return  # 退出函数
    fi

    # 检查输入是否为有效编号
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ $choice -lt ${#history_paths[@]} ]; then
        unset history_paths[$choice]  # 删除指定路径
        history_paths=("${history_paths[@]}")  # 重新索引数组
        echo "路径已删除，新的历史路径列表：(๑・.・๑)"
        show_history  # 显示更新后的列表

        # 更新.adb.txt文件
        sudo chattr -i "$adb_file"  # 解除不可变属性
        echo "" > "$adb_file"  # 清空文件
        for path in "${history_paths[@]}"; do
            echo "$path" >> "$adb_file"  # 重新写入历史路径
        done
        sudo chattr +i "$adb_file"  # 重新设置不可变属性
    else
        echo "无效的编号，请重试~ (๑・_・๑)"  # 提示无效输入
        delete_history  # 递归调用，重新尝试
    fi
}

# 选择安装方式
select_install_method() {
    echo "请选择安装方式：(๑・.・๑)"
    echo "1. 安装本地软件"
    echo "2. 从网络下载安装"
    echo "3. 从txt文件批量下载安装"
    read -p "请输入选择（1/2/3）: " choice  # 提示用户输入

    case $choice in
        1)
            selected_method="local"  # 设置安装方式为本地
            select_folder  # 调用路径选择函数
            ;;
        2)
            selected_method="network"  # 设置安装方式为网络
            network_install  # 调用网络安装函数
            ;;
        3)
            selected_method="batch"  # 设置安装方式为批量
            batch_network_install  # 调用批量安装函数
            ;;
        *)
            echo "无效选择，请重试~ (๑・_・๑)"  # 提示无效输入
            select_install_method  # 递归调用，重新尝试
            return
            ;;
    esac
}

# 选择APK文件夹路径
select_folder() {
    echo "请选择 APK 文件夹路径：(๑・.・๑)"
    echo "1. 使用默认路径：$default_apk_folder"
    echo "2. 自定义路径"
    echo "3. 从历史路径选择"
    read -p "请输入选择（1/2/3）: " choice  # 提示用户输入

    case $choice in
        1)
            apk_folder="$default_apk_folder"  # 使用默认路径
            ;;
        2)
            read -p "请输入自定义路径: " custom_path  # 提示输入自定义路径
            custom_path=$(echo "$custom_path" | sed "s/^'//;s/'$//")  # 去除引号
            if [ ! -d "$custom_path" ]; then
                echo "路径不存在，请检查后重试~ (๑・_・๑)"  # 检查路径是否存在
                select_folder  # 重新选择
                return
            fi
            apk_folder="$custom_path"  # 设置自定义路径
            default_apk_folder="$custom_path"  # 更新默认路径
            random_id=$(get_random_id)  # 生成随机ID
            history_paths+=("$random_id:$apk_folder")  # 添加到历史路径
            echo "路径已添加到历史记录，编号：$random_id (๑・̀ㅂ・́)و✧"
            ;;
        3)
            show_history  # 显示历史路径
            read -p "请输入历史路径编号（或输入 'q' 退出）: " hist_choice  # 提示输入编号
            if [[ "$hist_choice" == "q" ]]; then
                select_folder  # 退出并重新选择
                return
            fi
            if [[ "$hist_choice" =~ ^[0-9]+$ ]] && [ $hist_choice -lt ${#history_paths[@]} ]; then
                apk_folder="${history_paths[$hist_choice]#*:}"  # 提取路径
                echo "已选择路径：$apk_folder (๑・.・๑)"
            else
                echo "无效的编号，请重试~ (๑・_・๑)"  # 提示无效输入
                select_folder  # 重新选择
                return
            fi
            ;;
        *)
            echo "无效选择，请重试~ (๑・_・๑)"  # 提示无效输入
            select_folder  # 重新选择
            return
            ;;
    esac

    # 检查路径是否存在APK文件
    if [ ! -d "$apk_folder" ] || [ $(find "$apk_folder" -maxdepth 1 -name "*.apk" | wc -l) -eq 0 ]; then
        echo "文件夹内没有 APK 文件，需要重新选择路径~ (๑・_・๑)"
        select_folder  # 重新选择
        return
    fi
}

# 网络安装（单个APK）
network_install() {
    apk_folder="$HOME/.apk123"  # 设置APK存储目录
    https_file="$HOME/.https.txt"  # 设置下载链接历史记录文件

    # 清空存储目录
    rm -f "$apk_folder"/*

    # 显示历史下载记录
    declare -A history_downloads  # 定义关联数组
    if [ -f "$https_file" ]; then
        echo "=== 历史下载记录 ==="
        idx=1
        while IFS='|' read -r url name; do
            history_downloads["$idx"]="$url|$name"  # 存储历史记录
            echo "$idx: $name (URL: $url)"  # 显示历史记录
            idx=$((idx+1))
        done < "$https_file"
    fi

    # 选择操作模式
    echo "请选择操作："
    echo "1. 输入新下载链接"
    echo "2. 使用历史记录"
    read -p "请输入选择（1/2）: " sub_choice  # 提示用户输入

    case $sub_choice in
        1)
            read -p "下载链接: " download_url  # 输入下载链接
            read -p "自定义名称（回车使用随机名）: " custom_name  # 输入自定义名称
            ;;
        2)
            read -p "请输入历史记录编号: " hist_choice  # 输入历史记录编号
            if [[ "$hist_choice" =~ ^[0-9]+$ ]] && [ -n "${history_downloads[$hist_choice]}" ]; then
                IFS='|' read -r download_url custom_name <<< "${history_downloads[$hist_choice]}"  # 提取URL和名称
                echo "已选择: $custom_name"
            else
                echo "无效编号，请重试~ (๑・_・๑)"  # 提示无效输入
                return
            fi
            ;;
        *)
            echo "无效选择，退出~"  # 提示无效输入
            return
            ;;
    esac

    # 生成随机名称（如果未输入）
    if [ -z "$custom_name" ]; then
        random_id=$(get_random_id)
        custom_name="download_$random_id"
        save_to_history=false  # 不保存到历史记录
    else
        save_to_history=true  # 保存到历史记录
    fi

    # 保存链接到历史记录
    if [ "$save_to_history" = true ]; then
        sudo chattr -i "$https_file"  # 解除不可变属性
        echo "${download_url}|${custom_name}" >> "$https_file"  # 写入历史记录
        sudo chattr +i "$https_file"  # 重新设置不可变属性
        echo "链接已保存到历史记录~ (๑・̀ㅂ・́)و✧"
    fi

    # 下载文件
    echo "正在下载到专用目录: $apk_folder"
    wget --content-disposition -P "$apk_folder" "$download_url" 2>&1 | tee download.log  # 下载文件并记录日志
    if [ $? -ne 0 ]; then
        echo "下载失败，可能是网络问题或链接无效，请检查后重试~ (๑・_・๑)"  # 提示下载失败
        return
    fi

    # 检测下载的文件是否为APK
    downloaded_file=$(find "$apk_folder" -maxdepth 1 -type f | head -1)  # 获取下载文件路径
    if [ -z "$downloaded_file" ]; then
        echo "致命错误：未找到下载文件~ (๑・_・๑)"  # 提示未找到文件
        return
    fi

    # 使用aapt验证文件类型
    package_name=$(aapt dump badging "$downloaded_file" 2>/dev/null | grep -E 'package: name=' | awk -F "'" '{print $2}')  # 提取包名
    if [ -z "$package_name" ]; then
        echo "文件 '$downloaded_file' 不是有效的APK，已跳过~ (๑・_・๑)"  # 提示无效APK
        rm -f "$downloaded_file"  # 删除无效文件
        return
    fi

    # 检查是否已安装
    if adb shell pm list packages | grep -q "$package_name"; then
        echo "$package_name 已经安装在设备上了喵~ (๑・.・๑)"  # 提示已安装
    else
        echo "正在努力安装 $package_name 喵~ (๑・̀ㅂ・́)و✧"  # 提示安装中
        adb install "$downloaded_file"  # 安装APK
        if [ $? -eq 0 ]; then
            echo "$package_name 安装成功啦~ (๑・̀ㅂ・́)و✧"  # 提示安装成功
        else
            echo "$package_name 安装失败了，检查设备连接~ (๑・_・๑)"  # 提示安装失败
        fi
    fi

    # 清理文件
    rm -f "$downloaded_file" download.log  # 删除下载文件和日志
    echo "下载的文件已删除，保持整洁哦~ (๑・.・๑)"
}

# 批量网络安装
batch_network_install() {
    apk_folder="$HOME/.apk123"  # 设置APK存储目录
    https_file="$HOME/.https.txt"  # 设置下载链接历史记录文件
    echo "请将包含下载链接的txt文件拖入此处：(๑・.・๑)"
    read -p "txt文件路径: " txt_file  # 输入txt文件路径
    txt_file=$(echo "$txt_file" | sed "s/^'//;s/'$//")  # 去除引号

    if [ ! -f "$txt_file" ]; then
        echo "文件不存在，请检查后重试~ (๑・_・๑)"  # 检查文件是否存在
        return
    fi

    # 清空存储目录
    rm -f "$apk_folder"/*

    # 解析txt文件
    i=1
    declare -a download_urls  # 定义数组存储URL
    declare -a download_names  # 定义数组存储名称
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r' | xargs)  # 清理行内容
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
            download_urls[$i]="${BASH_REMATCH[1]}"  # 提取URL
            download_names[$i]="${BASH_REMATCH[2]}"  # 提取名称
        else
            download_urls[$i]="$line"  # 只有URL的情况
            download_names[$i]="download_$(get_random_id)"  # 生成随机名称
        fi
        echo "$i: ${download_names[$i]} (URL: ${download_urls[$i]})"  # 显示解析结果
        i=$((i+1))
    done < "$txt_file"

    # 选择要下载的项目
    read -p "请输入要下载的项目编号（多个编号用空格分隔）: " -a choices  # 输入项目编号
    for choice in "${choices[@]}"; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -lt $i ]; then
            url="${download_urls[$choice]}"  # 获取URL
            original_name="${download_names[$choice]}"  # 获取原始名称
            read -p "请输入自定义名称（回车保留原名称）: " custom_name  # 输入自定义名称
            name="${custom_name:-$original_name}"  # 使用自定义名称或保留原始名称

            # 保存到历史记录
            if [ -n "$custom_name" ]; then
                sudo chattr -i "$https_file"  # 解除不可变属性
                echo "${url}|${name}" >> "$https_file"  # 写入历史记录
                sudo chattr +i "$https_file"  # 重新设置不可变属性
                echo "链接已保存到历史记录~ (๑・̀ㅂ・́)و✧"
            fi

            # 下载文件
            echo "开始下载 $name ..."
            wget --content-disposition -P "$apk_folder" "$url" 2>&1 | tee download.log  # 下载文件并记录日志
            if [ $? -ne 0 ]; then
                echo "下载失败，检查链接有效性~ (๑・_・๑)"  # 提示下载失败
                continue
            fi

            # 检测文件是否为APK
            downloaded_file=$(find "$apk_folder" -maxdepth 1 -type f | head -1)  # 获取下载文件路径
            package_name=$(aapt dump badging "$downloaded_file" 2>/dev/null | grep -E 'package: name=' | awk -F "'" '{print $2}')  # 提取包名
            if [ -z "$package_name" ]; then
                echo "文件 '$downloaded_file' 不是有效的APK，已跳过~ (๑・_・๑)"  # 提示无效APK
                rm -f "$downloaded_file"  # 删除无效文件
                continue
            fi

            # 检查是否已安装
            if adb shell pm list packages | grep -q "$package_name"; then
                echo "$package_name 已经安装在设备上了喵~ (๑・.・๑)"  # 提示已安装
            else
                echo "正在努力安装 $package_name 喵~ (๑・̀ㅂ・́)و✧"  # 提示安装中
                adb install "$downloaded_file"  # 安装APK
                if [ $? -eq 0 ]; then
                    echo "$package_name 安装成功啦~ (๑・̀ㅂ・́)و✧"  # 提示安装成功
                else
                    echo "$package_name 安装失败了，检查设备连接~ (๑・_・๑)"  # 提示安装失败
                fi
            fi

            # 清理文件
            rm -f "$downloaded_file" download.log  # 删除下载文件和日志
        else
            echo "无效编号跳过~ (๑・_・๑)"  # 提示无效编号
        fi
    done
}

# 主程序入口
system_check  # 检测系统
tool_check  # 检查工具
file_init  # 初始化文件

# 读取历史路径
history_paths=()  # 定义历史路径数组
adb_file="$HOME/.adb.txt"  # 定义adb历史记录文件路径
if [ -f "$adb_file" ]; then
    while IFS= read -r line; do
        history_paths+=("$line")  # 读取历史路径
    done < "$adb_file"
fi

# 设置默认路径
default_apk_folder="/home/Ubuntu/apk"  # 默认APK路径
if [ ${#history_paths[@]} -gt 0 ]; then
    default_apk_folder="${history_paths[0]#*:}"  # 使用历史路径作为默认路径
    echo "检测到自定义路径，已设置为默认路径：$default_apk_folder (๑・.・๑)"
fi

select_install_method  # 选择安装方式

# 动态删除提示（增强版）
case "$selected_method" in
    "network"|"batch")
        read -p "是否需要删除历史下载记录？(y/n): " delete_choice  # 提示是否删除历史记录
        if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
            echo "=== 当前历史下载记录 ==="
            nl -w2 -s ": " "$https_file"  # 显示历史记录
            read -p "输入要删除的编号（或输入 all 删除全部）: " target  # 提示输入编号
            sudo chattr -i "$https_file"  # 解除不可变属性
            if [[ "$target" == "all" ]]; then
                echo "" > "$https_file"  # 清空文件
                echo "已清空所有历史下载记录~ (๑・.・๑)"
            else
                sed -i "${target}d" "$https_file"  # 删除指定行
                echo "已删除编号 $target 的记录~ (๑・.・๑)"
            fi
            sudo chattr +i "$https_file"  # 重新设置不可变属性
            echo "操作完成~ (๑・̀ㅂ・́)و✧"
        fi
        ;;
    "local")
        read -p "是否需要删除历史路径？(y/n): " delete_choice  # 提示是否删除历史路径
        if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
            delete_history  # 调用删除历史路径函数
        fi
        ;;
esac

# 安装本地APK
installed_count=0  # 定义安装计数器
for apk in "$apk_folder"/*.apk; do
    if [ -f "$apk" ]; then
        package_name=$(aapt dump badging "$apk" | grep -E 'package: name=' | awk -F "'" '{print $2}')  # 提取包名
        if [ -z "$package_name" ]; then
            echo "这个文件好像不是 APK 哦，跳过啦~ (๑・_・๑)"  # 提示无效APK
            continue
        fi
        if adb shell pm list packages | grep -q "$package_name"; then
            echo "$package_name 已经安装在设备上了喵~ (๑・.・๑)"  # 提示已安装
        else
            echo "正在努力安装 $package_name 喵~ (๑・̀ㅂ・́)و✧"  # 提示安装中
            adb install "$apk"  # 安装APK
            if [ $? -eq 0 ]; then
                echo "$package_name 安装成功啦~ (๑・̀ㅂ・́)و✧"  # 提示安装成功
                ((installed_count++))  # 增加计数器
            else
                echo "$package_name 安装失败了，检查一下设备连接吧~ (๑・_・๑)"  # 提示安装失败
            fi
        fi
    fi
done

# 安装完成提示
if [ $installed_count -gt 0 ]; then
    echo "安装完成啦~ 共安装了 $installed_count 个软件，好开心喵~ (๑・̀ㅂ・́)و✧"  # 提示安装数量
else
    echo "所有软件都已安装，没有新的软件需要安装哦~ (๑・.・๑)"  # 提示无新安装
fi
