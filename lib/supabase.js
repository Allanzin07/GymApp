import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  'SUA_SUPABASE_URL',
  'SUA_ANON_PUBLIC_KEY'
)
