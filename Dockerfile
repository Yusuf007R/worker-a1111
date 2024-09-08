
# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

# NOTE: CivitAI usually requires an API token, so you need to add it in the header
#       of the wget command if you're using a model from CivitAI.
RUN apk add --no-cache wget && \
    wget -q -O /model.safetensors \
    --header="Cookie: __Host-next-auth.csrf-token=fdde59db857d460cacd3ff269d64acac34f02f737700ca0caf734a207ce8e403%7Cfb36363320a6c67063211fbc65f9de5345aa0773fab1eae06f16dd27d641d90a; ref_landing_page=%2F; __stripe_mid=e17fb2b0-95d0-49e0-8a2e-4ba4901c1d77d5238c; __Secure-next-auth.callback-url=https%3A%2F%2Fcivitai.com%2Fmodels%2F18927%2Fsweet-mix; __stripe_sid=a2ba8602-5511-4c8a-89fe-496f3581e0d1078d64; __Secure-civitai-token=eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..aUhALPVVlKVg-Sb0.EN9p7xeHq2zRG4YNVytsXdZQG0-pWCy3CCMMrRHfrupTD5HbFAkyyYJdP8oMlxr6yc-2DQR8niPX4Ajyc-n-atMLnTTyHe8wlmT3o5xkS4doEMJEM97EfIDv7sFKnotNF5FooPYhvPAekDZm2nt4MQvZyYV4zZjNSpaRrUBykCIw_huaJ4b9a3vszG-fATB_uFf7F0kch4I50xhNSIf7aEWVBCZ9zcAMz0-R-8RVBfqeXh5UqvO27ySS1nosWm6fOrf3Dqwwow7z5aT3iGd23SYe4d4ILWvqNnTzsREWaSE6fZTmUu2aR6YbrzZD1oGv2L1ikqJlDSmxLBMgorLRnSuWECkaPuTqZ8iK0KjFrFE1C7UugFSZPy0yB1HJOYqeDcG1wXgrmdOpKM1V6RCP2sfkwv7reyJPA0p4AO-pY4sU37fUUKa6_XiecG6JNbLB-MbZQSHyIwN4IbI5uKpBstzPazg2keCEDPMfxI3VrNDBPlX9WPMzKbFEV47qsA-EYDt7XJGGiSJOQ8tJozgKSRQXwlGqkrFxVVth5tWwXVIg0ELLZmPiQiQOG-NWmbKi1ahkhQRAho4Kk6vIsg4MHJc0VvsIZgRnlI2r4yVdfethM68A80s_OqxXKiwyBvDijXlZug0RflN6SZMuQ2FdoAuAC1-i-CYRqzaT5SvX2oTCYS27FaXl-BqIgKJWCZJCWhqQI4sT6-rYy50sqZlVuzPaPSQe33Ktb93U4JX8XhnGecEsjYPsdxFmtVy9haaqGhkZWsjalm-naE14d6ksqTP2Dg90MFsZHmT9rj-EunNKp1Fstlp-8AgTUVrrZPL1CEYP0zxtTCKjDuLEU9dJzAjeOcJeyAbrXwV5EpMiTpSgVo6-sBdov4Cew1TKHczmHIeXlZZy2MyiL-ZXtEyW2hdTpR5mKBeghb8ptti_Lo_DFw22As0f8x_jNMf40H_Rv2kKVTm8Y12xggfku2-KZtkw4dWCw7B73syIiHDwRAogIBfEheLBhc-zz1wLeM3eeWYzP9qmHut2axgUhprCA1ndV-0fuaCYSrBe6nhBww_RQEQHDeiLWsx34nQVm69LMqvWnjMUQnIMHHyLhF7mapJEeqBaMBlmH05n82mxcFRKX8fZMOtVAJcSwT6q7LkRYn1lSerwO-mahU46SmflCGkmlYLWqQ6BtE7H7Gwy_nY_EoeRoh9ojULTKa2H5OqGkVD-kJxY4x2wtlwkuecnXFIwP4zPk1SP.HZgRAcvaV2jvVh3TvJOlbg" \
    https://civitai.com/api/download/models/771458


# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export COMMANDLINE_ARGS="--skip-torch-cuda-test --precision full --no-half"
RUN export TORCH_COMMAND='pip install ---no-cache-dir torch==2.1.2+cu118 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118'

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/cache --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    ${TORCH_COMMAND} && \
    pip install --no-cache-dir xformers==0.0.23.post1 --index-url https://download.pytorch.org/whl/cu118

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

COPY --from=download /model.safetensors /model.safetensors

# Install RunPod SDK
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir runpod

ADD src .

COPY builder/cache.py /stable-diffusion-webui/cache.py
RUN cd /stable-diffusion-webui && python cache.py --use-cpu=all --ckpt /model.safetensors || true

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
