/**
 * installActionsRunnerController.groovy  – Install or upgrade GitHub
 * Actions Runner Controller (ARC) in an EKS cluster.
 *
 * Example call:
 *     installActionsRunnerController(
 *         version: '0.23.7',
 *         namespace: 'actions-runner-system',
 *         helmTimeout: '5m',
 *         githubAppCertId: 'GITHUB_APP_PRIVATE_KEY',
 *         githubAppIdId: 'github_app_id',
 *         githubAppInstallationId: 'github_app_installation_id'
 *     )
 *
 * Parameters                                              (default)         Purpose
 * -----------------------------------------------------------------------------------------
 * version                  String  – chart / CR release   "0.23.7"          Pin for repeatable builds
 * namespace                String  – K8s namespace        "actions-runner-system"
 * helmTimeout              String  – Helm wait timeout    "5m"
 * githubAppCertId          String  – Jenkins credential   *mandatory*       → file credential (PEM)
 * githubAppIdId            String  – Jenkins credential   *mandatory*       → secret text
 * githubAppInstallationId  String  – Jenkins credential   *mandatory*       → secret text
 *
 * The step takes care of:
 *   • Adding / updating the ARC Helm repo
 *   • Running `helm upgrade --install` idempotently
 *   • Wiring the GitHub App credentials into the chart
 *
 * NOTE: This helper **wraps its own `withCredentials` block**, so callers
 *       do not need to repeat that boilerplate.
 */
def call(Map cfg = [:]) {

    //default values ───────────── 
    cfg = [
        version                 : cfg.get('version',                 '0.23.7'),
        namespace               : cfg.get('namespace',               'actions-runner-system'),
        helmTimeout             : cfg.get('helmTimeout',             '5m'),
        githubAppCertId         : cfg.githubAppCertId      ?: error('githubAppCertId missing'),
        githubAppIdId           : cfg.githubAppIdId        ?: error('githubAppIdId missing'),
        githubAppInstallationId : cfg.githubAppInstallationId ?: error('githubAppInstallationId missing')
    ]

    echo "Installing Actions Runner Controller ${cfg.version} in '${cfg.namespace}' …"

    withCredentials([
        file   (credentialsId: cfg.githubAppCertId,         variable: 'GITHUB_APP_PEM_PATH'),
        string (credentialsId: cfg.githubAppIdId,           variable: 'GITHUB_APP_ID'),
        string (credentialsId: cfg.githubAppInstallationId, variable: 'GITHUB_APP_INSTALLATION_ID')
    ]) {

        sh """
            set -euo pipefail

            #--------------------------------------------------------------
            # 1. Add / update Helm repository that hosts ARC.
            #--------------------------------------------------------------
            helm repo add actions-runner-controller \\
              https://actions-runner-controller.github.io/actions-runner-controller || true
            helm repo update

            #--------------------------------------------------------------
            # 2. Install or upgrade the chart.  All auth settings are
            #    provided via --set / --set-file so no extra values.yaml
            #    is required.
            #--------------------------------------------------------------
            #───────────────────── Helm install of Actions Runner Controller ─────────────────────
            # The ARC chart must authenticate to GitHub as a GitHub App in order to:
            #   • register self-hosted runners,
            #   • poll for work, and
            #   • update runner status.
            #
            # We therefore pass the three pieces of the GitHub App credential bundle:
            #
            #   ── authSecret.create=true
            #        Tells the chart to generate a Kubernetes Secret named `controller-manager-auth-secret`
            #        (default) instead of expecting us to pre-create it.
            #
            #   ── authSecret.github_app_id
            #        The *App ID* → a numeric identifier assigned by GitHub when we create the App
            #        (e.g. 123456). ARC includes this in authentication payloads so GitHub knows
            #        which App is calling.
            #
            #   ── authSecret.github_app_installation_id
            #        The *Installation ID* → each installation of an App in an org or repo gets
            #        its own numeric ID. ARC needs this to scope API calls to the correct org/repo.
            #
            #   ── authSecret.github_app_private_key
            #        Your App’s PEM-formatted private key. ARC signs JSON Web Tokens (JWTs) with
            #        this key to obtain short-lived access tokens from GitHub.
            #
            # All three fields land in a single Kubernetes Secret, mounted into the ARC Controller
            # pods. The controller reads them on startup and re-authenticates automatically when
            # tokens expire.
            
            helm upgrade --install arc actions-runner-controller/actions-runner-controller \\
              --namespace ${cfg.namespace} \\
              --create-namespace \\
              --version ${cfg.version} \\
              --wait --timeout ${cfg.helmTimeout} \\
              --set authSecret.create=true \\
              --set authSecret.github_app_id=\${GITHUB_APP_ID} \\
              --set authSecret.github_app_installation_id=\${GITHUB_APP_INSTALLATION_ID} \\
              --set-file authSecret.github_app_private_key=\${GITHUB_APP_PEM_PATH}
        """
    }
}

// helper: fail early with a clear message 
def error(String msg) {
    error "installActionsRunnerController ▶ ${msg}"
}