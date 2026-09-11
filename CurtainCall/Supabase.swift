import Foundation
import Supabase

/// Shared client for CurtainCall. This publishable key is intended for public apps.
/// Database access must be protected by server-side RLS policies.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://dkqswnfiyvaefroklwmy.supabase.co")!,
    supabaseKey: "sb_publishable_NGbl6FLe3Okirj098NUURw_BiPecHnJ"
)
