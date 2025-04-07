#!/usr/bin/env python

"""Set variables for Azure DevOps Pipelines.

Create a variable group called $AZURE_VARIABLE_GROUP_NAME (if it doesn't exist)
and set all the variables needed for the RHTAP pipeline.

Before running this script, source your .env or .envrc file.

Requires python>=3.9 (just the standard library).
"""

import io
import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, NamedTuple, Optional

logging.basicConfig(
    level=logging.DEBUG, format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)


class AzureAPI:
    def __init__(self, token: str, org_name: str, project_name: str) -> None:
        self._token = token
        self._org_name = org_name
        self._project_name = project_name

    def get_variable_group(self, name: str) -> Optional[dict[str, Any]]:
        # https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/get-variable-groups?view=azure-devops-rest-7.1
        resp = self._do_request(
            "GET",
            f"{self._project_name}/_apis/distributedtask/variablegroups",
            query={"groupName": name},
        )
        if not (groups := resp["value"]):
            return None

        return groups[0]

    def add_variable_group(self, variable_group: dict[str, Any]) -> dict[str, Any]:
        # https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-rest-7.1
        return self._do_request(
            "POST",
            "_apis/distributedtask/variablegroups",
            data=self._add_project_reference(variable_group),
        )

    def update_variable_group(
        self, id: int, variable_group: dict[str, Any]
    ) -> dict[str, Any]:
        # https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/update?view=azure-devops-rest-7.1
        return self._do_request(
            "PUT",
            f"_apis/distributedtask/variablegroups/{id}",
            data=self._add_project_reference(variable_group),
        )

    def _do_request(
        self,
        method: str,
        path: str,
        query: Optional[dict[str, str]] = None,
        data: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        if query is not None:
            query = query.copy()
        else:
            query = {}

        query.setdefault("api-version", "7.1")

        if data:
            data_buffer = io.BytesIO(json.dumps(data).encode())
        else:
            data_buffer = None

        query_str = urllib.parse.urlencode(query)
        url = f"https://dev.azure.com/{self._org_name}/{path}?{query_str}"

        request = urllib.request.Request(url, method=method)
        request.add_header("Authorization", f"Bearer {self._token}")
        request.add_header("Content-Type", "application/json")

        log.debug("%s %s", method, url)

        try:
            with urllib.request.urlopen(request, data=data_buffer) as response:
                log.debug("Response status: %d", response.status)
                return json.load(response)
        except urllib.error.HTTPError as e:
            msg = e.read().decode()
            log.error("Error status: %d, message: %s", e.status, msg or "<empty>")
            raise

    def _add_project_reference(self, variable_group: dict[str, Any]) -> dict[str, Any]:
        variable_group = variable_group.copy()
        if not variable_group.get("variableGroupProjectReferences"):
            variable_group["variableGroupProjectReferences"] = []

        for ref in variable_group["variableGroupProjectReferences"]:
            if ref["projectReference"].get("name") == self._project_name:
                # already has the project reference
                return variable_group

        variable_group["variableGroupProjectReferences"].append(
            {
                "name": variable_group["name"],
                "projectReference": {"name": self._project_name},
            }
        )
        return variable_group


class VarFromEnv(NamedTuple):
    name: str
    is_secret: bool = True

    def get_value(self) -> str:
        return os.environ.get(self.name, "")


def get_required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"Environment variable missing or empty: {name}")
    return value


def main() -> None:
    token = get_required_env("AZURE_DEVOPS_EXT_PAT")
    org_name = get_required_env("AZURE_ORGANIZATION")
    project_name = get_required_env("AZURE_PROJECT")
    vargroup_name = get_required_env("AZURE_VARIABLE_GROUP_NAME")

    client = AzureAPI(token=token, org_name=org_name, project_name=project_name)

    variables_to_set = [
        VarFromEnv("ROX_CENTRAL_ENDPOINT", is_secret=False),
        VarFromEnv("ROX_API_TOKEN"),
        VarFromEnv("GITOPS_AUTH_USERNAME"),
        VarFromEnv("GITOPS_AUTH_PASSWORD"),
        VarFromEnv("QUAY_IO_CREDS_USR", is_secret=False),
        VarFromEnv("QUAY_IO_CREDS_PSW"),
        VarFromEnv("IMAGE_REGISTRY", is_secret=False),
        VarFromEnv("IMAGE_REGISTRY_USER", is_secret=False),
        VarFromEnv("IMAGE_REGISTRY_PASSWORD"),
        VarFromEnv("COSIGN_SECRET_PASSWORD"),
        VarFromEnv("COSIGN_SECRET_KEY"),
        VarFromEnv("COSIGN_PUBLIC_KEY", is_secret=False),
        VarFromEnv("TRUSTIFICATION_BOMBASTIC_API_URL", is_secret=False),
        VarFromEnv("TRUSTIFICATION_OIDC_ISSUER_URL", is_secret=False),
        VarFromEnv("TRUSTIFICATION_OIDC_CLIENT_ID", is_secret=False),
        VarFromEnv("TRUSTIFICATION_OIDC_CLIENT_SECRET"),
        VarFromEnv("TRUSTIFICATION_SUPPORTED_CYCLONEDX_VERSION", is_secret=False),
    ]

    variables = {}

    for var in variables_to_set:
        value = var.get_value()
        variables[var.name] = {"value": value, "isSecret": var.is_secret}
        if value and var.is_secret:
            log.info("Will set %s=<redacted>", var.name)
        else:
            log.info("Will set %s=%s", var.name, value)

    log.info("Searching for '%s' variable group", vargroup_name)
    var_group = client.get_variable_group(vargroup_name)
    if not var_group:
        log.info("Creating a new variable group")
        var_group = client.add_variable_group(
            {"type": "Vsts", "name": vargroup_name, "variables": variables}
        )
    else:
        log.info("Updating existing variable group (id %d)", var_group["id"])
        var_group["variables"].update(variables)
        var_group = client.update_variable_group(var_group["id"], var_group)

    print(json.dumps(var_group, indent=2))


if __name__ == "__main__":
    main()
