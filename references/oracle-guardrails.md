# Oracle PAYG Guardrails

## Principle

Oracle has no perfect zero-spend hard cap. Budgets warn; quotas enforce resource limits. Use both, plus local script checks.

## Minimum Safe Setup

1. Create a dedicated compartment, usually `openclaw-free-only`.
2. Create a small tenancy-wide monthly budget alert, often `1` in the account currency.
3. Add actual and forecast alert rules to the account owner's email.
4. Create a quota policy that:
   - Zeroes compute core and memory quotas first.
   - Allows only `Standard.A1` up to 4 OCPU and 24 GB RAM.
   - Caps block storage at or below 200 GB and a small volume count.
   - Blocks block backups, load balancers, databases, OKE, object storage, file storage, and reserved public IPs unless the user explicitly accepts paid risk.
5. Patch/create provisioning scripts so they refuse:
   - Root tenancy compartment.
   - Any shape other than `VM.Standard.A1.Flex`.
   - More than 4 OCPU, 24 GB RAM, or 200 GB boot/block storage.

## Audit First

Run read-only list/get commands before creating anything:

```bash
oci iam compartment list --compartment-id "$TENANCY_OCID" --all
oci limits quota list --compartment-id "$TENANCY_OCID" --all
oci budgets budget budget list --compartment-id "$TENANCY_OCID" --all
oci compute instance list --compartment-id "$COMPARTMENT_OCID" --all
oci bv volume list --compartment-id "$COMPARTMENT_OCID" --availability-domain "$AD"
```

OCI CLI command shape varies by version. Confirm budget and quota subcommands with `--help` before applying.

## Known Caveats

- PAYG may still show a temporary card authorization during upgrade.
- PAYG improves A1 capacity odds but does not guarantee instant capacity.
- Quota names can be tenancy/version specific; verify accepted names with a small policy or Oracle docs before relying on them.
- Existing root-compartment VCNs should not be reused after introducing a guarded compartment unless there is a clear reason.
