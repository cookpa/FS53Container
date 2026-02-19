# CentOS 6 is EOL; the official image may still exist but its mirrors are dead.
# We repoint yum repos to the CentOS Vault and then install deps + FreeSurfer 5.3.0.

FROM centos:6

# Use bash for RUN lines
SHELL ["/bin/bash", "-lc"]

# ---- configurable bits ----
ARG FS_VERSION=5.3.0
ARG FS_BASE_URL="https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FS_VERSION}"
ARG FS_TARBALL="freesurfer-Linux-centos6_x86_64-stable-pub-v${FS_VERSION}.tar.gz"
ARG FS_URL="${FS_BASE_URL}/${FS_TARBALL}"
ARG FS_PREFIX="/opt"
ARG FS_DIR="${FS_PREFIX}/freesurfer-${FS_VERSION}"

# Repoint yum repos to CentOS Vault so installs work on EOL CentOS 6
RUN for f in /etc/yum.repos.d/*.repo; do \
      sed -i 's/^mirrorlist/#mirrorlist/g' "$f"; \
      sed -i 's|^#baseurl=http://mirror.centos.org/centos/$releasever|baseurl=http://vault.centos.org/6.10|g' "$f"; \
    done && \
    yum clean all && yum -y makecache

# Core runtime deps commonly needed by FreeSurfer 5.3.0 on CentOS 6
RUN yum install -y \
      tcsh csh perl bc which tar bzip2 gzip xz curl ca-certificates \
      glibc libgomp libgfortran \
      libX11 libXext libXt libXmu libXi libXp libXrender libICE libSM \
      libXrandr libXinerama libXcursor libXft mesa-libGLU \
    && yum clean all

# Fetch and install FreeSurfer
RUN mkdir -p "${FS_PREFIX}" /tmp/fs && \
    curl -fsSL "${FS_URL}" -o "/tmp/fs/${FS_TARBALL}" && \
    tar -xzf "/tmp/fs/${FS_TARBALL}" -C "${FS_PREFIX}" && \
    # The tarball usually extracts to ${FS_PREFIX}/freesurfer
    # Normalize to a versioned dir and keep a stable symlink.
    if [ -d "${FS_PREFIX}/freesurfer" ]; then mv "${FS_PREFIX}/freesurfer" "${FS_DIR}"; fi && \
    ln -sfn "${FS_DIR}" "${FS_PREFIX}/freesurfer" && \
    rm -rf /tmp/fs

# Environment: make it available to login + interactive shells.
# Non-interactive 'bash -c' won't source these automatically, so we also set ENV below.
RUN cat >/etc/profile.d/freesurfer.sh <<'EOF'
# FreeSurfer env for shells that source /etc/profile.d
export FREESURFER_HOME=/opt/freesurfer
export SUBJECTS_DIR="${FREESURFER_HOME}/subjects"
# If a license is placed at ${FREESURFER_HOME}/license.txt or FS_LICENSE is set, FS finds it.
# Source canonical setup if present
if [ -r "${FREESURFER_HOME}/SetUpFreeSurfer.sh" ]; then
  # shellcheck disable=SC1090
  source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
fi
EOF

# Also set ENV so tools work even if /etc/profile.d isn't sourced (e.g., non-login non-interactive)
ENV FREESURFER_HOME=/opt/freesurfer \
    SUBJECTS_DIR=/opt/freesurfer/subjects

# Create a placeholder for the license path (you'll mount or set FS_LICENSE at runtime)
# NOTE: You should supply a real license via volume or FS_LICENSE env.
# RUN touch "${FREESURFER_HOME}/license.txt"

# Default to an interactive shell; you can override in `docker run`
CMD ["/bin/bash"]

