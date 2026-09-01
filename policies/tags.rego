package main

# All resources from the root module and any child modules of a
# `terraform show -json` plan file.
all_resources contains r if {
	r := input.planned_values.root_module.resources[_]
}

all_resources contains r if {
	r := input.planned_values.root_module.child_modules[_].resources[_]
}

# Resource types that must carry cost/ownership tags.
tagged_types := {"aws_s3_bucket", "aws_instance", "aws_security_group"}

required_tags := ["Environment", "Owner"]

# Deny resources missing any required tag.
deny contains msg if {
	r := all_resources[_]
	tagged_types[r.type]
	tags := object.get(r.values, "tags", {})
	missing := [t | t := required_tags[_]; not tags[t]]
	count(missing) > 0
	msg := sprintf("%s '%s' is missing required tag(s): %s", [r.type, r.address, concat(", ", missing)])
}
