-- ============================================================================
-- Index Creation Script: TN-1086
-- Purpose: Create composite index for EURUSD extraction from historical SWIFT messages
-- Index: idx_sb_snp_mensajes_depdate
-- 
-- Performance Target: < 100ms for /DEPOSITDATE/YYMMDD lookups
-- Usage: SELECT nro_referencia FROM sb_snp_mensajes 
--        WHERE campo = '79' AND valor LIKE '%/DEPOSITDATE/200615%'
--
-- Created: 2026-07-02
-- Status: Phase 2 (WU-1)
-- ============================================================================

-- Step 1: Create composite index (campo, valor, nro_referencia)
-- This index optimizes queries filtering by:
--   1. campo (tag identifier, e.g., '79' for field 79)
--   2. valor (SWIFT tag content containing /DEPOSITDATE/, /DEPOSITTYPE/, /DEPOSITVALUE/)
--   3. nro_referencia (transfer reference - for uniqueness verification)

CREATE INDEX IT.IDX_SB_SNP_MENSAJES_DEPDATE 
ON IT.SB_SNP_MENSAJES (CAMPO, VALOR, NRO_REFERENCIA)
TABLESPACE IT_IND
PCTFREE 10
INITRANS 2
MAXTRANS 255
STORAGE (
  INITIAL 64K
  NEXT 1M
  MINEXTENTS 1
  MAXEXTENTS UNLIMITED
);
