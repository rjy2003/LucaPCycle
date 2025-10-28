# 1. 基础镜像选择 (保持不变，这个选择非常适合)
# nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 包含了完整的CUDA编译工具链，对DeepSpeed和ESMFold至关重要
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# 设置工作目录
WORKDIR /app

# 设置环境变量，避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 2. 安装基础依赖 (保持不变)
RUN apt-get update && apt-get install -y \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# 3. 安装 Anaconda (保持不变)
RUN wget https://repo.anaconda.com/archive/Anaconda3-2022.05-Linux-x86_64.sh -O anaconda.sh && \
    sh anaconda.sh -b -p /opt/conda && \
    rm anaconda.sh
ENV PATH /opt/conda/bin:$PATH

# 4. 创建Conda环境并安装核心依赖 (*** 这是关键的修改 ***)
# 我们在创建环境的同时，使用conda安装最复杂的包：rdkit, pytorch, torchvision, torchaudio
# -c pytorch -c conda-forge 指定了从哪里寻找这些包
RUN conda create -n lucapcycle python=3.9.13 -y && \
    conda install -n lucapcycle -c pytorch -c conda-forge -c rdkit \
    'pytorch=1.13.1' \
    'torchvision=0.14.1' \
    'torchaudio=0.13.1' \
    'pytorch-cuda=11.7' \
    'rdkit=2023.9.4' \
    -y && \
    conda clean -afy
# 注意: PyTorch 1.13.1 官方是为 CUDA 11.7 构建的，它在 CUDA 11.8 环境下可以向前兼容运行。这里明确指定版本以保证稳定性。

# 5. 安装剩余的Python依赖 (*** 这是另一个关键修改 ***)
# 先将 requirements.txt 复制到镜像中
COPY requirements.txt .

# 使用pip安装requirements.txt中剩余的包
# 我们先过滤掉已经用conda安装的包，避免冲突
# 然后再执行pip install
RUN echo "conda activate lucapcycle" > ~/.bashrc && \
    conda run -n lucapcycle /bin/bash -c " \
    grep -v -E 'torch|rdkit' requirements.txt > requirements_pip.txt && \
    pip install -r requirements_pip.txt -i https://pypi.tuna.tsinghua.edu.cn/simple \
    "

# 6. 将所有代码复制到镜像中
COPY . .

# 7. 设置容器启动后的默认命令
CMD ["/bin/bash", "-c", "echo 'Container is running. Activate environment with: conda activate lucapcycle' && /bin/bash"]
