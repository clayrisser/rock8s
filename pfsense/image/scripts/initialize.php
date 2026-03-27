#!/usr/local/bin/php
<?php
touch('/tmp/initialize.running');
$max_attempts = 60;
$attempt = 0;
while ($attempt < $max_attempts) {
    if (file_exists('/etc/inc/config.inc')) {
        break;
    }
    $attempt++;
    sleep(1);
}
if ($attempt >= $max_attempts) {
    echo "timeout waiting for pfsense to be ready\n";
    exit(1);
}
require_once('/etc/inc/globals.inc');
require_once('/etc/inc/config.inc');
require_once('/etc/inc/util.inc');
require_once('/etc/inc/filter.inc');
require_once('/etc/inc/interfaces.inc');
global $config;
if (!file_exists('/conf/initialized')) {
    if (isset($config['interfaces'])) {
        unset($config['interfaces']);
    }
    $config['interfaces'] = array();
    $first_boot = empty($config['interfaces']) || !isset($config['system']['hostname']);
    exec('ifconfig -l', $if_output);
    $all_ifs = explode(' ', trim($if_output[0]));
    $net_ifs = array_filter($all_ifs, function($if) {
        return preg_match('/^(vtnet|em|igb|ix|re|bge|ale|bce|bfe|xl|dc|fxp|rl|sf|sis|ste|vr|wb|vmx)\d+/', $if);
    });
    $net_ifs = array_values($net_ifs);
    sort($net_ifs);
    $wan_if = isset($net_ifs[0]) ? $net_ifs[0] : null;
    if ($wan_if) {
        $config['interfaces']['wan'] = array(
            'if' => $wan_if,
            'descr' => 'WAN',
            'ipaddr' => 'dhcp',
            'enable' => true
        );
    }
    if (isset($net_ifs[1])) {
        $config['interfaces']['lan'] = array(
            'if' => $net_ifs[1],
            'descr' => 'LAN',
            'enable' => true
        );
    }
    if (isset($config['dhcpd']) && is_array($config['dhcpd'])) {
        if (isset($config['dhcpd']['wan'])) {
            unset($config['dhcpd']['wan']);
        }
    }
    if (isset($config['trigger_initial_wizard'])) {
        unset($config['trigger_initial_wizard']);
    }
    if (!isset($config['system']) || !is_array($config['system'])) {
        $config['system'] = array();
    }
    $config['system']['already_run_config_upgrade'] = true;
    $config['lastchange'] = time();
    $config['system']['hostname'] = 'pfSense';
    $config['system']['domain'] = 'localdomain';
    $config['system']['timezone'] = 'Etc/UTC';
    if (!isset($config['system']['ssh'])) {
        $config['system']['ssh'] = array();
    }
    $config['system']['ssh']['enable'] = 'enabled';
    if (!isset($config['filter']['rule'])) {
        $config['filter']['rule'] = array();
    }
    $ssh_exists = false;
    $https_exists = false;
    foreach ($config['filter']['rule'] as $rule) {
        if (isset($rule['descr']) && $rule['descr'] == 'allow ssh on wan') {
            $ssh_exists = true;
        }
        if (isset($rule['descr']) && $rule['descr'] == 'allow https on wan') {
            $https_exists = true;
        }
    }
    if (!$ssh_exists) {
        array_unshift($config['filter']['rule'], array(
            'type' => 'pass',
            'interface' => 'wan',
            'ipprotocol' => 'inet',
            'protocol' => 'tcp',
            'source' => array('any' => true),
            'destination' => array(
                'any' => true,
                'port' => '22'
            ),
            'descr' => 'allow ssh on wan'
        ));
    }
    if (!$https_exists) {
        array_unshift($config['filter']['rule'], array(
            'type' => 'pass',
            'interface' => 'wan',
            'ipprotocol' => 'inet',
            'protocol' => 'tcp',
            'source' => array('any' => true),
            'destination' => array(
                'any' => true,
                'port' => '443'
            ),
            'descr' => 'allow https on wan'
        ));
    }
    $pf_rules = '
pass in quick on vtnet0 proto tcp from any to any port 22
pass in quick on vtnet0 proto tcp from any to any port 443
pass in quick on vtnet1 proto tcp from any to any port 22
pass in quick on vtnet1 proto tcp from any to any port 443
';
    file_put_contents('/tmp/rules.pf', $pf_rules);
    system('pfctl -a init_temp -f /tmp/rules.pf 2>/dev/null');
    system('pfctl -e 2>/dev/null');
    if (isset($config['staticroutes']) && is_array($config['staticroutes'])) {
        unset($config['staticroutes']);
    }
    $config['system']['defaultgw'] = 'wan';
    write_config('first boot provisioning');
    if (function_exists('interface_configure')) {
        interface_configure('wan', true);
    }
    if (function_exists('filter_configure')) {
        filter_configure();
    }
    system('pfctl -e 2>/dev/null');
    system('pfctl -f /tmp/rules.debug 2>/dev/null');
    system('sync');
    touch('/conf/config.xml');
    system('/etc/rc.reload_all 2>/dev/null');
}
if (file_exists('/etc/rc.conf')) {
    $rc_conf = file_get_contents('/etc/rc.conf');
    if (preg_match_all('/^ifconfig_(\w+)="inet\s+(\S+)\s+netmask\s+(\S+)"/m', $rc_conf, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $device = $match[1];
            $ipaddr = $match[2];
            $netmask = $match[3];
            $cidr = strlen(str_replace('0', '', decbin(ip2long($netmask))));
            if ($device == $wan_if) {
                continue;
            }
            exec('ifconfig -l', $if_list);
            $all_interfaces = explode(' ', trim($if_list[0]));
            $net_interfaces = array_filter($all_interfaces, function($if) {
                return !in_array($if, ['lo0', 'pflog0', 'pfsync0', 'enc0']) &&
                       !preg_match('/^(tun|tap|gif|gre|bridge|vlan)/', $if);
            });
            $net_interfaces = array_values($net_interfaces);
            sort($net_interfaces);
            $position = array_search($device, $net_interfaces);
            if ($position === 1) {
                $interface = 'lan';
            } else if ($position > 1) {
                $interface = 'opt' . ($position - 1);
            } else {
                continue;
            }
            $config['interfaces'][$interface] = array(
                'if' => $device,
                'descr' => ($interface == 'lan') ? 'LAN' : strtoupper($interface),
                'ipaddr' => $ipaddr,
                'subnet' => $cidr,
                'enable' => true
            );
        }
        if (count($matches) > 0) {
            write_config('applied network configuration');
            if (function_exists('interface_configure')) {
                foreach ($matches as $match) {
                    $device = $match[1];
                    if ($device != 'vtnet0') {
                        $interface = ($device == 'vtnet1') ? 'lan' : 'opt' . (intval(str_replace('vtnet', '', $device)) - 1);
                        interface_configure($interface, true);
                    }
                }
            }
        }
    }
}
exec('ifconfig -l', $if_output_check);
$all_ifs_check = explode(' ', trim($if_output_check[0]));
$net_ifs_check = array_filter($all_ifs_check, function($if) {
    return !in_array($if, ['lo0', 'pflog0', 'pfsync0', 'enc0']) &&
           !preg_match('/^(tun|tap|gif|gre|bridge|vlan)/', $if);
});
$net_ifs_check = array_values($net_ifs_check);
sort($net_ifs_check);
$wan_if_check = isset($net_ifs_check[0]) ? $net_ifs_check[0] : null;
if (!isset($config['interfaces']['wan']) ||
    (isset($config['interfaces']['wan']['if']) && $config['interfaces']['wan']['if'] != $wan_if_check) ||
    (isset($config['interfaces']['wan']['ipaddr']) && $config['interfaces']['wan']['ipaddr'] != 'dhcp')) {
    $config['interfaces']['wan'] = array(
        'if' => $wan_if_check,
        'descr' => 'WAN',
        'ipaddr' => 'dhcp',
        'enable' => true
    );
    if (isset($config['dhcpd']['wan'])) {
        unset($config['dhcpd']['wan']);
    }
    write_config('wan set as first interface');
    if (function_exists('interface_configure')) {
        interface_configure('wan', true);
    }
}
$lan_if_check = isset($net_ifs_check[1]) ? $net_ifs_check[1] : null;
if ($lan_if_check && (!isset($config['interfaces']['lan']) ||
    (isset($config['interfaces']['lan']['if']) && $config['interfaces']['lan']['if'] != $lan_if_check))) {
    $config['interfaces']['lan'] = array(
        'if' => $lan_if_check,
        'descr' => 'LAN',
        'enable' => true
    );
    write_config('lan set as second interface');
    if (function_exists('interface_configure')) {
        interface_configure('lan', true);
    }
}
touch('/conf/initialized');
touch('/tmp/initialize.complete');
@unlink('/tmp/initialize.running');
?>
