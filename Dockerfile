FROM registry.access.redhat.com/rhel7/rhel
LABEL "io.k8s.display-name"="nfs-target" \
      "io.openshift.s2i.build.image"="nfs-target" \
      "io.openshift.expose-services"="2049:nfs"

USER root

# Set the default port for applications built using this image
EXPOSE 2049

# Set the default CMD for the image
CMD tail -f /dev/null
