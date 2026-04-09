# Base image cho Label Studio — tag: sphere-ai-label-studio-base
# Build: docker build -t sphere-ai-label-studio-base .
# sphere-ai/labeling/Dockerfile kế thừa FROM image này.
# Venv path từ official image: /label-studio/.venv
FROM heartexlabs/label-studio:latest

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

# Inject custom template vào gallery của Label Studio
# Khi tạo project → Computer Vision → thấy "Anomaly — Polygon Labeling"
COPY template/ \
     /label-studio/label_studio/annotation_templates/computer-vision/anomaly-polygon/

# Copy thumbnail vào STATIC_ROOT để Django serve qua /static/templates/
COPY template/thumbnail.png \
     /label-studio/label_studio/core/static_build/templates/anomaly-polygon.png

USER 1001

ENTRYPOINT ["/entrypoint.sh"]
