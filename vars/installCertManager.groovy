/**
 * installCertManager.groovy  –  Declarative step to install or upgrade cert-manager
 *
 * Typical call:
 *     installCertManager(
 *         version: 'v1.18.1',
 *         namespace: 'cert-manager',
 *         helmTimeout: '5m',
 *         rolloutTimeout: '120s'
 *     )
 *
 * Parameters (all optional – sensible defaults provided):
 *   version         Tag of the cert-manager release to deploy
 *   namespace       Namespace to install into (created if missing)
 *   helmTimeout     How long Helm waits for Kubernetes objects to become ready
 *   rolloutTimeout  How long kubectl waits for each Deployment rollout
 *
 * The step is intentionally idempotent:
 *  • `kubectl apply` only (re-)creates CRDs when they differ.
 *  • `helm upgrade --install` is safe to run repeatedly.
 */
def call(Map cfg = [:]) {

    // ---------- default values ----------
    cfg = [
        version        : cfg.get('version',        'v1.18.1'),
        namespace      : cfg.get('namespace',      'cert-manager'),
        helmTimeout    : cfg.get('helmTimeout',    '5m'),
        rolloutTimeout : cfg.get('rolloutTimeout', '120s')
    ]

    // ---------- human-readable banner ----------
    echo "Installing cert-manager ${cfg.version} in namespace '${cfg.namespace}' …"

    // ---------- executable block ----------
    sh """
        set -euo pipefail

        # ---------------------------------------------------------------------
        # 1. Install Custom Resource Definitions (CRDs)
        #    Using kubectl instead of Helm makes upgrades deterministic because
        #    CRDs are cluster-scoped objects that rarely change once applied.
        # ---------------------------------------------------------------------
        kubectl apply -f \\
          https://github.com/cert-manager/cert-manager/releases/download/${cfg.version}/cert-manager.crds.yaml

        # ---------------------------------------------------------------------
        # 2. Add / update Helm repo
        #    '|| true' lets the command succeed even if the repo already exists.
        # ---------------------------------------------------------------------
        helm repo add jetstack https://charts.jetstack.io || true
        helm repo update

        # ---------------------------------------------------------------------
        # 3. Install or upgrade cert-manager
        #    --create-namespace keeps the command idempotent.
        # ---------------------------------------------------------------------
        helm upgrade --install cert-manager jetstack/cert-manager \\
            --namespace ${cfg.namespace} \\
            --create-namespace \\
            --version ${cfg.version} \\
            --wait --timeout ${cfg.helmTimeout}

        # ---------------------------------------------------------------------
        # 4. Block until all three cert-manager Deployments finish rolling out.
        #    This protects downstream stages that rely on the webhooks.
        # ---------------------------------------------------------------------
        for deploy in cert-manager cert-manager-webhook cert-manager-cainjector; do
          echo "Waiting for rollout of \$deploy …"
          kubectl rollout status deployment/\$deploy \\
            -n ${cfg.namespace} --timeout=${cfg.rolloutTimeout}
        done
    """
}