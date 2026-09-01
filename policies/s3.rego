package main

# All resources from the root module and any child modules of a
# `terraform show -json` plan file.
all_resources contains r if {
	r := input.planned_values.root_module.resources[_]
}

all_resources contains r if {
	r := input.planned_values.root_module.child_modules[_].resources[_]
}

# S3 ACLs that grant some form of public access.
public_acls := {"public-read", "public-read-write", "authenticated-read", "log-delivery-write"}

# Deny S3 buckets with public ACLs (e.g. acl = "public-read").
deny contains msg if {
	r := all_resources[_]
	r.type == "aws_s3_bucket"
	acl := object.get(r.values, "acl", "private")
	public_acls[acl]
	msg := sprintf("S3 bucket '%s' uses ACL '%s' — public bucket ACLs are denied", [r.address, acl])
}

# Deny S3 buckets without server-side encryption.
deny contains msg if {
	r := all_resources[_]
	r.type == "aws_s3_bucket"
	sse := object.get(r.values, "server_side_encryption_configuration", [])
	count(sse) == 0
	msg := sprintf("S3 bucket '%s' has no server-side encryption configured — SSE is required", [r.address])
}
