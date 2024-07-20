import sys
import json
from ipaddress import IPv6Network, IPv6Address

def get_dhcp(base_subnet, i):
    network = IPv6Network(base_subnet)
    if network.prefixlen != 96:
        raise ValueError("Input subnet must be a /96 subnet")
    subnets = list(network.subnets(new_prefix=112))
    if i >= len(subnets):
        raise IndexError("Index out of range for the number of available /112 subnets")
    subnet = subnets[i + 1]
    gateway = IPv6Address(subnet.network_address + 1)
    dhcp_start = IPv6Address(subnet.network_address + 0x1000)
    dhcp_end = IPv6Address(subnet.network_address + 0xffff)
    return {
        "gateway": str(gateway),
        "range": f"{dhcp_start} {dhcp_end}",
        "subnet": str(network.supernet(new_prefix=96)),
    }

def get_metallb(base_subnet, i, total_hosts):
    network = IPv6Network(base_subnet)
    if network.prefixlen != 96:
        raise ValueError("Input subnet must be a /96 subnet")
    subnets = list(network.subnets(new_prefix=112))
    if i >= len(subnets) - total_hosts:
        raise IndexError("Index out of range for the number of available /112 subnets")
    subnet = subnets[i + 1 + total_hosts]
    return {
        "range": f"{subnet.network_address} {subnet.broadcast_address}",
        "subnet": str(network.supernet(new_prefix=96)),
    }

def main():
    if len(sys.argv) != 5:
        print("Usage: python subnet_calculator.py <metallb|dhcp> <subnet> <instance_index> <total_hosts>")
        sys.exit(1)
    command = sys.argv[1]
    base_subnet = sys.argv[2]
    instance_index = int(sys.argv[3]) - 1
    total_hosts = int(sys.argv[4])
    base_network = IPv6Network(base_subnet)
    if base_network.prefixlen < 96:
        base_subnet_96 = next(base_network.subnets(new_prefix=96))
    elif base_network.prefixlen == 96:
        base_subnet_96 = base_network
    else:
        raise ValueError("Input subnet must be /96 or larger")
    if command == "dhcp":
        result = get_dhcp(base_subnet_96, instance_index)
    elif command == "metallb":
        result = get_metallb(base_subnet_96, instance_index, total_hosts)
    else:
        print("Invalid command. Use 'metallb' or 'dhcp'.")
        sys.exit(1)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
