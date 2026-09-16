/// Only fixed operation names are eligible for diagnostics. Never attach save,
/// transaction, product, player, or board identifiers to a report.
enum DiagnosticOperation: String, Sendable {
    case progressLoad = "progress_load"
    case progressSave = "progress_save"
    case storeLoad = "store_load"
    case coinDelivery = "coin_delivery"
}
