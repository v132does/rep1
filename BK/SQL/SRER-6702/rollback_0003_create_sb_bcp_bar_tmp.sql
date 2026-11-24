-- =============================================================================
-- Script  : rollback_0003_create_sb_bcp_bar_tmp.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: 0003_create_sb_bcp_bar_tmp.sql
-- =============================================================================

-- El DROP TABLE revoca automaticamente los GRANTs a IT_CONSULTAS e IT_TEMPORAL
DROP PUBLIC SYNONYM SB_BCP_BAR_TMP;
DROP TABLE IT.SB_BCP_BAR_TMP PURGE;

-- Verificacion: ambas deben dar 0
SELECT COUNT(*) AS staging_existe
FROM   all_tables
WHERE  owner = 'IT' AND table_name = 'SB_BCP_BAR_TMP';

SELECT COUNT(*) AS synonym_existe
FROM   all_synonyms
WHERE  synonym_name = 'SB_BCP_BAR_TMP';
