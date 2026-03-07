from kubernetes import client, config, watch
from time import sleep
import os
from itertools import cycle
import logging
import tempfile
import subprocess
import re

system_name = "holoscope"

def run_nft(cmd: str):
    full_cmd = "nft " + cmd
    result = subprocess.run(full_cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        logging.error(f"nft command failed: {full_cmd}\n{result.stderr}")
    else:
        logging.debug(f"Ran: {full_cmd}")


def cleanup():
    logging.info("Cleaning up CYBORG chain (if exists)") ####nft delete table ip cyborg

  
    # Check if chain exists first
    check_result = subprocess.run(
        "nft list chain ip nat CYBORG", shell=True, capture_output=True, text=True
    )

    if check_result.returncode == 0:
        logging.debug("CYBORG chain exists, cleaning up...")

        # Remove ALL jump rules to CYBORG from PREROUTING
        list_cmd = "nft -a list chain ip nat PREROUTING"
        result = subprocess.run(list_cmd, shell=True, capture_output=True, text=True)

        handles_to_remove = []
        if result.returncode == 0:
            lines = result.stdout.splitlines()

            # Collect all handles that jump to CYBORG
            for line in lines:
                if "jump CYBORG" in line:
                    handle_match = re.search(r"handle (\d+)", line)
                    if handle_match:
                        handles_to_remove.append(handle_match.group(1))

            # Remove all the jump rules
            for handle in handles_to_remove:
                run_nft(f"delete rule ip nat PREROUTING handle {handle}")
                logging.debug(f"Removed PREROUTING jump rule with handle {handle}")

        # Flush the chain
        run_nft("flush chain ip nat CYBORG")
        logging.info(
            f"CYBORG chain cleanup completed - removed {len(handles_to_remove)} jump rules"
        )
    else:
        logging.debug("CYBORG chain doesn't exist, skipping cleanup")


def init_tables():
    logging.info(f"Initializing nftables table ip {system_name}")
  
    chain_check = subprocess.run(
        f"nft delete table ip {system_name}", shell=True, capture_output=True, text=True
    )

    run_nft(f"add table ip {system_name}")
    



    run_nft(f"add chain ip {system_name} PREROUTING {{ type nat hook prerouting priority -101 \; policy accept \; }}")
    run_nft(f"add chain ip {system_name} OUTPUT {{ type filter hook output priority -1 \; policy accept \; }}")




    '''
    # Check if jump rule already exists
    check_cmd = "nft list chain ip nat PREROUTING | grep 'jump CYBORG'"
    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0 or not result.stdout.strip():
        run_nft("add rule ip nat PREROUTING jump CYBORG")
        logging.info("Added jump from nat-PREROUTING to nat-CYBORG chain.")
    else:
        logging.debug("Jump from nat-PREROUTING to nat-CYBORG already exists.")

    logging.info("Initializing nftables FILTER table and CYBORG_OUTPUT chain...")

    # Create CYBORG chain if it doesn't exist
    chain_check = subprocess.run(
        "nft list chain ip FILTER CYBORG", shell=True, capture_output=True, text=True
    )
    if chain_check.returncode != 0:
        run_nft("add chain ip filter CYBORG")
        logging.debug("Created filter-CYBORG chain")
    else:
        logging.debug("filter-CYBORG chain already exists")

    # Check if jump rule already exists
    check_cmd = "nft list chain ip filter OUTPUT | grep 'jump CYBORG'"
    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0 or not result.stdout.strip():
        run_nft("add rule ip filter OUTPUT jump CYBORG")
        logging.info("Added jump from filter-OUTPUT to filter-CYBORG chain.")
    else:
        logging.debug("Jump from filter-OUTPUT to filter-CYBORG already exists.")
    '''

def ensure_masquerade():
    check_cmd = "nft list chain ip nat POSTROUTING | grep masquerade"
    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
    if not result.stdout.strip():
        run_nft("add rule ip nat POSTROUTING masquerade")
        logging.info("Added MASQUERADE rule to POSTROUTING.")
    else:
        logging.debug("MASQUERADE rule already exists.")


def add_forward( host_ip: str, host_port: str, pod_ip: str, pod_port: str, pod_name: str):


    run_nft(
        f"add rule ip {system_name} PREROUTING ip daddr {host_ip} tcp dport {host_port} counter "
        f"dnat to {pod_ip}:{pod_port} comment {pod_name}"
    )

def add_block(ip: str, pod_name: str):
    #logging.info(f"[{pod_name}] Adding nftables rule to BLOCK outgoing traffic from: {ip}")
    run_nft(f'add rule ip {system_name} OUTPUT ip saddr {ip} drop comment "{pod_name}"')


def remove_block( pod_name: str, pod_ip: str):
 
    list_cmd = f"nft -a list chain ip  {system_name} OUTPUT"
    result = subprocess.run(list_cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        logging.error(f"Failed to list nftables rules for chain {chain_name}")
        return

    lines = result.stdout.splitlines()
    found = False
    for line in lines:
        if f'{pod_name}' in line:
            handle_match = re.search(r"handle (\d+)", line)
            if handle_match:
                handle = handle_match.group(1)
                run_nft(f"delete rule ip {system_name} handle {handle}")
                found = True


    if not found:
        logging.warning(f"No matching nftables BLOCK rule found for pod [{pod_name}].")


def remove_forward(pod_name: str):
    #logging.info(f"Removing nftables rule(s) for POD [{pod_name}]")

    list_cmd = f"nft -a list chain ip {system_name} PREROUTING"
    result = subprocess.run(list_cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        logging.error(f"Failed to list nftables rules for chain ip {system_name} PREROUTING")
        return

    lines = result.stdout.splitlines()
    found = False
    for line in lines:
        if f'{pod_name}' in line:
            handle_match = re.search(r"handle (\d+)", line)
            if handle_match:
                handle = handle_match.group(1)
                run_nft(f"delete rule ip {system_name} PREROUTING handle {handle}")
                found = True

    if not found:
        logging.warning(f"No matching rule found for pod [{pod_name}].")