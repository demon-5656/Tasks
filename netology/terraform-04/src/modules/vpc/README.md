## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [yandex_vpc_network.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_network) | resource |
| [yandex_vpc_subnet.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env_name"></a> [env\_name](#input\_env\_name) | Environment/network name | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnets to create | <pre>list(object({<br/>    zone = string<br/>    cidr = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | Created network ID |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Created network name |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs by zone |
| <a name="output_subnet_info"></a> [subnet\_info](#output\_subnet\_info) | Short subnet info by zone |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Created subnets |
