# 📘 Terraform Modular: Boas Práticas com Variáveis, Outputs e Data Sources

Este repositório segue uma arquitetura modular no Terraform. Abaixo estão as orientações e boas práticas para o uso correto de **variáveis**, **outputs** e **data sources** entre o `main.tf` principal (nível root) e os módulos reutilizáveis.

---

## 🔁 Uso de Variáveis Entre Root e Módulos

### ✔️ Definir variáveis no root (`main.tf`) e passar para módulos

```hcl
# main.tf (nível root)
variable "env" {
  description = "Ambiente de deploy"
  type        = string
}

module "app" {
  source = "./modules/app"
  env    = var.env
}
```

```hcl
# ./modules/app/variables.tf
variable "env" {
  description = "Ambiente"
  type        = string
}
```

📌 **Importante**: As variáveis **não são propagadas automaticamente** para os módulos. Elas precisam ser **explicitamente passadas** no bloco `module`.

---

## 🔗 Uso de Outputs Entre Módulos

### ✔️ Produzir um output em um módulo

```hcl
# ./modules/network/outputs.tf
output "vnet_id" {
  value = azurerm_virtual_network.my_vnet.id
}
```

### ✔️ Consumir o output no root e repassar para outro módulo

```hcl
# main.tf
module "network" {
  source = "./modules/network"
}

module "app" {
  source  = "./modules/app"
  vnet_id = module.network.vnet_id
}
```

```hcl
# ./modules/app/variables.tf
variable "vnet_id" {
  type = string
}
```

📌 **Regra**: Outputs são acessados via `module.<nome>.output_name`, e devem ser **repassados explicitamente** a outros módulos.

---

## 🗂️ Uso de `data` Sources Entre Módulos

### 🔸 Quando o `data` está no root e precisa ser usado no módulo

```hcl
# main.tf
data "azurerm_virtual_network" "default" {
  name                = "vnet-principal"
  resource_group_name = "rg-principal"
}

module "app" {
  source  = "./modules/app"
  vnet_id = data.azurerm_virtual_network.default.id
}
```

```hcl
# ./modules/app/variables.tf
variable "vnet_id" {
  type = string
}
```

### 🔸 Quando o `data` é usado diretamente no módulo

```hcl
# ./modules/app/data.tf
data "azurerm_virtual_network" "default" {
  name                = var.vnet_name
  resource_group_name = var.rg_name
}
```

```hcl
# ./modules/app/variables.tf
variable "vnet_name" {
  type = string
}
variable "rg_name" {
  type = string
}
```

📌 **Dica**: Use `data` dentro do módulo quando quiser encapsular a lógica. Use no root quando o valor for compartilhado entre múltiplos módulos.

---

## ✅ Boas Práticas

- Sempre declare os `variables.tf` e `outputs.tf` nos módulos.
- Evite hardcoding de valores nos módulos — tudo deve vir via `variables`.
- Centralize valores globais no root (`main.tf`) e **propague explicitamente**.
- Use arquivos `terraform.tfvars` ou `*.auto.tfvars` para facilitar parametrização.

---

## 📂 Estrutura de Diretórios Recomendada

```
.
├── main.tf
├── variables.tf
├── terraform.tfvars
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── data.tf
```

---

## 🧠 Conclusão

Terraform modular favorece a reutilização, clareza e escalabilidade. Seguindo essas práticas, o código permanece organizado, previsível e fácil de manter.
