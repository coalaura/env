import { Plugin } from "@opencode/plugin";

const patterns = [
	// AI providers
	{ name: "openrouter", prefix: 9, pattern: /\bsk-or-v1-[0-9a-f]{64}\b/gi },
	{ name: "openai-project", prefix: 8, pattern: /\bsk-proj-[A-Za-z0-9_-]{80,}\b/g },
	{ name: "openai-service-account", prefix: 11, pattern: /\bsk-svcacct-[A-Za-z0-9_-]{80,}\b/g },
	{ name: "openai-admin", prefix: 9, pattern: /\bsk-admin-[A-Za-z0-9_-]{80,}\b/g },
	{ name: "anthropic", prefix: 13, pattern: /\bsk-ant-api03-[A-Za-z0-9_-]{95}\b/g },
	{ name: "anthropic-admin", prefix: 15, pattern: /\bsk-ant-admin01-[A-Za-z0-9_-]{95}\b/g },
	{ name: "perplexity", prefix: 5, pattern: /\bpplx-[A-Za-z0-9]{48}\b/g },
	{ name: "groq", prefix: 4, pattern: /\bgsk_[A-Za-z0-9]{48}\b/g },
	{ name: "xai", prefix: 4, pattern: /\bxai-[A-Za-z0-9]{80}\b/g },
	{ name: "replicate", prefix: 3, pattern: /\br8_[A-Za-z0-9]{32,64}\b/g },
	{ name: "cerebras", prefix: 4, pattern: /\bcsk-[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "nvidia", prefix: 6, pattern: /\bnvapi-[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "huggingface", prefix: 3, pattern: /\bhf_[A-Za-z]{34}\b/gi },
	{ name: "huggingface-org", prefix: 8, pattern: /\bapi_org_[A-Za-z]{34}\b/gi },

	// GitHub / GitLab
	{ name: "github", prefix: 4, pattern: /\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9._-]{20,255}\b/g },
	{ name: "github-fine-grained", prefix: 11, pattern: /\bgithub_pat_[A-Za-z0-9._-]{20,255}\b/g },
	{ name: "gitlab-pat", prefix: 6, pattern: /\bglpat-[A-Za-z0-9_-]{20,300}(?:\.[A-Za-z0-9]{9})?\b/g },
	{ name: "gitlab-oauth-secret", prefix: 6, pattern: /\bgloas-[A-Za-z0-9_-]{64}\b/g },
	{ name: "gitlab-deploy-token", prefix: 5, pattern: /\bgldt-[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-runner-token", prefix: 5, pattern: /\bglrt-[A-Za-z0-9_-]{20,300}(?:\.[A-Za-z0-9]{9})?\b/g },
	{ name: "gitlab-runner-token-legacy-registration", prefix: 9, pattern: /\bGR1348941[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-runner-token-registration", prefix: 6, pattern: /\bglrtr-[A-Za-z0-9_-]{20,300}\b/g },
	{ name: "gitlab-job-token", prefix: 6, pattern: /\bglcbt-[A-Za-z0-9]{1,5}_[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-trigger-token", prefix: 6, pattern: /\bglptt-[0-9a-f]{40}\b/gi },
	{ name: "gitlab-feed-token", prefix: 5, pattern: /\bglft-[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-incoming-mail-token", prefix: 6, pattern: /\bglimt-[A-Za-z0-9_-]{25}\b/g },
	{ name: "gitlab-agent-token", prefix: 8, pattern: /\bglagent-[A-Za-z0-9_-]{50}\b/g },
	{ name: "gitlab-workspace-token", prefix: 5, pattern: /\bglwt-[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "gitlab-scim-token", prefix: 7, pattern: /\bglsoat-[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-feature-flag-token", prefix: 7, pattern: /\bglffct-[A-Za-z0-9_-]{20}\b/g },
	{ name: "gitlab-session", prefix: 16, pattern: /_gitlab_session=[a-z0-9]{32}/gi },

	// Cloud / infrastructure
	{ name: "aws-access-key", prefix: 4, pattern: /\b(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}\b/g },
	{ name: "aws-bedrock", prefix: 4, pattern: /\bABSK[A-Za-z0-9+/]{109,269}={0,2}(?=$|[^A-Za-z0-9+/=])/g },
	{ name: "gcp-api-key", prefix: 4, pattern: /\bAIza[A-Za-z0-9_-]{35}\b/g },
	{ name: "databricks", prefix: 4, pattern: /\bdapi[a-f0-9]{32}(?:-\d)?\b/gi },
	{ name: "digitalocean-oauth", prefix: 7, pattern: /\bdoo_v1_[a-f0-9]{64}\b/gi },
	{ name: "digitalocean-pat", prefix: 7, pattern: /\bdop_v1_[a-f0-9]{64}\b/gi },
	{ name: "digitalocean-refresh", prefix: 7, pattern: /\bdor_v1_[a-f0-9]{64}\b/gi },
	{ name: "doppler", prefix: 6, pattern: /\bdp\.pt\.[A-Za-z0-9]{43}\b/g },
	{ name: "dropbox-short-lived", prefix: 3, pattern: /\bsl\.[A-Za-z0-9_=-]{135}\b/g },
	{ name: "flyio", prefix: 4, pattern: /\bfo1_[A-Za-z0-9_-]{43}\b/g },
	{ name: "flyio-macaroon-v1", prefix: 5, pattern: /\bfm1[ar]_[A-Za-z0-9+/]{100,}={0,3}(?=$|[^A-Za-z0-9+/=])/g },
	{ name: "flyio-macaroon-v2", prefix: 4, pattern: /\bfm2_[A-Za-z0-9+/]{100,}={0,3}(?=$|[^A-Za-z0-9+/=])/g },
	{ name: "grafana-cloud", prefix: 4, pattern: /\bglc_[A-Za-z0-9+/]{32,400}={0,3}(?=$|[^A-Za-z0-9+/=])/g },
	{ name: "grafana-service-account", prefix: 5, pattern: /\bglsa_[A-Za-z0-9]{32}_[A-Fa-f0-9]{8}\b/g },
	{ name: "hashicorp-terraform", pattern: /\b[A-Za-z0-9]{14}\.atlasv1\.[A-Za-z0-9_=-]{60,70}\b/g },
	{ name: "heroku-v2", prefix: 7, pattern: /\bHRKU-AA[A-Za-z0-9_-]{58}\b/g },
	{ name: "infracost", prefix: 4, pattern: /\bico-[A-Za-z0-9]{32}\b/g },
	{ name: "pulumi", prefix: 4, pattern: /\bpul-[a-f0-9]{40}\b/gi },
	{ name: "vercel-personal", prefix: 4, pattern: /\bvcp_[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "vercel-integration", prefix: 4, pattern: /\bvci_[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "vercel-app-access", prefix: 4, pattern: /\bvca_[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "vercel-app-refresh", prefix: 4, pattern: /\bvcr_[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "vercel-api-key", prefix: 4, pattern: /\bvck_[A-Za-z0-9_-]{20,255}\b/g },
	{ name: "supabase-secret", prefix: 10, pattern: /\bsb_secret_[A-Za-z0-9_-]{22}_[A-Za-z0-9_-]{8}\b/g },
	{ name: "supabase-pat", prefix: 4, pattern: /\bsbp_(?:v0_)?[a-f0-9]{40}\b/gi },

	// Secret managers / developer tools
	{ name: "1password-service-account", prefix: 4, pattern: /\bops_eyJ[A-Za-z0-9+/]{250,}={0,3}(?=$|[^A-Za-z0-9+/=])/g },
	{ name: "age-secret-key", prefix: 16, pattern: /\bAGE-SECRET-KEY-1[QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L]{58}\b/g },
	{ name: "airtable-pat", prefix: 3, pattern: /\bpat[A-Za-z0-9]{14}\.[a-f0-9]{64}\b/gi },
	{ name: "artifactory-api-key", prefix: 4, pattern: /\bAKCp[A-Za-z0-9]{69}\b/g },
	{ name: "artifactory-reference-token", prefix: 5, pattern: /\bcmVmd[A-Za-z0-9]{59}\b/g },
	{ name: "atlassian", prefix: 6, pattern: /\bATATT3[A-Za-z0-9_=-]{186}\b/g },
	{ name: "harness-pat", prefix: 4, pattern: /\bpat\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9]{24}\.[A-Za-z0-9]{20}\b/g },
	{ name: "harness-sat", prefix: 4, pattern: /\bsat\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9]{24}\.[A-Za-z0-9]{20}\b/g },
	{ name: "linear", prefix: 8, pattern: /\blin_api_[A-Za-z0-9]{40}\b/g },
	{ name: "notion", prefix: 4, pattern: /\bntn_[0-9]{11}[A-Za-z0-9]{35}\b/g },
	{ name: "openshift", prefix: 7, pattern: /\bsha256~[A-Za-z0-9_-]{43}\b/g },
	{ name: "postman", prefix: 5, pattern: /\bPMAK-[a-f0-9]{24}-[a-f0-9]{34}\b/gi },
	{ name: "prefect", prefix: 4, pattern: /\bpnu_[A-Za-z0-9]{36}\b/g },
	{ name: "readme", prefix: 5, pattern: /\brdme_[a-z0-9]{70}\b/gi },
	{ name: "sourcegraph", prefix: 4, pattern: /\bsgp_(?:(?:[a-f0-9]{16}|local)_[a-f0-9]{40}|[a-f0-9]{40})\b/gi },
	{ name: "sonar", prefix: 4, pattern: /\b(?:squ_|sqp_|sqa_)[A-Za-z0-9_=-]{40}\b/g },

	// Package registries
	{ name: "npm-legacy", prefix: 4, pattern: /\bnpm_[a-z0-9]{36}\b/gi },
	{ name: "pypi", prefix: 5, pattern: /\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,1000}(?=$|[^A-Za-z0-9_-])/g },
	{ name: "rubygems", prefix: 9, pattern: /\brubygems_[a-f0-9]{48}\b/gi },

	// Messaging
	{ name: "discord-bot", pattern: /\b[A-Za-z0-9_-]{20,30}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{20,}\b/g },
	{ name: "discord-mfa", prefix: 4, pattern: /\bmfa\.[A-Za-z0-9_-]{40,120}\b/g },
	{ name: "slack-app", prefix: 5, pattern: /\bxapp-\d-[A-Za-z0-9]+-\d+-[A-Za-z0-9]+\b/g },
	{ name: "slack-bot", prefix: 5, pattern: /\bxoxb-[0-9]{8,14}(?:-[0-9]{10,13})?[A-Za-z0-9-]{18,80}\b/g },
	{ name: "slack-user", prefix: 5, pattern: /\bxox[pe](?:-[0-9]{10,13}){3}-[A-Za-z0-9-]{28,34}\b/g },
	{ name: "slack-config", prefix: 5, pattern: /\bxoxe\.xox[bp]-\d-[A-Za-z0-9]{163,166}\b/g },
	{ name: "slack-refresh", prefix: 5, pattern: /\bxoxe-\d-[A-Za-z0-9]{146}\b/g },
	{ name: "slack-legacy", prefix: 4, pattern: /\bxox[osar]-(?:\d-)?[A-Za-z0-9-]{8,80}\b/g },
	{ name: "telegram-bot", pattern: /\b[0-9]{5,16}:A[A-Za-z0-9_-]{34}\b/g },

	// Email / monitoring
	{ name: "mailgun", prefix: 4, pattern: /\bkey-[a-f0-9]{32}\b/gi },
	{ name: "new-relic-user", prefix: 5, pattern: /\bNRAK-[A-Za-z0-9]{27}\b/gi },
	{ name: "new-relic-insert", prefix: 5, pattern: /\bNRII-[A-Za-z0-9-]{32}\b/gi },
	{ name: "sendgrid", prefix: 3, pattern: /\bSG\.[A-Za-z0-9_.=-]{66}\b/g },
	{ name: "brevo", prefix: 8, pattern: /\bxkeysib-[a-f0-9]{64}-[A-Za-z0-9]{16}\b/gi },
	{ name: "sentry-org", prefix: 7, pattern: /\bsntrys_eyJpYXQiO[A-Za-z0-9+/]{10,200}(?:LCJyZWdpb25fdXJs|InJlZ2lvbl91cmwi|cmVnaW9uX3VybCI6)[A-Za-z0-9+/]{10,200}={0,2}_[A-Za-z0-9+/]{43}(?=$|[^A-Za-z0-9+/])/g },
	{ name: "sentry-user", prefix: 7, pattern: /\bsntryu_[a-f0-9]{64}\b/gi },

	// Commerce / payments / shipping
	{ name: "duffel", prefix: 7, pattern: /\bduffel_(?:test|live)_[A-Za-z0-9_=-]{43}\b/gi },
	{ name: "easypost-live", prefix: 4, pattern: /\bEZAK[A-Za-z0-9]{54}\b/gi },
	{ name: "easypost-test", prefix: 4, pattern: /\bEZTK[A-Za-z0-9]{54}\b/gi },
	{ name: "shippo", prefix: 7, pattern: /\bshippo_(?:live|test)_[A-Fa-f0-9]{40}\b/g },
	{ name: "shopify", prefix: 6, pattern: /\b(?:shpat_|shpca_|shppa_)[A-Fa-f0-9]{32}\b/g },
	{ name: "square", prefix: 7, pattern: /\bsq0atp-[A-Za-z0-9_-]{22,60}\b/g },
	{ name: "square-legacy", prefix: 4, pattern: /\bEAAA[A-Za-z0-9_-]{22,60}\b/g },
	{ name: "stripe", prefix: 8, pattern: /\b(?:sk|rk)_(?:test|live|prod)_[A-Za-z0-9]{10,99}\b/g },
	{ name: "twilio", prefix: 2, pattern: /\bSK[a-f0-9]{32}\b/gi },

	// Observability
	{ name: "dynatrace", prefix: 7, pattern: /\bdt0c01\.[A-Za-z0-9]{24}\.[A-Za-z0-9]{64}\b/g },

	// Private keys
	{ name: "private-key", prefix: 27, pattern: /-----BEGIN PRIVATE KEY-----[\s\S]+?-----END PRIVATE KEY-----/g },
	{ name: "rsa-private-key", prefix: 31, pattern: /-----BEGIN RSA PRIVATE KEY-----[\s\S]+?-----END RSA PRIVATE KEY-----/g },
	{ name: "ec-private-key", prefix: 30, pattern: /-----BEGIN EC PRIVATE KEY-----[\s\S]+?-----END EC PRIVATE KEY-----/g },
	{ name: "openssh-private-key", prefix: 35, pattern: /-----BEGIN OPENSSH PRIVATE KEY-----[\s\S]+?-----END OPENSSH PRIVATE KEY-----/g },
	{ name: "pgp-private-key", prefix: 37, pattern: /-----BEGIN PGP PRIVATE KEY BLOCK-----[\s\S]+?-----END PGP PRIVATE KEY BLOCK-----/g },
];

function maskSecret(secret, prefix) {
	const secretLength = secret.length,
		prefixLength = prefix ? prefix + 2 : 2,
		suffixLength = 2,
		suffixStart = secretLength - suffixLength;

	if (secretLength <= prefixLength + suffixLength) {
		return "x".repeat(secretLength);
	}

	let redacted = "";

	for (let i = 0; i < secretLength; i++) {
		const ch = secret[i]

		if (i < prefixLength || i >= suffixStart) {
			redacted += ch;

			continue;
		}

		switch (ch) {
			case ".":
			case "-":
			case "\n":
				redacted += ch;

				break;
			default:
				redacted += "x";
		}
	}

	return redacted;
}

function redactString(value) {
	for (const secret of patterns) {
		value = value.replace(secret.pattern, found => {
			return maskSecret(found, secret.prefix);
		});
	}

	return value;
}

function redact(value) {
	if (!value || typeof value !== "object") {
		return;
	}

	for (const [key, child] of Object.entries(value)) {
		if (typeof child === "string") {
			value[key] = redactString(child);

			continue;
		}

		redact(child);
	}
}

function redactMessages(event) {
	redact(event.messages);
}

export default Plugin.define({
	id: "coalaura.secret-redactor",

	async setup(ctx) {
		await ctx.session.hook("context", redactMessages);
		await ctx.session.hook("compaction", redactMessages);
		await ctx.session.hook("generate", redactMessages);
		await ctx.session.hook("title", redactMessages);
	},
});