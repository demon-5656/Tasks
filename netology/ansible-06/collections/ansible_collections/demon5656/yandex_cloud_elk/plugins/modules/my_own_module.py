#!/usr/bin/python
from __future__ import annotations

from pathlib import Path

from ansible.module_utils.basic import AnsibleModule


DOCUMENTATION = r'''
---
module: my_own_module

short_description: Create a text file with selected content
version_added: "1.0.0"

description:
  - Creates or updates a text file on a managed host.
  - The module is idempotent and reports changed only when file content changes.

options:
  path:
    description:
      - Path to the target text file.
    required: true
    type: path
  content:
    description:
      - Text content for the target file.
    required: true
    type: str
  mode:
    description:
      - File mode to apply after create or update.
    required: false
    type: str
    default: "0644"

author:
  - demon-5656
'''

EXAMPLES = r'''
- name: Create demo file
  demon5656.yandex_cloud_elk.my_own_module:
    path: /tmp/netology_module.txt
    content: "hello from my module"
'''

RETURN = r'''
path:
  description: File path managed by module.
  type: str
  returned: always
  sample: /tmp/netology_module.txt
content:
  description: Content that should be stored in the file.
  type: str
  returned: always
  sample: hello from my module
previous_content:
  description: Previous file content, if the file existed.
  type: str
  returned: when file existed
  sample: old text
message:
  description: Human readable module result.
  type: str
  returned: always
  sample: file updated
'''


def build_result(path: str, content: str, previous_content: str | None, changed: bool, message: str) -> dict:
    result = {
        "changed": changed,
        "path": path,
        "content": content,
        "message": message,
    }
    if previous_content is not None:
        result["previous_content"] = previous_content
    return result


def run_module() -> None:
    module = AnsibleModule(
        argument_spec={
            "path": {"type": "path", "required": True},
            "content": {"type": "str", "required": True, "no_log": False},
            "mode": {"type": "str", "required": False, "default": "0644"},
        },
        supports_check_mode=True,
    )

    target = Path(module.params["path"])
    content = module.params["content"]
    mode = int(module.params["mode"], 8)

    previous_content = None
    if target.exists():
        if not target.is_file():
            module.fail_json(msg=f"{target} exists and is not a file")
        previous_content = target.read_text(encoding="utf-8")

    changed = previous_content != content
    if not changed:
        module.exit_json(**build_result(str(target), content, previous_content, False, "file already has requested content"))

    if module.check_mode:
        module.exit_json(**build_result(str(target), content, previous_content, True, "file would be updated"))

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    target.chmod(mode)

    message = "file created" if previous_content is None else "file updated"
    module.exit_json(**build_result(str(target), content, previous_content, True, message))


def main() -> None:
    run_module()


if __name__ == "__main__":
    main()
