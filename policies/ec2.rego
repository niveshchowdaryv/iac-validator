package main

# All resources from the root module and any child modules of a
# `terraform show -json` plan file.
all_resources contains r if {
	r := input.planned_values.root_module.resources[_]
}

all_resources contains r if {
	r := input.planned_values.root_module.child_modules[_].resources[_]
}

# Deny security groups exposing SSH (port 22) to the open internet.
deny contains msg if {
	r := all_resources[_]
	r.type == "aws_security_group"
	ingress := r.values.ingress[_]
	ingress.from_port <= 22
	ingress.to_port >= 22
	ingress.cidr_blocks[_] == "0.0.0.0/0"
	msg := sprintf("Security group '%s' allows port 22 from 0.0.0.0/0 — restrict SSH to known CIDRs", [r.address])
}
