# Multi-Tenant White-Label App Builds

Automated Android & iOS White-Label Build Factory for multi-tenant SaaS client applications.

## Applications

| Directory | Default Name | Default Package ID | Description |
| :--- | :--- | :--- | :--- |
| `kiosk-terminal` | **Kiosk Terminal** | `com.multitenant.kiosk` | Self-Service Touch Kiosk Terminal (Flutter Android) |
| `print-bridge` | **Thermal Print Bridge** | `com.multitenant.printbridge` | Thermal ESC/POS LAN & Bluetooth Print Bridge (Flutter Android) |
| `delivery-driver` | **Delivery Driver** | `com.multitenant.driver` | Multi-Tenant Delivery Driver & Telemetry Client (Flutter Android/iOS) |

## White-Label CI/CD Parameters (`workflow_dispatch`)

All build workflows support on-demand white-label customization without modifying source code:
- `tenant_slug`: Unique identifier for the tenant release artifact (e.g. `sabor-latino`)
- `app_name`: Custom display name injected into AndroidLauncher and Flutter runtime
- `app_id`: Custom Android `applicationId` (e.g. `com.saborlatino.kiosk`)
- `api_url`: Tenant or cloud GraphQL/REST API endpoint
- `ws_url`: Tenant or cloud WebSocket GraphQL subscriptions endpoint
- `primary_color`: Brand primary hex color (e.g. `#EA581E`)
- `surface_color`: Brand surface hex color (e.g. `#F8FAFC`)
- `logo_url`: Public HTTPS URL for tenant brand logo & launcher icon generation
