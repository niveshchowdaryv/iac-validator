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

# Deny S3 buckets with public ACLs.
# In AWS provider v5 the ACL lives on a separate aws_s3_bucket_acl resource,
# not inline on the bucket, so both shapes are checked.
deny contains msg if {
	r := all_resources[_]
	r.type == "aws_s3_bucket"
	acl := object.get(r.values, "acl", "private")
	public_acls[acl]
	msg := sprintf("S3 bucket '%s' uses ACL '%s' — public bucket ACLs are denied", [r.address, acl])
}

deny contains msg if {
	r := all_resources[_]
	r.type == "aws_s3_bucket_acl"
	public_acls[r.values.acl]
	msg := sprintf("S3 bucket ACL '%s' grants '%s' — public bucket ACLs are denied", [r.address, r.values.acl])
}

# Deny S3 buckets without server-side encryption.
# In AWS provider v5 SSE is a separate
# aws_s3_bucket_server_side_encryption_configuration resource, not an inline
# bucket attribute, so the policy requires that companion resource to exist
# and actually apply a default SSE rule. (The companion's `bucket` argument
# usually references the bucket id, which is unknown until apply, so instead
# of trying to link companion -> bucket by name, the gate requires at least
# one properly-configured SSE resource per plan. Good enough for this demo;
# a multi-bucket setup would want per-bucket linking via the configuration
# expressions.)
deny contains msg if {
	r := all_resources[_]
	r.type == "aws_s3_bucket"
	not sse_configured
	msg := sprintf("S3 bucket '%s' has no server-side encryption configured — SSE is required", [r.address])
}

sse_configured if {
	s := all_resources[_]
	s.type == "aws_s3_bucket_server_side_encryption_configuration"
	rule := s.values.rule[_]
	count(rule.apply_server_side_encryption_by_default) > 0
}
