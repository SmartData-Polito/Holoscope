## Configuration
Populate `hosts` file  with the right value for each field
## Execution 

Inside the playbook folder run : `ansible-playbook -i ./hosts playbook.yml`

`playbook.yml` will automatically invoke the different  `playbook_partX.yml` files

## Actual setup
node2(worker) is a remote node, node1(master) is the local machine