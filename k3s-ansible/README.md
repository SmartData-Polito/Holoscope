# Deployment of K3s Cluster with WireGuard 

## Install requirements: 

```bash
$ ansible-galaxy collection install ansible.posix
```

## Deploy the basic wireguard and k3s installation 

```bash
$ ansible-playbook playbooks/site.yml --i path/to/hosts.yml --ask-vault-password
```

The wireguard server need a fixed public and private key, which should not be regenerated every deploy, for this reason execute the procedure below:

1. In a terminal generate the keys with wg genkey and wg pubkey commands. You can output both with the following command:

```sh
privkey=$(wg genkey) sh -c 'echo "
    wireguard_private_key: $privkey
    wireguard_public_key: $(echo $privkey | wg pubkey)"'
```

Copy the output lines and add them to a vars/main.yml. Here's what mine looks like now:

```yaml
# WireGuard server variables
wireguard_private_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  66363663316337643535666635613466303466623039376335333561643536613334306339626233
  6337613835623662323164303461316336363962633831630a366365386635376262396563313134
  35313534623965316664626630643239303963653862663034643531383265663038333035393539
  3362633363666464360a346435656638356664666561616131333562396639343762643064636265
  66626466383930383538633438613366313836326430646131386135326335636239636638613739
  3135643630386131303865616535366638633036613438663133
wireguard_public_key: k6vJn2qKMJ4edWK0B5FBCF/cGWmYz76J5tNYnWzSLRk=
```

## Encrypting the Private Key

It's a good practice to AVOID having secrets in plaintext (like the VPN private key above). This is especially true if those secrets will be shared with anyone else, like via a git repo. Let's prevent this by using Ansible Vault. Vault is a tool for encrypting secret values and using them in playbooks. Encrypt the private key with:

```sh
ansible-vault encrypt_string --ask-vault-password --stdin-name wireguard_private_key
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

Make sure to remember your encryption password (and save it in a password manager); you will need to enter it every time you run the playbook.
