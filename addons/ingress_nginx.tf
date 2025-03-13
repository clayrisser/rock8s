/**
 * File: /ingress_nginx.tf
 * Project: main
 * File Created: 27-09-2023 05:26:35
 * Author: Clay Risser
 * -----
 * BitSpur (c) Copyright 2021 - 2023
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "ingress-nginx" {
  source        = "./modules/ingress_nginx"
  enabled       = var.ingress_nginx
  replicas      = 0
  ingress_ports = local.ingress_ports
  load_balancer = var.ingress_nginx_load_balancer
}

data "kubernetes_service" "ingress_nginx" {
  count = var.ingress_nginx ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [
    module.ingress-nginx
  ]
}

resource "null_resource" "wait-for-ingress-nginx" {
  count = var.ingress_nginx ? 1 : 0
  provisioner "local-exec" {
    command     = <<EOF
s=5
while [ "$s" -ge "5" ]; do
  _s=$(echo $(curl -v $ENTRYPOINT 2>&1 | grep -E '^< HTTP') | awk '{print $3}' | head -c 1)
  if [ "$_s" != "" ]; then
    s=$_s
  fi
  if [ "$s" -ge "5" ]; then
    sleep 10
  fi
done
EOF
    interpreter = ["bash", "-c"]
    environment = {
      ENTRYPOINT = local.entrypoint
    }
  }
  depends_on = [
    module.ingress-nginx
  ]
}
