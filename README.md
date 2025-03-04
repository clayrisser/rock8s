# rock8s

> universal kubernetes cluster

![](./rock8t.jpg)

## Hetzner

1. Clone and configure:
    ```bash
    git clone https://github.com/bitspur/rock8s.git
    cd rock8s
    cp .env.default .env
    ```

2. Set required variables:
    ```bash
    CLUSTER_NAME=rock8s
    EMAIL=you@example.com
    ENTRYPOINT=cluster.example.com
    HETZNER_TOKEN=your_token
    HETZNER_MASTERS="cpx31:1"
    HETZNER_WORKERS="cx41:2 cx51:3 cpx31:2"
    ```

3. Deploy:
    ```bash
    make providers/hetzner
    make kubernetes
    ```
