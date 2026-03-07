from kubernetes import client, config,watch
from time import sleep
import os
from itertools import cycle
import logging
import tempfile
import subprocess

from utility import  cleanup, init_tables, add_forward, remove_forward,add_block, remove_block




# Set up colored logging output
class ColorFormatter(logging.Formatter):
    COLORS = {
        'DEBUG': '\033[94m',    # Blue
        'INFO': '\033[92m',     # Green
        'WARNING': '\033[93m',  # Yellow
        'ERROR': '\033[91m',    # Red
        'CRITICAL': '\033[95m', # Magenta
    }
    RESET = '\033[0m'

    def format(self, record):
        color = self.COLORS.get(record.levelname, self.RESET)
        message = super().format(record)
        return f"{color}{message}{self.RESET}"




handler = logging.StreamHandler()
formatter = ColorFormatter('[%(levelname)s] %(asctime)s - %(message)s', "%Y-%m-%d %H:%M:%S")
handler.setFormatter(formatter)
logging.basicConfig(level=logging.DEBUG, handlers=[handler])


################################################################################################## Extract environment variables






# Extract all port ranges of the responder
port_ranges_responder = []
i = 0
while True:
    port_range = os.getenv(f"PORT_RANGE_RESPONDER_{i}")
    if port_range is None:
        break
    start, end = map(int, port_range.split('-'))
    port_ranges_responder.append((start, end))
    i += 1

# Extract all ip ranges of the responder
ip_list_responder = []
i = 0
while True:
    ip = os.getenv(f"IP_RANGE_RESPONDER_{i}")
    if ip is None:
        break
    ip_list_responder.append((ip))
    i += 1


# Extract all ip ranges of theresponder
ip_list_darknet = []
i = 0
while True:
    ip = os.getenv(f"IP_RANGE_DARKNET_{i}")
    if ip is None:
        break
    ip_list_darknet.append((ip))
    i += 1

NODE_NAME = os.getenv("NODE_NAME")
KUBECONFIG = os.getenv("KUBECONFIG")

CONTAINER_PORT = os.getenv("CONTAINER_PORT_RESPONDER")
L4_SERVER_APP_NAME = os.getenv("L4_SERVER_APP_NAME")
DARKNET_APP_NAME = os.getenv("DARKNET_APP_NAME")


if KUBECONFIG == None and NODE_NAME == None:
    #MANUAL MODE
    

    with open("./kubeconfig.yaml", "r") as f:
        KUBECONFIG = f.read()
    logging.info(f"I am running LOCALLY on node: {NODE_NAME} with loaded kubeconfig")
    
    NODE_NAME ="worker-01" 
    port_ranges_responder = [(44, 48), (12000, 12005)]
    ip_list_responder = ["10.10.0.102/32"]
    ip_list_darknet = ["10.10.0.111/32"]
    CONTAINER_PORT= "80"
    L4_SERVER_APP_NAME = "netshoot"
    DARKNET_APP_NAME = "darknet"
    with tempfile.NamedTemporaryFile(mode="w+", delete=False) as tmpfile:
        tmpfile.write(KUBECONFIG)
        tmpfile.flush()
        tmp_kubeconfig_path = tmpfile.name

        # Now load config from the temp file
    config.load_kube_config(config_file=tmp_kubeconfig_path)

else:
    #DEVELOPMENT/PRODUCTION MODE
    config.load_incluster_config()
    logging.info(f"I am running on node: {NODE_NAME} with kubeconfig 'incluster_config'")






logging.info(f"Node name: {NODE_NAME}")
logging.info(f"Kubeconfig: {KUBECONFIG}")
logging.info(f"Container port: {CONTAINER_PORT}")

logging.info("L4 App Name: %s", L4_SERVER_APP_NAME)
logging.info("L4 Port Ranges : %s", port_ranges_responder)
logging.info("L4 IP list: %s", ip_list_responder)
logging.info("Darknet App Name: %s", DARKNET_APP_NAME)
logging.info("Darknet IP list: %s", ip_list_darknet)



######################################################################################################################################
# Initialize the NAT table and CYBORG chain
#cleanup()
init_tables() 


#Listen to cluster events

