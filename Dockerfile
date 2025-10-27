# 阶段 1: 选择一个完美的基础环境
# 我们选择 NVIDIA 官方的 CUDA 11.7.1 开发镜像，它与 torch==1.13.1 官方支持的 CUDA 版本完全匹配。
# "devel" 版本包含了完整的编译工具链，这对安装某些库至关重要。
FROM nvidia/cuda:11.7.1-devel-ubuntu22.04

# 阶段 2: 准备系统工具和环境变量
# 设置为非交互模式，避免 apt-get 在构建时卡住提问。
ENV DEBIAN_FRONTEND=noninteractive

# 更新系统并安装核心工具：
# - wget: 用于下载文件
# - git: 用于版本控制
# - build-essential: 极其重要！它包含了 C/C++ 编译器 (g++)，是安装 deepspeed, fair-esm 等库的必需品。
RUN apt-get update && apt-get install -y \
    wget \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 阶段 3: 安装 Miniconda 环境管理器
# Conda 是处理复杂科学计算包 (尤其是 RDKit) 的最佳选择。
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh
ENV PATH /opt/conda/bin:$PATH

# 阶段 4: 创建一个独立、干净的项目环境
# 我们为项目创建一个名为 "lucapcycle" 的 conda 环境，并指定 Python 版本以保证一致性。
RUN conda create -n lucapcycle python=3.9.13 -y

# 阶段 5: 【核心】采用“贵宾通道”策略安装所有 Python 依赖
# 这是整个 Dockerfile 最关键的一步。我们分三步走，确保最棘手的库被正确安装。
WORKDIR /app
COPY requirements.txt .

RUN conda run -n lucapcycle /bin/bash -c " \
    echo '===> 步骤 1/3: 使用 Conda 安装最难处理的 RDKit...' && \
    conda install -c conda-forge rdkit==2023.9.4 -y && \
    \
    echo '===> 步骤 2/3: 使用 Pip 特殊命令安装 GPU 版本的 PyTorch...' && \
    pip install torch==1.13.1+cu117 torchvision==0.14.1+cu117 torchaudio==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu117 && \
    \
    echo '===> 步骤 3/3: 使用 Pip 和国内镜像源安装所有剩余的依赖...' && \
    pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple \
    "

# 阶段 6: 将你的项目代码复制到镜像中
# 这一步会把你本地的所有代码文件（.py, .sh 等）都拷贝进去。
COPY . .

# 阶段 7: 定义容器启动后的默认行为
# 当容器启动时，它会自动进入 "lucapcycle" 这个 conda 环境，并打开一个 bash 终端。
# 这让你一进入容器，就处于一个完美的、随时可以运行 python 命令的状态。
CMD ["conda", "run", "-n", "lucapcycle", "bash"]
