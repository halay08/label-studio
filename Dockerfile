# Base image: dùng bản **gốc** từ Docker Hub làm layer 0.
# Nếu bạn `docker build -t heartexlab/label-studio:latest` trong khi máy đã có tag đó = bản custom cũ,
# Docker sẽ FROM nhầm chính image cũ → entrypoint/script có thể không đúng. Trước khi build:
#   docker pull heartexlab/label-studio:latest
# hoặc tag output khác (vd. heartexlab/label-studio:sphere-custom).
# Venv path từ official image: /label-studio/.venv
FROM heartexlab/label-studio:latest

USER root

# Cài thêm dependencies nếu có
COPY requirements.txt /tmp/requirements.txt
RUN /label-studio/.venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

# Copy entrypoint wrapper
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy init script vào container (seed template khi start)
COPY init_template.sh /label-studio/init_template.sh
COPY auto_attach_ml_backend.sh /label-studio/auto_attach_ml_backend.sh
RUN chmod +x /label-studio/init_template.sh /label-studio/auto_attach_ml_backend.sh

# Gallery template (config.yml + label_config.xml + …); init_template.sh đọc label_config.xml từ cùng thư mục này
# Khi tạo project → Computer Vision → thấy "Anomaly — Polygon Labeling"
COPY template/ \
     /label-studio/label_studio/annotation_templates/computer-vision/anomaly-polygon/

# Copy thumbnail vào STATIC_ROOT để Django serve qua /static/templates/
COPY template/thumbnail.png \
     /label-studio/label_studio/core/static_build/templates/anomaly-polygon.png

USER 1001

ENTRYPOINT ["/entrypoint.sh"]
