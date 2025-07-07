FROM registry.suse.com/suse/sle15:15.6
COPY install-nvidia-driver.sh /usr/local/bin/install-nvidia-driver.sh
RUN chmod +x /usr/local/bin/install-nvidia-driver.sh
ENTRYPOINT ["/usr/local/bin/install-nvidia-driver.sh"]
