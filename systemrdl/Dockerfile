# build: docker build -t systemrdl-img .
# run container (windows powershell): docker run -it --rm -v ${PWD}:/workspace --name systemrdl-container systemrdl-img

FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    bash \
    procps \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN pip install --no-cache-dir \
    peakrdl \
    peakrdl-regblock \
    peakrdl-cheader \
    peakrdl-html

RUN echo 'alias generate="python3 generate_regs.py"' >> ~/.bashrc

CMD ["/bin/bash"]