v1 = client.CoreV1Api()
w = watch.Watch()
pod_stream = w.stream(v1.list_pod_for_all_namespaces, timeout_seconds=0)
#svc_stream = w.stream(v1.list_service_for_all_namespaces, timeout_seconds=0)
#config_stream = w.stream(v1.list_config_map_for_all_namespaces, timeout_seconds=0)
streams = [("pod", pod_stream)]  
stream_cycle = cycle(streams)




def handle_pod_event(event):
        pod = event['object']
        event_type = event['type']
        node_name = pod.spec.node_name
        pod_name = pod.metadata.name
        
        ####
        #    L4-RESPONDER POD EVENT HANDLER
        ####
        if node_name != NODE_NAME:
            return
        
        logging.info(f"[{pod.metadata.name}] - {pod.metadata.labels.get('app')}- {event_type} - {pod.status.phase} - {pod.status.pod_ip} ")
        if pod.metadata.labels is None:
            return
        if  pod.spec.node_name is None:
            return

        if  pod.metadata.labels.get("app") == L4_SERVER_APP_NAME \
            and pod.spec.node_name == NODE_NAME  \
            and (event_type == "ADDED" or event_type == "MODIFIED")\
            and pod.status.pod_ip is not None:

            logging.debug(f"[{event_type}] Pod '{pod_name}' added/modified on node {node_name} in namespace '{pod.metadata.namespace}'")

            #while pod.status.pod_ip == None:
            #    pod = v1.read_namespaced_pod(name=pod.metadata.name,namespace=pod.metadata.namespace)
            #    logging.debug(f"---[{pod.metadata.name}] Waiting for pod to get an IP address...")
            #    sleep(2)
            logging.info(F"---[{pod.metadata.name}] Modifying iptables rules to redirect traffic to  pod IP {pod.status.pod_ip}...")
            remove_forward(pod.metadata.name)  # Remove any existing rules for this pod 
            for ip in ip_list_responder:
                for start, end in port_ranges_responder:
                    from_ports = f"{start}-{end}"
                    add_forward(ip, from_ports, pod.status.pod_ip, CONTAINER_PORT,pod.metadata.name)

        if pod.metadata.labels.get("app") == L4_SERVER_APP_NAME and pod.spec.node_name == NODE_NAME and event_type == "DELETED":
          #  logging.info(f"---[{pod.metadata.name}]Modifying iptables rules to REMOVE the traffic redirect...")
            remove_forward(pod.metadata.name)

        ####
        #    DARKNET POD EVENT HANDLER
        ####
        
        if  pod.metadata.labels.get("app") == DARKNET_APP_NAME and  pod.spec.node_name == NODE_NAME and event_type == "ADDED":
            #logging.debug(f"[{event_type}] Pod '{pod_name}' scheduled on node {node_name} in namespace '{pod.metadata.namespace}'")
            #logging.info(F"---[{pod.metadata.name}] Modifying iptables rules to block any egress traffic from IP {ip_list_darknet}...")
            for ip in ip_list_darknet:
                add_block(ip,pod.metadata.name)

        if pod.metadata.labels.get("app") == DARKNET_APP_NAME and  pod.spec.node_name == NODE_NAME and event_type == "DELETED":
            #logging.info(F"---[{pod.metadata.name}] Modifying iptables rules to REMOVE the block of egress traffic from IP {ip_list_darknet}...")
            remove_block(pod.metadata.name)
     
       

while True: # Continuously listen for events
    stream_type, stream = next(stream_cycle)
    try:
        event = next(stream)
    except StopIteration:
        continue
    except Exception as e:
        
        logging.error(f"Error reading from {stream_type} stream: {e}")
        continue
    if stream_type == "pod":
        handle_pod_event(event)
    sleep(1)  # Sleep to avoid overwhelming the output
    '''
    elif stream_type == "config":
        config_map = event['object']
        event_type = event['type']
        config_name = config_map.metadata.name
        config_namespace = config_map.metadata.namespace

        logging.debug(f"[{event_type}] ConfigMap '{config_name}' in namespace '{config_namespace}'")
        # You can add logic here to handle config map events as needed
    elif stream_type == "svc":
        svc = event['object']
        event_type = event['type']
        svc_name = svc.metadata.name
        svc_namespace = svc.metadata.namespace

        logging.debug(f"[{event_type}] Service '{svc_name}' in namespace '{svc_namespace}'")
    '''
      

# for each event involving a pod, we will handle it with this function
# we are interested in pod events like ADDED and DELETED on l4-server pod