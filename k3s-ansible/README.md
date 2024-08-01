To run the playbook run this:

ansible-playbook playbooks/site.yml

The wireguard server need a fixed public and private key, which should not be regenerated every deploy, for this reason execute the procedure below:

1. In a terminal generate the keys with wg genkey and wg pubkey commands. You can output both with the following command:

```sh

privkey=$(wg genkey) sh -c 'echo "
    server_private_key: $privkey
    server_public_key: $(echo $privkey | wg pubkey)"'

```

Copy the output lines and add them to a vars/main.yml. Here's what mine looks like now (your keys will be different):

```yaml
# K3s variables
k3s_version: "v1.20.0+k3s2"
k3s_token: "your_k3s_token"
k3s_url: "https://{{ hostvars[groups['master'][0]] }}:6443"

# WireGuard server variables
server_ip: "10.0.0.1"
listen_port: "51820"
server_private_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  66633530373637636637333065363864616339313262623361393132326564386661393935323865
  3964663130373962333333653931376334356338313231310a366562343233636166376634376631
  31353534396666336230326464333064343337383463343035383333326162373666383363313538
  3261353731313330310a356261626630306263653537656238333536313134323465353163316633
  32343632383539356530366531646562353335313739663436366666663965343663663163396132
  6631326264396663313935373037383230333833636665323464
server_public_key: /SPUC+mZEcY0ChebN97MhEExlWh/LJR0NbLs8eg27Uk=
gateway_interface_name: "name_of_the_gateway_interface"

# WireGuard clients
clients:
  - ip: "10.0.0.2"
    public_key: "client1_public_key"
  - ip: "10.0.0.3"
    public_key: "client2_public_key"
  # Add additional clients here
```

Encrypting the Private Key

It's a good practice to AVOID having secrets in plaintext (like the VPN private key above). This is especially true if those secrets will be shared with anyone else, like via a git repo. Let's prevent this by using Ansible Vault. Vault is a tool for encrypting secret values and using them in playbooks. Encrypt the private key with:

```sh

ansible-vault encrypt_string --ask-vault-password --stdin-name server_privkey

```

You'll be prompted twice for a Vault encryption password, after which you'll paste your privkey value and hit Ctrl+d twice. If the command completed after a single Ctrl+d, try again and make sure you're not copy-pasting an invisible newline character at the end of the privkey value. Copy the output into your playbook, which will now look like:

```yaml
- name: setup vpn server
  hosts: vpn_server
  vars:
    server_privkey: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          646438636565343063343631326136386239623935393637336539653636386135363
          663386639393232346534643163656363316234306439306566306534610a31326664
          363763663139383034636632343230376365333130333230373866353033326563303
          5636138373830633534373033303536303566663166616539360a3936353033663263
          336662663034376661616631343661333164363134373061343739633637623739306
          465653532383838393662396333623966343165366635353132396332313762343534
          65313761623964653532623839356633343838
    server_pubkey: 7/6f7bUT+2hWMEP5BxeK51PGuMuTnQ9pRpkxg5jUSTo=
  tasks:
  ...

```

Make sure to remember your encryption password (and save it in a password manager); you'll need to enter it every time you run the playbook.
