FROM registry.access.redhat.com/rhel7/rhel
LABEL "io.k8s.display-name"="nfs-target" \
      "io.openshift.s2i.build.image"="nfs-target" \
      "io.openshift.expose-services"="2049:nfs"

USER root

# Obtain and compile dependencies
RUN yum install -y openssl-devel gcc libstdc++-devel gcc-c++ fuse fuse-devel curl-devel libxml2-devel mailcap git automake make nfs-utils rpcbind sudo && yum -y clean all && \
    git clone https://github.com/s3fs-fuse/s3fs-fuse.git && \
    cd s3fs-fuse && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

# Build the start script
RUN echo '%root ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    # --- Begin create wrapper script for start script ---
    echo '#!/bin/bash' >> /s3fs-fuse/wrapper_start_script && \
    echo 'setsid /s3fs-fuse/start_script 2> /dev/null &' >> /s3fs-fuse/wrapper_start_script && \
    echo 'exec /sbin/init' >> /s3fs-fuse/wrapper_start_script && \
    # --- Begin create start script ---
    echo '#!/bin/bash' >> /s3fs-fuse/start_script && \
    echo 'sleep 10' >> /s3fs-fuse/start_script && \
    echo 'echo ${COS_API_CREDENTIAL} >> /s3fs-fuse/creds' >> /s3fs-fuse/start_script && \
    echo 'chmod 0600 /s3fs-fuse/creds' >> /s3fs-fuse/start_script  && \
    echo 'mkdir -p ${COS_MOUNT_POINT:-/s3fs-fuse/cos}' >> /s3fs-fuse/start_script && \
    echo 'chmod -R 0777 ${COS_MOUNT_POINT:-/s3fs-fuse/cos}' >> /s3fs-fuse/start_script && \
    echo 'chgrp -R 0 ${COS_MOUNT_POINT:-/s3fs-fuse/cos}' >> /s3fs-fuse/start_script && \
    echo 'chmod -R g+rwX ${COS_MOUNT_POINT:-/s3fs-fuse/cos}' >> /s3fs-fuse/start_script && \
    echo 'echo "${COS_MOUNT_POINT:-/s3fs-fuse/cos} *(rw,fsid=0,no_root_squash,sync)" >> /etc/exports' >> /s3fs-fuse/start_script && \
    echo 's3fs ${COS_BUCKET} ${COS_MOUNT_POINT:-/s3fs-fuse/cos} -o url=${COS_URL} -o passwd_file=/s3fs-fuse/creds -o ibm_iam_auth' >> /s3fs-fuse/start_script && \
    echo 'exportfs -r' >> /s3fs-fuse/start_script && \
    # Commented out nfs-lock as it was hanging, need to revisit
    echo 'sudo systemctl start rpcbind nfs-server nfs-idmap' >> /s3fs-fuse/start_script && \
    chmod 0755 /s3fs-fuse/wrapper_start_script && \
    chmod 0755 /s3fs-fuse/start_script && \
    chgrp -R 0 /s3fs-fuse && \
    chmod -R g+rwX /s3fs-fuse && \
    chmod -R g+rwX /etc/exports

# Set the default port for applications built using this image
EXPOSE 2049

# Set the default CMD for the image
ENTRYPOINT ["/s3fs-fuse/wrapper_start_script"]
